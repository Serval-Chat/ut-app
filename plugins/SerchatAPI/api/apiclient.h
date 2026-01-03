#ifndef APICLIENT_H
#define APICLIENT_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkReply>
#include <QPointer>
#include <QMap>
#include <QCache>
#include <QDateTime>

#include "../apibase.h"

class NetworkClient;

/**
 * @brief Cached data entry with TTL support.
 */
struct CacheEntry {
    QVariantMap data;
    QDateTime expiry;
    
    bool isValid() const { return QDateTime::currentDateTime() < expiry; }
};

/**
 * @brief Main API client for business logic endpoints.
 * 
 * Handles all non-authentication API calls. Uses NetworkClient for HTTP
 * operations - NetworkClient automatically handles auth token injection.
 * 
 * Design notes:
 * - Supports unlimited concurrent requests via request IDs
 * - Built-in caching with configurable TTL for efficiency on slow devices
 * - Request IDs allow QML to track specific async operations
 * - Deduplication: identical in-flight requests share the same network call
 * 
 * Usage from QML:
 *   var requestId = SerchatAPI.getProfile("user123")
 *   // Listen for profileFetched(requestId, profile) or profileFetchFailed(requestId, error)
 */
class ApiClient : public ApiBase {
    Q_OBJECT

public:
    explicit ApiClient(NetworkClient* networkClient, QObject* parent = nullptr);
    ~ApiClient();

    /// Set the base URL for API requests
    void setBaseUrl(const QString& baseUrl) { m_baseUrl = baseUrl; }
    QString baseUrl() const { return m_baseUrl; }

    // ========================================================================
    // Profile API
    // ========================================================================
    
    /**
     * @brief Fetch the current user's profile.
     * @return Request ID that will be included in the result signal
     */
    int getMyProfile();
    
    /**
     * @brief Fetch a specific user's profile by ID.
     * @param userId The user ID to fetch (use "me" for current user)
     * @param useCache If true, return cached data if available and valid
     * @return Request ID that will be included in the result signal
     */
    int getProfile(const QString& userId, bool useCache = true);
    
    // ========================================================================
    // Cache Management
    // ========================================================================
    
    /// Set cache TTL in seconds (default: 60)
    void setCacheTTL(int seconds) { m_cacheTTLSeconds = seconds; }
    int cacheTTL() const { return m_cacheTTLSeconds; }
    
    /// Clear all cached data
    void clearCache();
    
    /// Clear cached data for a specific user
    void clearCacheFor(const QString& userId);
    
    /// Check if valid cached data exists for a user
    bool hasCachedProfile(const QString& userId) const;

    // ========================================================================
    // Request Management
    // ========================================================================
    
    /// Cancel a pending request by ID
    void cancelRequest(int requestId);
    
    /// Cancel all pending requests
    void cancelAllRequests();
    
    /// Check if a request is still pending
    bool isRequestPending(int requestId) const;

signals:
    // Profile signals - include requestId for QML to match requests
    void profileFetched(int requestId, const QVariantMap& profile);
    void profileFetchFailed(int requestId, const QString& error);
    
    // Convenience signals without requestId (for simple use cases)
    void myProfileFetched(const QVariantMap& profile);
    void myProfileFetchFailed(const QString& error);

private slots:
    void onReplyFinished();

private:
    NetworkClient* m_networkClient;
    QString m_baseUrl;
    
    // Request tracking
    int m_nextRequestId = 1;
    
    // Maps requestId -> {reply, endpoint, params}
    struct PendingRequest {
        QPointer<QNetworkReply> reply;
        QString endpoint;      // e.g., "/api/v1/profile/user123"
        QString cacheKey;      // Key for caching result
        bool isMyProfile;      // Special handling for "me" endpoint
    };
    QMap<int, PendingRequest> m_pendingRequests;
    
    // Maps endpoint -> list of requestIds waiting for this endpoint
    // Used for request deduplication
    QMap<QString, QList<int>> m_endpointToRequests;
    
    // Profile cache: userId -> CacheEntry
    QMap<QString, CacheEntry> m_profileCache;
    int m_cacheTTLSeconds = 60;
    
    // Internal helpers
    int generateRequestId() { return m_nextRequestId++; }
    void completeRequest(int requestId, bool success, const QVariantMap& data, const QString& error);
    void cleanupRequest(int requestId);
};

#endif // APICLIENT_H