#include "socketclient.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>

// Engine.IO packet types
const int ENGINE_OPEN = 0;
const int ENGINE_CLOSE = 1;
const int ENGINE_PING = 2;
const int ENGINE_PONG = 3;
const int ENGINE_MESSAGE = 4;
const int ENGINE_UPGRADE = 5;
const int ENGINE_NOOP = 6;

// Socket.IO packet types
const int SOCKET_CONNECT = 0;
const int SOCKET_DISCONNECT = 1;
const int SOCKET_EVENT = 2;
const int SOCKET_ACK = 3;
const int SOCKET_CONNECT_ERROR = 4;
const int SOCKET_BINARY_EVENT = 5;
const int SOCKET_BINARY_ACK = 6;

SocketClient::SocketClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_connected(false)
    , m_socketIOConnected(false)
    , m_pingTimer(new QTimer(this))
    , m_pongTimeoutTimer(new QTimer(this))
    , m_pingInterval(25000)
    , m_pingTimeout(20000)
    , m_reconnectTimer(new QTimer(this))
    , m_reconnectAttempts(0)
    , m_maxReconnectAttempts(10)
    , m_shouldReconnect(true)
    , m_ackId(0)
{
    QObject::connect(m_socket, &QWebSocket::connected, 
                     this, &SocketClient::onWebSocketConnected);
    QObject::connect(m_socket, &QWebSocket::disconnected, 
                     this, &SocketClient::onWebSocketDisconnected);
    QObject::connect(m_socket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
                     this, &SocketClient::onWebSocketError);
    QObject::connect(m_socket, &QWebSocket::textMessageReceived,
                     this, &SocketClient::onTextMessageReceived);
    
    // Ping timer - used to send ping probes when server doesn't ping us
    QObject::connect(m_pingTimer, &QTimer::timeout, 
                     this, &SocketClient::onPingTimeout);
    // Pong timeout timer - if we don't get pong/ping from server, connection is dead
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

void SocketClient::connect(const QString& url, const QString& authToken)
{
    if (m_connected) {
        disconnect();
    }
    
    m_url = url;
    m_authToken = authToken;
    m_reconnectAttempts = 0;
    m_shouldReconnect = true;
    
    // Build WebSocket URL for Engine.IO
    QUrl wsUrl(url);
    if (wsUrl.scheme() == "https") {
        wsUrl.setScheme("wss");
    } else if (wsUrl.scheme() == "http") {
        wsUrl.setScheme("ws");
    }
    
    // Add Engine.IO path and query params
    QString path = wsUrl.path();
    if (path.isEmpty() || path == "/") {
        path = "/socket.io/";
    } else if (!path.endsWith("/socket.io/")) {
        path = path + "/socket.io/";
    }
    wsUrl.setPath(path);
    
    QUrlQuery query;
    query.addQueryItem("EIO", "4");  // Engine.IO version 4
    query.addQueryItem("transport", "websocket");
    wsUrl.setQuery(query);
    
    qDebug() << "[SocketClient] Connecting to:" << wsUrl.toString();
    
    // Set up request with auth token
    QNetworkRequest request(wsUrl);
    if (!authToken.isEmpty()) {
        request.setRawHeader("Authorization", ("Bearer " + authToken).toUtf8());
    }
    
    m_socket->open(request);
}

void SocketClient::disconnect()
{
    m_shouldReconnect = false;
    m_pingTimer->stop();
    m_pongTimeoutTimer->stop();
    m_reconnectTimer->stop();
    
    if (m_socketIOConnected) {
        sendSocketPacket(SOCKET_DISCONNECT, "/");
    }
    
    m_socket->close();
    m_connected = false;
    m_socketIOConnected = false;
}

void SocketClient::emitEvent(const QString& event, const QVariantMap& data)
{
    QJsonArray args;
    args.append(event);
    args.append(QJsonObject::fromVariantMap(data));
    sendSocketPacket(SOCKET_EVENT, "/", args);
}

void SocketClient::emitEvent(const QString& event, const QVariantList& args)
{
    QJsonArray jsonArgs;
    jsonArgs.append(event);
    for (const QVariant& arg : args) {
        jsonArgs.append(QJsonValue::fromVariant(arg));
    }
    sendSocketPacket(SOCKET_EVENT, "/", jsonArgs);
}

void SocketClient::joinServer(const QString& serverId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    emitEvent("join_server", data);
}

void SocketClient::joinChannel(const QString& serverId, const QString& channelId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    emitEvent("join_channel", data);
}

void SocketClient::leaveServer(const QString& serverId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    emitEvent("leave_server", data);
}

void SocketClient::leaveChannel(const QString& serverId, const QString& channelId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    emitEvent("leave_channel", data);
}

void SocketClient::markChannelRead(const QString& serverId, const QString& channelId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    emitEvent("mark_channel_read", data);
}

void SocketClient::markDMRead(const QString& peerId)
{
    QVariantMap data;
    data["peerId"] = peerId;
    emitEvent("mark_read", data);
}

void SocketClient::sendTyping(const QString& serverId, const QString& channelId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    emitEvent("server_typing", data);
}

void SocketClient::sendDMTyping(const QString& receiver)
{
    QVariantMap data;
    data["to"] = receiver;
    emitEvent("typing", data);
}

void SocketClient::sendServerMessage(const QString& serverId, const QString& channelId, 
                                      const QString& text, const QString& replyToId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    data["text"] = text;
    if (!replyToId.isEmpty()) {
        data["replyToId"] = replyToId;
    }
    emitEvent("server_message", data);
}

void SocketClient::sendDirectMessage(const QString& receiver, const QString& text, 
                                      const QString& replyToId)
{
    QVariantMap data;
    data["receiver"] = receiver;
    data["text"] = text;
    if (!replyToId.isEmpty()) {
        data["replyToId"] = replyToId;
    }
    emitEvent("message", data);
}

void SocketClient::editServerMessage(const QString& serverId, const QString& channelId,
                                      const QString& messageId, const QString& text)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    data["messageId"] = messageId;
    data["text"] = text;
    emitEvent("edit_server_message", data);
}

