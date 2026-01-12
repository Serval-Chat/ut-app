#include "socketclient.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDateTime>

SocketClient::SocketClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_connected(false)
    , m_authenticated(false)
    , m_pingTimer(new QTimer(this))
    , m_pongTimeoutTimer(new QTimer(this))
    , m_pingInterval(25000)   // Send ping every 25 seconds
    , m_pingTimeout(10000)    // Wait 10 seconds for pong
    , m_reconnectTimer(new QTimer(this))
    , m_reconnectAttempts(0)
    , m_maxReconnectAttempts(10)
    , m_shouldReconnect(true)
{
    QObject::connect(m_socket, &QWebSocket::connected, 
                     this, &SocketClient::onWebSocketConnected);
    QObject::connect(m_socket, &QWebSocket::disconnected, 
                     this, &SocketClient::onWebSocketDisconnected);
    QObject::connect(m_socket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
                     this, &SocketClient::onWebSocketError);
    QObject::connect(m_socket, &QWebSocket::textMessageReceived,
                     this, &SocketClient::onTextMessageReceived);
    
    // Ping timer - send heartbeat to keep connection alive
    QObject::connect(m_pingTimer, &QTimer::timeout, 
                     this, &SocketClient::onPingTimeout);
    // Pong timeout timer - if we don't get pong from server, connection is dead
    QObject::connect(m_pongTimeoutTimer, &QTimer::timeout,
                     this, &SocketClient::onPongTimeout);
    QObject::connect(m_reconnectTimer, &QTimer::timeout,
                     this, &SocketClient::onReconnectTimeout);
    
    m_pingTimer->setSingleShot(false);
    m_pongTimeoutTimer->setSingleShot(true);
    m_reconnectTimer->setSingleShot(true);
}

SocketClient::~SocketClient()
{
    m_shouldReconnect = false;
    disconnect();
}

QString SocketClient::generateMessageId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void SocketClient::connect(const QString& url, const QString& authToken)
{
    if (m_connected) {
        disconnect();
    }
    
    m_url = url;
    m_authToken = authToken;
    m_reconnectAttempts = 0;
    m_shouldReconnect = true;
    m_authenticated = false;
    
    // Build WebSocket URL
    QUrl wsUrl(url);
    if (wsUrl.scheme() == "https") {
        wsUrl.setScheme("wss");
    } else if (wsUrl.scheme() == "http") {
        wsUrl.setScheme("ws");
    }
    
    // Use /ws endpoint for pure WebSocket
    QString path = wsUrl.path();
    if (path.isEmpty() || path == "/") {
        path = "/ws";
    } else if (!path.endsWith("/ws")) {
        if (path.endsWith("/")) {
            path = path + "ws";
        } else {
            path = path + "/ws";
        }
    }
    wsUrl.setPath(path);
    
    qDebug() << "[SocketClient] Connecting to:" << wsUrl.toString();
    
    m_socket->open(wsUrl);
}

void SocketClient::disconnect()
{
    m_shouldReconnect = false;
    m_pingTimer->stop();
    m_pongTimeoutTimer->stop();
    m_reconnectTimer->stop();
    m_pendingReplies.clear();

    m_socket->close();
    m_connected = false;
    m_authenticated = false;
}

void SocketClient::resetReconnectAttempts()
{
    m_reconnectAttempts = 0;
    m_shouldReconnect = true;
    m_reconnectTimer->stop();
    qDebug() << "[SocketClient] Reconnect attempts reset";
}

void SocketClient::checkConnectionHealth()
{
    if (!m_connected || !m_authenticated) {
        qDebug() << "[SocketClient] Not connected/authenticated, skipping health check";
        return;
    }

    qDebug() << "[SocketClient] Checking connection health";
    sendPing();
}

// ============================================================================
// Event emission
// ============================================================================

