#include <QDebug>
#include <QDateTime>
#include <QStandardPaths>

#include "serchatapi.h"
#include "network/networkclient.h"
#include "network/socketclient.h"
#include "auth/authclient.h"
#include "api/apiclient.h"

SerchatAPI::SerchatAPI() {
    // Initialize persistent storage
    QString settingsPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/settings.ini";
    qDebug() << "[SerchatAPI] Using settings file:" << settingsPath;
    m_settings = new QSettings(settingsPath, QSettings::IniFormat, this);

    // Initialize network and API clients
    m_networkClient = new NetworkClient(this);
    m_authClient = new AuthClient(m_networkClient, this);
    m_apiClient = new ApiClient(m_networkClient, this);
    m_socketClient = new SocketClient(this);

    // Configure base URLs
    QString baseUrl = apiBaseUrl();
    m_authClient->setBaseUrl(baseUrl);
    m_apiClient->setBaseUrl(baseUrl);

    // Connect auth client signals
    connect(m_authClient, &AuthClient::loginSuccessful, 
            this, &SerchatAPI::onAuthLoginSuccessful);
    connect(m_authClient, &AuthClient::loginFailed, 
            this, &SerchatAPI::onAuthLoginFailed);
    connect(m_authClient, &AuthClient::registerSuccessful, 
            this, &SerchatAPI::onAuthRegisterSuccessful);
    connect(m_authClient, &AuthClient::registerFailed, 
            this, &SerchatAPI::onAuthRegisterFailed);
    connect(m_authClient, &AuthClient::networkError, 
            this, &SerchatAPI::onAuthNetworkError);

    // Connect API client signals (with request IDs)
    connect(m_apiClient, &ApiClient::profileFetched, 
            this, &SerchatAPI::profileFetched);
    connect(m_apiClient, &ApiClient::profileFetchFailed, 
            this, &SerchatAPI::profileFetchFailed);
    
    // Connect convenience signals for current user's profile
    connect(m_apiClient, &ApiClient::myProfileFetched, 
            this, &SerchatAPI::myProfileFetched);
    connect(m_apiClient, &ApiClient::myProfileFetchFailed, 
            this, &SerchatAPI::myProfileFetchFailed);
    
    // Connect server signals
    connect(m_apiClient, &ApiClient::serversFetched,
            this, &SerchatAPI::serversFetched);
    connect(m_apiClient, &ApiClient::serversFetchFailed,
            this, &SerchatAPI::serversFetchFailed);
    connect(m_apiClient, &ApiClient::serverDetailsFetched,
            this, &SerchatAPI::serverDetailsFetched);
    connect(m_apiClient, &ApiClient::serverDetailsFetchFailed,
            this, &SerchatAPI::serverDetailsFetchFailed);
    
    // Connect channel signals
    connect(m_apiClient, &ApiClient::channelsFetched,
            this, &SerchatAPI::channelsFetched);
    connect(m_apiClient, &ApiClient::channelsFetchFailed,
            this, &SerchatAPI::channelsFetchFailed);
    connect(m_apiClient, &ApiClient::channelDetailsFetched,
            this, &SerchatAPI::channelDetailsFetched);
    connect(m_apiClient, &ApiClient::channelDetailsFetchFailed,
            this, &SerchatAPI::channelDetailsFetchFailed);
    
    // Connect message signals
    connect(m_apiClient, &ApiClient::messagesFetched,
            this, &SerchatAPI::messagesFetched);
    connect(m_apiClient, &ApiClient::messagesFetchFailed,
            this, &SerchatAPI::messagesFetchFailed);
    connect(m_apiClient, &ApiClient::messageSent,
            this, &SerchatAPI::messageSent);
    connect(m_apiClient, &ApiClient::messageSendFailed,
            this, &SerchatAPI::messageSendFailed);
    
    // Connect friends signals
    connect(m_apiClient, &ApiClient::friendsFetched,
            this, &SerchatAPI::friendsFetched);
    connect(m_apiClient, &ApiClient::friendsFetchFailed,
            this, &SerchatAPI::friendsFetchFailed);
    
    // Connect server management signals
    connect(m_apiClient, &ApiClient::serverJoined,
            this, &SerchatAPI::serverJoined);
    connect(m_apiClient, &ApiClient::serverJoinFailed,
            this, &SerchatAPI::serverJoinFailed);
    connect(m_apiClient, &ApiClient::serverCreated,
            this, &SerchatAPI::serverCreated);
    connect(m_apiClient, &ApiClient::serverCreateFailed,
            this, &SerchatAPI::serverCreateFailed);

    // Connect network client for automatic 401 handling
    connect(m_networkClient, &NetworkClient::authTokenExpired,
            this, &SerchatAPI::onNetworkAuthTokenExpired);

    // Connect socket client signals
    connect(m_socketClient, &SocketClient::connectedChanged,
            this, &SerchatAPI::socketConnectedChanged);
    connect(m_socketClient, &SocketClient::socketIdChanged,
            this, &SerchatAPI::socketIdChanged);
    connect(m_socketClient, &SocketClient::connected,
            this, &SerchatAPI::socketConnected);
    connect(m_socketClient, &SocketClient::disconnected,
            this, &SerchatAPI::socketDisconnected);
    connect(m_socketClient, &SocketClient::reconnecting,
            this, &SerchatAPI::socketReconnecting);
    connect(m_socketClient, &SocketClient::error,
            this, &SerchatAPI::socketError);
    
    // Real-time server message events
    connect(m_socketClient, &SocketClient::serverMessageReceived,
            this, &SerchatAPI::serverMessageReceived);
    connect(m_socketClient, &SocketClient::serverMessageEdited,
            this, &SerchatAPI::serverMessageEdited);
    connect(m_socketClient, &SocketClient::serverMessageDeleted,
            this, &SerchatAPI::serverMessageDeleted);
    
    // Real-time DM events
    connect(m_socketClient, &SocketClient::directMessageReceived,
            this, &SerchatAPI::directMessageReceived);
    connect(m_socketClient, &SocketClient::directMessageEdited,
            this, &SerchatAPI::directMessageEdited);
    connect(m_socketClient, &SocketClient::directMessageDeleted,
            this, &SerchatAPI::directMessageDeleted);
    
    // Real-time channel events
    connect(m_socketClient, &SocketClient::channelUpdated,
            this, &SerchatAPI::channelUpdated);
    connect(m_socketClient, &SocketClient::channelCreated,
            this, &SerchatAPI::channelCreated);
    connect(m_socketClient, &SocketClient::channelDeleted,
            this, &SerchatAPI::channelDeleted);
    connect(m_socketClient, &SocketClient::channelUnread,
            this, &SerchatAPI::channelUnread);
    
    // Real-time DM unread
    connect(m_socketClient, &SocketClient::dmUnread,
            this, &SerchatAPI::dmUnread);
    
    // Real-time presence events
    connect(m_socketClient, &SocketClient::userOnline,
            this, &SerchatAPI::userOnline);
    connect(m_socketClient, &SocketClient::userOffline,
            this, &SerchatAPI::userOffline);
    connect(m_socketClient, &SocketClient::userStatusUpdate,
            this, &SerchatAPI::userStatusUpdate);
    
    // Real-time reaction events
    connect(m_socketClient, &SocketClient::reactionAdded,
            this, &SerchatAPI::reactionAdded);
    connect(m_socketClient, &SocketClient::reactionRemoved,
            this, &SerchatAPI::reactionRemoved);
    
    // Real-time typing events
    connect(m_socketClient, &SocketClient::userTyping,
            this, &SerchatAPI::userTyping);
    connect(m_socketClient, &SocketClient::dmTyping,
            this, &SerchatAPI::dmTyping);
    
    // Real-time server membership events
    connect(m_socketClient, &SocketClient::serverMemberJoined,
            this, &SerchatAPI::serverMemberJoined);
    connect(m_socketClient, &SocketClient::serverMemberLeft,
            this, &SerchatAPI::serverMemberLeft);
    
    // Real-time friend events
    connect(m_socketClient, &SocketClient::friendAdded,
            this, &SerchatAPI::friendAdded);
    connect(m_socketClient, &SocketClient::friendRemoved,
            this, &SerchatAPI::friendRemoved);
    connect(m_socketClient, &SocketClient::incomingRequestAdded,
            this, &SerchatAPI::incomingRequestAdded);
    connect(m_socketClient, &SocketClient::incomingRequestRemoved,
            this, &SerchatAPI::incomingRequestRemoved);
    
    // Real-time notifications
    connect(m_socketClient, &SocketClient::pingReceived,
            this, &SerchatAPI::pingReceived);
    connect(m_socketClient, &SocketClient::presenceState,
            this, &SerchatAPI::presenceState);

    // Restore any existing auth state
    restoreAuthState();

    qDebug() << "[SerchatAPI] Initialized, logged in:" << isLoggedIn();
}

