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

// ============================================================================
// Generic Request Infrastructure
// ============================================================================

int ApiClient::startGetRequest(RequestType type, const QString& endpoint, 
                                const QString& cacheKey, bool useCache,
                                const QVariantMap& context) {
    int requestId = generateRequestId();
    
    if (m_baseUrl.isEmpty()) {
        // Emit error asynchronously for consistent behavior
        QMetaObject::invokeMethod(this, [this, requestId, type, context]() {
            PendingRequest req;
            req.type = type;
            req.context = context;
            emitFailure(requestId, req, "API base URL not configured");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    // Check cache first if allowed
    if (useCache && !cacheKey.isEmpty()) {
        QVariantMap cachedData;
        if (checkCache(cacheKey, cachedData)) {
            qDebug() << "[ApiClient] Cache hit for:" << cacheKey;
            QMetaObject::invokeMethod(this, [this, requestId, type, context, cachedData]() {
                PendingRequest req;
                req.type = type;
                req.context = context;
                emitSuccess(requestId, req, cachedData);
            }, Qt::QueuedConnection);
            return requestId;
        }
    }
    
    // Check for request deduplication
    if (m_endpointToRequests.contains(endpoint)) {
        qDebug() << "[ApiClient] Deduplicating request for:" << endpoint;
        m_endpointToRequests[endpoint].append(requestId);
        
        PendingRequest pending;
        pending.reply = nullptr;  // No direct reply, sharing existing
        pending.endpoint = endpoint;
        pending.cacheKey = cacheKey;
        pending.type = type;
        pending.context = context;
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
    pending.type = type;
    pending.context = context;
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
        updateCache(cacheKey, result.data);
    }
    
    // Get all requestIds waiting for this endpoint
    QList<int> waitingRequests = m_endpointToRequests.take(endpoint);
    
    // Complete all waiting requests with the same result
    for (int requestId : waitingRequests) {
        handleRequestComplete(requestId, result);
    }
}

void ApiClient::handleRequestComplete(int requestId, const ApiResult& result) {
    if (!m_pendingRequests.contains(requestId)) {
        return;
    }
    
    PendingRequest req = m_pendingRequests.take(requestId);
    
    if (result.success) {
        emitSuccess(requestId, req, result.data);
    } else {
        emitFailure(requestId, req, result.errorMessage);
    }
}

// ============================================================================
// Signal Emission (routes based on RequestType)
// ============================================================================

void ApiClient::emitSuccess(int requestId, const PendingRequest& req, const QVariantMap& data) {
    switch (req.type) {
        case RequestType::Profile:
            emit profileFetched(requestId, data);
            break;
            
        case RequestType::MyProfile:
            emit profileFetched(requestId, data);
            emit myProfileFetched(data);
            break;
            
        case RequestType::Servers:
            emit serversFetched(requestId, data.value("items").toList());
            break;
            
        case RequestType::ServerDetails:
            emit serverDetailsFetched(requestId, data);
            break;
            
        case RequestType::Channels:
            emit channelsFetched(requestId, req.context.value("serverId").toString(), 
                                 data.value("items").toList());
            break;
            
        case RequestType::ChannelDetails:
            emit channelDetailsFetched(requestId, data);
            break;
            
        case RequestType::Messages:
            emit messagesFetched(requestId, req.context.value("serverId").toString(),
                                 req.context.value("channelId").toString(),
                                 data.value("items").toList());
            break;
            
        case RequestType::SendMessage:
            emit messageSent(requestId, data);
            break;
            
        case RequestType::Friends:
            emit friendsFetched(requestId, data.value("items").toList());
            break;
            
        case RequestType::JoinServer:
            emit serverJoined(requestId, data.value("serverId").toString());
            break;
            
        case RequestType::CreateServer:
            emit serverCreated(requestId, data.value("server").toMap());
            break;
            
        case RequestType::ServerMembers:
            emit serverMembersFetched(requestId, req.context.value("serverId").toString(),
                                      data.value("items").toList());
            break;
            
        case RequestType::ServerEmojis:
            emit serverEmojisFetched(requestId, req.context.value("serverId").toString(),
                                     data.value("items").toList());
            break;
            
        case RequestType::AllEmojis:
            emit allEmojisFetched(requestId, data.value("items").toList());
            break;
            
        case RequestType::SingleEmoji:
            emit emojiFetched(requestId, req.context.value("emojiId").toString(), data);
            break;
            
        case RequestType::DMMessages:
            emit dmMessagesFetched(requestId, req.context.value("recipientId").toString(),
                                   data.value("items").toList());
            break;
            
        case RequestType::SendDMMessage:
            emit dmMessageSent(requestId, data);
            break;
    }
}

void ApiClient::emitFailure(int requestId, const PendingRequest& req, const QString& error) {
    switch (req.type) {
        case RequestType::Profile:
            emit profileFetchFailed(requestId, error);
            break;
            
        case RequestType::MyProfile:
            emit profileFetchFailed(requestId, error);
            emit myProfileFetchFailed(error);
            break;
            
        case RequestType::Servers:
            emit serversFetchFailed(requestId, error);
            break;
            
        case RequestType::ServerDetails:
            emit serverDetailsFetchFailed(requestId, error);
            break;
            
        case RequestType::Channels:
            emit channelsFetchFailed(requestId, req.context.value("serverId").toString(), error);
            break;
            
        case RequestType::ChannelDetails:
            emit channelDetailsFetchFailed(requestId, error);
            break;
            
        case RequestType::Messages:
            emit messagesFetchFailed(requestId, req.context.value("serverId").toString(),
                                     req.context.value("channelId").toString(), error);
            break;
            
        case RequestType::SendMessage:
            emit messageSendFailed(requestId, error);
            break;
            
        case RequestType::Friends:
            emit friendsFetchFailed(requestId, error);
            break;
            
        case RequestType::JoinServer:
            emit serverJoinFailed(requestId, error);
            break;
            
        case RequestType::CreateServer:
            emit serverCreateFailed(requestId, error);
            break;
            
        case RequestType::ServerMembers:
            emit serverMembersFetchFailed(requestId, req.context.value("serverId").toString(), error);
            break;
            
        case RequestType::ServerEmojis:
            emit serverEmojisFetchFailed(requestId, req.context.value("serverId").toString(), error);
            break;
            
        case RequestType::AllEmojis:
            emit allEmojisFetchFailed(requestId, error);
            break;
            
        case RequestType::SingleEmoji:
            emit emojiFetchFailed(requestId, req.context.value("emojiId").toString(), error);
            break;
            
        case RequestType::DMMessages:
            emit dmMessagesFetchFailed(requestId, req.context.value("recipientId").toString(), error);
            break;
            
        case RequestType::SendDMMessage:
            emit dmMessageSendFailed(requestId, error);
            break;
    }
}
