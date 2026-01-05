#include "emojicache.h"
#include "api/apiclient.h"
#include <QDebug>

EmojiCache::EmojiCache(QObject *parent)
    : QObject(parent)
{
}

void EmojiCache::setApiClient(ApiClient* apiClient)
{
    if (m_apiClient) {
        disconnect(m_apiClient, nullptr, this, nullptr);
    }
    
    m_apiClient = apiClient;
    
    if (m_apiClient) {
        connect(m_apiClient, &ApiClient::emojiFetched,
                this, &EmojiCache::onEmojiFetched);
        connect(m_apiClient, &ApiClient::emojiFetchFailed,
                this, &EmojiCache::onEmojiFetchFailed);
    }
}

void EmojiCache::setBaseUrl(const QString& baseUrl)
{
    m_baseUrl = baseUrl;
}

// ============================================================================
// QML-accessible methods
// ============================================================================

QVariantMap EmojiCache::getEmoji(const QString& emojiId)
{
    if (emojiId.isEmpty()) {
        return QVariantMap();
    }
    
    if (m_emojis.contains(emojiId)) {
        return m_emojis.value(emojiId);
    }
    
    // Not in cache - trigger fetch
    fetchEmoji(emojiId);
    return QVariantMap();
}

QString EmojiCache::getEmojiUrl(const QString& emojiId)
{
    if (emojiId.isEmpty()) {
        return QString();
    }
    
    if (m_emojis.contains(emojiId)) {
        QVariantMap emoji = m_emojis.value(emojiId);
        QString imageUrl = emoji.value("imageUrl").toString();
        if (!imageUrl.isEmpty()) {
            return m_baseUrl + imageUrl;
        }
    }
    
    // Not in cache - trigger fetch
    fetchEmoji(emojiId);
    return QString();
}

bool EmojiCache::hasEmoji(const QString& emojiId) const
{
    return m_emojis.contains(emojiId);
}

void EmojiCache::fetchEmoji(const QString& emojiId)
{
    if (emojiId.isEmpty()) {
        return;
    }
    
    // Already in cache
    if (m_emojis.contains(emojiId)) {
        return;
    }
    
    // Already fetching
    if (m_fetchingEmojis.contains(emojiId)) {
        return;
    }
    
    // No API client configured
    if (!m_apiClient) {
        qWarning() << "[EmojiCache] Cannot fetch emoji - no API client configured";
        return;
    }
    
    qDebug() << "[EmojiCache] Fetching unknown emoji:" << emojiId;
    m_fetchingEmojis.insert(emojiId);
    
    int requestId = m_apiClient->getEmojiById(emojiId, true);
    m_pendingFetches.insert(requestId, emojiId);
}

QVariantList EmojiCache::getAllEmojis() const
{
    QVariantList result;
    result.reserve(m_emojis.size());
    
    for (auto it = m_emojis.constBegin(); it != m_emojis.constEnd(); ++it) {
        result.append(it.value());
    }
    
    return result;
}

QVariantList EmojiCache::getServerEmojis(const QString& serverId) const
{
    QVariantList result;
    
    if (!m_serverEmojis.contains(serverId)) {
        return result;
    }
    
    const QSet<QString>& emojiIds = m_serverEmojis.value(serverId);
    result.reserve(emojiIds.size());
    
    for (const QString& emojiId : emojiIds) {
        if (m_emojis.contains(emojiId)) {
            result.append(m_emojis.value(emojiId));
        }
    }
    
    return result;
}

// ============================================================================
// C++ methods for bulk loading
// ============================================================================

void EmojiCache::loadServerEmojis(const QString& serverId, const QVariantList& emojis)
{
    qDebug() << "[EmojiCache] Loading" << emojis.size() << "emojis for server:" << serverId;
    
    QSet<QString>& serverEmojiSet = m_serverEmojis[serverId];
    
    for (const QVariant& emojiVar : emojis) {
        QVariantMap emoji = emojiVar.toMap();
        QString emojiId = extractId(emoji);
        
        if (emojiId.isEmpty()) {
            continue;
        }
        
        // Store the emoji
        m_emojis.insert(emojiId, emoji);
        serverEmojiSet.insert(emojiId);
        
        // Remove from pending fetches if it was being fetched
        m_fetchingEmojis.remove(emojiId);
    }
    
    bumpVersion();
}

