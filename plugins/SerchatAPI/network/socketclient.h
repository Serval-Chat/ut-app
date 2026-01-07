#ifndef SOCKETCLIENT_H
#define SOCKETCLIENT_H

#include <QObject>
#include <QWebSocket>
#include <QTimer>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QPointer>

/**
 * @brief Socket.IO client implementation for Qt.
 * 
 * Implements the Engine.IO/Socket.IO protocol for real-time communication.
 * Supports Engine.IO v4 / Socket.IO v4 protocol.
 * 
 * Engine.IO packet types:
 * - 0: open
 * - 1: close
 * - 2: ping
 * - 3: pong
 * - 4: message
 * - 5: upgrade
 * - 6: noop
 * 
 * Socket.IO packet types (within Engine.IO message):
 * - 0: CONNECT
 * - 1: DISCONNECT  
 * - 2: EVENT
 * - 3: ACK
 * - 4: CONNECT_ERROR
 * - 5: BINARY_EVENT
 * - 6: BINARY_ACK
 */
class SocketClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString socketId READ socketId NOTIFY socketIdChanged)

public:
    explicit SocketClient(QObject *parent = nullptr);
    ~SocketClient();

    bool isConnected() const { return m_connected; }
    QString socketId() const { return m_socketId; }

public slots:
    /// Connect to a Socket.IO server
    void connect(const QString& url, const QString& authToken = QString());

    /// Disconnect from the server
    void disconnect();

    /// Reset reconnection attempts counter (call before reconnecting after app resume)
    void resetReconnectAttempts();

    /// Check if the connection is truly alive by sending a ping
    /// If no response within timeout, the connection will be closed and reconnected
    void checkConnectionHealth();

    /// Emit an event to the server
    void emitEvent(const QString& event, const QVariantMap& data = {});
    void emitEvent(const QString& event, const QVariantList& args);
    
    /// Join a room (emits 'join_server' or 'join_channel' event)
    void joinServer(const QString& serverId);
    void joinChannel(const QString& serverId, const QString& channelId);
    void leaveServer(const QString& serverId);
    void leaveChannel(const QString& serverId, const QString& channelId);
    
    /// Mark messages as read
    void markChannelRead(const QString& serverId, const QString& channelId);
    void markDMRead(const QString& peerId);
    
    /// Send typing indicator
    void sendTyping(const QString& serverId, const QString& channelId);
    void sendDMTyping(const QString& receiver);
    
    /// Send server message via Socket.IO (real-time)
    void sendServerMessage(const QString& serverId, const QString& channelId,
                          const QString& text, const QString& replyToId = QString());
    
    /// Send direct message via Socket.IO (real-time)
    void sendDirectMessage(const QString& receiver, const QString& text,
                          const QString& replyToId = QString());
    
    /// Edit messages via Socket.IO
    void editServerMessage(const QString& serverId, const QString& channelId,
                          const QString& messageId, const QString& text);
    void deleteServerMessage(const QString& serverId, const QString& channelId,
                            const QString& messageId);
    void editDirectMessage(const QString& messageId, const QString& text);
    void deleteDirectMessage(const QString& messageId);
    
    /// Reactions via Socket.IO
    void addReaction(const QString& messageId, const QString& messageType,
                    const QString& emoji, const QString& serverId = QString(),
                    const QString& channelId = QString());
    void removeReaction(const QString& messageId, const QString& messageType,
                       const QString& emoji, const QString& serverId = QString(),
                       const QString& channelId = QString());

