#ifndef MESSAGECACHE_H
#define MESSAGECACHE_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>
#include <QString>

class ApiClient;

/**
 * @brief Global cache for channel messages with TTL support.
 * 
 * This cache provides centralized message storage with:
 * - TTL-based expiration with stale-while-revalidate pattern
 * - Automatic refresh when data is stale
 * - Socket.IO event-driven updates
 * - Pagination support for message history
 * - Graceful handling of app suspension/reconnection
 * 
 * Messages are stored per-channel with support for:
 * - Adding new messages from socket events
 * - Editing messages from socket events  
 * - Deleting messages from socket events
 * - Loading historical messages with pagination
 * 
 * Usage in QML:
 *   var messages = SerchatAPI.messageCache.getMessages(serverId, channelId)
 *   var message = SerchatAPI.messageCache.getMessage(channelId, messageId)
 */
class MessageCache : public QObject {
    Q_OBJECT
    
    Q_PROPERTY(int version READ version NOTIFY versionChanged)

public:
    explicit MessageCache(QObject *parent = nullptr);
    ~MessageCache() override = default;
    
    /**
     * @brief Set the API client for fetching messages.
     */
    void setApiClient(ApiClient* apiClient);
    
    /**
     * @brief Set TTL for cache entries in seconds (default: 120 = 2 minutes).
     * Messages have a shorter TTL since they change more frequently.
     */
    void setTTL(int seconds);
    
    /**
     * @brief Set maximum messages to keep per channel (default: 200).
     */
    void setMaxMessagesPerChannel(int count);
    
    // ========================================================================
    // QML-accessible methods
    // ========================================================================
    
    /**
     * @brief Get all cached messages for a channel.
     * Returns cached data immediately (even if stale), triggers refresh if needed.
     * Messages are sorted by timestamp (newest last).
     * @param serverId The server ID
     * @param channelId The channel ID
     * @return List of message objects
     */
    Q_INVOKABLE QVariantList getMessages(const QString& serverId, const QString& channelId);
    
    /**
     * @brief Get a specific message by ID.
     * @param channelId The channel ID
     * @param messageId The message ID
     * @return Message object or empty map if not found
     */
    Q_INVOKABLE QVariantMap getMessage(const QString& channelId, const QString& messageId);
    
    /**
     * @brief Check if messages for a channel are in the cache.
     */
    Q_INVOKABLE bool hasMessages(const QString& channelId) const;
    
    /**
     * @brief Check if cached messages are fresh (not expired).
     */
    Q_INVOKABLE bool isFresh(const QString& channelId) const;
    
    /**
     * @brief Explicitly request a refresh of messages for a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param limit Maximum number of messages to fetch (default: 50)
     */
    Q_INVOKABLE void refreshMessages(const QString& serverId, const QString& channelId, int limit = 50);
    
    /**
     * @brief Load older messages (pagination).
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param beforeMessageId Load messages before this message
     * @param limit Maximum number of messages to fetch
     */
    Q_INVOKABLE void loadMoreMessages(const QString& serverId, const QString& channelId, 
                                       const QString& beforeMessageId, int limit = 50);
    
    /**
     * @brief Check if there are more messages to load.
     * @param channelId The channel ID
     * @return true if more messages may be available
     */
    Q_INVOKABLE bool hasMoreMessages(const QString& channelId) const;
    
    /**
     * @brief Get the count of cached messages for a channel.
     */
    Q_INVOKABLE int messageCount(const QString& channelId) const;
    
    /**
     * @brief Get version counter for QML binding invalidation.
     */
    int version() const { return m_version; }
    
    // ========================================================================
    // C++ methods for cache management
    // ========================================================================
    
    /**
     * @brief Load messages from API response into cache.
     * @param serverId The server ID (for refresh lookup)
     * @param channelId The channel ID
     * @param messages List of messages
     * @param prepend If true, add to beginning (historical messages)
     * @param hasMore If false, indicates no more historical messages
     */
    void loadMessages(const QString& serverId, const QString& channelId, const QVariantList& messages, 
                      bool prepend = false, bool hasMore = true);
    