SerchatAPI::~SerchatAPI() {
    // Children are cleaned up automatically via QObject parent
}

// ============================================================================
// Configuration
// ============================================================================

QString SerchatAPI::apiBaseUrl() const {
    return m_settings->value("apiBaseUrl", "https://catfla.re/").toString();
}

void SerchatAPI::setApiBaseUrl(const QString& baseUrl) {
    QUrl url(baseUrl);
    if (!url.isValid() || url.scheme().isEmpty() || url.host().isEmpty()) {
        qWarning() << "[SerchatAPI] Invalid API base URL:" << baseUrl;
        return;
    }

    if (apiBaseUrl() != baseUrl) {
        m_settings->setValue("apiBaseUrl", baseUrl);
        m_authClient->setBaseUrl(baseUrl);
        m_apiClient->setBaseUrl(baseUrl);
        emit apiBaseUrlChanged();
        qDebug() << "[SerchatAPI] API base URL changed to:" << baseUrl;
    }
}

void SerchatAPI::setDebug(bool debug) {
    m_networkClient->setDebug(debug);
}

// ============================================================================
// Authentication
// ============================================================================

bool SerchatAPI::isLoggedIn() const {
    return m_settings->value("loggedIn", false).toBool();
}

void SerchatAPI::login(const QString& login, const QString& password) {
    m_loginInProgress = true;
    m_authClient->login(login, password);
}