void EmojiCache::loadAllEmojis(const QVariantList& emojis)
{
    qDebug() << "[EmojiCache] Loading" << emojis.size() << "emojis from all servers";
    
    for (const QVariant& emojiVar : emojis) {
        QVariantMap emoji = emojiVar.toMap();
        QString emojiId = extractId(emoji);
        
        if (emojiId.isEmpty()) {
            continue;
        }
        
        // Store the emoji
        m_emojis.insert(emojiId, emoji);
        
        // Track server association
        QString serverId = emoji.value("serverId").toString();
        if (!serverId.isEmpty()) {
            m_serverEmojis[serverId].insert(emojiId);
        }
        
        // Remove from pending fetches if it was being fetched
        m_fetchingEmojis.remove(emojiId);
    }
    
    bumpVersion();
}

void EmojiCache::addEmoji(const QVariantMap& emoji)
{
    QString emojiId = extractId(emoji);
    
    if (emojiId.isEmpty()) {
        qWarning() << "[EmojiCache] Cannot add emoji without ID";
        return;
    }
    
    qDebug() << "[EmojiCache] Adding emoji:" << emojiId;
    
    m_emojis.insert(emojiId, emoji);
    
    // Track server association
    QString serverId = emoji.value("serverId").toString();
    if (!serverId.isEmpty()) {
        m_serverEmojis[serverId].insert(emojiId);
    }
    
    // Remove from pending fetches
    m_fetchingEmojis.remove(emojiId);
    
    bumpVersion();
    emit emojiLoaded(emojiId);
}

void EmojiCache::clear()
{
    qDebug() << "[EmojiCache] Clearing cache";
    m_emojis.clear();
    m_serverEmojis.clear();
    m_fetchingEmojis.clear();
    m_pendingFetches.clear();
    bumpVersion();
}

// ============================================================================
// Private slots
// ============================================================================

void EmojiCache::onEmojiFetched(int requestId, const QString& emojiId, const QVariantMap& emoji)
{
    Q_UNUSED(emojiId);  // We get emojiId from our pending map
    
    QString trackedEmojiId = m_pendingFetches.take(requestId);
    
    if (trackedEmojiId.isEmpty()) {
        // Not our request
        return;
    }
    
    qDebug() << "[EmojiCache] Received emoji:" << trackedEmojiId;
    
    m_fetchingEmojis.remove(trackedEmojiId);
    m_emojis.insert(trackedEmojiId, emoji);
    
    // Track server association
    QString serverId = emoji.value("serverId").toString();
    if (!serverId.isEmpty()) {
        m_serverEmojis[serverId].insert(trackedEmojiId);
    }
    
    bumpVersion();
    emit emojiLoaded(trackedEmojiId);
}

void EmojiCache::onEmojiFetchFailed(int requestId, const QString& emojiId, const QString& error)
{
    Q_UNUSED(emojiId);  // We get emojiId from our pending map
    
    QString trackedEmojiId = m_pendingFetches.take(requestId);
    
    if (trackedEmojiId.isEmpty()) {
        // Not our request
        return;
    }
    
    qWarning() << "[EmojiCache] Failed to fetch emoji:" << trackedEmojiId << "-" << error;
    
    m_fetchingEmojis.remove(trackedEmojiId);
    emit emojiFetchFailed(trackedEmojiId, error);
}

// ============================================================================
// Private helpers
// ============================================================================

void EmojiCache::bumpVersion()
{
    m_version++;
    emit versionChanged();
}

QString EmojiCache::extractId(const QVariantMap& emoji)
{
    // Try common ID field names
    if (emoji.contains("_id")) {
        return emoji.value("_id").toString();
    }
    if (emoji.contains("id")) {
        return emoji.value("id").toString();
    }
    return QString();
}
