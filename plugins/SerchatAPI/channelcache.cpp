#include "channelcache.h"
#include "api/apiclient.h"
#include <QDebug>

// Check if entry is stale based on TTL
bool ChannelCache::CacheEntry::isStale() const {
    static const int defaultTTL = 300;  // Fallback TTL
    return fetchedAt.isNull() || 
           fetchedAt.secsTo(QDateTime::currentDateTime()) > defaultTTL;
}

ChannelCache::ChannelCache(QObject *parent)
    : QObject(parent)
{
}

void ChannelCache::setApiClient(ApiClient* apiClient) {
    m_apiClient = apiClient;
}

void ChannelCache::setTTL(int seconds) {
    m_ttlSeconds = seconds;
}

void ChannelCache::bumpVersion() {
    m_version++;
    emit versionChanged();
}

QString ChannelCache::extractId(const QVariantMap& item) const {
    // Handle both "id" and "_id" patterns
    if (item.contains("id")) {
        return item["id"].toString();
    }
    if (item.contains("_id")) {
        return item["_id"].toString();
    }
    return QString();
}

// ============================================================================
// QML-accessible methods
// ============================================================================

QVariantList ChannelCache::getChannels(const QString& serverId) {
    if (serverId.isEmpty()) {
        return QVariantList();
    }
    
    // Check if we have any data
    bool hasData = m_channels.contains(serverId);
    bool needsRefresh = !hasData;
    
    if (hasData) {
        const CacheEntry& entry = m_channels[serverId];
        // Check if data is stale
        if (entry.fetchedAt.isNull() || 
            entry.fetchedAt.secsTo(QDateTime::currentDateTime()) > m_ttlSeconds) {
            needsRefresh = true;
        }
    }
    
    // Trigger background refresh if needed
    if (needsRefresh && !m_pendingChannelFetches.contains(serverId)) {
        refreshChannels(serverId);
    }
    
    // Return whatever we have (stale-while-revalidate pattern)
    return hasData ? m_channels[serverId].data : QVariantList();
}

QVariantMap ChannelCache::getChannel(const QString& serverId, const QString& channelId) {
    if (serverId.isEmpty() || channelId.isEmpty()) {
        return QVariantMap();
    }
    
    // Get all channels (this handles refresh logic)
    QVariantList channels = getChannels(serverId);
    
    // Find the specific channel
    for (const QVariant& v : channels) {
        QVariantMap channel = v.toMap();
        if (extractId(channel) == channelId) {
            return channel;
        }
    }
    
    return QVariantMap();
}

bool ChannelCache::hasChannels(const QString& serverId) const {
    return m_channels.contains(serverId) && !m_channels[serverId].data.isEmpty();
}

bool ChannelCache::isFresh(const QString& serverId) const {
    if (!m_channels.contains(serverId)) {
        return false;
    }
    const CacheEntry& entry = m_channels[serverId];
    if (entry.fetchedAt.isNull()) {
        return false;
    }
    return entry.fetchedAt.secsTo(QDateTime::currentDateTime()) <= m_ttlSeconds;
}

void ChannelCache::refreshChannels(const QString& serverId) {
    if (serverId.isEmpty() || !m_apiClient) {
        qWarning() << "ChannelCache::refreshChannels - invalid server ID or no API client";
        return;
    }
    
    // Avoid duplicate requests
    if (m_pendingChannelFetches.contains(serverId)) {
        return;
    }
    
    m_pendingChannelFetches.insert(serverId);
    
    // Use the API client to fetch channels
    int requestId = m_apiClient->getChannels(serverId, false);  // Don't use ApiClient cache, we are the cache
    m_channelRequestIds[requestId] = serverId;
    
    qDebug() << "ChannelCache: Fetching channels for server" << serverId;
}

QVariantList ChannelCache::getCategories(const QString& serverId) {
    if (serverId.isEmpty()) {
        return QVariantList();
    }
    
    bool hasData = m_categories.contains(serverId);
    bool needsRefresh = !hasData;
    
    if (hasData) {
        const CacheEntry& entry = m_categories[serverId];
        if (entry.fetchedAt.isNull() || 
            entry.fetchedAt.secsTo(QDateTime::currentDateTime()) > m_ttlSeconds) {
            needsRefresh = true;
        }
    }
    
    if (needsRefresh && !m_pendingCategoryFetches.contains(serverId)) {
        if (!m_apiClient) {
            return hasData ? m_categories[serverId].data : QVariantList();
        }
        
        m_pendingCategoryFetches.insert(serverId);
        int requestId = m_apiClient->getCategories(serverId, false);  // Don't use ApiClient cache
        m_categoryRequestIds[requestId] = serverId;
    }
    
    return hasData ? m_categories[serverId].data : QVariantList();
}

