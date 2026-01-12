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
#include <QUuid>

/**
 * @brief Pure WebSocket client for Serchat API.
 * 
 * Implements the Serchat WebSocket protocol for real-time communication.
 * This replaces the previous Socket.IO-based implementation.
 * 
 * Protocol Details:
 * - Connection: Standard WebSocket to /ws endpoint
 * - Authentication: Send 'authenticate' event with JWT within 30s grace period
 * - Wire Format: All messages use IWsEnvelope structure with id, event, and meta
 * - Heartbeat: Client sends 'ping', server responds with 'pong'
 * 
 * Wire Format (IWsEnvelope):
 * {
 *     "id": "uuid-v4",      // Unique message ID
 *     "event": {
 *         "type": "event_name",
 *         "payload": { ... }
 *     },
 *     "meta": {
 *         "replyTo": "uuid",  // Optional: ID of request being replied to
 *         "ts": 1234567890    // Unix timestamp in ms
 *     }
 * }
 */
class SocketClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString socketId READ socketId NOTIFY socketIdChanged)

public:
    explicit SocketClient(QObject *parent = nullptr);
    ~SocketClient();

    bool isConnected() const { return m_connected && m_authenticated; }
    QString socketId() const { return m_socketId; }

public slots:
    /// Connect to a WebSocket server
    void connect(const QString& url, const QString& authToken = QString());

    /// Disconnect from the server
    void disconnect();

    /// Reset reconnection attempts counter (call before reconnecting after app resume)
    void resetReconnectAttempts();

    /// Check if the connection is truly alive by sending a ping
    /// If no response within timeout, the connection will be closed and reconnected
    void checkConnectionHealth();

    /// Emit an event to the server
    void emitEvent(const QString& eventType, const QVariantMap& payload = {});
    
    /// Join a room (emits 'join_server' or 'join_channel' event)
    void joinServer(const QString& serverId);
    void joinChannel(const QString& serverId, const QString& channelId);
    void leaveServer(const QString& serverId);
    void leaveChannel(const QString& channelId);
    
    /// Mark messages as read
    void markChannelRead(const QString& serverId, const QString& channelId);
    void markDMRead(const QString& peerId);
    
    /// Send typing indicator
    void sendTyping(const QString& serverId, const QString& channelId);
    void sendDMTyping(const QString& receiverId);
    
    /// Send server message via WebSocket (real-time)
    void sendServerMessage(const QString& serverId, const QString& channelId,
                          const QString& text, const QString& replyToId = QString());
    
    /// Send direct message via WebSocket (real-time)
    void sendDirectMessage(const QString& receiverId, const QString& text,
                          const QString& replyToId = QString());
    
    /// Edit messages via WebSocket
    void editServerMessage(const QString& messageId, const QString& text);
    void deleteServerMessage(const QString& serverId, const QString& messageId);
    void editDirectMessage(const QString& messageId, const QString& text);
    void deleteDirectMessage(const QString& messageId);
    
    /// Reactions via WebSocket
    void addReaction(const QString& messageId, const QString& messageType,
                    const QString& emoji, const QString& emojiType = "unicode",
                    const QString& emojiId = QString());
    void removeReaction(const QString& messageId, const QString& messageType,
                       const QString& emoji, const QString& emojiType = "unicode",
                       const QString& emojiId = QString());
    
    /// Set user status
    void setStatus(const QString& status);

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
    void serverMessageSent(const QVariantMap& message);
    void serverMessageEdited(const QVariantMap& message);
    void serverMessageDeleted(const QString& messageId, const QString& channelId);
    
    // Direct message events
    void directMessageReceived(const QVariantMap& message);
    void directMessageSent(const QVariantMap& message);
    void directMessageEdited(const QVariantMap& message);
    void directMessageDeleted(const QString& messageId);
    
    // Channel events
    void channelUpdated(const QString& serverId, const QVariantMap& channel);
    void channelCreated(const QString& serverId, const QVariantMap& channel);
    void channelDeleted(const QString& serverId, const QString& channelId);
    void channelUnread(const QString& channelId, const QString& lastMessageAt, const QString& senderId);
    void channelPermissionsUpdated(const QString& serverId, const QString& channelId,
                                   const QVariantMap& permissions);
    void channelsReordered(const QString& serverId, const QVariantList& channelPositions);
    void channelJoined(const QString& serverId, const QString& channelId);
    
    // Category events
    void categoryCreated(const QString& serverId, const QVariantMap& category);
    void categoryUpdated(const QString& serverId, const QVariantMap& category);
    void categoryDeleted(const QString& serverId, const QString& categoryId);
    void categoryPermissionsUpdated(const QString& serverId, const QString& categoryId,
                                    const QVariantMap& permissions);
    void categoriesReordered(const QString& serverId, const QVariantList& categoryPositions);
    
    // Server events
    void serverUpdated(const QString& serverId, const QVariantMap& server);
    void serverDeleted(const QString& serverId);
    void serverIconUpdated(const QString& serverId, const QString& icon);
    void serverBannerUpdated(const QString& serverId, const QVariantMap& banner);
    void serverOwnershipTransferred(const QString& serverId, const QString& oldOwnerId,
                                    const QString& newOwnerId);
    void serverJoined(const QString& serverId);
    
    // Role events
    void roleCreated(const QString& serverId, const QVariantMap& role);
    void roleUpdated(const QString& serverId, const QVariantMap& role);
    void roleDeleted(const QString& serverId, const QString& roleId);
    void rolesReordered(const QString& serverId, const QVariantList& rolePositions);
    
    // Server member events
    void memberAdded(const QString& serverId, const QString& userId);
    void memberRemoved(const QString& serverId, const QString& userId);
    void memberUpdated(const QString& serverId, const QString& userId, const QVariantMap& member);
    void memberBanned(const QString& serverId, const QString& userId);
    void memberUnbanned(const QString& serverId, const QString& userId);
    
    // DM events
    void dmUnread(const QString& peerId, int count);
    
    // User presence events
    void userOnline(const QString& userId, const QString& username, const QString& status);
    void userOffline(const QString& userId, const QString& username);
    void userStatusUpdate(const QString& userId, const QString& username, const QString& status);
    
    // Reaction events
    void reactionAdded(const QVariantMap& reaction);
    void reactionRemoved(const QVariantMap& reaction);
    
    // Typing events
    void userTyping(const QString& channelId, const QString& userId, const QString& username);
    void dmTyping(const QString& senderId, const QString& senderUsername);
    
    // Friend events
    void friendAdded(const QVariantMap& friendData);
    void friendRemoved(const QString& username, const QString& userId);
    void incomingRequestAdded(const QVariantMap& request);
    
    // Mention/notification events
    void mentionReceived(const QVariantMap& mention);
    
    // Presence state (initial connection)
    void presenceSync(const QVariantList& onlineUsers);
    
    // User profile events
    void userUpdated(const QVariantMap& updates);
    void userBannerUpdated(const QString& username, const QString& userId, const QString& banner);
    void displayNameUpdated(const QString& username, const QString& userId, const QString& displayName);
    
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
    /// Generate a new UUID for message ID
    QString generateMessageId();
    
    /// Send a message in envelope format
    void sendEnvelope(const QString& eventType, const QVariantMap& payload, 
                      const QString& replyTo = QString());
    
    /// Handle incoming envelope
    void handleEnvelope(const QJsonObject& envelope);
    
    /// Handle event from envelope
    void handleEvent(const QString& eventType, const QJsonObject& payload, 
                     const QString& messageId);
    
    /// Normalize message data from WebSocket format to internal format
    /// Converts messageId -> _id for consistency with REST API
    QVariantMap normalizeMessageData(const QVariantMap& data);
    
    /// Send authentication
    void sendAuthentication();
    
    /// Send ping heartbeat
    void sendPing();
    
    // Reconnection
    void scheduleReconnect();
    void attemptReconnect();
    
    QWebSocket* m_socket;
    QString m_url;
    QString m_authToken;
    QString m_socketId;      // User ID after authentication
    bool m_connected;        // WebSocket connected
    bool m_authenticated;    // Successfully authenticated
    
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
    
    // Pending replies tracking
    QMap<QString, std::function<void(const QJsonObject&)>> m_pendingReplies;
};

#endif // SOCKETCLIENT_H