void SocketClient::deleteServerMessage(const QString& serverId, const QString& channelId,
                                        const QString& messageId)
{
    QVariantMap data;
    data["serverId"] = serverId;
    data["channelId"] = channelId;
    data["messageId"] = messageId;
    emitEvent("delete_server_message", data);
}

void SocketClient::editDirectMessage(const QString& messageId, const QString& text)
{
    QVariantMap data;
    data["messageId"] = messageId;
    data["text"] = text;
    emitEvent("edit_message", data);
}

void SocketClient::deleteDirectMessage(const QString& messageId)
{
    QVariantMap data;
    data["messageId"] = messageId;
    emitEvent("delete_message", data);
}

void SocketClient::addReaction(const QString& messageId, const QString& messageType,
                               const QString& emoji, const QString& serverId,
                               const QString& channelId)
{
    QVariantMap data;
    data["messageId"] = messageId;
    data["messageType"] = messageType;
    data["emoji"] = emoji;
    data["emojiType"] = "unicode";
    if (!serverId.isEmpty()) {
        data["serverId"] = serverId;
    }
    if (!channelId.isEmpty()) {
        data["channelId"] = channelId;
    }
    emitEvent("add_reaction", data);
}

void SocketClient::removeReaction(const QString& messageId, const QString& messageType,
                                   const QString& emoji, const QString& serverId,
                                   const QString& channelId)
{
    QVariantMap data;
    data["messageId"] = messageId;
    data["messageType"] = messageType;
    data["emoji"] = emoji;
    if (!serverId.isEmpty()) {
        data["serverId"] = serverId;
    }
    if (!channelId.isEmpty()) {
        data["channelId"] = channelId;
    }
    emitEvent("remove_reaction", data);
}

// ============================================================================
// WebSocket event handlers
// ============================================================================

void SocketClient::onWebSocketConnected()
{
    qDebug() << "[SocketClient] WebSocket connected";
    m_connected = true;
    m_reconnectAttempts = 0;
    emit connectedChanged();
}

void SocketClient::onWebSocketDisconnected()
{
    qDebug() << "[SocketClient] WebSocket disconnected";
    bool wasConnected = m_connected;
    m_connected = false;
    m_socketIOConnected = false;
    m_pingTimer->stop();
    m_pongTimeoutTimer->stop();
    
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
    
    // Parse Engine.IO packet - first char is packet type
    int type = message.at(0).digitValue();
    QString data = message.mid(1);
    
    handleEnginePacket(type, data);
}

