#include "apiclient.h"
#include "../network/networkclient.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>

// ============================================================================
// Servers API
// ============================================================================

int ApiClient::getServers(bool useCache) {
    QString cacheKey = QStringLiteral("servers:list");
    QString endpoint = "/api/v1/servers";
    
    return startGetRequest(RequestType::Servers, endpoint, cacheKey, useCache);
}

int ApiClient::getServerDetails(const QString& serverId, bool useCache) {
    if (serverId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::ServerDetails;
            emitFailure(requestId, req, "Server ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("server:%1").arg(serverId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1").arg(serverId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    
    return startGetRequest(RequestType::ServerDetails, endpoint, cacheKey, useCache, context);
}

int ApiClient::getChannels(const QString& serverId, bool useCache) {
    if (serverId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::Channels;
            emitFailure(requestId, req, "Server ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("channels:%1").arg(serverId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1/channels").arg(serverId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    
    return startGetRequest(RequestType::Channels, endpoint, cacheKey, useCache, context);
}

int ApiClient::getChannelDetails(const QString& serverId, const QString& channelId, bool useCache) {
    if (serverId.isEmpty() || channelId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::ChannelDetails;
            emitFailure(requestId, req, "Server ID and Channel ID are required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("channel:%1:%2").arg(serverId, channelId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1/channels/%2").arg(serverId, channelId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    context["channelId"] = channelId;
    
    return startGetRequest(RequestType::ChannelDetails, endpoint, cacheKey, useCache, context);
}

// ============================================================================
// Friends API (for DM conversations)
// ============================================================================

int ApiClient::getFriends(bool useCache) {
    QString cacheKey = QStringLiteral("friends:list");
    QString endpoint = "/api/v1/friends";
    
    return startGetRequest(RequestType::Friends, endpoint, cacheKey, useCache);
}

// ============================================================================
// Server Management API
// ============================================================================

int ApiClient::joinServerByInvite(const QString& inviteCode) {
    int requestId = generateRequestId();
    
    if (inviteCode.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::JoinServer;
            emitFailure(requestId, req, "Invite code is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    if (m_baseUrl.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::JoinServer;
            emitFailure(requestId, req, "API base URL not configured");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString endpoint = QStringLiteral("/api/v1/invites/%1/join").arg(inviteCode);
    
    // POST with empty body
    QUrl url = buildUrl(m_baseUrl, endpoint);
    QNetworkReply* reply = m_networkClient->post(url, QByteArray("{}"));
    
    // Track the request
    PendingRequest pending;
    pending.reply = reply;
    pending.endpoint = endpoint;
    pending.cacheKey = QString();  // No caching for POST
    pending.type = RequestType::JoinServer;
    m_pendingRequests[requestId] = pending;
    
    reply->setProperty("requestId", requestId);
    connect(reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);
    
    qDebug() << "[ApiClient] Started join server request" << requestId << "with code:" << inviteCode;
    return requestId;
}

int ApiClient::createServer(const QString& name) {
    int requestId = generateRequestId();
    
    if (name.trimmed().isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::CreateServer;
            emitFailure(requestId, req, "Server name is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    if (m_baseUrl.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::CreateServer;
            emitFailure(requestId, req, "API base URL not configured");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString endpoint = "/api/v1/servers";
    
    // Build JSON body
    QJsonObject body;
    body["name"] = name.trimmed();
    
    QJsonDocument doc(body);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
    
    // POST request
    QUrl url = buildUrl(m_baseUrl, endpoint);
    QNetworkReply* reply = m_networkClient->post(url, jsonData);
    
    // Track the request
    PendingRequest pending;
    pending.reply = reply;
    pending.endpoint = endpoint;
    pending.cacheKey = QString();  // No caching for POST
    pending.type = RequestType::CreateServer;
    m_pendingRequests[requestId] = pending;
    
    reply->setProperty("requestId", requestId);
    connect(reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);
    
    qDebug() << "[ApiClient] Started create server request" << requestId << "with name:" << name;
    return requestId;
}
