#include "messagecache.h"
#include "api/apiclient.h"
#include <QDebug>
#include <algorithm>

MessageCache::MessageCache(QObject *parent)
    : QObject(parent)
{
}

void MessageCache::setApiClient(ApiClient* apiClient) {
    m_apiClient = apiClient;
}

void MessageCache::setTTL(int seconds) {
    m_ttlSeconds = seconds;
}

void MessageCache::setMaxMessagesPerChannel(int count) {
    m_maxMessagesPerChannel = count;
}

void MessageCache::bumpVersion() {
    m_version++;
    emit versionChanged();
}

QString MessageCache::extractId(const QVariantMap& item) const {
    // Handle both "id" and "_id" patterns
    if (item.contains("id")) {
        return item["id"].toString();
    }
    if (item.contains("_id")) {
        return item["_id"].toString();
    }
    return QString();
}

QDateTime MessageCache::extractTimestamp(const QVariantMap& message) const {
    // Try different timestamp field names
    QVariant ts;
    if (message.contains("createdAt")) {
        ts = message["createdAt"];
    } else if (message.contains("timestamp")) {
        ts = message["timestamp"];
    } else if (message.contains("created_at")) {
        ts = message["created_at"];
    }
    
    if (ts.type() == QVariant::DateTime) {
        return ts.toDateTime();
    }
    if (ts.type() == QVariant::String) {
        return QDateTime::fromString(ts.toString(), Qt::ISODate);
    }
    if (ts.type() == QVariant::LongLong || ts.type() == QVariant::Double) {
        return QDateTime::fromMSecsSinceEpoch(ts.toLongLong());
    }
    
    return QDateTime();
}

void MessageCache::sortMessages(QVariantList& messages) {
    // Sort by timestamp (oldest first for chat display)
    std::sort(messages.begin(), messages.end(), 
        [this](const QVariant& a, const QVariant& b) {
            QDateTime tsA = extractTimestamp(a.toMap());
            QDateTime tsB = extractTimestamp(b.toMap());
            return tsA < tsB;
        });
}

void MessageCache::trimMessages(CacheEntry& entry) {
    // Keep only the most recent messages if over limit
    if (entry.messages.size() > m_maxMessagesPerChannel) {
        // Remove oldest messages (from the beginning)
        int toRemove = entry.messages.size() - m_maxMessagesPerChannel;
        entry.messages = entry.messages.mid(toRemove);
        entry.hasMoreHistory = true;  // Since we trimmed, there are more to load
    }
}

int MessageCache::findMessageIndex(const QVariantList& messages, const QString& messageId) const {
    for (int i = 0; i < messages.size(); ++i) {
        if (extractId(messages[i].toMap()) == messageId) {
            return i;
        }
    }
    return -1;
}

// ============================================================================
// QML-accessible methods
// ============================================================================

QVariantList MessageCache::getMessages(const QString& serverId, const QString& channelId) {
    if (channelId.isEmpty()) {
        return QVariantList();
    }
    
    bool hasData = m_messages.contains(channelId);
    bool needsRefresh = !hasData;
    
    if (hasData) {
        const CacheEntry& entry = m_messages[channelId];
        if (entry.isStale(m_ttlSeconds)) {
            needsRefresh = true;
        }
    }
    
    // Trigger background refresh if needed
    if (needsRefresh && !m_pendingFetches.contains(channelId)) {
        refreshMessages(serverId, channelId);
    }
    
    return hasData ? m_messages[channelId].messages : QVariantList();
}

QVariantMap MessageCache::getMessage(const QString& channelId, const QString& messageId) {
    if (channelId.isEmpty() || messageId.isEmpty()) {
        return QVariantMap();
    }
    
    if (!m_messages.contains(channelId)) {
        return QVariantMap();
    }
    
    const QVariantList& messages = m_messages[channelId].messages;
    int idx = findMessageIndex(messages, messageId);
    if (idx >= 0) {
        return messages[idx].toMap();
    }
    
    return QVariantMap();
}

bool MessageCache::hasMessages(const QString& channelId) const {
    return m_messages.contains(channelId) && !m_messages[channelId].messages.isEmpty();
}

bool MessageCache::isFresh(const QString& channelId) const {
    if (!m_messages.contains(channelId)) {
        return false;
    }
    return !m_messages[channelId].isStale(m_ttlSeconds);
}

void MessageCache::refreshMessages(const QString& serverId, const QString& channelId, int limit) {
    if (channelId.isEmpty() || serverId.isEmpty() || !m_apiClient) {
        qWarning() << "MessageCache::refreshMessages - invalid channel/server ID or no API client";
        return;
    }
    
    // Avoid duplicate requests for full refresh
    QString fetchKey = channelId + "_refresh";
    if (m_pendingFetches.contains(fetchKey)) {
        return;
    }
    
    m_pendingFetches.insert(fetchKey);
    emit loadingMessages(channelId, true);
    
    // Use the API client to fetch messages
    int requestId = m_apiClient->getMessages(serverId, channelId, limit);
    
    PendingRequest req;
    req.serverId = serverId;
    req.channelId = channelId;
    req.isPagination = false;
    m_pendingRequests[requestId] = req;
    
    // Store serverId for this channel
    if (m_messages.contains(channelId)) {
        m_messages[channelId].serverId = serverId;
    }
    
    qDebug() << "MessageCache: Fetching messages for channel" << channelId;
}