void SocketClient::sendEnvelope(const QString& eventType, const QVariantMap& payload,
                                 const QString& replyTo)
{
    if (!m_connected) {
        qWarning() << "[SocketClient] Cannot send event, not connected:" << eventType;
        return;
    }
    
    QJsonObject envelope;
    envelope["id"] = generateMessageId();
    
    QJsonObject event;
    event["type"] = eventType;
    event["payload"] = QJsonObject::fromVariantMap(payload);
    envelope["event"] = event;
    
    QJsonObject meta;
    if (!replyTo.isEmpty()) {
        meta["replyTo"] = replyTo;
    }
    meta["ts"] = QDateTime::currentMSecsSinceEpoch();
    envelope["meta"] = meta;
    
    QJsonDocument doc(envelope);
    QString message = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
    
    qDebug() << "[SocketClient] Sending:" << eventType;
    m_socket->sendTextMessage(message);
}

void SocketClient::emitEvent(const QString& eventType, const QVariantMap& payload)
{
    sendEnvelope(eventType, payload);
}

void SocketClient::sendAuthentication()
{
    QVariantMap payload;
    payload["token"] = m_authToken;
    sendEnvelope("authenticate", payload);
}

void SocketClient::sendPing()
{
    sendEnvelope("ping", {});
    m_pongTimeoutTimer->start(m_pingTimeout);
}

// ============================================================================
// High-level API methods
// ============================================================================

void SocketClient::joinServer(const QString& serverId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    emitEvent("join_server", payload);
}

void SocketClient::joinChannel(const QString& serverId, const QString& channelId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    payload["channelId"] = channelId;
    emitEvent("join_channel", payload);
}

void SocketClient::leaveServer(const QString& serverId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    emitEvent("leave_server", payload);
}

void SocketClient::leaveChannel(const QString& channelId)
{
    QVariantMap payload;
    payload["channelId"] = channelId;
    emitEvent("leave_channel", payload);
}

void SocketClient::markChannelRead(const QString& serverId, const QString& channelId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    payload["channelId"] = channelId;
    emitEvent("mark_channel_read", payload);
}

void SocketClient::markDMRead(const QString& peerId)
{
    QVariantMap payload;
    payload["peerId"] = peerId;
    emitEvent("mark_dm_read", payload);
}

void SocketClient::sendTyping(const QString& serverId, const QString& channelId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    payload["channelId"] = channelId;
    emitEvent("typing_server", payload);
}

void SocketClient::sendDMTyping(const QString& receiverId)
{
    QVariantMap payload;
    payload["receiverId"] = receiverId;
    emitEvent("typing_dm", payload);
}

void SocketClient::sendServerMessage(const QString& serverId, const QString& channelId, 
                                      const QString& text, const QString& replyToId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    payload["channelId"] = channelId;
    payload["text"] = text;
    if (!replyToId.isEmpty()) {
        payload["replyToId"] = replyToId;
    }
    emitEvent("send_message_server", payload);
}

void SocketClient::sendDirectMessage(const QString& receiverId, const QString& text, 
                                      const QString& replyToId)
{
    QVariantMap payload;
    payload["receiverId"] = receiverId;
    payload["text"] = text;
    if (!replyToId.isEmpty()) {
        payload["replyToId"] = replyToId;
    }
    emitEvent("send_message_dm", payload);
}

void SocketClient::editServerMessage(const QString& messageId, const QString& text)
{
    QVariantMap payload;
    payload["messageId"] = messageId;
    payload["text"] = text;
    emitEvent("edit_message_server", payload);
}

void SocketClient::deleteServerMessage(const QString& serverId, const QString& messageId)
{
    QVariantMap payload;
    payload["serverId"] = serverId;
    payload["messageId"] = messageId;
    emitEvent("delete_message_server", payload);
}

void SocketClient::editDirectMessage(const QString& messageId, const QString& text)
{
    QVariantMap payload;
    payload["messageId"] = messageId;
    payload["text"] = text;
    emitEvent("edit_message_dm", payload);
}