// ============================================================================
// Cache loading methods
// ============================================================================

void ChannelCache::loadChannels(const QString& serverId, const QVariantList& channels) {
    CacheEntry entry;
    entry.data = channels;
    entry.fetchedAt = QDateTime::currentDateTime();
    
    m_channels[serverId] = entry;
    m_pendingChannelFetches.remove(serverId);
    
    bumpVersion();
    emit channelsLoaded(serverId);
    
    qDebug() << "ChannelCache: Loaded" << channels.size() << "channels for server" << serverId;
}

void ChannelCache::loadCategories(const QString& serverId, const QVariantList& categories) {
    CacheEntry entry;
    entry.data = categories;
    entry.fetchedAt = QDateTime::currentDateTime();
    
    m_categories[serverId] = entry;
    m_pendingCategoryFetches.remove(serverId);
    
    bumpVersion();
    emit categoriesLoaded(serverId);
}

// ============================================================================
// Single item update methods (from socket events)
// ============================================================================

void ChannelCache::updateChannel(const QString& serverId, const QVariantMap& channel) {
    if (!m_channels.contains(serverId)) {
        return;
    }
    
    QString channelId = extractId(channel);
    if (channelId.isEmpty()) {
        return;
    }
    
    QVariantList& channels = m_channels[serverId].data;
    for (int i = 0; i < channels.size(); ++i) {
        if (extractId(channels[i].toMap()) == channelId) {
            channels[i] = channel;
            // Update timestamp since this is fresh data from server
            m_channels[serverId].fetchedAt = QDateTime::currentDateTime();
            bumpVersion();
            emit channelUpdated(serverId, channelId);
            return;
        }
    }
}

void ChannelCache::addChannel(const QString& serverId, const QVariantMap& channel) {
    QString channelId = extractId(channel);
    if (channelId.isEmpty()) {
        return;
    }
    
    // Initialize entry if needed
    if (!m_channels.contains(serverId)) {
        CacheEntry entry;
        entry.fetchedAt = QDateTime::currentDateTime();
        m_channels[serverId] = entry;
    }
    
    // Check if already exists
    QVariantList& channels = m_channels[serverId].data;
    for (const QVariant& v : channels) {
        if (extractId(v.toMap()) == channelId) {
            // Already exists, update instead
            updateChannel(serverId, channel);
            return;
        }
    }
    
    channels.append(channel);
    m_channels[serverId].fetchedAt = QDateTime::currentDateTime();
    bumpVersion();
    emit channelAdded(serverId, channelId);
}

void ChannelCache::removeChannel(const QString& serverId, const QString& channelId) {
    if (!m_channels.contains(serverId) || channelId.isEmpty()) {
        return;
    }
    
    QVariantList& channels = m_channels[serverId].data;
    for (int i = 0; i < channels.size(); ++i) {
        if (extractId(channels[i].toMap()) == channelId) {
            channels.removeAt(i);
            bumpVersion();
            emit channelRemoved(serverId, channelId);
            return;
        }
    }
}

void ChannelCache::updateCategory(const QString& serverId, const QVariantMap& category) {
    if (!m_categories.contains(serverId)) {
        return;
    }
    
    QString categoryId = extractId(category);
    if (categoryId.isEmpty()) {
        return;
    }
    
    QVariantList& categories = m_categories[serverId].data;
    for (int i = 0; i < categories.size(); ++i) {
        if (extractId(categories[i].toMap()) == categoryId) {
            categories[i] = category;
            m_categories[serverId].fetchedAt = QDateTime::currentDateTime();
            bumpVersion();
            emit categoryUpdated(serverId, categoryId);
            return;
        }
    }
}