void MessageCache::loadMoreMessages(const QString& serverId, const QString& channelId, 
                                     const QString& beforeMessageId, int limit) {
    if (channelId.isEmpty() || serverId.isEmpty() || beforeMessageId.isEmpty() || !m_apiClient) {
        return;
    }
    
    // Check if we know there are no more messages
    if (m_messages.contains(channelId) && !m_messages[channelId].hasMoreHistory) {
        return;
    }
    
    // Avoid duplicate pagination requests
    QString fetchKey = channelId + "_before_" + beforeMessageId;
    if (m_pendingFetches.contains(fetchKey)) {
        return;
    }
    
    m_pendingFetches.insert(fetchKey);
    emit loadingMessages(channelId, true);
    
    int requestId = m_apiClient->getMessages(serverId, channelId, limit, beforeMessageId);
    
    PendingRequest req;
    req.serverId = serverId;
    req.channelId = channelId;
    req.isPagination = true;
    req.beforeMessageId = beforeMessageId;
    m_pendingRequests[requestId] = req;
    
    qDebug() << "MessageCache: Loading more messages for channel" << channelId 
             << "before" << beforeMessageId;
}

bool MessageCache::hasMoreMessages(const QString& channelId) const {
    if (!m_messages.contains(channelId)) {
        return true;  // Unknown, assume there might be
    }
    return m_messages[channelId].hasMoreHistory;
}

int MessageCache::messageCount(const QString& channelId) const {
    if (!m_messages.contains(channelId)) {
        return 0;
    }
    return m_messages[channelId].messages.size();
}

// ============================================================================
// Cache loading methods
// ============================================================================

void MessageCache::loadMessages(const QString& serverId, const QString& channelId, 
                                 const QVariantList& messages, bool prepend, bool hasMore) {
    if (!m_messages.contains(channelId)) {
        CacheEntry entry;
        entry.fetchedAt = QDateTime::currentDateTime();
        entry.hasMoreHistory = hasMore;
        entry.serverId = serverId;
        m_messages[channelId] = entry;
    }
    
    CacheEntry& entry = m_messages[channelId];
    
    // Update serverId if provided
    if (!serverId.isEmpty()) {
        entry.serverId = serverId;
    }
    
    if (prepend) {
        // Loading historical messages - add to beginning
        QVariantList combined = messages;
        combined.append(entry.messages);
        entry.messages = combined;
        entry.hasMoreHistory = hasMore && !messages.isEmpty();
    } else {
        // Fresh load - replace all
        entry.messages = messages;
        entry.hasMoreHistory = hasMore;
    }
    
    entry.fetchedAt = QDateTime::currentDateTime();
    
    // Sort and trim
    sortMessages(entry.messages);
    trimMessages(entry);
    
    // Clear pending flags
    m_pendingFetches.remove(channelId + "_refresh");
    
    emit loadingMessages(channelId, false);
    bumpVersion();
    
    if (prepend) {
        emit moreMessagesLoaded(channelId);
    } else {
        emit messagesLoaded(channelId);
    }
    
    qDebug() << "MessageCache: Loaded" << messages.size() << "messages for channel" 
             << channelId << "(total:" << entry.messages.size() << ")";
}

void MessageCache::addMessage(const QString& channelId, const QVariantMap& message) {
    QString messageId = extractId(message);
    if (channelId.isEmpty() || messageId.isEmpty()) {
        return;
    }
    
    // Initialize entry if needed
    if (!m_messages.contains(channelId)) {
        CacheEntry entry;
        entry.fetchedAt = QDateTime::currentDateTime();
        m_messages[channelId] = entry;
    }
    
    CacheEntry& entry = m_messages[channelId];
    
    // Check if already exists (might be echo from our own send)
    int existingIdx = findMessageIndex(entry.messages, messageId);
    if (existingIdx >= 0) {
        // Update existing
        entry.messages[existingIdx] = message;
        bumpVersion();
        emit messageUpdated(channelId, messageId);
        return;
    }
    
    // Add new message
    entry.messages.append(message);
    entry.fetchedAt = QDateTime::currentDateTime();
    
    // Keep sorted
    sortMessages(entry.messages);
    trimMessages(entry);
    
    bumpVersion();
    emit messageAdded(channelId, messageId);
}

void MessageCache::updateMessage(const QString& channelId, const QVariantMap& message) {
    QString messageId = extractId(message);
    if (channelId.isEmpty() || messageId.isEmpty()) {
        return;
    }
    
    if (!m_messages.contains(channelId)) {
        return;
    }
    
    CacheEntry& entry = m_messages[channelId];
    int idx = findMessageIndex(entry.messages, messageId);
    
    if (idx >= 0) {
        entry.messages[idx] = message;
        entry.fetchedAt = QDateTime::currentDateTime();
        bumpVersion();
        emit messageUpdated(channelId, messageId);
    }
}

