#ifndef SERCHATAPI_H
#define SERCHATAPI_H

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QMap>
#include <QSet>
#include <QSettings>
#include <QTimer>

class NetworkClient;
class AuthClient;
class ApiClient;
class SocketClient;
class MessageModel;
class GenericListModel;
class ChannelListModel;

/**
 * @brief Main API facade exposed to QML.
 * 
 * This singleton provides a clean interface for QML to interact with
 * the Serchat API. It handles:
 * - Persistent storage of auth state via QSettings
 * - Token lifecycle management
 * - Coordinating AuthClient and ApiClient
 * 
 * Token Management:
 * - Tokens are stored persistently in QSettings
 * - AuthClient is the runtime source of truth
 * - NetworkClient automatically uses the token from AuthClient
 * - 401 responses trigger automatic logout
 */
class SerchatAPI : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString apiBaseUrl READ apiBaseUrl WRITE setApiBaseUrl NOTIFY apiBaseUrlChanged)
    Q_PROPERTY(QString lastServerId READ lastServerId WRITE setLastServerId NOTIFY lastServerIdChanged)
    Q_PROPERTY(QString lastChannelId READ lastChannelId WRITE setLastChannelId NOTIFY lastChannelIdChanged)
    Q_PROPERTY(QString lastDMRecipientId READ lastDMRecipientId WRITE setLastDMRecipientId NOTIFY lastDMRecipientIdChanged)
    Q_PROPERTY(bool loggedIn READ isLoggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(bool socketConnected READ isSocketConnected NOTIFY socketConnectedChanged)
    Q_PROPERTY(QString socketId READ socketId NOTIFY socketIdChanged)
    
    // Unread state version counter - triggers QML re-binding when unread state changes
    Q_PROPERTY(int unreadStateVersion READ unreadStateVersion NOTIFY unreadStateVersionChanged)
    
    // C++ models for better performance and proper scroll behavior
    Q_PROPERTY(MessageModel* messageModel READ messageModel CONSTANT)
    Q_PROPERTY(GenericListModel* serversModel READ serversModel CONSTANT)
    Q_PROPERTY(GenericListModel* channelsModel READ channelsModel CONSTANT)
    Q_PROPERTY(GenericListModel* membersModel READ membersModel CONSTANT)
    Q_PROPERTY(GenericListModel* friendsModel READ friendsModel CONSTANT)
    Q_PROPERTY(GenericListModel* rolesModel READ rolesModel CONSTANT)
    Q_PROPERTY(ChannelListModel* channelListModel READ channelListModel CONSTANT)

public:
    SerchatAPI();
    ~SerchatAPI();

    // ========================================================================
    // Authentication
    // ========================================================================
    
    /// Check if user is currently logged in
    Q_INVOKABLE bool isLoggedIn() const;
    /// Log in with login/email and password
    Q_INVOKABLE void login(const QString& login, const QString& password);
    /// Register a new user account
    Q_INVOKABLE void registerUser(const QString& login, const QString& username, 
                                   const QString& password, const QString& inviteToken);
    /// Log out and clear all auth state
    Q_INVOKABLE void logout();
    /// Validate current auth token (emits authTokenInvalid if expired)
    Q_INVOKABLE void validateAuthToken();

    // ========================================================================
    // Profile API
    // ========================================================================
    
    /// Fetch current user's profile (simple API, no request ID)
    Q_INVOKABLE void getUserProfile();
    
    /**
     * @brief Fetch current user's profile with request tracking.
     * @return Request ID for matching with profileFetched signal
     */
    Q_INVOKABLE int getMyProfile();
    
    /**
     * @brief Fetch a specific user's profile.
     * @param userId User ID to fetch (or "me" for current user)
     * @param useCache If true, return cached data if valid (default: true)
     * @return Request ID for matching with profileFetched signal
     */
    Q_INVOKABLE int getProfile(const QString& userId, bool useCache = true);
    
    // ========================================================================
    // Servers API
    // ========================================================================
    
    /**
     * @brief Fetch all servers the current user is a member of.
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serversFetched signal
     */
    Q_INVOKABLE int getServers(bool useCache = true);
    
    /**
     * @brief Fetch details for a specific server.
     * @param serverId The server ID to fetch
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serverDetailsFetched signal
     */
    Q_INVOKABLE int getServerDetails(const QString& serverId, bool useCache = true);
    
    /**
     * @brief Join a server via invite code.
     * @param inviteCode The invite code (without URL prefix)
     * @return Request ID for matching with serverJoined signal
     */
    Q_INVOKABLE int joinServerByInvite(const QString& inviteCode);
    
    /**
     * @brief Create a new server.
     * @param name The server name
     * @return Request ID for matching with serverCreated signal
     */
    Q_INVOKABLE int createNewServer(const QString& name);
    
    // ========================================================================
    // Friends API (for DM conversations)
    // ========================================================================
    
    /**
     * @brief Get the list of friends (for DM conversations).
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with friendsFetched signal
     */
    Q_INVOKABLE int getFriends(bool useCache = true);
    
    // ========================================================================
    // Channels API
    // ========================================================================
    
    /**
     * @brief Fetch all channels for a specific server.
     * @param serverId The server ID to fetch channels for
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with channelsFetched signal
     */
    Q_INVOKABLE int getChannels(const QString& serverId, bool useCache = true);
    
    /**
     * @brief Fetch details for a specific channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with channelDetailsFetched signal
     */
    Q_INVOKABLE int getChannelDetails(const QString& serverId, const QString& channelId, 
                                       bool useCache = true);
    
    /**
     * @brief Fetch all categories for a specific server.
     * @param serverId The server ID to fetch categories for
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with categoriesFetched signal
     */
    Q_INVOKABLE int getCategories(const QString& serverId, bool useCache = true);
    
    // ========================================================================
    // Server Members API
    // ========================================================================
    
    /**
     * @brief Fetch all members of a server.
     * @param serverId The server ID
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serverMembersFetched signal
     */
    Q_INVOKABLE int getServerMembers(const QString& serverId, bool useCache = true);
    
    // ========================================================================
    // Server Roles API
    // ========================================================================
    
    /**
     * @brief Fetch all roles for a server.
     * @param serverId The server ID
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serverRolesFetched signal
     */
    Q_INVOKABLE int getServerRoles(const QString& serverId, bool useCache = true);
    
    // ========================================================================
    // Presence Tracking
    // ========================================================================
    
    /**
     * @brief Check if a user is currently online.
     * @param username The username to check
     * @return true if user is online
     */
    Q_INVOKABLE bool isUserOnline(const QString& username) const;
    
    /**
     * @brief Get list of all online usernames.
     * @return List of usernames currently online
     */
    Q_INVOKABLE QStringList getOnlineUsers() const;
    
    // ========================================================================
    // Typing Indicators
    // ========================================================================
    
    /**
     * @brief Get list of users currently typing in a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @return List of usernames currently typing
     */
    Q_INVOKABLE QStringList getTypingUsers(const QString& serverId, const QString& channelId) const;
    
    /**
     * @brief Get list of users currently typing in a DM.
     * @param recipientId The DM recipient ID
     * @return List of usernames currently typing (usually 0 or 1)
     */
    Q_INVOKABLE QStringList getDMTypingUsers(const QString& recipientId) const;
    
    /**
     * @brief Check if any users are typing in a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @return true if at least one user is typing
     */
    Q_INVOKABLE bool hasTypingUsers(const QString& serverId, const QString& channelId) const;
    
    /**
     * @brief Check if any users are typing in a DM.
     * @param recipientId The DM recipient ID
     * @return true if at least one user is typing
     */
    Q_INVOKABLE bool hasDMTypingUsers(const QString& recipientId) const;
    
    // ========================================================================
    // Unread State Tracking
    // ========================================================================
    
    /**
     * @brief Check if a channel has unread messages.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @return true if channel has unread messages
     */
    Q_INVOKABLE bool hasUnreadMessages(const QString& serverId, const QString& channelId) const;
    
    /**
     * @brief Check if a DM has unread messages.
     * @param recipientId The DM recipient ID
     * @return true if DM has unread messages
     */
    Q_INVOKABLE bool hasDMUnreadMessages(const QString& recipientId) const;
    
    /**
     * @brief Check if a server has any unread channels.
     * @param serverId The server ID
     * @return true if any channel in the server has unread messages
     */
    Q_INVOKABLE bool hasServerUnread(const QString& serverId) const;
    
    /**
     * @brief Get the last read message ID for a channel.
     * Used to display the "NEW" divider in message view.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @return The last read message ID, or empty string if none
     */
    Q_INVOKABLE QString getLastReadMessageId(const QString& serverId, const QString& channelId) const;
    
    /**
     * @brief Get the last read message ID for a DM.
     * @param recipientId The DM recipient ID
     * @return The last read message ID, or empty string if none
     */
    Q_INVOKABLE QString getDMLastReadMessageId(const QString& recipientId) const;
    
    /**
     * @brief Set the last read message ID for a channel.
     * Called when user views messages to update the "NEW" divider position.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param messageId The ID of the last read message
     */
    Q_INVOKABLE void setLastReadMessageId(const QString& serverId, const QString& channelId, const QString& messageId);
    
    /**
     * @brief Set the last read message ID for a DM.
     * @param recipientId The DM recipient ID
     * @param messageId The ID of the last read message
     */
    Q_INVOKABLE void setDMLastReadMessageId(const QString& recipientId, const QString& messageId);
    
    /**
     * @brief Clear unread state for a channel and notify server.
     * @param serverId The server ID
     * @param channelId The channel ID
     */
    Q_INVOKABLE void clearChannelUnread(const QString& serverId, const QString& channelId);
    
    /**
     * @brief Clear unread state for a DM and notify server.
     * @param recipientId The DM recipient ID
     */
    Q_INVOKABLE void clearDMUnread(const QString& recipientId);
    
    // ========================================================================
    // Server Emojis API
    // ========================================================================
    
    /**
     * @brief Fetch all custom emojis for a server.
     * @param serverId The server ID
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with serverEmojisFetched signal
     */
    Q_INVOKABLE int getServerEmojis(const QString& serverId, bool useCache = true);
    
    /**
     * @brief Fetch all custom emojis from all servers user is a member of.
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with allEmojisFetched signal
     */
    Q_INVOKABLE int getAllEmojis(bool useCache = true);
    
    /**
     * @brief Fetch a specific emoji by its ID.
     * Use this to fetch emojis that aren't in the user's servers (cross-server emojis).
     * @param emojiId The emoji ID to fetch
     * @param useCache If true, return cached data if valid
     * @return Request ID for matching with emojiFetched signal
     */
    Q_INVOKABLE int getEmojiById(const QString& emojiId, bool useCache = true);
    
    // ========================================================================
    // Messages API
    // ========================================================================
    
    /**
     * @brief Fetch messages for a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param limit Maximum number of messages to fetch (default: 50)
     * @param before Fetch messages before this message ID (for pagination)
     * @return Request ID for matching with messagesFetched signal
     */
    Q_INVOKABLE int getMessages(const QString& serverId, const QString& channelId,
                                int limit = 50, const QString& before = QString());
    
    /**
     * @brief Send a message to a channel.
     * @param serverId The server ID
     * @param channelId The channel ID
     * @param text The message text
     * @param replyToId Optional message ID to reply to
     * @return Request ID for matching with messageSent signal
     */
    Q_INVOKABLE int sendMessage(const QString& serverId, const QString& channelId,
                                const QString& text, const QString& replyToId = QString());

    // ========================================================================
    // Direct Messages API
    // ========================================================================
    
    /**
     * @brief Fetch direct messages with a user.
     * @param userId The user ID to fetch DMs with
     * @param limit Maximum number of messages to fetch (default: 50)
     * @param before Fetch messages before this message ID (for pagination)
     * @return Request ID for matching with dmMessagesFetched signal
     */
    Q_INVOKABLE int getDMMessages(const QString& userId, int limit = 50, const QString& before = QString());
    
    /**
     * @brief Send a direct message to a user.
     * @param userId The recipient user ID
     * @param text The message text
     * @param replyToId Optional message ID to reply to
     * @return Request ID for matching with dmMessageSent signal
     */
    Q_INVOKABLE int sendDMMessage(const QString& userId, const QString& text, const QString& replyToId = QString());

    // ========================================================================
    // Cache Management
    // ========================================================================
    
    /// Set cache TTL in seconds (default: 60)
    Q_INVOKABLE void setCacheTTL(int seconds);
    
    /// Clear all cached data
    Q_INVOKABLE void clearCache();
    
    /// Clear cached data for a specific cache key
    Q_INVOKABLE void clearCacheFor(const QString& cacheKey);
    
    // Legacy profile cache methods (for backward compatibility)
    Q_INVOKABLE void setProfileCacheTTL(int seconds) { setCacheTTL(seconds); }
    Q_INVOKABLE void clearProfileCache() { clearCache(); }
    Q_INVOKABLE void clearProfileCacheFor(const QString& userId);
    Q_INVOKABLE bool hasProfileCached(const QString& userId) const;
    
    // ========================================================================
    // Request Management
    // ========================================================================
    
    /// Cancel a pending request by ID
    Q_INVOKABLE void cancelRequest(int requestId);
    
    /// Check if a request is still pending
    Q_INVOKABLE bool isRequestPending(int requestId) const;

    // ========================================================================
    // Socket.IO Real-time Connection
    // ========================================================================
    
    /// Check if socket is connected
    Q_INVOKABLE bool isSocketConnected() const;
    
    /// Get socket ID
    Q_INVOKABLE QString socketId() const;
    
    /// Get unread state version (for QML binding updates)
    int unreadStateVersion() const { return m_unreadStateVersion; }
    
    /// Connect to the real-time socket server (called automatically on login)
    Q_INVOKABLE void connectSocket();
    
    /// Disconnect from the socket server
    Q_INVOKABLE void disconnectSocket();
    
    /// Join a server room to receive server events
    Q_INVOKABLE void joinServer(const QString& serverId);
    
    /// Leave a server room
    Q_INVOKABLE void leaveServer(const QString& serverId);
    
    /// Join a channel room to receive channel events
    Q_INVOKABLE void joinChannel(const QString& serverId, const QString& channelId);
    
    /// Leave a channel room
    Q_INVOKABLE void leaveChannel(const QString& serverId, const QString& channelId);
    
    /// Mark a channel as read
    Q_INVOKABLE void markChannelRead(const QString& serverId, const QString& channelId);
    
    /// Mark DM as read
    Q_INVOKABLE void markDMRead(const QString& peerId);
    
    /// Send typing indicator for server channel
    Q_INVOKABLE void sendTyping(const QString& serverId, const QString& channelId);
    
    /// Send typing indicator for DM
    Q_INVOKABLE void sendDMTyping(const QString& receiver);
    
    /// Send server message via Socket.IO (real-time, preferred over HTTP)
    Q_INVOKABLE void sendServerMessageRT(const QString& serverId, const QString& channelId,
                                         const QString& text, const QString& replyToId = QString());
    
    /// Send direct message via Socket.IO (real-time)
    Q_INVOKABLE void sendDirectMessageRT(const QString& receiver, const QString& text,
                                         const QString& replyToId = QString());
    
    /// Edit server message via Socket.IO
    Q_INVOKABLE void editServerMessage(const QString& serverId, const QString& channelId,
                                       const QString& messageId, const QString& text);
    
    /// Delete server message via Socket.IO
    Q_INVOKABLE void deleteServerMessage(const QString& serverId, const QString& channelId,
                                         const QString& messageId);
    
    /// Edit direct message via Socket.IO
    Q_INVOKABLE void editDirectMessage(const QString& messageId, const QString& text);
    
    /// Delete direct message via Socket.IO
    Q_INVOKABLE void deleteDirectMessage(const QString& messageId);
    
    /// Add reaction to a message via Socket.IO
    Q_INVOKABLE void addReaction(const QString& messageId, const QString& messageType,
                                 const QString& emoji, const QString& serverId = QString(),
                                 const QString& channelId = QString());
    
    /// Remove reaction from a message via Socket.IO
    Q_INVOKABLE void removeReaction(const QString& messageId, const QString& messageType,
                                    const QString& emoji, const QString& serverId = QString(),
                                    const QString& channelId = QString());

    // ========================================================================
    // Configuration
    // ========================================================================
    
    /// Enable/disable debug logging
    Q_INVOKABLE void setDebug(bool debug);

    // API URL configuration
    QString apiBaseUrl() const;
    void setApiBaseUrl(const QString& baseUrl);
    
    // Last opened state persistence
    QString lastServerId() const;
    void setLastServerId(const QString& id);
    QString lastChannelId() const;
    void setLastChannelId(const QString& id);
    QString lastDMRecipientId() const;
    void setLastDMRecipientId(const QString& id);

    // Token accessors (mainly for debugging)
    QString authToken() const;
    bool hasValidAuthToken() const;

signals:
    // Authentication signals
    void loginSuccessful();
    void loginFailed(const QString& reason);
    void registerSuccessful();
    void registerFailed(const QString& reason);
    void authTokenInvalid();
    void loggedInChanged();

    // Configuration signals
    void apiBaseUrlChanged();
    void lastServerIdChanged();
    void lastChannelIdChanged();
    void lastDMRecipientIdChanged();

    // Profile signals (with request ID for parallel request tracking)
    void profileFetched(int requestId, const QVariantMap& profile);
    void profileFetchFailed(int requestId, const QString& error);
    
    // Convenience signals for simple use (current user's profile only)
    void myProfileFetched(const QVariantMap& profile);
    void myProfileFetchFailed(const QString& error);
    
    // Server signals
    void serversFetched(int requestId, const QVariantList& servers);
    void serversFetchFailed(int requestId, const QString& error);
    void serverDetailsFetched(int requestId, const QVariantMap& server);
    void serverDetailsFetchFailed(int requestId, const QString& error);
    
    // Channel signals
    void channelsFetched(int requestId, const QString& serverId, const QVariantList& channels);
    void channelsFetchFailed(int requestId, const QString& serverId, const QString& error);
    void channelDetailsFetched(int requestId, const QVariantMap& channel);
    void channelDetailsFetchFailed(int requestId, const QString& error);
    
    // Category signals
    void categoriesFetched(int requestId, const QString& serverId, const QVariantList& categories);
    void categoriesFetchFailed(int requestId, const QString& serverId, const QString& error);
    
    // Server members signals
    void serverMembersFetched(int requestId, const QString& serverId, const QVariantList& members);
    void serverMembersFetchFailed(int requestId, const QString& serverId, const QString& error);
    
    // Server roles signals
    void serverRolesFetched(int requestId, const QString& serverId, const QVariantList& roles);
    void serverRolesFetchFailed(int requestId, const QString& serverId, const QString& error);
    
    // Presence signals
    void onlineUsersChanged();
    
    // Server emojis signals
    void serverEmojisFetched(int requestId, const QString& serverId, const QVariantList& emojis);
    void serverEmojisFetchFailed(int requestId, const QString& serverId, const QString& error);
    
    // All emojis signals (from all servers)
    void allEmojisFetched(int requestId, const QVariantList& emojis);
    void allEmojisFetchFailed(int requestId, const QString& error);
    
    // Single emoji signals (for cross-server emojis)
    void emojiFetched(int requestId, const QString& emojiId, const QVariantMap& emoji);
    void emojiFetchFailed(int requestId, const QString& emojiId, const QString& error);
    
    // Message signals
    void messagesFetched(int requestId, const QString& serverId, const QString& channelId,
                         const QVariantList& messages);
    void messagesFetchFailed(int requestId, const QString& serverId, const QString& channelId,
                             const QString& error);
    void messageSent(int requestId, const QVariantMap& message);
    void messageSendFailed(int requestId, const QString& error);
    
    // DM message signals
    void dmMessagesFetched(int requestId, const QString& recipientId, const QVariantList& messages);
    void dmMessagesFetchFailed(int requestId, const QString& recipientId, const QString& error);
    void dmMessageSent(int requestId, const QVariantMap& message);
    void dmMessageSendFailed(int requestId, const QString& error);
    
    // Friends signals
    void friendsFetched(int requestId, const QVariantList& friends);
    void friendsFetchFailed(int requestId, const QString& error);
    
    // Server management signals
    void serverJoined(int requestId, const QString& serverId);
    void serverJoinFailed(int requestId, const QString& error);
    void serverCreated(int requestId, const QVariantMap& server);
    void serverCreateFailed(int requestId, const QString& error);
    
    // Socket.IO connection signals
    void socketConnectedChanged();
    void socketIdChanged();
    void socketConnected();
    void socketDisconnected();
    void socketReconnecting(int attempt);
    void socketError(const QString& message);
    
    // Unread state version changed signal (for QML binding triggers)
    void unreadStateVersionChanged();
    
    // Real-time server message signals
    void serverMessageReceived(const QVariantMap& message);
    void serverMessageEdited(const QVariantMap& message);
    void serverMessageDeleted(const QString& messageId, const QString& channelId);
    
    // Real-time direct message signals
    void directMessageReceived(const QVariantMap& message);
    void directMessageEdited(const QVariantMap& message);
    void directMessageDeleted(const QString& messageId);
    
    // Real-time channel signals
    void channelUpdated(const QString& serverId, const QVariantMap& channel);
    void channelCreated(const QString& serverId, const QVariantMap& channel);
    void channelDeleted(const QString& serverId, const QString& channelId);
    void channelUnread(const QString& serverId, const QString& channelId,
                       const QString& lastMessageAt, const QString& senderId);
    
    // Real-time category signals
    void categoryCreated(const QString& serverId, const QVariantMap& category);
    void categoryUpdated(const QString& serverId, const QVariantMap& category);
    void categoryDeleted(const QString& serverId, const QString& categoryId);
    
    // Real-time permission signals
    void channelPermissionsUpdated(const QString& serverId, const QString& channelId,
                                   const QVariantMap& permissions);
    void categoryPermissionsUpdated(const QString& serverId, const QString& categoryId,
                                    const QVariantMap& permissions);
    
    // Real-time DM signals
    void dmUnread(const QString& peer, int count);
    
    // Real-time presence signals
    void userOnline(const QString& username);
    void userOffline(const QString& username);
    void userStatusUpdate(const QString& username, const QVariantMap& status);
    
    // Real-time reaction signals
    void reactionAdded(const QString& messageId, const QString& messageType,
                       const QVariantList& reactions);
    void reactionRemoved(const QString& messageId, const QString& messageType,
                         const QVariantList& reactions);
    
    // Real-time typing signals
    void userTyping(const QString& serverId, const QString& channelId,
                    const QString& username);
    void dmTyping(const QString& username);
    
    // Typing indicator state change signals (for UI updates)
    void typingUsersChanged(const QString& serverId, const QString& channelId);
    void dmTypingUsersChanged(const QString& recipientId);
    
    // Unread state change signals (for UI badge updates)
    void channelUnreadStateChanged(const QString& serverId, const QString& channelId, bool hasUnread);
    void dmUnreadStateChanged(const QString& recipientId, bool hasUnread);
    void serverUnreadStateChanged(const QString& serverId, bool hasUnread);
    void lastReadMessageChanged(const QString& serverId, const QString& channelId, const QString& messageId);
    void dmLastReadMessageChanged(const QString& recipientId, const QString& messageId);
    
    // Real-time server membership signals
    void serverMemberJoined(const QString& serverId, const QString& userId);
    void serverMemberLeft(const QString& serverId, const QString& userId);
    
    // Real-time friend signals
    void friendAdded(const QVariantMap& friendData);
    void friendRemoved(const QString& username, const QString& userId);
    void incomingRequestAdded(const QVariantMap& request);
    void incomingRequestRemoved(const QString& from, const QString& fromId);
    
    // Real-time notification signals
    void pingReceived(const QVariantMap& ping);
    void presenceState(const QVariantMap& presence);
    
    // Real-time server management signals
    void serverUpdated(const QString& serverId, const QVariantMap& server);
    void serverDeleted(const QString& serverId);
    void serverOwnershipTransferred(const QString& serverId, const QString& previousOwnerId,
                                    const QString& newOwnerId, const QString& newOwnerUsername);
    
    // Real-time role signals
    void roleCreated(const QString& serverId, const QVariantMap& role);
    void roleUpdated(const QString& serverId, const QVariantMap& role);
    void roleDeleted(const QString& serverId, const QString& roleId);
    void rolesReordered(const QString& serverId, const QVariantList& rolePositions);
    
    // Real-time member update signals (from REST operations)
    void memberAdded(const QString& serverId, const QString& userId);
    void memberRemoved(const QString& serverId, const QString& userId);
    void memberUpdated(const QString& serverId, const QString& userId, const QVariantMap& member);
    
    // Real-time user profile signals
    void userUpdated(const QString& userId, const QVariantMap& updates);
    void userBannerUpdated(const QString& username, const QVariantMap& updates);
    void usernameChanged(const QString& oldUsername, const QString& newUsername,
                         const QString& userId);
    
    // Real-time admin signals
    void warningReceived(const QVariantMap& warning);
    void accountDeleted(const QString& reason);
    
    // Real-time emoji signals
    void emojiUpdated(const QString& serverId);

public:
    // ========================================================================
    // C++ Models - These provide better performance than QML JavaScript arrays
    // ========================================================================
    
    /**
     * @brief Get the message model.
     * This model provides proper scroll preservation during updates.
     */
    MessageModel* messageModel() const { return m_messageModel; }
    
    /**
     * @brief Get the servers model.
     */
    GenericListModel* serversModel() const { return m_serversModel; }
    
    /**
     * @brief Get the channels model for the current server.
     */
    GenericListModel* channelsModel() const { return m_channelsModel; }
    
    /**
     * @brief Get the members model for the current server.
     */
    GenericListModel* membersModel() const { return m_membersModel; }
    
    /**
     * @brief Get the friends model for DM conversations.
     */
    GenericListModel* friendsModel() const { return m_friendsModel; }
    
    /**
     * @brief Get the roles model for the current server.
     */
    GenericListModel* rolesModel() const { return m_rolesModel; }
    
    /**
     * @brief Get the channel list model with category grouping.
     * This model provides a hierarchical view of channels organized by category.
     */
    ChannelListModel* channelListModel() const { return m_channelListModel; }

private slots:
    // Auth client handlers
    void onAuthLoginSuccessful(const QVariantMap& userData);
    void onAuthLoginFailed(const QString& error);
    void onAuthRegisterSuccessful(const QVariantMap& userData);
    void onAuthRegisterFailed(const QString& error);
    void onAuthNetworkError(const QString& error);
    
    // Network client handlers
    void onNetworkAuthTokenExpired();

private:
    // Persistent storage
    QSettings* m_settings;

    // API clients
    NetworkClient* m_networkClient;
    AuthClient* m_authClient;
    ApiClient* m_apiClient;
    SocketClient* m_socketClient;
    
    // C++ models (owned by this class, exposed to QML)
    MessageModel* m_messageModel;
    GenericListModel* m_serversModel;
    GenericListModel* m_channelsModel;
    GenericListModel* m_membersModel;
    GenericListModel* m_friendsModel;
    GenericListModel* m_rolesModel;
    ChannelListModel* m_channelListModel;
    
    // Presence tracking
    QSet<QString> m_onlineUsers;
    
    // Typing indicator tracking
    // Key format for channels: "serverId:channelId", for DMs: "dm:recipientId"
    // Value: map of username -> expiry timer
    QMap<QString, QMap<QString, QTimer*>> m_typingUsers;
    static const int TYPING_TIMEOUT_MS = 5000;  // 5 seconds
    
    // Unread state tracking
    // Key: "serverId:channelId" for channels, "dm:recipientId" for DMs
    // Value: true if has unread messages
    QMap<QString, bool> m_unreadState;
    // Track last read message ID per channel/DM for "NEW" divider
    QMap<QString, QString> m_lastReadMessageId;
    // Version counter to trigger QML binding updates
    int m_unreadStateVersion = 0;

    // State tracking for network error handling
    bool m_loginInProgress = false;
    bool m_registerInProgress = false;

    // Helper to persist auth state after successful login/register
    void persistAuthState(const QVariantMap& userData);
    // Helper to clear all auth state
    void clearAuthState();
    // Restore auth state from QSettings on startup
    void restoreAuthState();
    
    // Presence event handlers
    void handlePresenceState(const QVariantMap& presence);
    void handleUserOnline(const QString& username);
    void handleUserOffline(const QString& username);
    
    // Typing event handlers
    void handleUserTyping(const QString& serverId, const QString& channelId, const QString& username);
    void handleDMTyping(const QString& username);
    void removeTypingUser(const QString& key, const QString& username);
    
    // Unread event handlers
    void handleChannelUnread(const QString& serverId, const QString& channelId,
                             const QString& lastMessageAt, const QString& senderId);
    void handleDMUnread(const QString& peer, int count);
    
    // Model population handlers
    void handleServerMembersFetched(int requestId, const QString& serverId, const QVariantList& members);
    void handleServerRolesFetched(int requestId, const QString& serverId, const QVariantList& roles);
};

#endif