void ChannelCache::addCategory(const QString& serverId, const QVariantMap& category) {
    QString categoryId = extractId(category);
    if (categoryId.isEmpty()) {
        return;
    }
    
    if (!m_categories.contains(serverId)) {
        CacheEntry entry;
        entry.fetchedAt = QDateTime::currentDateTime();
        m_categories[serverId] = entry;
    }
    
    QVariantList& categories = m_categories[serverId].data;
    for (const QVariant& v : categories) {
        if (extractId(v.toMap()) == categoryId) {
            updateCategory(serverId, category);
            return;
        }
    }
    
    categories.append(category);
    m_categories[serverId].fetchedAt = QDateTime::currentDateTime();
    bumpVersion();
}

void ChannelCache::removeCategory(const QString& serverId, const QString& categoryId) {
    if (!m_categories.contains(serverId) || categoryId.isEmpty()) {
        return;
    }
    
    QVariantList& categories = m_categories[serverId].data;
    for (int i = 0; i < categories.size(); ++i) {
        if (extractId(categories[i].toMap()) == categoryId) {
            categories.removeAt(i);
            bumpVersion();
            return;
        }
    }
}

// ============================================================================
// Cache management
// ============================================================================

void ChannelCache::markAllStale() {
    // Set all timestamps to null to mark as stale
    QDateTime veryOldTime = QDateTime::fromSecsSinceEpoch(0);
    
    for (auto it = m_channels.begin(); it != m_channels.end(); ++it) {
        it.value().fetchedAt = veryOldTime;
    }
    
    for (auto it = m_categories.begin(); it != m_categories.end(); ++it) {
        it.value().fetchedAt = veryOldTime;
    }
    
    qDebug() << "ChannelCache: All entries marked as stale";
}

void ChannelCache::refreshStaleEntries(const QStringList& serverIds) {
    for (const QString& serverId : serverIds) {
        // Refresh channels if stale
        if (!isFresh(serverId)) {
            refreshChannels(serverId);
        }
        
        // Refresh categories if stale
        if (m_categories.contains(serverId)) {
            const CacheEntry& entry = m_categories[serverId];
            if (entry.fetchedAt.isNull() || 
                entry.fetchedAt.secsTo(QDateTime::currentDateTime()) > m_ttlSeconds) {
                if (m_apiClient && !m_pendingCategoryFetches.contains(serverId)) {
                    m_pendingCategoryFetches.insert(serverId);
                    int requestId = m_apiClient->getCategories(serverId, false);
                    m_categoryRequestIds[requestId] = serverId;
                }
            }
        }
    }
}

void ChannelCache::clear() {
    m_channels.clear();
    m_categories.clear();
    m_pendingChannelFetches.clear();
    m_pendingCategoryFetches.clear();
    m_channelRequestIds.clear();
    m_categoryRequestIds.clear();
    bumpVersion();
}

void ChannelCache::clearServer(const QString& serverId) {
    m_channels.remove(serverId);
    m_categories.remove(serverId);
    m_pendingChannelFetches.remove(serverId);
    m_pendingCategoryFetches.remove(serverId);
    bumpVersion();
}

// ============================================================================
// Slots for API responses
// ============================================================================

void ChannelCache::onChannelsFetched(int requestId, const QString& serverId, const QVariantList& channels) {
    if (!m_channelRequestIds.contains(requestId)) {
        return;
    }
    
    QString storedServerId = m_channelRequestIds.take(requestId);
    if (storedServerId != serverId) {
        qWarning() << "ChannelCache: Server ID mismatch in response";
    }
    
    loadChannels(serverId, channels);
}

void ChannelCache::onChannelsFetchFailed(int requestId, const QString& serverId, const QString& error) {
    if (!m_channelRequestIds.contains(requestId)) {
        return;
    }
    
    m_channelRequestIds.remove(requestId);
    m_pendingChannelFetches.remove(serverId);
    
    qWarning() << "ChannelCache: Failed to fetch channels for server" << serverId << ":" << error;
}

void ChannelCache::onCategoriesFetched(int requestId, const QString& serverId, const QVariantList& categories) {
    if (!m_categoryRequestIds.contains(requestId)) {
        return;
    }
    
    m_categoryRequestIds.take(requestId);
    loadCategories(serverId, categories);
}

void ChannelCache::onCategoriesFetchFailed(int requestId, const QString& serverId, const QString& error) {
    if (!m_categoryRequestIds.contains(requestId)) {
        return;
    }
    
    m_categoryRequestIds.remove(requestId);
    m_pendingCategoryFetches.remove(serverId);
    
    qWarning() << "ChannelCache: Failed to fetch categories for server" << serverId << ":" << error;
}
