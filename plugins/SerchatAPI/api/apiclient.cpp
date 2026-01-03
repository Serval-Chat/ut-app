#include "apiclient.h"
#include "../network/networkclient.h"
#include <QDebug>

ApiClient::ApiClient(NetworkClient* networkClient, QObject* parent)
    : ApiBase(parent)
    , m_networkClient(networkClient)
{
}

ApiClient::~ApiClient() {
    cancelAllRequests();
}

// ============================================================================
// Profile API
// ============================================================================

int ApiClient::getMyProfile() {
    return getProfile("me", true);
}

int ApiClient::getProfile(const QString& userId, bool useCache) {
    int requestId = generateRequestId();
    
    if (m_baseUrl.isEmpty()) {
        // Use QTimer to emit asynchronously (consistent behavior)
        QMetaObject::invokeMethod(this, [this, requestId]() {
            completeRequest(requestId, false, {}, "API base URL not configured");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = userId;
    bool isMyProfile = (userId == "me");
    
    // Check cache first if allowed
    if (useCache && m_profileCache.contains(cacheKey)) {
        const CacheEntry& entry = m_profileCache[cacheKey];
        if (entry.isValid()) {
            qDebug() << "[ApiClient] Cache hit for profile:" << userId;
            // Emit asynchronously for consistent behavior
            QVariantMap cachedData = entry.data;
            QMetaObject::invokeMethod(this, [this, requestId, cachedData, isMyProfile]() {
                emit profileFetched(requestId, cachedData);
                if (isMyProfile) {
                    emit myProfileFetched(cachedData);
                }
            }, Qt::QueuedConnection);
            return requestId;
        } else {
            // Expired, remove from cache
            m_profileCache.remove(cacheKey);
        }
    }
    
    // Build endpoint
    QString endpoint = (userId == "me") 
        ? "/api/v1/profile/me" 
        : QString("/api/v1/profile/%1").arg(userId);
    
    // Check for request deduplication - if we already have an in-flight request
    // for this endpoint, just add our requestId to the waiting list
    if (m_endpointToRequests.contains(endpoint)) {
        qDebug() << "[ApiClient] Deduplicating request for:" << endpoint;
        m_endpointToRequests[endpoint].append(requestId);
        
        // Create a pending request entry without a reply (we'll share the existing one)
        PendingRequest pending;
        pending.reply = nullptr;  // No direct reply, we're sharing
        pending.endpoint = endpoint;
        pending.cacheKey = cacheKey;
        pending.isMyProfile = isMyProfile;
        m_pendingRequests[requestId] = pending;
        
        return requestId;
    }
    
    // Make the actual network request
    QUrl url = buildUrl(m_baseUrl, endpoint);
    QNetworkReply* reply = m_networkClient->get(url);
    
    // Track the request
    PendingRequest pending;
    pending.reply = reply;
    pending.endpoint = endpoint;
    pending.cacheKey = cacheKey;
    pending.isMyProfile = isMyProfile;
    m_pendingRequests[requestId] = pending;
    
    // Track endpoint -> requestIds for deduplication
    m_endpointToRequests[endpoint].append(requestId);
    
    // Store requestId in reply for lookup in slot
    reply->setProperty("requestId", requestId);
    connect(reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);
    
    qDebug() << "[ApiClient] Started request" << requestId << "for" << endpoint;
    return requestId;
}

void ApiClient::onReplyFinished() {
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    
    int primaryRequestId = reply->property("requestId").toInt();
    
    // Find the pending request to get endpoint info
    if (!m_pendingRequests.contains(primaryRequestId)) {
        reply->deleteLater();
        return;
    }
    
    PendingRequest& primary = m_pendingRequests[primaryRequestId];
    QString endpoint = primary.endpoint;
    QString cacheKey = primary.cacheKey;
    
    // Process the reply
    ApiResult result = handleReply(reply);
    reply->deleteLater();
    
    // Cache successful results
    if (result.success && !cacheKey.isEmpty()) {
        CacheEntry entry;
        entry.data = result.data;
        entry.expiry = QDateTime::currentDateTime().addSecs(m_cacheTTLSeconds);
        m_profileCache[cacheKey] = entry;
        qDebug() << "[ApiClient] Cached profile for:" << cacheKey;
    }
    
    // Get all requestIds waiting for this endpoint
    QList<int> waitingRequests = m_endpointToRequests.take(endpoint);
    
    // Complete all waiting requests with the same result
    for (int requestId : waitingRequests) {
        if (m_pendingRequests.contains(requestId)) {
            PendingRequest& req = m_pendingRequests[requestId];
            
            if (result.success) {
                emit profileFetched(requestId, result.data);
                if (req.isMyProfile) {
                    emit myProfileFetched(result.data);
                }
            } else {
                emit profileFetchFailed(requestId, result.errorMessage);
                if (req.isMyProfile) {
                    emit myProfileFetchFailed(result.errorMessage);
                }
            }
            
            m_pendingRequests.remove(requestId);
        }
    }
}

// ============================================================================
// Cache Management
// ============================================================================

void ApiClient::clearCache() {
    m_profileCache.clear();
    qDebug() << "[ApiClient] Cache cleared";
}

void ApiClient::clearCacheFor(const QString& userId) {
    m_profileCache.remove(userId);
    qDebug() << "[ApiClient] Cache cleared for:" << userId;
}

bool ApiClient::hasCachedProfile(const QString& userId) const {
    if (!m_profileCache.contains(userId)) {
        return false;
    }
    return m_profileCache[userId].isValid();
}

// ============================================================================
// Request Management
// ============================================================================

void ApiClient::cancelRequest(int requestId) {
    if (!m_pendingRequests.contains(requestId)) {
        return;
    }
    
    PendingRequest& req = m_pendingRequests[requestId];
    
    // Remove from endpoint tracking
    if (m_endpointToRequests.contains(req.endpoint)) {
        m_endpointToRequests[req.endpoint].removeAll(requestId);
        if (m_endpointToRequests[req.endpoint].isEmpty()) {
            m_endpointToRequests.remove(req.endpoint);
        }
    }
    
    // Only abort if this request owns the reply
    if (req.reply) {
        req.reply->abort();
        req.reply->deleteLater();
    }
    
    m_pendingRequests.remove(requestId);
    qDebug() << "[ApiClient] Cancelled request:" << requestId;
}

void ApiClient::cancelAllRequests() {
    QList<int> requestIds = m_pendingRequests.keys();
    for (int requestId : requestIds) {
        cancelRequest(requestId);
    }
}

bool ApiClient::isRequestPending(int requestId) const {
    return m_pendingRequests.contains(requestId);
}

void ApiClient::completeRequest(int requestId, bool success, const QVariantMap& data, const QString& error) {
    // Check if request was cancelled
    if (!m_pendingRequests.contains(requestId)) {
        return;
    }
    
    PendingRequest& req = m_pendingRequests[requestId];
    bool isMyProfile = req.isMyProfile;
    
    cleanupRequest(requestId);
    
    if (success) {
        emit profileFetched(requestId, data);
        if (isMyProfile) {
            emit myProfileFetched(data);
        }
    } else {
        emit profileFetchFailed(requestId, error);
        if (isMyProfile) {
            emit myProfileFetchFailed(error);
        }
    }
}

void ApiClient::cleanupRequest(int requestId) {
    if (!m_pendingRequests.contains(requestId)) {
        return;
    }
    
    PendingRequest& req = m_pendingRequests[requestId];
    
    // Remove from endpoint tracking
    if (m_endpointToRequests.contains(req.endpoint)) {
        m_endpointToRequests[req.endpoint].removeAll(requestId);
        if (m_endpointToRequests[req.endpoint].isEmpty()) {
            m_endpointToRequests.remove(req.endpoint);
        }
    }
    
    m_pendingRequests.remove(requestId);
}