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

int ApiClient::getCategories(const QString& serverId, bool useCache) {
    if (serverId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::Categories;
            emitFailure(requestId, req, "Server ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("categories:%1").arg(serverId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1/categories").arg(serverId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    
    return startGetRequest(RequestType::Categories, endpoint, cacheKey, useCache, context);
}

// ============================================================================
// Server Members API
// ============================================================================

int ApiClient::getServerMembers(const QString& serverId, bool useCache) {
    if (serverId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::ServerMembers;
            emitFailure(requestId, req, "Server ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("members:%1").arg(serverId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1/members").arg(serverId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    
    return startGetRequest(RequestType::ServerMembers, endpoint, cacheKey, useCache, context);
}

// ============================================================================
// Server Roles API
// ============================================================================

int ApiClient::getServerRoles(const QString& serverId, bool useCache) {
    if (serverId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::ServerRoles;
            emitFailure(requestId, req, "Server ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("roles:%1").arg(serverId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1/roles").arg(serverId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    
    return startGetRequest(RequestType::ServerRoles, endpoint, cacheKey, useCache, context);
}

// ============================================================================
// Server Emojis API
// ============================================================================

int ApiClient::getServerEmojis(const QString& serverId, bool useCache) {
    if (serverId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::ServerEmojis;
            emitFailure(requestId, req, "Server ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("emojis:%1").arg(serverId);
    QString endpoint = QStringLiteral("/api/v1/servers/%1/emojis").arg(serverId);
    
    QVariantMap context;
    context["serverId"] = serverId;
    
    return startGetRequest(RequestType::ServerEmojis, endpoint, cacheKey, useCache, context);
}

int ApiClient::getAllEmojis(bool useCache) {
    QString cacheKey = QStringLiteral("emojis:all");
    QString endpoint = "/api/v1/emojis";
    
    return startGetRequest(RequestType::AllEmojis, endpoint, cacheKey, useCache);
}

int ApiClient::getEmojiById(const QString& emojiId, bool useCache) {
    if (emojiId.isEmpty()) {
        int requestId = generateRequestId();
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SingleEmoji;
            emitFailure(requestId, req, "Emoji ID is required");
        }, Qt::QueuedConnection);
        return requestId;
    }
    
    QString cacheKey = QStringLiteral("emoji:%1").arg(emojiId);
    QString endpoint = QStringLiteral("/api/v1/emojis/%1").arg(emojiId);
    
    QVariantMap context;
    context["emojiId"] = emojiId;
    
    return startGetRequest(RequestType::SingleEmoji, endpoint, cacheKey, useCache, context);
}

// ============================================================================
// Friends API (for DM conversations)
// ============================================================================

int ApiClient::getFriends(bool useCache) {
    QString cacheKey = QStringLiteral("friends:list");
    QString endpoint = "/api/v1/friends";
    
    return startGetRequest(RequestType::Friends, endpoint, cacheKey, useCache);
}

int ApiClient::sendFriendRequest(const QString& username) {
    int requestId = generateRequestId();
    
    if (username.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::SendFriendRequest;
            emitFailure(requestId, req, "Username is required");
        });
        return requestId;
    }
    
    QJsonObject payload;
    payload["username"] = username;
    
    QString endpoint = "/api/v1/friends";
    
    return startPostRequest(RequestType::SendFriendRequest, endpoint, payload, QString());
}

int ApiClient::removeFriend(const QString& friendId) {
    int requestId = generateRequestId();
    
    if (friendId.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            PendingRequest req;
            req.type = RequestType::RemoveFriend;
            emitFailure(requestId, req, "Friend ID is required");
        });
        return requestId;
    }
    
    QString endpoint = QString("/api/v1/friends/%1").arg(friendId);
    
    return startDeleteRequest(RequestType::RemoveFriend, endpoint, QString());
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
