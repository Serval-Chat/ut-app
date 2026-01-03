#include "apiclient.h"
#include <QDebug>

// ============================================================================
// Cache Management
// ============================================================================

void ApiClient::clearCache() {
    m_cache.clear();
    qDebug() << "[ApiClient] Cache cleared";
}

void ApiClient::clearCacheFor(const QString& cacheKey) {
    m_cache.remove(cacheKey);
    qDebug() << "[ApiClient] Cache cleared for:" << cacheKey;
}

bool ApiClient::hasCachedData(const QString& cacheKey) const {
    if (!m_cache.contains(cacheKey)) {
        return false;
    }
    return m_cache[cacheKey].isValid();
}

bool ApiClient::checkCache(const QString& cacheKey, QVariantMap& outData) const {
    if (cacheKey.isEmpty()) {
        return false;
    }
    
    if (!m_cache.contains(cacheKey)) {
        return false;
    }
    
    const CacheEntry& entry = m_cache[cacheKey];
    if (!entry.isValid()) {
        return false;
    }
    
    outData = entry.data;
    return true;
}

void ApiClient::updateCache(const QString& cacheKey, const QVariantMap& data) {
    if (cacheKey.isEmpty()) {
        return;
    }
    
    CacheEntry entry;
    entry.data = data;
    entry.expiry = QDateTime::currentDateTime().addSecs(m_cacheTTLSeconds);
    m_cache[cacheKey] = entry;
    qDebug() << "[ApiClient] Cached data for:" << cacheKey;
}