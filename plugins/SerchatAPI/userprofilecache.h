#ifndef USERPROFILECACHE_H
#define USERPROFILECACHE_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

class ApiClient;

/**
 * @brief Global cache for user profiles.
 * 
 * This singleton cache provides centralized user profile storage and lookup,
 * eliminating the need to pass profile data through component hierarchies.
 * 
 * Features:
 * - O(1) profile lookup by user ID
 * - Automatic fetch for unknown profiles
 * - Version counter for QML binding invalidation
 * - Deduplication of in-flight fetch requests
 * - Helper methods for common display name/avatar lookups
 * 
 * Usage in QML:
 *   var profile = SerchatAPI.userProfileCache.getProfile(userId)
 *   var name = SerchatAPI.userProfileCache.getDisplayName(userId)
 *   var avatar = SerchatAPI.userProfileCache.getAvatarUrl(userId)
 */
class UserProfileCache : public QObject {
    Q_OBJECT
    
    // Version counter triggers QML re-rendering when cache updates
    Q_PROPERTY(int version READ version NOTIFY versionChanged)

public:
    explicit UserProfileCache(QObject *parent = nullptr);
    ~UserProfileCache() override = default;
    
    /**
     * @brief Set the API client for fetching unknown profiles.
     * Must be called during initialization.
     */
    void setApiClient(ApiClient* apiClient);
    
    /**
     * @brief Set the base URL for constructing full avatar URLs.
     */
    void setBaseUrl(const QString& baseUrl);
    
    // ========================================================================
    // QML-accessible methods
    // ========================================================================
    
    /**
     * @brief Get profile data by user ID.
     * @param userId The user's unique ID
     * @return QVariantMap with profile data or empty if not found
     * 
     * If the profile is not in cache, automatically triggers a fetch.
     * Returns empty map immediately; listen for profileLoaded signal.
     */
    Q_INVOKABLE QVariantMap getProfile(const QString& userId);
    
    /**
     * @brief Get display name for a user.
     * @param userId The user's unique ID
     * @return Display name, or username, or truncated ID as fallback
     * 
     * If the profile is not in cache, automatically triggers a fetch.
     */
    Q_INVOKABLE QString getDisplayName(const QString& userId);
    
    /**
     * @brief Get the full avatar URL for a user.
     * @param userId The user's unique ID
     * @return Full URL (baseUrl + profilePicture) or empty string if not found
     * 
     * If the profile is not in cache, automatically triggers a fetch.
     */
    Q_INVOKABLE QString getAvatarUrl(const QString& userId);
    
    /**
     * @brief Check if a profile is in the cache.
     * Does NOT trigger a fetch for unknown profiles.
     */
    Q_INVOKABLE bool hasProfile(const QString& userId) const;
    
    /**
     * @brief Explicitly request fetch for a profile.
     * Use this when you know a user ID but don't need the data immediately.
     */
    Q_INVOKABLE void fetchProfile(const QString& userId);
    
    /**
     * @brief Pre-fetch profiles for multiple users.
     * Useful when loading a message list to avoid per-message fetches.
     */
    Q_INVOKABLE void prefetchProfiles(const QVariantList& userIds);
    
    /**
     * @brief Get version counter for QML binding invalidation.
     */
    int version() const { return m_version; }
    
    // ========================================================================
    // C++ methods for cache management (also callable from QML)
    // ========================================================================
    
    /**
     * @brief Update a single user profile in the cache.
     * Emits profileLoaded signal.
     */
    Q_INVOKABLE void updateProfile(const QString& userId, const QVariantMap& profile);
    
    /**
     * @brief Bulk update profiles from server members list.
     */
    void updateProfiles(const QVariantList& profiles);
    
    /**
     * @brief Mark all entries as potentially stale.
     * Call this after reconnection - doesn't clear data but allows refresh.
     */
    void markAllStale();
    
    /**
     * @brief Clear all cached profiles.
     */
    void clear();

signals:
    /**
     * @brief Emitted when the cache version changes (after any update).
     * Connect to this in QML to trigger re-rendering.
     */
    void versionChanged();
    
    /**
     * @brief Emitted when a specific profile has been loaded.
     * Useful for components waiting on a specific profile.
     */
    void profileLoaded(const QString& userId);
    
    /**
     * @brief Emitted when a profile fetch fails.
     */
    void profileFetchFailed(const QString& userId, const QString& error);

private slots:
    /**
     * @brief Handle successful profile fetch from API.
     */
    void onProfileFetched(int requestId, const QVariantMap& profile);
    
    /**
     * @brief Handle failed profile fetch.
     */
    void onProfileFetchFailed(int requestId, const QString& error);

private:
    // Profile storage: userId -> profile data
    QHash<QString, QVariantMap> m_profiles;
    
    // Track pending fetch requests to avoid duplicates
    // Maps requestId -> userId
    QHash<int, QString> m_pendingFetches;
    
    // Track user IDs that are currently being fetched
    QSet<QString> m_fetchingProfiles;
    
    // API client for fetching unknown profiles
    ApiClient* m_apiClient = nullptr;
    
    // Base URL for constructing full avatar URLs
    QString m_baseUrl;
    
    // Version counter for QML binding invalidation
    int m_version = 0;
    
    /**
     * @brief Increment version and emit signal.
     */
    void bumpVersion();
    
    /**
     * @brief Extract user ID from profile data map.
     */
    static QString extractId(const QVariantMap& profile);
};

#endif // USERPROFILECACHE_H
