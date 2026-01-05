#ifndef EMOJICACHE_H
#define EMOJICACHE_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

class ApiClient;

/**
 * @brief Global cache for custom emojis.
 * 
 * This singleton cache provides centralized emoji storage and lookup,
 * eliminating the need to pass emoji data through component hierarchies.
 * 
 * Features:
 * - O(1) emoji lookup by ID
 * - Automatic fetch for unknown emojis (cross-server support)
 * - Version counter for QML binding invalidation
 * - Deduplication of in-flight fetch requests
 * 
 * Usage in QML:
 *   var emoji = SerchatAPI.emojiCache.getEmoji(emojiId)
 *   var url = SerchatAPI.emojiCache.getEmojiUrl(emojiId)
 */
class EmojiCache : public QObject {
    Q_OBJECT
    
    // Version counter triggers QML re-rendering when cache updates
    Q_PROPERTY(int version READ version NOTIFY versionChanged)

public:
    explicit EmojiCache(QObject *parent = nullptr);
    ~EmojiCache() override = default;
    
    /**
     * @brief Set the API client for fetching unknown emojis.
     * Must be called during initialization.
     */
    void setApiClient(ApiClient* apiClient);
    
    /**
     * @brief Set the base URL for constructing full emoji URLs.
     */
    void setBaseUrl(const QString& baseUrl);
    
    // ========================================================================
    // QML-accessible methods
    // ========================================================================
    
    /**
     * @brief Get emoji data by ID.
     * @param emojiId The emoji's unique ID
     * @return QVariantMap with {id, name, imageUrl, serverId} or empty if not found
     * 
     * If the emoji is not in cache, automatically triggers a fetch.
     * Returns empty map immediately; listen for emojiLoaded signal.
     */
    Q_INVOKABLE QVariantMap getEmoji(const QString& emojiId);
    
    /**
     * @brief Get the full URL for an emoji image.
     * @param emojiId The emoji's unique ID
     * @return Full URL (baseUrl + imageUrl) or empty string if not found
     * 
     * If the emoji is not in cache, automatically triggers a fetch.
     */
    Q_INVOKABLE QString getEmojiUrl(const QString& emojiId);
    
    /**
     * @brief Check if an emoji is in the cache.
     * Does NOT trigger a fetch for unknown emojis.
     */
    Q_INVOKABLE bool hasEmoji(const QString& emojiId) const;
    
    /**
     * @brief Explicitly request fetch for an emoji.
     * Use this when you know an emoji ID but don't need the data immediately.
     */
    Q_INVOKABLE void fetchEmoji(const QString& emojiId);
    
    /**
     * @brief Get all cached emojis as a list.
     * Useful for emoji pickers.
     */
    Q_INVOKABLE QVariantList getAllEmojis() const;
    
    /**
     * @brief Get all emojis for a specific server.
     */
    Q_INVOKABLE QVariantList getServerEmojis(const QString& serverId) const;
    
    /**
     * @brief Get version counter for QML binding invalidation.
     */
    int version() const { return m_version; }
    
    // ========================================================================
    // C++ methods for bulk loading
    // ========================================================================
    
    /**
     * @brief Load emojis from a server into the cache.
     * Called when server emojis are fetched from API.
     */
    void loadServerEmojis(const QString& serverId, const QVariantList& emojis);
    
    /**
     * @brief Load all emojis from all servers into the cache.
     * Called when getAllEmojis API returns.
     */
    void loadAllEmojis(const QVariantList& emojis);
    
    /**
     * @brief Add a single emoji to the cache.
     * Called when a cross-server emoji is fetched.
     */
    void addEmoji(const QVariantMap& emoji);
    
    /**
     * @brief Clear all cached emojis.
     */
    void clear();

signals:
    /**
     * @brief Emitted when the cache version changes (after any update).
     * Connect to this in QML to trigger re-rendering.
     */
    void versionChanged();
    
    /**
     * @brief Emitted when a specific emoji has been loaded.
     * Useful for components waiting on a specific emoji.
     */
    void emojiLoaded(const QString& emojiId);
    
    /**
     * @brief Emitted when an emoji fetch fails.
     */
    void emojiFetchFailed(const QString& emojiId, const QString& error);

private slots:
    /**
     * @brief Handle successful emoji fetch from API.
     */
    void onEmojiFetched(int requestId, const QString& emojiId, const QVariantMap& emoji);
    
    /**
     * @brief Handle failed emoji fetch.
     */
    void onEmojiFetchFailed(int requestId, const QString& emojiId, const QString& error);

private:
    // Emoji storage: emojiId -> emoji data
    QHash<QString, QVariantMap> m_emojis;
    
    // Server -> emoji IDs mapping for getServerEmojis()
    QHash<QString, QSet<QString>> m_serverEmojis;
    
    // Track pending fetch requests to avoid duplicates
    // Maps requestId -> emojiId
    QHash<int, QString> m_pendingFetches;
    
    // Track emoji IDs that are currently being fetched
    QSet<QString> m_fetchingEmojis;
    
    // API client for fetching unknown emojis
    ApiClient* m_apiClient = nullptr;
    
    // Base URL for constructing full emoji URLs
    QString m_baseUrl;
    
    // Version counter for QML binding invalidation
    int m_version = 0;
    
    /**
     * @brief Increment version and emit signal.
     */
    void bumpVersion();
    
    /**
     * @brief Extract emoji ID from emoji data map.
     */
    static QString extractId(const QVariantMap& emoji);
};

#endif // EMOJICACHE_H