    /**
     * @brief Add a new message (from socket event or send confirmation).
     */
    void addMessage(const QString& channelId, const QVariantMap& message);
    
    /**
     * @brief Update an existing message (from socket edit event).
     */
    void updateMessage(const QString& channelId, const QVariantMap& message);
    
    /**
     * @brief Remove a message (from socket delete event).
     */
    void removeMessage(const QString& channelId, const QString& messageId);
    
    /**
     * @brief Update reactions on a message.
     */
    void updateMessageReactions(const QString& channelId, const QString& messageId, 
                                 const QVariantList& reactions);
    
    /**
     * @brief Mark all entries as stale (call after reconnection).
     */
    void markAllStale();
    
    /**
     * @brief Refresh messages for specific channels (call after reconnection).
     * @param channelIds List of channel IDs to refresh
     */
    void refreshStaleEntries(const QStringList& channelIds);
    
    /**
     * @brief Refresh currently active channel only (lighter reconnection).
     */
    void refreshActiveChannel();
    
    /**
     * @brief Set the currently active/visible channel for priority refresh.
     * @param serverId The server ID
     * @param channelId The channel ID
     */
    void setActiveChannel(const QString& serverId, const QString& channelId);
    
    /**
     * @brief Get the currently active channel.
     */
    QString activeChannel() const { return m_activeChannelId; }
    
    /**
     * @brief Get the currently active server.
     */
    QString activeServer() const { return m_activeServerId; }
    
    /**
     * @brief Clear all cached data.
     */
    void clear();
    
    /**
     * @brief Clear cache for a specific channel.
     */
    void clearChannel(const QString& channelId);

signals:
    void versionChanged();
    void messagesLoaded(const QString& channelId);
    void messageAdded(const QString& channelId, const QString& messageId);
    void messageUpdated(const QString& channelId, const QString& messageId);
    void messageRemoved(const QString& channelId, const QString& messageId);
    void moreMessagesLoaded(const QString& channelId);
    void loadingMessages(const QString& channelId, bool isLoading);

public slots:
    void onMessagesFetched(int requestId, const QString& serverId, const QString& channelId,
                           const QVariantList& messages);
    void onMessagesFetchFailed(int requestId, const QString& serverId, const QString& channelId,
                                const QString& error);

private:
    struct CacheEntry {
        QVariantList messages;
        QDateTime fetchedAt;
        QString serverId;  // Track which server this channel belongs to
        bool hasMoreHistory = true;  // Whether there are older messages to load
        
        bool isStale(int ttlSeconds) const {
            return fetchedAt.isNull() || 
                   fetchedAt.secsTo(QDateTime::currentDateTime()) > ttlSeconds;
        }
    };
    
    struct PendingRequest {
        QString serverId;
        QString channelId;
        bool isPagination;  // true if loading older messages
        QString beforeMessageId;
    };
    
    // Message storage: channelId -> cache entry
    QHash<QString, CacheEntry> m_messages;
    
    // Track pending fetches to avoid duplicates
    QSet<QString> m_pendingFetches;
    QHash<int, PendingRequest> m_pendingRequests;
    
    // Configuration
    ApiClient* m_apiClient = nullptr;
    int m_ttlSeconds = 120;  // 2 minutes default
    int m_maxMessagesPerChannel = 200;
    int m_version = 0;
    QString m_activeChannelId;
    QString m_activeServerId;
    
    void bumpVersion();
    QString extractId(const QVariantMap& item) const;
    QDateTime extractTimestamp(const QVariantMap& message) const;
    void trimMessages(CacheEntry& entry);
    void sortMessages(QVariantList& messages);
    int findMessageIndex(const QVariantList& messages, const QString& messageId) const;
};

#endif // MESSAGECACHE_H