#ifndef APICLIENT_H
#define APICLIENT_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkReply>
#include <QPointer>
#include <QMap>
#include <QDateTime>
#include <functional>

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
 * @brief Types of API requests for signal routing.
 */
enum class RequestType {
    Profile,
    MyProfile,
    Servers,
    ServerDetails,
    Channels,
    ChannelDetails,
    Messages,
    SendMessage
};

/**
 * @brief Metadata for a pending request.
 */
struct PendingRequest {
    QPointer<QNetworkReply> reply;
    QString endpoint;      // e.g., "/api/v1/profile/user123"
    QString cacheKey;      // Key for caching result (empty = no cache)
    RequestType type;      // Type of request for signal routing
    QVariantMap context;   // Additional context (e.g., userId, serverId)
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
 * - Modular: each API domain is in a separate .cpp file
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
    // Profile API (implemented in profile.cpp)
    // ========================================================================
    
    int getMyProfile();
    int getProfile(const QString& userId, bool useCache = true);
    
    // ========================================================================
    // Servers API (implemented in servers.cpp)
    // ========================================================================
    
    /**
     * @brief Fetch all servers the current user is a member of.
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serversFetched signal
     */
    int getServers(bool useCache = true);
    
    /**
     * @brief Fetch details for a specific server.
     * @param serverId The server ID to fetch
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serverDetailsFetched signal
     */
    int getServerDetails(const QString& serverId, bool useCache = true);
    
    /**
     * @brief Fetch all channels for a specific server.
     * @param serverId The server ID to fetch channels for
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with channelsFetched signal
     */
    int getChannels(const QString& serverId, bool useCache = true);
    
    /**
     * @brief Fetch details for a specific channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with channelDetailsFetched signal
     */
    int getChannelDetails(const QString& serverId, const QString& channelId, bool useCache = true);

    // ========================================================================
    // Messages API (implemented in messages.cpp)
    // ========================================================================
    
    /**
     * @brief Fetch messages for a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param limit Maximum number of messages to fetch (default: 50)
     * @param before Fetch messages before this message ID (for pagination)
     * @return Request ID for matching with messagesFetched signal
     */
    int getMessages(const QString& serverId, const QString& channelId, 
                    int limit = 50, const QString& before = QString());
    
    /**
     * @brief Send a message to a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param text The message text
     * @param replyToId Optional message ID to reply to
     * @return Request ID for matching with messageSent signal
     */
    int sendMessage(const QString& serverId, const QString& channelId,
                    const QString& text, const QString& replyToId = QString());

    // ========================================================================
    // Cache Management (implemented in cache.cpp)
    // ========================================================================
    
    void setCacheTTL(int seconds) { m_cacheTTLSeconds = seconds; }
    int cacheTTL() const { return m_cacheTTLSeconds; }
    
    void clearCache();
    void clearCacheFor(const QString& cacheKey);
    bool hasCachedData(const QString& cacheKey) const;
    
    // Legacy profile-specific cache methods
    bool hasCachedProfile(const QString& userId) const { return hasCachedData(userId); }

    // ========================================================================
    // Request Management (implemented in apiclient.cpp)
    // ========================================================================
    
    void cancelRequest(int requestId);
    void cancelAllRequests();
    bool isRequestPending(int requestId) const;

signals:
    // ========================================================================
    // Profile Signals
    // ========================================================================
    void profileFetched(int requestId, const QVariantMap& profile);
    void profileFetchFailed(int requestId, const QString& error);
    void myProfileFetched(const QVariantMap& profile);
    void myProfileFetchFailed(const QString& error);
    
    // ========================================================================
    // Server Signals
    // ========================================================================
    void serversFetched(int requestId, const QVariantList& servers);
    void serversFetchFailed(int requestId, const QString& error);
    void serverDetailsFetched(int requestId, const QVariantMap& server);
    void serverDetailsFetchFailed(int requestId, const QString& error);
    
    // ========================================================================
    // Channel Signals
    // ========================================================================
    void channelsFetched(int requestId, const QString& serverId, const QVariantList& channels);
    void channelsFetchFailed(int requestId, const QString& serverId, const QString& error);
    void channelDetailsFetched(int requestId, const QVariantMap& channel);
    void channelDetailsFetchFailed(int requestId, const QString& error);
    
    // ========================================================================
    // Message Signals
    // ========================================================================
    void messagesFetched(int requestId, const QString& serverId, const QString& channelId, 
                         const QVariantList& messages);
    void messagesFetchFailed(int requestId, const QString& serverId, const QString& channelId, 
                             const QString& error);
    void messageSent(int requestId, const QVariantMap& message);
    void messageSendFailed(int requestId, const QString& error);

protected:
    // ========================================================================
    // Internal Request Infrastructure
    // ========================================================================
    
    /**
     * @brief Start a GET request with full control over parameters.
     * @param type The request type for signal routing
     * @param endpoint The API endpoint (e.g., "/api/v1/servers")
     * @param cacheKey Key for caching (empty string = no caching)
     * @param useCache Whether to check cache first
     * @param context Additional context to store with the request
     * @return Request ID
     */
    int startGetRequest(RequestType type, const QString& endpoint, 
                        const QString& cacheKey = QString(), bool useCache = true,
                        const QVariantMap& context = {});
    
    /**
     * @brief Called when a request completes. Routes to appropriate signal.
     * @param requestId The completed request ID
     * @param result The API result
     */
    void handleRequestComplete(int requestId, const ApiResult& result);
    
    // Cache helpers
    bool checkCache(const QString& cacheKey, QVariantMap& outData) const;
    void updateCache(const QString& cacheKey, const QVariantMap& data);
    
    // Request ID generator
    int generateRequestId() { return m_nextRequestId++; }

private slots:
    void onReplyFinished();

private:
    NetworkClient* m_networkClient;
    QString m_baseUrl;
    
    // Request tracking
    int m_nextRequestId = 1;
    QMap<int, PendingRequest> m_pendingRequests;
    QMap<QString, QList<int>> m_endpointToRequests;
    
    // Generic cache: cacheKey -> CacheEntry
    QMap<QString, CacheEntry> m_cache;
    int m_cacheTTLSeconds = 60;
    
    // Internal helpers
    void cleanupRequest(int requestId);
    void emitSuccess(int requestId, const PendingRequest& req, const QVariantMap& data);
    void emitFailure(int requestId, const PendingRequest& req, const QString& error);
};

#endif // APICLIENT_H