void SerchatAPI::registerUser(const QString& login, const QString& username, 
                               const QString& password, const QString& inviteToken) {
    m_registerInProgress = true;
    m_authClient->registerUser(login, username, password, inviteToken);
}

void SerchatAPI::logout() {
    clearAuthState();
    qDebug() << "[SerchatAPI] User logged out";
}

QString SerchatAPI::authToken() const {
    return m_authClient->authToken();
}

bool SerchatAPI::hasValidAuthToken() const {
    return !m_authClient->authToken().isEmpty() && isLoggedIn();
}

void SerchatAPI::validateAuthToken() {
    if (!hasValidAuthToken()) {
        logout();
        emit authTokenInvalid();
        return;
    }

    // Make a simple authenticated request to validate the token
    // The 401 handling in NetworkClient will trigger onNetworkAuthTokenExpired
    // if the token is invalid
    getUserProfile();
}

// ============================================================================
// API Methods - Profile
// ============================================================================

void SerchatAPI::getUserProfile() {
    m_apiClient->getMyProfile();
}

int SerchatAPI::getMyProfile() {
    return m_apiClient->getMyProfile();
}

int SerchatAPI::getProfile(const QString& userId, bool useCache) {
    return m_apiClient->getProfile(userId, useCache);
}

// ============================================================================
// API Methods - Servers
// ============================================================================

int SerchatAPI::getServers(bool useCache) {
    return m_apiClient->getServers(useCache);
}

int SerchatAPI::getServerDetails(const QString& serverId, bool useCache) {
    return m_apiClient->getServerDetails(serverId, useCache);
}

int SerchatAPI::joinServerByInvite(const QString& inviteCode) {
    return m_apiClient->joinServerByInvite(inviteCode);
}

int SerchatAPI::createNewServer(const QString& name) {
    return m_apiClient->createServer(name);
}

// ============================================================================
// API Methods - Friends
// ============================================================================

int SerchatAPI::getFriends(bool useCache) {
    return m_apiClient->getFriends(useCache);
}

// ============================================================================
// API Methods - Channels
// ============================================================================

int SerchatAPI::getChannels(const QString& serverId, bool useCache) {
    return m_apiClient->getChannels(serverId, useCache);
}

int SerchatAPI::getChannelDetails(const QString& serverId, const QString& channelId, bool useCache) {
    return m_apiClient->getChannelDetails(serverId, channelId, useCache);
}

// ============================================================================
// API Methods - Messages
// ============================================================================

int SerchatAPI::getMessages(const QString& serverId, const QString& channelId,
                            int limit, const QString& before) {
    return m_apiClient->getMessages(serverId, channelId, limit, before);
}