signals:
    void connectedChanged();
    void socketIdChanged();
    void error(const QString& message);
    
    // Connection events
    void connected();
    void disconnected();
    void reconnecting(int attempt);
    
    // Server message events
    void serverMessageReceived(const QVariantMap& message);
    void serverMessageEdited(const QVariantMap& message);
    void serverMessageDeleted(const QString& messageId, const QString& channelId);
    
    // Direct message events
    void directMessageReceived(const QVariantMap& message);
    void directMessageEdited(const QVariantMap& message);
    void directMessageDeleted(const QString& messageId);
    
    // Channel events
    void channelUpdated(const QString& serverId, const QVariantMap& channel);
    void channelCreated(const QString& serverId, const QVariantMap& channel);
    void channelDeleted(const QString& serverId, const QString& channelId);
    void channelUnread(const QString& serverId, const QString& channelId, 
                       const QString& lastMessageAt, const QString& senderId);
    void channelPermissionsUpdated(const QString& serverId, const QString& channelId,
                                   const QVariantMap& permissions);
    
    // Category events
    void categoryCreated(const QString& serverId, const QVariantMap& category);
    void categoryUpdated(const QString& serverId, const QVariantMap& category);
    void categoryDeleted(const QString& serverId, const QString& categoryId);
    void categoryPermissionsUpdated(const QString& serverId, const QString& categoryId,
                                    const QVariantMap& permissions);
    
    // Server events
    void serverUpdated(const QString& serverId, const QVariantMap& server);
    void serverDeleted(const QString& serverId);
    void serverOwnershipTransferred(const QString& serverId, const QString& previousOwnerId,
                                    const QString& newOwnerId, const QString& newOwnerUsername);
    
    // Role events
    void roleCreated(const QString& serverId, const QVariantMap& role);
    void roleUpdated(const QString& serverId, const QVariantMap& role);
    void roleDeleted(const QString& serverId, const QString& roleId);
    void rolesReordered(const QString& serverId, const QVariantList& rolePositions);
    
    // Server member events (REST-triggered events)
    void memberAdded(const QString& serverId, const QString& userId);
    void memberRemoved(const QString& serverId, const QString& userId);
    void memberUpdated(const QString& serverId, const QString& userId, const QVariantMap& member);
    
    // DM events
    void dmUnread(const QString& peer, int count);
    
    // User presence events
    void userOnline(const QString& username);
    void userOffline(const QString& username);
    void userStatusUpdate(const QString& username, const QVariantMap& status);
    
    // Reaction events
    void reactionAdded(const QString& messageId, const QString& messageType, 
                       const QVariantList& reactions);
    void reactionRemoved(const QString& messageId, const QString& messageType,
                         const QVariantList& reactions);
    
    // Typing events
    void userTyping(const QString& serverId, const QString& channelId, 
                    const QString& username);
    void dmTyping(const QString& username);
    
    // Server membership events
    void serverMemberJoined(const QString& serverId, const QString& userId);
    void serverMemberLeft(const QString& serverId, const QString& userId);
    
    // Friend events
    void friendAdded(const QVariantMap& friendData);
    void friendRemoved(const QString& username, const QString& userId);
    void incomingRequestAdded(const QVariantMap& request);
    void incomingRequestRemoved(const QString& from, const QString& fromId);
    
    // Ping notification
    void pingReceived(const QVariantMap& ping);
    
    // Presence state (initial connection)
    void presenceState(const QVariantMap& presence);
    
    // User profile events
    void userUpdated(const QString& userId, const QVariantMap& updates);
    void userBannerUpdated(const QString& username, const QVariantMap& updates);
    void usernameChanged(const QString& oldUsername, const QString& newUsername,
                         const QString& userId);
    
    // Admin events
    void warningReceived(const QVariantMap& warning);
    void accountDeleted(const QString& reason);
    
    // Emoji events
    void emojiUpdated(const QString& serverId);

private slots:
    void onWebSocketConnected();
    void onWebSocketDisconnected();
    void onWebSocketError(QAbstractSocket::SocketError error);
    void onTextMessageReceived(const QString& message);
    void onPingTimeout();
    void onPongTimeout();
    void onReconnectTimeout();

private:
    // Engine.IO protocol
    void sendEnginePacket(int type, const QString& data = QString());
    void handleEnginePacket(int type, const QString& data);
    void handleOpen(const QJsonObject& config);
    
    // Socket.IO protocol
    void sendSocketPacket(int type, const QString& nsp, const QJsonValue& data = {});
    void handleSocketPacket(int type, const QString& nsp, const QJsonValue& data);
    void handleEvent(const QString& nsp, const QJsonArray& args);
    void sendConnect();
    
    // Reconnection
    void scheduleReconnect();
    void attemptReconnect();
    
    QWebSocket* m_socket;
    QString m_url;
    QString m_authToken;
    QString m_socketId;
    QString m_sessionId;  // Engine.IO sid
    bool m_connected;
    bool m_socketIOConnected;
    
    // Heartbeat
    QTimer* m_pingTimer;
    QTimer* m_pongTimeoutTimer;
    int m_pingInterval;
    int m_pingTimeout;
    
    // Reconnection
    QTimer* m_reconnectTimer;
    int m_reconnectAttempts;
    int m_maxReconnectAttempts;
    bool m_shouldReconnect;
    
    // Message acknowledgement
    int m_ackId;
    QMap<int, std::function<void(const QJsonValue&)>> m_ackCallbacks;
};

#endif // SOCKETCLIENT_H
