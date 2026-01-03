#include "apiclient.h"
#include <QDebug>

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
