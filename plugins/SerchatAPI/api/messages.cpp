#include "apiclient.h"
#include "../network/networkclient.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>

// ============================================================================
// Messages API
// ============================================================================

int ApiClient::getMessages(const QString& serverId, const QString& channelId, 
                           int limit, const QString& before) {
    if (serverId.isEmpty() || channelId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId, serverId, channelId]() {
            PendingRequest req;
            req.type = RequestType::Messages;
            req.context["serverId"] = serverId;
            req.context["channelId"] = channelId;
            emitFailure(requestId, req, "Server ID and Channel ID are required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    // Build endpoint with query parameters
    QString endpoint = QStringLiteral("/api/v1/servers/%1/channels/%2/messages?limit=%3")
                        .arg(serverId, channelId, QString::number(limit));
    
    if (!before.isEmpty()) {
        endpoint += QStringLiteral("&before=%1").arg(before);
    }
    
    // Don't cache messages - they change frequently
    QString cacheKey;  // Empty = no caching
    
    QVariantMap context;
    context["serverId"] = serverId;
    context["channelId"] = channelId;
    
    return startGetRequest(RequestType::Messages, endpoint, cacheKey, false, context);
}

int ApiClient::sendMessage(const QString& serverId, const QString& channelId,
                           const QString& text, const QString& replyToId) {
    int requestId = generateRequestId();
    
    if (serverId.isEmpty() || channelId.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendMessage;
            emitFailure(requestId, req, "Server ID and Channel ID are required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    if (text.trimmed().isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendMessage;
            emitFailure(requestId, req, "Message text is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    if (m_baseUrl.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendMessage;
            emitFailure(requestId, req, "API base URL not configured");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString endpoint = QStringLiteral("/api/v1/servers/%1/channels/%2/messages")
                        .arg(serverId, channelId);
    
    // Build JSON body
    QJsonObject body;
    body["content"] = text.trimmed();
    if (!replyToId.isEmpty()) {
        body["replyToId"] = replyToId;
    }
    
    QJsonDocument doc(body);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
    
    // Make the POST request
    QUrl url = buildUrl(m_baseUrl, endpoint);
    QNetworkReply* reply = m_networkClient->post(url, jsonData);
    
    // Track the request
    PendingRequest pending;
    pending.reply = reply;
    pending.endpoint = endpoint;
    pending.cacheKey = QString();  // No caching for POST
    pending.type = RequestType::SendMessage;
    pending.context["serverId"] = serverId;
    pending.context["channelId"] = channelId;
    m_pendingRequests[requestId] = pending;
    
    // Store requestId in reply for lookup in slot
    reply->setProperty("requestId", requestId);
    connect(reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);
    
    qDebug() << "[ApiClient] Started send message request" << requestId;
    return requestId;
}

// ============================================================================
// Direct Messages API
// ============================================================================

int ApiClient::getDMMessages(const QString& userId, int limit, const QString& before) {
    if (userId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId, userId]() {
            PendingRequest req;
            req.type = RequestType::DMMessages;
            req.context["recipientId"] = userId;
            emitFailure(requestId, req, "User ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    // Build endpoint with query parameters
    QString endpoint = QStringLiteral("/api/v1/messages?userId=%1&limit=%2")
                        .arg(userId, QString::number(limit));
    
    if (!before.isEmpty()) {
        endpoint += QStringLiteral("&before=%1").arg(before);
    }
    
    // Don't cache DM messages - they change frequently
    QString cacheKey;  // Empty = no caching
    
    QVariantMap context;
    context["recipientId"] = userId;
    
    return startGetRequest(RequestType::DMMessages, endpoint, cacheKey, false, context);
}

int ApiClient::sendDMMessage(const QString& userId, const QString& text, const QString& replyToId) {
    int requestId = generateRequestId();
    
    if (userId.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendDMMessage;
            emitFailure(requestId, req, "User ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    if (text.trimmed().isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendDMMessage;
            emitFailure(requestId, req, "Message text is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    if (m_baseUrl.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendDMMessage;
            emitFailure(requestId, req, "API base URL not configured");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString endpoint = QStringLiteral("/api/v1/messages/%1").arg(userId);
    
    // Build JSON body
    QJsonObject body;
    body["content"] = text.trimmed();
    if (!replyToId.isEmpty()) {
        body["replyToId"] = replyToId;
    }
    
    QJsonDocument doc(body);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
    
    // Make the POST request
    QUrl url = buildUrl(m_baseUrl, endpoint);
    QNetworkReply* reply = m_networkClient->post(url, jsonData);
    
    // Track the request
    PendingRequest pending;
    pending.reply = reply;
    pending.endpoint = endpoint;
    pending.cacheKey = QString();  // No caching for POST
    pending.type = RequestType::SendDMMessage;
    pending.context["recipientId"] = userId;
    m_pendingRequests[requestId] = pending;
    
    // Store requestId in reply for lookup in slot
    reply->setProperty("requestId", requestId);
    connect(reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);
    
    qDebug() << "[ApiClient] Started send DM message request" << requestId;
    return requestId;
}