void SocketClient::deleteDirectMessage(const QString& messageId)
{
    QVariantMap payload;
    payload["messageId"] = messageId;
    emitEvent("delete_message_dm", payload);
}

void SocketClient::addReaction(const QString& messageId, const QString& messageType,
                               const QString& emoji, const QString& emojiType,
                               const QString& emojiId)
{
    QVariantMap payload;
    payload["messageId"] = messageId;
    payload["emoji"] = emoji;
    payload["emojiType"] = emojiType;
    payload["messageType"] = messageType;
    if (!emojiId.isEmpty()) {
        payload["emojiId"] = emojiId;
    }
    emitEvent("add_reaction", payload);
}

void SocketClient::removeReaction(const QString& messageId, const QString& messageType,
                                   const QString& emoji, const QString& emojiType,
                                   const QString& emojiId)
{
    QVariantMap payload;
    payload["messageId"] = messageId;
    payload["emoji"] = emoji;
    payload["emojiType"] = emojiType;
    payload["messageType"] = messageType;
    if (!emojiId.isEmpty()) {
        payload["emojiId"] = emojiId;
    }
    emitEvent("remove_reaction", payload);
}

void SocketClient::setStatus(const QString& status)
{
    QVariantMap payload;
    payload["status"] = status;
    emitEvent("set_status", payload);
}

// ============================================================================
// WebSocket event handlers
// ============================================================================

void SocketClient::onWebSocketConnected()
{
    qDebug() << "[SocketClient] WebSocket connected";
    m_connected = true;
    m_reconnectAttempts = 0;
    
    // Send authentication immediately (within 30s grace period)
    if (!m_authToken.isEmpty()) {
        sendAuthentication();
    }
    
    emit connectedChanged();
}

void SocketClient::onWebSocketDisconnected()
{
    qDebug() << "[SocketClient] WebSocket disconnected";
    bool wasConnected = m_connected && m_authenticated;
    m_connected = false;
    m_authenticated = false;
    m_pingTimer->stop();
    m_pongTimeoutTimer->stop();
    m_pendingReplies.clear();
    
    emit connectedChanged();
    if (wasConnected) {
        emit disconnected();
    }
    
    if (m_shouldReconnect) {
        scheduleReconnect();
    }
}

void SocketClient::onWebSocketError(QAbstractSocket::SocketError err)
{
    qWarning() << "[SocketClient] WebSocket error:" << err << m_socket->errorString();
    emit error(m_socket->errorString());
}

void SocketClient::onTextMessageReceived(const QString& message)
{
    if (message.isEmpty()) return;
    
    // Reset ping timer on any message received
    if (m_pingTimer->isActive()) {
        m_pingTimer->start(m_pingInterval);
    }
    m_pongTimeoutTimer->stop();
    
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8(), &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "[SocketClient] JSON parse error:" << parseError.errorString();
        return;
    }
    
    if (!doc.isObject()) {
        qWarning() << "[SocketClient] Expected JSON object envelope";
        return;
    }
    
    handleEnvelope(doc.object());
}

void SocketClient::onPingTimeout()
{
    if (m_connected && m_authenticated) {
        sendPing();
    }
}

void SocketClient::onPongTimeout()
{
    qWarning() << "[SocketClient] Pong timeout - connection appears dead";
    m_socket->close();
}

void SocketClient::onReconnectTimeout()
{
    attemptReconnect();
}

// ============================================================================
// Envelope handling
// ============================================================================

void SocketClient::handleEnvelope(const QJsonObject& envelope)
{
    QString messageId = envelope["id"].toString();
    QJsonObject event = envelope["event"].toObject();
    QJsonObject meta = envelope["meta"].toObject();
    
    QString eventType = event["type"].toString();
    QJsonObject payload = event["payload"].toObject();
    QString replyTo = meta["replyTo"].toString();
    
    if (eventType.isEmpty()) {
        qWarning() << "[SocketClient] Received envelope without event type";
        return;
    }
    
    qDebug() << "[SocketClient] Event:" << eventType;
    
    // Check if this is a reply to a pending request
    if (!replyTo.isEmpty() && m_pendingReplies.contains(replyTo)) {
        auto callback = m_pendingReplies.take(replyTo);
        callback(payload);
        return;
    }
    
    handleEvent(eventType, payload, messageId);
}