int SerchatAPI::sendMessage(const QString& serverId, const QString& channelId,
                            const QString& text, const QString& replyToId) {
    return m_apiClient->sendMessage(serverId, channelId, text, replyToId);
}

// ============================================================================
// Cache Management
// ============================================================================

void SerchatAPI::setCacheTTL(int seconds) {
    m_apiClient->setCacheTTL(seconds);
}

void SerchatAPI::clearCache() {
    m_apiClient->clearCache();
}

void SerchatAPI::clearCacheFor(const QString& cacheKey) {
    m_apiClient->clearCacheFor(cacheKey);
}

void SerchatAPI::clearProfileCacheFor(const QString& userId) {
    m_apiClient->clearCacheFor(QStringLiteral("profile:%1").arg(userId));
}

bool SerchatAPI::hasProfileCached(const QString& userId) const {
    return m_apiClient->hasCachedData(QStringLiteral("profile:%1").arg(userId));
}

// ============================================================================
// Request Management
// ============================================================================

void SerchatAPI::cancelRequest(int requestId) {
    m_apiClient->cancelRequest(requestId);
}

bool SerchatAPI::isRequestPending(int requestId) const {
    return m_apiClient->isRequestPending(requestId);
}

// ============================================================================
// Auth State Management
// ============================================================================

void SerchatAPI::persistAuthState(const QVariantMap& userData) {
    m_settings->setValue("loggedIn", true);
    
    if (userData.contains("username")) {
        m_settings->setValue("username", userData["username"].toString());
    } else {
        qDebug() << "[SerchatAPI] Warning: userData missing 'username' field";
    }

    // Store token - AuthClient already has it, but we persist for app restart
    if (userData.contains("token")) {
        m_settings->setValue("authToken", userData["token"].toString());
    } else {
        qDebug() << "[SerchatAPI] Warning: userData missing 'token' field";
    }

    m_settings->sync();
    emit loggedInChanged();
}

void SerchatAPI::clearAuthState() {
    bool wasLoggedIn = isLoggedIn();

    m_settings->setValue("loggedIn", false);
    m_settings->remove("username");
    m_settings->remove("authToken");
    m_settings->sync();

    m_authClient->clearAuthToken();

    if (wasLoggedIn) {
        emit loggedInChanged();
    }
}

void SerchatAPI::restoreAuthState() {
    QString storedToken = m_settings->value("authToken", "").toString();
    
    if (!storedToken.isEmpty() && isLoggedIn()) {
        // Restore token to AuthClient (which propagates to NetworkClient)
        m_authClient->setAuthToken(storedToken);
        qDebug() << "[SerchatAPI] Restored auth state from settings";
        
        // Auto-connect socket after restoring auth
        connectSocket();
    } else if (isLoggedIn()) {
        // Inconsistent state - marked logged in but no token
        qWarning() << "[SerchatAPI] Inconsistent auth state, clearing";
        clearAuthState();
    }
}

// ============================================================================
// Slot Implementations
// ============================================================================

void SerchatAPI::onAuthLoginSuccessful(const QVariantMap& userData) {
    m_loginInProgress = false;
    persistAuthState(userData);
    qDebug() << "[SerchatAPI] Login successful for:" << userData.value("username").toString();
    emit loginSuccessful();
    
    // Auto-connect socket on login
    connectSocket();
}

void SerchatAPI::onAuthLoginFailed(const QString& error) {
    m_loginInProgress = false;
    qDebug() << "[SerchatAPI] Login failed:" << error;
    emit loginFailed(error);
}

void SerchatAPI::onAuthRegisterSuccessful(const QVariantMap& userData) {
    m_registerInProgress = false;
    persistAuthState(userData);
    qDebug() << "[SerchatAPI] Registration successful for:" << userData.value("username").toString();
    emit registerSuccessful();
}

void SerchatAPI::onAuthRegisterFailed(const QString& error) {
    m_registerInProgress = false;
    qDebug() << "[SerchatAPI] Registration failed:" << error;
    emit registerFailed(error);
}

void SerchatAPI::onAuthNetworkError(const QString& error) {
    qDebug() << "[SerchatAPI] Network error:" << error;

    // Only emit to the operation that was in progress
    if (m_loginInProgress) {
        m_loginInProgress = false;
        emit loginFailed(QStringLiteral("Network error: %1").arg(error));
    }
    if (m_registerInProgress) {
        m_registerInProgress = false;
        emit registerFailed(QStringLiteral("Network error: %1").arg(error));
    }
}

