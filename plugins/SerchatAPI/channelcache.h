#ifndef CHANNELCACHE_H
#define CHANNELCACHE_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>
#include <QString>
#include <QTimer>

class ApiClient;

/**
 * @brief Global cache for server channels with TTL support.
 * 
 * This cache provides centralized channel storage with:
 * - TTL-based expiration with stale-while-revalidate pattern
 * - Automatic refresh when data is stale
 * - Socket.IO event-driven updates
 * - Graceful handling of app suspension/reconnection
 * 
 * Usage in QML:
 *   var channels = SerchatAPI.channelCache.getChannels(serverId)
 *   var channel = SerchatAPI.channelCache.getChannel(serverId, channelId)
 */
class ChannelCache : public QObject {
    Q_OBJECT
    
    Q_PROPERTY(int version READ version NOTIFY versionChanged)

public:
    explicit ChannelCache(QObject *parent = nullptr);
    ~ChannelCache() override = default;
    
    /**
     * @brief Set the API client for fetching channels.
     */
    void setApiClient(ApiClient* apiClient);
    
    /**
     * @brief Set TTL for cache entries in seconds (default: 300 = 5 minutes).
     */
    void setTTL(int seconds);
    
    // ========================================================================
    // QML-accessible methods
    // ========================================================================
    
    /**
     * @brief Get all channels for a server.
     * Returns cached data immediately (even if stale), triggers refresh if needed.
     * @param serverId The server ID
     * @return List of channel objects
     */
    Q_INVOKABLE QVariantList getChannels(const QString& serverId);
    
    /**
     * @brief Get a specific channel by ID.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @return Channel object or empty map if not found
     */
    Q_INVOKABLE QVariantMap getChannel(const QString& serverId, const QString& channelId);
    
    /**
     * @brief Get the server ID for a channel.
     * Searches all cached servers to find which one contains this channel.
     * @param channelId The channel ID
     * @return Server ID or empty string if not found
     */
    Q_INVOKABLE QString getServerIdForChannel(const QString& channelId) const;
    
    /**
     * @brief Check if channels for a server are in the cache.
     */
    Q_INVOKABLE bool hasChannels(const QString& serverId) const;
    
    /**
     * @brief Check if cached channels are fresh (not expired).
     */
    Q_INVOKABLE bool isFresh(const QString& serverId) const;
    
    /**
     * @brief Explicitly request a refresh of channels for a server.
     */
    Q_INVOKABLE void refreshChannels(const QString& serverId);
    
    /**
     * @brief Get all categories for a server.
     */
    Q_INVOKABLE QVariantList getCategories(const QString& serverId);
    
    /**
     * @brief Get version counter for QML binding invalidation.
     */
    int version() const { return m_version; }
    
    // ========================================================================
    // C++ methods for cache management
    // ========================================================================
    
    /**
     * @brief Load channels from API response into cache.
     */
    void loadChannels(const QString& serverId, const QVariantList& channels);
    
    /**
     * @brief Load categories from API response into cache.
     */
    void loadCategories(const QString& serverId, const QVariantList& categories);
    
    /**
     * @brief Update a single channel (from socket event).
     */
    void updateChannel(const QString& serverId, const QVariantMap& channel);
    
    /**
     * @brief Add a new channel (from socket event).
     */
    void addChannel(const QString& serverId, const QVariantMap& channel);
    
    /**
     * @brief Remove a channel (from socket event).
     */
    void removeChannel(const QString& serverId, const QString& channelId);
    
    /**
     * @brief Update a category (from socket event).
     */
    void updateCategory(const QString& serverId, const QVariantMap& category);
    
    /**
     * @brief Add a new category (from socket event).
     */
    void addCategory(const QString& serverId, const QVariantMap& category);
    
    /**
     * @brief Remove a category (from socket event).
     */
    void removeCategory(const QString& serverId, const QString& categoryId);
    
    /**
     * @brief Mark all entries as stale (call after reconnection).
     */
    void markAllStale();
    
    /**
     * @brief Refresh all stale entries (call after reconnection).
     * @param serverIds List of server IDs to refresh
     */
    void refreshStaleEntries(const QStringList& serverIds);
    
    /**
     * @brief Clear all cached data.
     */
    void clear();
    
    /**
     * @brief Clear cache for a specific server.
     */
    void clearServer(const QString& serverId);

signals:
    void versionChanged();
    void channelsLoaded(const QString& serverId);
    void channelUpdated(const QString& serverId, const QString& channelId);
    void channelAdded(const QString& serverId, const QString& channelId);
    void channelRemoved(const QString& serverId, const QString& channelId);
    void categoriesLoaded(const QString& serverId);
    void categoryUpdated(const QString& serverId, const QString& categoryId);

public slots:
    void onChannelsFetched(int requestId, const QString& serverId, const QVariantList& channels);
    void onChannelsFetchFailed(int requestId, const QString& serverId, const QString& error);
    void onCategoriesFetched(int requestId, const QString& serverId, const QVariantList& categories);
    void onCategoriesFetchFailed(int requestId, const QString& serverId, const QString& error);

private:
    struct CacheEntry {
        QVariantList data;
        QDateTime fetchedAt;
        bool isStale(int ttlSeconds) const {
            return fetchedAt.isNull() || 
                   fetchedAt.secsTo(QDateTime::currentDateTime()) > ttlSeconds;
        }
    };
    
    // Channel storage: serverId -> list of channels
    QHash<QString, CacheEntry> m_channels;
    
    // Category storage: serverId -> list of categories  
    QHash<QString, CacheEntry> m_categories;
    
    // Track pending fetches to avoid duplicates
    QSet<QString> m_pendingChannelFetches;
    QSet<QString> m_pendingCategoryFetches;
    QHash<int, QString> m_channelRequestIds;  // requestId -> serverId
    QHash<int, QString> m_categoryRequestIds;
    
    // Configuration
    ApiClient* m_apiClient = nullptr;
    int m_ttlSeconds = 300;  // 5 minutes default
    int m_version = 0;
    
    void bumpVersion();
    QString extractId(const QVariantMap& item) const;
};

#endif // CHANNELCACHE_H