QVariantMap SocketClient::normalizeMessageData(const QVariantMap& data)
{
    QVariantMap normalized = data;
    
    // WebSocket API uses 'messageId', but our internal code expects '_id'
    // Convert for consistency with REST API responses
    if (normalized.contains("messageId") && !normalized.contains("_id")) {
        normalized["_id"] = normalized["messageId"];
    }
    
    return normalized;
}

void SocketClient::handleEvent(const QString& eventType, const QJsonObject& payload,
                                const QString& messageId)
{
    Q_UNUSED(messageId)
    
    QVariantMap data = payload.toVariantMap();
    
    // ========================================================================
    // Connection & Authentication
    // ========================================================================
    
    if (eventType == "authenticated") {
        m_authenticated = true;
        QJsonObject user = payload["user"].toObject();
        m_socketId = user["id"].toString();
        
        qDebug() << "[SocketClient] Authenticated as:" << user["username"].toString();
        
        // Start heartbeat
        m_pingTimer->start(m_pingInterval);
        
        emit socketIdChanged();
        emit connectedChanged();
        emit connected();
    }
    else if (eventType == "pong") {
        // Heartbeat response received
        qDebug() << "[SocketClient] Pong received";
    }
    else if (eventType == "error") {
        QString code = payload["code"].toString();
        QString message = payload["message"].toString();
        qWarning() << "[SocketClient] Error:" << code << message;
        
        if (code == "AUTHENTICATION_FAILED" || code == "UNAUTHORIZED") {
            m_authenticated = false;
            emit connectedChanged();
        }
        
        emit error(message);
    }
    
    // ========================================================================
    // Direct Messages
    // ========================================================================
    
    else if (eventType == "message_dm") {
        emit directMessageReceived(normalizeMessageData(data));
    }
    else if (eventType == "message_dm_sent") {
        // Only emit sent signal - serchatapi.cpp will handle adding to cache
        emit directMessageSent(normalizeMessageData(data));
    }
    else if (eventType == "message_dm_edited") {
        emit directMessageEdited(normalizeMessageData(data));
    }
    else if (eventType == "message_dm_deleted") {
        emit directMessageDeleted(payload["messageId"].toString());
    }
    else if (eventType == "dm_unread_updated") {
        emit dmUnread(payload["peerId"].toString(), payload["count"].toInt());
    }
    else if (eventType == "typing_dm") {
        emit dmTyping(payload["senderId"].toString(), 
                      payload["senderUsername"].toString());
    }
    
    // ========================================================================
    // Server Messages
    // ========================================================================
    
    else if (eventType == "message_server") {
        emit serverMessageReceived(normalizeMessageData(data));
    }
    else if (eventType == "message_server_sent") {
        // Only emit sent signal - serchatapi.cpp will handle adding to cache
        emit serverMessageSent(normalizeMessageData(data));
    }
    else if (eventType == "message_server_edited") {
        emit serverMessageEdited(normalizeMessageData(data));
    }
    else if (eventType == "message_server_deleted") {
        emit serverMessageDeleted(payload["messageId"].toString(),
                                  payload["channelId"].toString());
    }
    else if (eventType == "channel_unread_updated") {
        emit channelUnread(payload["channelId"].toString(),
                          payload["lastMessageAt"].toString(),
                          payload["senderId"].toString());
    }
    else if (eventType == "typing_server") {
        emit userTyping(payload["channelId"].toString(),
                       payload["senderId"].toString(),
                       payload["senderUsername"].toString());
    }
    
    // ========================================================================
    // Server & Channel Management
    // ========================================================================
    
    else if (eventType == "server_joined") {
        emit serverJoined(payload["serverId"].toString());
    }
    else if (eventType == "channel_joined") {
        emit channelJoined(payload["serverId"].toString(),
                          payload["channelId"].toString());
    }
    else if (eventType == "server_updated") {
        emit serverUpdated(payload["serverId"].toString(),
                          payload["server"].toObject().toVariantMap());
    }
    else if (eventType == "server_deleted") {
        emit serverDeleted(payload["serverId"].toString());
    }
    else if (eventType == "server_icon_updated") {
        emit serverIconUpdated(payload["serverId"].toString(),
                               payload["icon"].toString());
    }
    else if (eventType == "server_banner_updated") {
        emit serverBannerUpdated(payload["serverId"].toString(),
                                 payload["banner"].toObject().toVariantMap());
    }
    else if (eventType == "ownership_transferred") {
        emit serverOwnershipTransferred(payload["serverId"].toString(),
                                        payload["oldOwnerId"].toString(),
                                        payload["newOwnerId"].toString());
    }
    else if (eventType == "channel_created") {
        emit channelCreated(payload["serverId"].toString(),
                           payload["channel"].toObject().toVariantMap());
    }
    else if (eventType == "channel_updated") {
        emit channelUpdated(payload["serverId"].toString(),
                           payload["channel"].toObject().toVariantMap());
    }
    else if (eventType == "channel_deleted") {
        emit channelDeleted(payload["serverId"].toString(),
                           payload["channelId"].toString());
    }
    else if (eventType == "channels_reordered") {
        QVariantList positions;
        for (const auto& pos : payload["channelPositions"].toArray()) {
            positions.append(pos.toObject().toVariantMap());
        }
        emit channelsReordered(payload["serverId"].toString(), positions);
    }
    else if (eventType == "channel_permissions_updated") {
        emit channelPermissionsUpdated(payload["serverId"].toString(),
                                       payload["channelId"].toString(),
                                       payload["permissions"].toObject().toVariantMap());
    }
    
    // ========================================================================
    // Categories
    // ========================================================================
    
    else if (eventType == "category_created") {
        emit categoryCreated(payload["serverId"].toString(),
                            payload["category"].toObject().toVariantMap());
    }
    else if (eventType == "category_updated") {
        emit categoryUpdated(payload["serverId"].toString(),
                            payload["category"].toObject().toVariantMap());
    }
    else if (eventType == "category_deleted") {
        emit categoryDeleted(payload["serverId"].toString(),
                            payload["categoryId"].toString());
    }
    else if (eventType == "categories_reordered") {
        QVariantList positions;
        for (const auto& pos : payload["categoryPositions"].toArray()) {
            positions.append(pos.toObject().toVariantMap());
        }
        emit categoriesReordered(payload["serverId"].toString(), positions);
    }
    else if (eventType == "category_permissions_updated") {
        emit categoryPermissionsUpdated(payload["serverId"].toString(),
                                        payload["categoryId"].toString(),
                                        payload["permissions"].toObject().toVariantMap());
    }
    
    // ========================================================================
    // Roles
    // ========================================================================
    
    else if (eventType == "role_created") {
        emit roleCreated(payload["serverId"].toString(),
                        payload["role"].toObject().toVariantMap());
    }
    else if (eventType == "role_updated") {
        emit roleUpdated(payload["serverId"].toString(),
                        payload["role"].toObject().toVariantMap());
    }
    else if (eventType == "role_deleted") {
        emit roleDeleted(payload["serverId"].toString(),
                        payload["roleId"].toString());
    }
    else if (eventType == "roles_reordered") {
        QVariantList positions;
        for (const auto& pos : payload["rolePositions"].toArray()) {
            positions.append(pos.toObject().toVariantMap());
        }
        emit rolesReordered(payload["serverId"].toString(), positions);
    }
    
    // ========================================================================
    // Members
    // ========================================================================
    
    else if (eventType == "member_added") {
        emit memberAdded(payload["serverId"].toString(),
                        payload["userId"].toString());
    }
    else if (eventType == "member_removed") {
        emit memberRemoved(payload["serverId"].toString(),
                          payload["userId"].toString());
    }
    else if (eventType == "member_updated") {
        emit memberUpdated(payload["serverId"].toString(),
                          payload["userId"].toString(),
                          payload["member"].toObject().toVariantMap());
    }
    else if (eventType == "member_banned") {
        emit memberBanned(payload["serverId"].toString(),
                         payload["userId"].toString());
    }
    else if (eventType == "member_unbanned") {
        emit memberUnbanned(payload["serverId"].toString(),
                           payload["userId"].toString());
    }
    
    // ========================================================================
    // Presence & Profile
    // ========================================================================
    
    else if (eventType == "presence_sync") {
        QVariantList onlineUsers;
        for (const auto& user : payload["online"].toArray()) {
            onlineUsers.append(user.toObject().toVariantMap());
        }
        emit presenceSync(onlineUsers);
    }
    else if (eventType == "user_online") {
        emit userOnline(payload["userId"].toString(),
                       payload["username"].toString(),
                       payload["status"].toString());
    }
    else if (eventType == "user_offline") {
        emit userOffline(payload["userId"].toString(),
                        payload["username"].toString());
    }
    else if (eventType == "status_updated") {
        emit userStatusUpdate(payload["userId"].toString(),
                             payload["username"].toString(),
                             payload["status"].toString());
    }
    else if (eventType == "user_updated") {
        emit userUpdated(data);
    }
    else if (eventType == "user_banner_updated") {
        emit userBannerUpdated(payload["username"].toString(),
                               payload["userId"].toString(),
                               payload["banner"].toString());
    }
    else if (eventType == "display_name_updated") {
        emit displayNameUpdated(payload["username"].toString(),
                                payload["userId"].toString(),
                                payload["displayName"].toString());
    }
    
    // ========================================================================
    // Reactions
    // ========================================================================
    
    else if (eventType == "reaction_added") {
        emit reactionAdded(data);
    }
    else if (eventType == "reaction_removed") {
        emit reactionRemoved(data);
    }
    
    // ========================================================================
    // Friends
    // ========================================================================
    
    else if (eventType == "incoming_request_added") {
        emit incomingRequestAdded(data);
    }
    else if (eventType == "friend_added") {
        emit friendAdded(payload["friend"].toObject().toVariantMap());
    }
    else if (eventType == "friend_removed") {
        emit friendRemoved(payload["username"].toString(),
                          payload["userId"].toString());
    }
    
    // ========================================================================
    // Notifications
    // ========================================================================
    
    else if (eventType == "mention") {
        emit mentionReceived(data);
    }
    
    // ========================================================================
    // Emoji
    // ========================================================================
    
    else if (eventType == "emoji_updated") {
        emit emojiUpdated(payload["serverId"].toString());
    }
    
    // ========================================================================
    // Unknown event
    // ========================================================================
    
    else {
        qDebug() << "[SocketClient] Unknown event:" << eventType << data;
    }
}

// ============================================================================
// Reconnection logic
// ============================================================================

void SocketClient::scheduleReconnect()
{
    if (!m_shouldReconnect || m_reconnectAttempts >= m_maxReconnectAttempts) {
        return;
    }
    
    // Exponential backoff: 1s, 2s, 4s, 8s... up to 30s
    int delay = qMin(1000 * (1 << m_reconnectAttempts), 30000);
    qDebug() << "[SocketClient] Scheduling reconnect in" << delay << "ms";
    
    emit reconnecting(m_reconnectAttempts + 1);
    m_reconnectTimer->start(delay);
}

void SocketClient::attemptReconnect()
{
    if (!m_shouldReconnect) return;
    
    m_reconnectAttempts++;
    qDebug() << "[SocketClient] Reconnect attempt" << m_reconnectAttempts;
    
    connect(m_url, m_authToken);
}