void SocketClient::onPingTimeout()
{
    // In Engine.IO v4, the SERVER sends pings, not the client.
    // This timer is used to detect if the server has gone silent.
    // If we reach here, it means we haven't received any data from the server
    // within the pingInterval. Start the pong timeout to wait a bit more.
    if (m_connected) {
        qDebug() << "[SocketClient] No data received from server, starting timeout";
        m_pongTimeoutTimer->start(m_pingTimeout);
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
// Engine.IO protocol
// ============================================================================

void SocketClient::sendEnginePacket(int type, const QString& data)
{
    if (!m_connected && type != ENGINE_OPEN) return;
    
    QString packet = QString::number(type) + data;
    m_socket->sendTextMessage(packet);
}

void SocketClient::handleEnginePacket(int type, const QString& data)
{
    // Reset inactivity timer on any packet received (server is alive)
    // This replaces the ping-based heartbeat - we rely on server's pings
    if (m_pingTimer->isActive()) {
        m_pingTimer->start(m_pingInterval);  // Reset the interval
    }
    // Cancel timeout if we got any response
    m_pongTimeoutTimer->stop();
    
    switch (type) {
    case ENGINE_OPEN:
        {
            QJsonDocument doc = QJsonDocument::fromJson(data.toUtf8());
            if (!doc.isNull() && doc.isObject()) {
                handleOpen(doc.object());
            }
        }
        break;
        
    case ENGINE_CLOSE:
        qDebug() << "[SocketClient] Engine close received";
        m_socket->close();
        break;
        
    case ENGINE_PING:
        // Server pinged us - respond with pong immediately
        qDebug() << "[SocketClient] Received ping from server, sending pong";
        sendEnginePacket(ENGINE_PONG);
        break;
        
    case ENGINE_PONG:
        // This shouldn't happen in Engine.IO v4 (client doesn't send ping)
        // but handle it gracefully in case of protocol variations
        qDebug() << "[SocketClient] Received unexpected pong from server";
        break;
        
    case ENGINE_MESSAGE:
        // Socket.IO message - parse Socket.IO packet
        if (!data.isEmpty()) {
            int sioType = data.at(0).digitValue();
            QString sioData = data.mid(1);
            
            // Parse namespace if present
            QString nsp = "/";
            if (sioData.startsWith("/")) {
                int commaIdx = sioData.indexOf(',');
                if (commaIdx != -1) {
                    nsp = sioData.left(commaIdx);
                    sioData = sioData.mid(commaIdx + 1);
                } else {
                    nsp = sioData;
                    sioData = "";
                }
            }
            
            // Parse JSON data if present
            QJsonValue jsonData;
            if (!sioData.isEmpty()) {
                QJsonDocument doc = QJsonDocument::fromJson(sioData.toUtf8());
                if (doc.isArray()) {
                    jsonData = doc.array();
                } else if (doc.isObject()) {
                    jsonData = doc.object();
                }
            }
            
            handleSocketPacket(sioType, nsp, jsonData);
        }
        break;
        
    case ENGINE_UPGRADE:
    case ENGINE_NOOP:
        break;
        
    default:
        qWarning() << "[SocketClient] Unknown Engine.IO packet type:" << type;
    }
}

void SocketClient::handleOpen(const QJsonObject& config)
{
    m_sessionId = config["sid"].toString();
    m_pingInterval = config["pingInterval"].toInt(25000);
    m_pingTimeout = config["pingTimeout"].toInt(20000);
    
    qDebug() << "[SocketClient] Engine.IO open, sid:" << m_sessionId 
             << "pingInterval:" << m_pingInterval
             << "pingTimeout:" << m_pingTimeout;
    
    // Start inactivity timer - in Engine.IO v4, the server sends pings.
    // We use this timer to detect if we haven't received anything from the server.
    // Set to pingInterval + pingTimeout to give server time to ping us.
    m_pingTimer->setInterval(m_pingInterval + m_pingTimeout);
    m_pingTimer->start();
    
    // Send Socket.IO connect packet
    sendConnect();
}

// ============================================================================
// Socket.IO protocol
// ============================================================================

void SocketClient::sendSocketPacket(int type, const QString& nsp, const QJsonValue& data)
{
    QString packet = QString::number(type);
    
    // Add namespace if not default
    if (nsp != "/") {
        packet += nsp;
        if (!data.isNull() && !data.isUndefined()) {
            packet += ",";
        }
    }
    
    // Add data
    if (!data.isNull() && !data.isUndefined()) {
        QJsonDocument doc;
        if (data.isArray()) {
            doc = QJsonDocument(data.toArray());
        } else if (data.isObject()) {
            doc = QJsonDocument(data.toObject());
        }
        packet += QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
    }
    
    sendEnginePacket(ENGINE_MESSAGE, packet);
}

void SocketClient::handleSocketPacket(int type, const QString& nsp, const QJsonValue& data)
{
    switch (type) {
    case SOCKET_CONNECT:
        {
            m_socketIOConnected = true;
            if (data.isObject()) {
                m_socketId = data.toObject()["sid"].toString();
                emit socketIdChanged();
            }
            qDebug() << "[SocketClient] Socket.IO connected, sid:" << m_socketId;
            emit connected();
        }
        break;
        
    case SOCKET_DISCONNECT:
        m_socketIOConnected = false;
        emit disconnected();
        break;
        
    case SOCKET_EVENT:
        if (data.isArray()) {
            handleEvent(nsp, data.toArray());
        }
        break;
        
    case SOCKET_ACK:
        // Handle acknowledgement
        break;
        
    case SOCKET_CONNECT_ERROR:
        {
            QString errMsg = "Connection error";
            if (data.isObject()) {
                errMsg = data.toObject()["message"].toString(errMsg);
            }
            qWarning() << "[SocketClient] Socket.IO connect error:" << errMsg;
            emit error(errMsg);
        }
        break;
        
    default:
        qDebug() << "[SocketClient] Unhandled Socket.IO packet type:" << type;
    }
}

void SocketClient::handleEvent(const QString& nsp, const QJsonArray& args)
{
    Q_UNUSED(nsp)
    
    if (args.isEmpty()) return;
    
    QString event = args[0].toString();
    QVariantMap data;
    if (args.size() > 1 && args[1].isObject()) {
        data = args[1].toObject().toVariantMap();
    }
    
    qDebug() << "[SocketClient] Event:" << event;
    
    // Route events to appropriate signals
    if (event == "server_message") {
        emit serverMessageReceived(data);
    }
    else if (event == "server_message_edited" || event == "server_message_updated") {
        emit serverMessageEdited(data);
    }
    else if (event == "server_message_deleted") {
        emit serverMessageDeleted(data["messageId"].toString(), 
                                  data["channelId"].toString());
    }
    else if (event == "message") {
        emit directMessageReceived(data);
    }
    else if (event == "message_edited") {
        emit directMessageEdited(data);
    }
    else if (event == "message_deleted") {
        emit directMessageDeleted(data["messageId"].toString());
    }
    else if (event == "channel_updated") {
        emit channelUpdated(data["serverId"].toString(), 
                           data["channel"].toMap());
    }
    else if (event == "channel_created") {
        emit channelCreated(data["serverId"].toString(),
                           data["channel"].toMap());
    }
    else if (event == "channel_deleted") {
        emit channelDeleted(data["serverId"].toString(),
                           data["channelId"].toString());
    }
    else if (event == "channel_unread") {
        emit channelUnread(data["serverId"].toString(),
                          data["channelId"].toString(),
                          data["lastMessageAt"].toString(),
                          data["senderId"].toString());
    }
    else if (event == "dm_unread") {
        emit dmUnread(data["peer"].toString(), data["count"].toInt());
    }
    else if (event == "user_online") {
        emit userOnline(data["username"].toString());
    }
    else if (event == "user_offline") {
        emit userOffline(data["username"].toString());
    }
    else if (event == "status_update") {
        emit userStatusUpdate(data["username"].toString(),
                             data["status"].toMap());
    }
    else if (event == "reaction_added") {
        emit reactionAdded(data["messageId"].toString(),
                          data["messageType"].toString(),
                          data["reactions"].toList());
    }
    else if (event == "reaction_removed") {
        emit reactionRemoved(data["messageId"].toString(),
                            data["messageType"].toString(),
                            data["reactions"].toList());
    }
    else if (event == "typing") {
        emit dmTyping(data["from"].toString());
    }
    else if (event == "server_typing") {
        emit userTyping(data["serverId"].toString(),
                       data["channelId"].toString(),
                       data["from"].toString());
    }
    else if (event == "server_member_joined") {
        emit serverMemberJoined(data["serverId"].toString(),
                               data["userId"].toString());
    }
    else if (event == "server_member_left") {
        emit serverMemberLeft(data["serverId"].toString(),
                             data["userId"].toString());
    }
    else if (event == "friend_added") {
        emit friendAdded(data["friend"].toMap());
    }
    else if (event == "friend_removed") {
        emit friendRemoved(data["username"].toString(),
                          data["userId"].toString());
    }
    else if (event == "incoming_request_added") {
        emit incomingRequestAdded(data);
    }
    else if (event == "incoming_request_removed") {
        emit incomingRequestRemoved(data["from"].toString(),
                                   data["fromId"].toString());
    }
    else if (event == "ping") {
        emit pingReceived(data);
    }
    else if (event == "presence_state") {
        emit presenceState(data);
    }
    else if (event == "ban") {
        qWarning() << "[SocketClient] User banned:" << data;
        emit error("Account banned: " + data["reason"].toString());
    }
    else {
        qDebug() << "[SocketClient] Unknown event:" << event << data;
    }
}

void SocketClient::sendConnect()
{
    // Send Socket.IO CONNECT packet with auth
    QJsonObject auth;
    if (!m_authToken.isEmpty()) {
        auth["token"] = m_authToken;
    }
    
    sendSocketPacket(SOCKET_CONNECT, "/", auth);
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
