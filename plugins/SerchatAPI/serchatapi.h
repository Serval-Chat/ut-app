#ifndef SERCHATAPI_H
#define SERCHATAPI_H

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QMap>
#include <QSettings>

class NetworkClient;
class AuthClient;
class ApiClient;
class SocketClient;

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
    Q_PROPERTY(bool loggedIn READ isLoggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(bool socketConnected READ isSocketConnected NOTIFY socketConnectedChanged)
    Q_PROPERTY(QString socketId READ socketId NOTIFY socketIdChanged)

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
    
    // Message signals
    void messagesFetched(int requestId, const QString& serverId, const QString& channelId,
                         const QVariantList& messages);
    void messagesFetchFailed(int requestId, const QString& serverId, const QString& channelId,
                             const QString& error);
    void messageSent(int requestId, const QVariantMap& message);
    void messageSendFailed(int requestId, const QString& error);
    
    // Socket.IO connection signals
    void socketConnectedChanged();
    void socketIdChanged();
    void socketConnected();
    void socketDisconnected();
    void socketReconnecting(int attempt);
    void socketError(const QString& message);
    
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

    // State tracking for network error handling
    bool m_loginInProgress = false;
    bool m_registerInProgress = false;

    // Helper to persist auth state after successful login/register
    void persistAuthState(const QVariantMap& userData);
    // Helper to clear all auth state
    void clearAuthState();
    // Restore auth state from QSettings on startup
    void restoreAuthState();
};

#endif