void SerchatAPI::onNetworkAuthTokenExpired() {
    // This is called when NetworkClient detects a 401 on any authenticated request
    qDebug() << "[SerchatAPI] Auth token expired, logging out";
    disconnectSocket();
    clearAuthState();
    emit authTokenInvalid();
}

// ============================================================================
// Socket.IO Real-time Connection
// ============================================================================

bool SerchatAPI::isSocketConnected() const {
    return m_socketClient->isConnected();
}

QString SerchatAPI::socketId() const {
    return m_socketClient->socketId();
}

void SerchatAPI::connectSocket() {
    if (!isLoggedIn()) {
        qWarning() << "[SerchatAPI] Cannot connect socket: not logged in";
        return;
    }
    
    QString token = authToken();
    if (token.isEmpty()) {
        qWarning() << "[SerchatAPI] Cannot connect socket: no auth token";
        return;
    }
    
    QString url = apiBaseUrl();
    qDebug() << "[SerchatAPI] Connecting socket to:" << url;
    m_socketClient->connect(url, token);
}

void SerchatAPI::disconnectSocket() {
    m_socketClient->disconnect();
}

void SerchatAPI::joinServer(const QString& serverId) {
    m_socketClient->joinServer(serverId);
}

void SerchatAPI::leaveServer(const QString& serverId) {
    m_socketClient->leaveServer(serverId);
}

void SerchatAPI::joinChannel(const QString& serverId, const QString& channelId) {
    m_socketClient->joinChannel(serverId, channelId);
}

void SerchatAPI::leaveChannel(const QString& serverId, const QString& channelId) {
    m_socketClient->leaveChannel(serverId, channelId);
}

void SerchatAPI::markChannelRead(const QString& serverId, const QString& channelId) {
    m_socketClient->markChannelRead(serverId, channelId);
}

void SerchatAPI::markDMRead(const QString& peerId) {
    m_socketClient->markDMRead(peerId);
}

void SerchatAPI::sendTyping(const QString& serverId, const QString& channelId) {
    m_socketClient->sendTyping(serverId, channelId);
}

void SerchatAPI::sendDMTyping(const QString& receiver) {
    m_socketClient->sendDMTyping(receiver);
}

void SerchatAPI::sendServerMessageRT(const QString& serverId, const QString& channelId,
                                      const QString& text, const QString& replyToId) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot send message: socket not connected";
        return;
    }
    m_socketClient->sendServerMessage(serverId, channelId, text, replyToId);
}

void SerchatAPI::sendDirectMessageRT(const QString& receiver, const QString& text,
                                      const QString& replyToId) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot send DM: socket not connected";
        return;
    }
    m_socketClient->sendDirectMessage(receiver, text, replyToId);
}

void SerchatAPI::editServerMessage(const QString& serverId, const QString& channelId,
                                    const QString& messageId, const QString& text) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot edit message: socket not connected";
        return;
    }
    m_socketClient->editServerMessage(serverId, channelId, messageId, text);
}

void SerchatAPI::deleteServerMessage(const QString& serverId, const QString& channelId,
                                      const QString& messageId) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot delete message: socket not connected";
        return;
    }
    m_socketClient->deleteServerMessage(serverId, channelId, messageId);
}

void SerchatAPI::editDirectMessage(const QString& messageId, const QString& text) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot edit DM: socket not connected";
        return;
    }
    m_socketClient->editDirectMessage(messageId, text);
}

void SerchatAPI::deleteDirectMessage(const QString& messageId) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot delete DM: socket not connected";
        return;
    }
    m_socketClient->deleteDirectMessage(messageId);
}

void SerchatAPI::addReaction(const QString& messageId, const QString& messageType,
                              const QString& emoji, const QString& serverId,
                              const QString& channelId) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot add reaction: socket not connected";
        return;
    }
    m_socketClient->addReaction(messageId, messageType, emoji, serverId, channelId);
}

void SerchatAPI::removeReaction(const QString& messageId, const QString& messageType,
                                 const QString& emoji, const QString& serverId,
                                 const QString& channelId) {
    if (!isSocketConnected()) {
        qWarning() << "[SerchatAPI] Cannot remove reaction: socket not connected";
        return;
    }
    m_socketClient->removeReaction(messageId, messageType, emoji, serverId, channelId);
}