void MessageCache::removeMessage(const QString& channelId, const QString& messageId) {
    if (channelId.isEmpty() || messageId.isEmpty()) {
        return;
    }
    
    if (!m_messages.contains(channelId)) {
        return;
    }
    
    CacheEntry& entry = m_messages[channelId];
    int idx = findMessageIndex(entry.messages, messageId);
    
    if (idx >= 0) {
        entry.messages.removeAt(idx);
        bumpVersion();
        emit messageRemoved(channelId, messageId);
    }
}

void MessageCache::updateMessageReactions(const QString& channelId, const QString& messageId, 
                                           const QVariantList& reactions) {
    if (channelId.isEmpty() || messageId.isEmpty()) {
        return;
    }
    
    if (!m_messages.contains(channelId)) {
        return;
    }
    
    CacheEntry& entry = m_messages[channelId];
    int idx = findMessageIndex(entry.messages, messageId);
    
    if (idx >= 0) {
        QVariantMap msg = entry.messages[idx].toMap();
        msg["reactions"] = reactions;
        entry.messages[idx] = msg;
        bumpVersion();
        emit messageUpdated(channelId, messageId);
    }
}

// ============================================================================
// Cache management
// ============================================================================

void MessageCache::markAllStale() {
    QDateTime veryOldTime = QDateTime::fromSecsSinceEpoch(0);
    
    for (auto it = m_messages.begin(); it != m_messages.end(); ++it) {
        it.value().fetchedAt = veryOldTime;
    }
    
    qDebug() << "MessageCache: All entries marked as stale";
}

void MessageCache::refreshStaleEntries(const QStringList& channelIds) {
    for (const QString& channelId : channelIds) {
        if (!isFresh(channelId) && m_messages.contains(channelId)) {
            // Use the stored serverId from the cache entry
            const CacheEntry& entry = m_messages[channelId];
            if (!entry.serverId.isEmpty()) {
                refreshMessages(entry.serverId, channelId);
            }
        }
    }
}

void MessageCache::refreshActiveChannel() {
    if (!m_activeChannelId.isEmpty() && !m_activeServerId.isEmpty()) {
        refreshMessages(m_activeServerId, m_activeChannelId);
    }
}

void MessageCache::setActiveChannel(const QString& serverId, const QString& channelId) {
    m_activeServerId = serverId;
    m_activeChannelId = channelId;
    
    // If the new active channel is stale, refresh it immediately
    if (!channelId.isEmpty() && !serverId.isEmpty() && !isFresh(channelId)) {
        refreshMessages(serverId, channelId);
    }
}

void MessageCache::clear() {
    m_messages.clear();
    m_pendingFetches.clear();
    m_pendingRequests.clear();
    m_activeChannelId.clear();
    bumpVersion();
}

void MessageCache::clearChannel(const QString& channelId) {
    m_messages.remove(channelId);
    
    // Remove any pending fetches for this channel
    QSet<QString> toRemove;
    for (const QString& key : m_pendingFetches) {
        if (key.startsWith(channelId)) {
            toRemove.insert(key);
        }
    }
    for (const QString& key : toRemove) {
        m_pendingFetches.remove(key);
    }
    
    bumpVersion();
}

// ============================================================================
// Slots for API responses
// ============================================================================

void MessageCache::onMessagesFetched(int requestId, const QString& serverId, const QString& channelId, 
                                      const QVariantList& messages) {
    if (!m_pendingRequests.contains(requestId)) {
        return;
    }
    
    PendingRequest req = m_pendingRequests.take(requestId);
    
    // Remove pending fetch marker
    if (req.isPagination) {
        m_pendingFetches.remove(channelId + "_before_" + req.beforeMessageId);
    } else {
        m_pendingFetches.remove(channelId + "_refresh");
    }
    
    // Determine if there are more messages based on response size
    bool hasMore = messages.size() >= 50;  // Assuming 50 is the default limit
    
    loadMessages(serverId.isEmpty() ? req.serverId : serverId, channelId, messages, req.isPagination, hasMore);
}

void MessageCache::onMessagesFetchFailed(int requestId, const QString& serverId, const QString& channelId, 
                                          const QString& error) {
    Q_UNUSED(serverId)
    
    if (!m_pendingRequests.contains(requestId)) {
        return;
    }
    
    PendingRequest req = m_pendingRequests.take(requestId);
    
    if (req.isPagination) {
        m_pendingFetches.remove(channelId + "_before_" + req.beforeMessageId);
    } else {
        m_pendingFetches.remove(channelId + "_refresh");
    }
    
    emit loadingMessages(channelId, false);
    
    qWarning() << "MessageCache: Failed to fetch messages for channel" << channelId << ":" << error;
}
