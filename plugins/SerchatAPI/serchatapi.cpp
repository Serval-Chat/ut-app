#include <QDebug>
#include <QDateTime>
#include <QStandardPaths>
#include <QGuiApplication>

#include "serchatapi.h"
#include "network/networkclient.h"
#include "network/socketclient.h"
#include "auth/authclient.h"
#include "api/apiclient.h"
#include "models/messagemodel.h"
#include "models/genericlistmodel.h"
#include "models/channellistmodel.h"
#include "emojicache.h"
#include "userprofilecache.h"
#include "servermembercache.h"
#include "channelcache.h"
#include "messagecache.h"
#include "markdownparser.h"

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
    
    // Initialize C++ models for QML
    // These provide better performance than JavaScript arrays and proper scroll behavior
    m_messageModel = new MessageModel(this);
    m_serversModel = new GenericListModel("_id", this);
    m_channelsModel = new GenericListModel("_id", this);
    m_membersModel = new GenericListModel("_id", this);
    m_friendsModel = new GenericListModel("_id", this);
    m_rolesModel = new GenericListModel("_id", this);
    m_channelListModel = new ChannelListModel(this);
    
    // Initialize global caches
    // These provide centralized storage, eliminating prop drilling in QML
    m_emojiCache = new EmojiCache(this);
    m_userProfileCache = new UserProfileCache(this);
    m_serverMemberCache = new ServerMemberCache(this);
    m_channelCache = new ChannelCache(this);
    m_messageCache = new MessageCache(this);

    // Initialize markdown parser (moves text processing from QML to C++)
    m_markdownParser = new MarkdownParser(this);
    m_markdownParser->setEmojiCache(m_emojiCache);
    m_markdownParser->setUserProfileCache(m_userProfileCache);

    // Connect MessageModel to UserProfileCache for sender name/avatar lookups
    m_messageModel->setUserProfileCache(m_userProfileCache);

    // Configure base URLs
    QString baseUrl = apiBaseUrl();
    m_authClient->setBaseUrl(baseUrl);
    m_apiClient->setBaseUrl(baseUrl);
    
    // Configure caches with API client for auto-fetch and base URL for image URLs
    m_emojiCache->setApiClient(m_apiClient);
    m_emojiCache->setBaseUrl(baseUrl);
    m_userProfileCache->setApiClient(m_apiClient);
    m_userProfileCache->setBaseUrl(baseUrl);
    m_serverMemberCache->setApiClient(m_apiClient);
    m_channelCache->setApiClient(m_apiClient);
    m_messageCache->setApiClient(m_apiClient);

    // Configure markdown parser with base URL
    m_markdownParser->setBaseUrl(baseUrl);

    // Connect auth client signals
    connect(m_authClient, &AuthClient::loginSuccessful, 
            this, &SerchatAPI::onAuthLoginSuccessful);
    connect(m_authClient, &AuthClient::loginFailed, 
            this, &SerchatAPI::onAuthLoginFailed);
    connect(m_authClient, &AuthClient::registerSuccessful, 
            this, &SerchatAPI::onAuthRegisterSuccessful);
    connect(m_authClient, &AuthClient::registerFailed, 
            this, &SerchatAPI::onAuthRegisterFailed);
    connect(m_authClient, &AuthClient::changeLoginSuccessful,
            this, &SerchatAPI::onAuthChangeLoginSuccessful);
    connect(m_authClient, &AuthClient::changeLoginFailed,
            this, &SerchatAPI::onAuthChangeLoginFailed);
    connect(m_authClient, &AuthClient::changePasswordSuccessful,
            this, &SerchatAPI::onAuthChangePasswordSuccessful);
    connect(m_authClient, &AuthClient::changePasswordFailed,
            this, &SerchatAPI::onAuthChangePasswordFailed);
    connect(m_authClient, &AuthClient::networkError, 
            this, &SerchatAPI::onAuthNetworkError);

    // Connect API client signals (with request IDs) - also populate profile cache
    connect(m_apiClient, &ApiClient::profileFetched, 
            this, [this](int requestId, const QVariantMap& profile) {
                QString userId = profile.value("_id").toString();
                if (userId.isEmpty()) {
                    userId = profile.value("id").toString();
                }
                if (!userId.isEmpty()) {
                    m_userProfileCache->updateProfile(userId, profile);
                }
                emit profileFetched(requestId, profile);
            });
    connect(m_apiClient, &ApiClient::profileFetchFailed, 
            this, &SerchatAPI::profileFetchFailed);
    connect(m_apiClient, &ApiClient::profileUpdateSuccess,
            this, &SerchatAPI::profileUpdateSuccess);
    connect(m_apiClient, &ApiClient::profileUpdateFailed,
            this, &SerchatAPI::profileUpdateFailed);
    
    // Connect file upload signals
    connect(m_apiClient, &ApiClient::fileUploadSuccess,
            this, &SerchatAPI::fileUploadSuccess);
    connect(m_apiClient, &ApiClient::fileUploadFailed,
            this, &SerchatAPI::fileUploadFailed);
    
    // Connect convenience signals for current user's profile - also populate cache
    connect(m_apiClient, &ApiClient::myProfileFetched, 
            this, [this](const QVariantMap& profile) {
                QString userId = profile.value("_id").toString();
                if (userId.isEmpty()) {
                    userId = profile.value("id").toString();
                }
                if (!userId.isEmpty()) {
                    m_userProfileCache->updateProfile(userId, profile);
                }
                emit myProfileFetched(profile);
            });
    connect(m_apiClient, &ApiClient::myProfileFetchFailed, 
            this, &SerchatAPI::myProfileFetchFailed);
    
    // Connect server signals
    connect(m_apiClient, &ApiClient::serversFetched,
            this, &SerchatAPI::handleServersFetched);
    connect(m_apiClient, &ApiClient::serversFetchFailed,
            this, &SerchatAPI::serversFetchFailed);
    connect(m_apiClient, &ApiClient::serverDetailsFetched,
            this, &SerchatAPI::serverDetailsFetched);
    connect(m_apiClient, &ApiClient::serverDetailsFetchFailed,
            this, &SerchatAPI::serverDetailsFetchFailed);
    
    // Connect channel signals - intercept to extract lastReadAt
    connect(m_apiClient, &ApiClient::channelsFetched,
            this, &SerchatAPI::handleChannelsFetched);
    connect(m_apiClient, &ApiClient::channelsFetchFailed,
            this, &SerchatAPI::channelsFetchFailed);

    // Also connect to ChannelCache for its internal refresh mechanism
    connect(m_apiClient, &ApiClient::channelsFetched,
            m_channelCache, &ChannelCache::onChannelsFetched);
    connect(m_apiClient, &ApiClient::channelsFetchFailed,
            m_channelCache, &ChannelCache::onChannelsFetchFailed);
    connect(m_apiClient, &ApiClient::categoriesFetched,
            m_channelCache, &ChannelCache::onCategoriesFetched);
    connect(m_apiClient, &ApiClient::categoriesFetchFailed,
            m_channelCache, &ChannelCache::onCategoriesFetchFailed);
    connect(m_apiClient, &ApiClient::channelDetailsFetched,
            this, &SerchatAPI::channelDetailsFetched);
    connect(m_apiClient, &ApiClient::channelDetailsFetchFailed,
            this, &SerchatAPI::channelDetailsFetchFailed);
    
    // Connect category signals
    connect(m_apiClient, &ApiClient::categoriesFetched,
            this, &SerchatAPI::categoriesFetched);
    connect(m_apiClient, &ApiClient::categoriesFetchFailed,
            this, &SerchatAPI::categoriesFetchFailed);
    
    // Connect server members signals
    connect(m_apiClient, &ApiClient::serverMembersFetched,
            this, &SerchatAPI::handleServerMembersFetched);
    connect(m_apiClient, &ApiClient::serverMembersFetchFailed,
            this, &SerchatAPI::serverMembersFetchFailed);
    
    // Connect server roles signals
    connect(m_apiClient, &ApiClient::serverRolesFetched,
            this, &SerchatAPI::handleServerRolesFetched);
    connect(m_apiClient, &ApiClient::serverRolesFetchFailed,
            this, &SerchatAPI::serverRolesFetchFailed);
    
    // Connect server emojis signals - also populate cache
    connect(m_apiClient, &ApiClient::serverEmojisFetched,
            this, [this](int requestId, const QString& serverId, const QVariantList& emojis) {
                m_emojiCache->loadServerEmojis(serverId, emojis);
                emit serverEmojisFetched(requestId, serverId, emojis);
            });
    connect(m_apiClient, &ApiClient::serverEmojisFetchFailed,
            this, &SerchatAPI::serverEmojisFetchFailed);
    
    // Connect all emojis signals - also populate cache
    connect(m_apiClient, &ApiClient::allEmojisFetched,
            this, [this](int requestId, const QVariantList& emojis) {
                m_emojiCache->loadAllEmojis(emojis);
                emit allEmojisFetched(requestId, emojis);
            });
    connect(m_apiClient, &ApiClient::allEmojisFetchFailed,
            this, &SerchatAPI::allEmojisFetchFailed);
    
    // Connect single emoji signals (for cross-server emoji lookup) - also populate cache
    connect(m_apiClient, &ApiClient::emojiFetched,
            this, [this](int requestId, const QString& emojiId, const QVariantMap& emoji) {
                m_emojiCache->addEmoji(emoji);
                emit emojiFetched(requestId, emojiId, emoji);
            });
    connect(m_apiClient, &ApiClient::emojiFetchFailed,
            this, &SerchatAPI::emojiFetchFailed);
    
    // Connect message signals - intercept to calculate first unread
    connect(m_apiClient, &ApiClient::messagesFetched,
            this, &SerchatAPI::handleMessagesFetched);
    connect(m_apiClient, &ApiClient::messagesFetchFailed,
            this, &SerchatAPI::messagesFetchFailed);

    // Also connect to MessageCache for its internal refresh mechanism
    connect(m_apiClient, &ApiClient::messagesFetched,
            m_messageCache, &MessageCache::onMessagesFetched);
    connect(m_apiClient, &ApiClient::messagesFetchFailed,
            m_messageCache, &MessageCache::onMessagesFetchFailed);
    connect(m_apiClient, &ApiClient::messageSent,
            this, &SerchatAPI::messageSent);
    connect(m_apiClient, &ApiClient::messageSendFailed,
            this, &SerchatAPI::messageSendFailed);
    
    // Connect DM message signals - intercept to reverse order
    connect(m_apiClient, &ApiClient::dmMessagesFetched,
            this, &SerchatAPI::handleDMMessagesFetched);
    connect(m_apiClient, &ApiClient::dmMessagesFetchFailed,
            this, &SerchatAPI::dmMessagesFetchFailed);
    connect(m_apiClient, &ApiClient::dmMessageSent,
            this, &SerchatAPI::dmMessageSent);
    connect(m_apiClient, &ApiClient::dmMessageSendFailed,
            this, &SerchatAPI::dmMessageSendFailed);
    
    // Connect friends signals
    connect(m_apiClient, &ApiClient::friendsFetched,
            this, &SerchatAPI::handleFriendsFetched);
    connect(m_apiClient, &ApiClient::friendsFetchFailed,
            this, &SerchatAPI::friendsFetchFailed);
    connect(m_apiClient, &ApiClient::friendRequestSent,
            this, &SerchatAPI::friendRequestSent);
    connect(m_apiClient, &ApiClient::friendRequestSendFailed,
            this, &SerchatAPI::friendRequestSendFailed);
    connect(m_apiClient, &ApiClient::friendRemoved,
            this, &SerchatAPI::handleFriendRemovedApi);
    connect(m_apiClient, &ApiClient::friendRemoveFailed,
            this, &SerchatAPI::friendRemoveFailed);
    
    // Connect system signals
    connect(m_apiClient, &ApiClient::systemInfoFetched,
            this, &SerchatAPI::systemInfoFetched);
    connect(m_apiClient, &ApiClient::systemInfoFetchFailed,
            this, &SerchatAPI::systemInfoFetchFailed);
    
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
            this, &SerchatAPI::handleSocketConnected);  // Internal handler for cache refresh
    connect(m_socketClient, &SocketClient::disconnected,
            this, &SerchatAPI::handleSocketDisconnected);  // Internal handler
    connect(m_socketClient, &SocketClient::reconnecting,
            this, &SerchatAPI::socketReconnecting);
    connect(m_socketClient, &SocketClient::error,
            this, &SerchatAPI::socketError);
    
    // Real-time server message events - route through internal handlers to update caches
    connect(m_socketClient, &SocketClient::serverMessageReceived,
            this, &SerchatAPI::handleServerMessageReceived);
    connect(m_socketClient, &SocketClient::serverMessageEdited,
            this, &SerchatAPI::handleServerMessageEdited);
    connect(m_socketClient, &SocketClient::serverMessageDeleted,
            this, &SerchatAPI::handleServerMessageDeleted);
    
    // Real-time DM events
    connect(m_socketClient, &SocketClient::directMessageReceived,
            this, &SerchatAPI::directMessageReceived);
    connect(m_socketClient, &SocketClient::directMessageEdited,
            this, &SerchatAPI::directMessageEdited);
    connect(m_socketClient, &SocketClient::directMessageDeleted,
            this, &SerchatAPI::directMessageDeleted);
    
    // Real-time channel events - route through internal handlers to update caches
    connect(m_socketClient, &SocketClient::channelUpdated,
            this, &SerchatAPI::handleChannelUpdated);
    connect(m_socketClient, &SocketClient::channelCreated,
            this, &SerchatAPI::handleChannelCreated);
    connect(m_socketClient, &SocketClient::channelDeleted,
            this, &SerchatAPI::handleChannelDeleted);
    // Route through internal handler for unread tracking
    connect(m_socketClient, &SocketClient::channelUnread,
            this, &SerchatAPI::handleChannelUnread);
    
    // Real-time category events - route through internal handlers
    connect(m_socketClient, &SocketClient::categoryCreated,
            this, &SerchatAPI::handleCategoryCreated);
    connect(m_socketClient, &SocketClient::categoryUpdated,
            this, &SerchatAPI::handleCategoryUpdated);
    connect(m_socketClient, &SocketClient::categoryDeleted,
            this, &SerchatAPI::handleCategoryDeleted);
    
    // Real-time DM unread - route through internal handler
    connect(m_socketClient, &SocketClient::dmUnread,
            this, &SerchatAPI::handleDMUnread);
    
    // Real-time presence events
    connect(m_socketClient, &SocketClient::userOnline,
            this, &SerchatAPI::userOnline);
    connect(m_socketClient, &SocketClient::userOffline,
            this, &SerchatAPI::userOffline);
    connect(m_socketClient, &SocketClient::userStatusUpdate,
            this, &SerchatAPI::userStatusUpdate);
    
    // Internal presence tracking handlers (update m_onlineUsers set)
    connect(m_socketClient, &SocketClient::userOnline,
            this, &SerchatAPI::handleUserOnline);
    connect(m_socketClient, &SocketClient::userOffline,
            this, &SerchatAPI::handleUserOffline);
    connect(m_socketClient, &SocketClient::presenceState,
            this, &SerchatAPI::handlePresenceState);
    
    // Real-time reaction events
    connect(m_socketClient, &SocketClient::reactionAdded,
            this, &SerchatAPI::reactionAdded);
    connect(m_socketClient, &SocketClient::reactionRemoved,
            this, &SerchatAPI::reactionRemoved);
    
    // Real-time typing events - route through internal handlers for tracking
    connect(m_socketClient, &SocketClient::userTyping,
            this, &SerchatAPI::handleUserTyping);
    connect(m_socketClient, &SocketClient::dmTyping,
            this, &SerchatAPI::handleDMTyping);
    
    // Real-time server membership events
    connect(m_socketClient, &SocketClient::serverMemberJoined,
            this, &SerchatAPI::serverMemberJoined);
    connect(m_socketClient, &SocketClient::serverMemberLeft,
            this, &SerchatAPI::serverMemberLeft);
    
    // Real-time friend events
    connect(m_socketClient, &SocketClient::friendAdded,
            this, &SerchatAPI::handleFriendAdded);
    connect(m_socketClient, &SocketClient::friendRemoved,
            this, &SerchatAPI::handleFriendRemoved);
    connect(m_socketClient, &SocketClient::incomingRequestAdded,
            this, &SerchatAPI::incomingRequestAdded);
    connect(m_socketClient, &SocketClient::incomingRequestRemoved,
            this, &SerchatAPI::incomingRequestRemoved);
    
    // Real-time notifications
    connect(m_socketClient, &SocketClient::pingReceived,
            this, &SerchatAPI::pingReceived);
    connect(m_socketClient, &SocketClient::presenceState,
            this, &SerchatAPI::presenceState);
    
    // Real-time permission events
    connect(m_socketClient, &SocketClient::channelPermissionsUpdated,
            this, &SerchatAPI::channelPermissionsUpdated);
    connect(m_socketClient, &SocketClient::categoryPermissionsUpdated,
            this, &SerchatAPI::categoryPermissionsUpdated);
    
    // Real-time server management events
    connect(m_socketClient, &SocketClient::serverUpdated,
            this, &SerchatAPI::serverUpdated);
    connect(m_socketClient, &SocketClient::serverDeleted,
            this, &SerchatAPI::serverDeleted);
    connect(m_socketClient, &SocketClient::serverOwnershipTransferred,
            this, &SerchatAPI::serverOwnershipTransferred);
    
    // Real-time role events - route through internal handlers to update cache
    connect(m_socketClient, &SocketClient::roleCreated,
            this, &SerchatAPI::handleRoleCreated);
    connect(m_socketClient, &SocketClient::roleUpdated,
            this, &SerchatAPI::handleRoleUpdated);
    connect(m_socketClient, &SocketClient::roleDeleted,
            this, &SerchatAPI::handleRoleDeleted);
    connect(m_socketClient, &SocketClient::rolesReordered,
            this, &SerchatAPI::handleRolesReordered);
    
    // Real-time member update events - route through internal handlers to update cache
    connect(m_socketClient, &SocketClient::memberAdded,
            this, &SerchatAPI::handleMemberAdded);
    connect(m_socketClient, &SocketClient::memberRemoved,
            this, &SerchatAPI::handleMemberRemoved);
    connect(m_socketClient, &SocketClient::memberUpdated,
            this, &SerchatAPI::handleMemberUpdated);
    
    // Real-time user profile events
    connect(m_socketClient, &SocketClient::userUpdated,
            this, &SerchatAPI::userUpdated);
    connect(m_socketClient, &SocketClient::userBannerUpdated,
            this, &SerchatAPI::userBannerUpdated);
    connect(m_socketClient, &SocketClient::usernameChanged,
            this, &SerchatAPI::usernameChanged);
    
    // Real-time admin events
    connect(m_socketClient, &SocketClient::warningReceived,
            this, &SerchatAPI::warningReceived);
    connect(m_socketClient, &SocketClient::accountDeleted,
            this, &SerchatAPI::accountDeleted);
    
    // Real-time emoji events
    connect(m_socketClient, &SocketClient::emojiUpdated,
            this, &SerchatAPI::emojiUpdated);

    // Connect to app lifecycle events for Ubuntu Touch suspension handling
    connect(qGuiApp, &QGuiApplication::applicationStateChanged,
            this, &SerchatAPI::handleApplicationStateChanged);

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
        m_emojiCache->setBaseUrl(baseUrl);
        m_userProfileCache->setBaseUrl(baseUrl);
        emit apiBaseUrlChanged();
        qDebug() << "[SerchatAPI] API base URL changed to:" << baseUrl;
    }
}

QString SerchatAPI::lastServerId() const {
    return m_settings->value("lastServerId", "").toString();
}

void SerchatAPI::setLastServerId(const QString& id) {
    if (lastServerId() != id) {
        m_settings->setValue("lastServerId", id);
        emit lastServerIdChanged();
    }
}

QString SerchatAPI::lastChannelId() const {
    return m_settings->value("lastChannelId", "").toString();
}

void SerchatAPI::setLastChannelId(const QString& id) {
    if (lastChannelId() != id) {
        m_settings->setValue("lastChannelId", id);
        emit lastChannelIdChanged();
    }
}

QString SerchatAPI::lastDMRecipientId() const {
    return m_settings->value("lastDMRecipientId", "").toString();
}

void SerchatAPI::setLastDMRecipientId(const QString& id) {
    if (lastDMRecipientId() != id) {
        m_settings->setValue("lastDMRecipientId", id);
        emit lastDMRecipientIdChanged();
    }
}

// Current user ID (for filtering own messages from unread counts)
QString SerchatAPI::currentUserId() const {
    return m_currentUserId;
}

void SerchatAPI::setCurrentUserId(const QString& id) {
    if (m_currentUserId != id) {
        m_currentUserId = id;
        emit currentUserIdChanged();
    }
}

// Currently viewing channel/DM (for auto-marking messages as read)
QString SerchatAPI::viewingServerId() const {
    return m_viewingServerId;
}

void SerchatAPI::setViewingServerId(const QString& id) {
    if (m_viewingServerId != id) {
        m_viewingServerId = id;
        emit viewingServerIdChanged();
    }
}

QString SerchatAPI::viewingChannelId() const {
    return m_viewingChannelId;
}

void SerchatAPI::setViewingChannelId(const QString& id) {
    if (m_viewingChannelId != id) {
        m_viewingChannelId = id;
        emit viewingChannelIdChanged();
    }
}

QString SerchatAPI::viewingDMRecipientId() const {
    return m_viewingDMRecipientId;
}

void SerchatAPI::setViewingDMRecipientId(const QString& id) {
    if (m_viewingDMRecipientId != id) {
        m_viewingDMRecipientId = id;
        emit viewingDMRecipientIdChanged();
    }
}

void SerchatAPI::setActiveChannel(const QString& serverId, const QString& channelId) {
    m_messageCache->setActiveChannel(serverId, channelId);
    qDebug() << "[SerchatAPI] Active channel set to:" << serverId << "/" << channelId;
}

void SerchatAPI::setCurrentServer(const QString& serverId) {
    if (serverId.isEmpty()) {
        qWarning() << "[SerchatAPI] setCurrentServer called with empty serverId";
        return;
    }

    qDebug() << "[SerchatAPI] Setting current server and preloading data for:" << serverId;

    // Clear any previous server's UI-specific data
    m_channelListModel->clear();
    m_membersModel->clear();
    m_rolesModel->clear();
    m_messageModel->clear();

    // Preload all data needed for the server UI in parallel:
    // Each cache handles its own TTL, deduplication, and stale-while-revalidate

    // 1. Channels - via ChannelCache (triggers fetch if stale/missing)
    m_channelCache->refreshChannels(serverId);

    // 2. Categories - via ChannelCache (triggers fetch if stale/missing, returns stale data immediately)
    //    The getCategories call triggers an async fetch and the result is handled by onCategoriesFetched
    m_channelCache->getCategories(serverId);

    // 3. Members - via ServerMemberCache (for member list, username colors)
    m_serverMemberCache->fetchServerMembers(serverId);

    // 4. Roles - via ServerMemberCache (for role colors, permissions)
    //    Always fetch to ensure we have latest roles for color display
    m_serverMemberCache->fetchServerRoles(serverId);

    // 5. Emojis - via API with cache (for custom emoji rendering in messages)
    //    EmojiCache is populated via the signal handler when emojis are fetched
    m_apiClient->getServerEmojis(serverId, true);

    qDebug() << "[SerchatAPI] Initiated preload for server:" << serverId;
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

int SerchatAPI::updateDisplayName(const QString& displayName) {
    return m_apiClient->updateDisplayName(displayName);
}

int SerchatAPI::updatePronouns(const QString& pronouns) {
    return m_apiClient->updatePronouns(pronouns);
}

int SerchatAPI::updateBio(const QString& bio) {
    return m_apiClient->updateBio(bio);
}

int SerchatAPI::uploadProfilePicture(const QString& filePath) {
    return m_apiClient->uploadProfilePicture(filePath);
}

int SerchatAPI::uploadBanner(const QString& filePath) {
    return m_apiClient->uploadBanner(filePath);
}

int SerchatAPI::changeUsername(const QString& newUsername) {
    return m_apiClient->changeUsername(newUsername);
}

void SerchatAPI::changeLogin(const QString& newLogin, const QString& password) {
    m_authClient->changeLogin(newLogin, password);
}

void SerchatAPI::changePassword(const QString& currentPassword, const QString& newPassword) {
    m_authClient->changePassword(currentPassword, newPassword);
}

// ============================================================================
// API Methods - File Upload
// ============================================================================

int SerchatAPI::uploadFile(const QString& filePath) {
    return m_apiClient->uploadFile(filePath);
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

int SerchatAPI::sendFriendRequest(const QString& username) {
    return m_apiClient->sendFriendRequest(username);
}

int SerchatAPI::removeFriend(const QString& friendId) {
    return m_apiClient->removeFriend(friendId);
}

// ============================================================================
// API Methods - System
// ============================================================================

int SerchatAPI::getSystemInfo() {
    return m_apiClient->getSystemInfo();
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

int SerchatAPI::getCategories(const QString& serverId, bool useCache) {
    return m_apiClient->getCategories(serverId, useCache);
}

// ============================================================================
// API Methods - Server Members
// ============================================================================

int SerchatAPI::getServerMembers(const QString& serverId, bool useCache) {
    return m_apiClient->getServerMembers(serverId, useCache);
}

// ============================================================================
// API Methods - Server Emojis
// ============================================================================

int SerchatAPI::getServerEmojis(const QString& serverId, bool useCache) {
    return m_apiClient->getServerEmojis(serverId, useCache);
}

int SerchatAPI::getAllEmojis(bool useCache) {
    return m_apiClient->getAllEmojis(useCache);
}

int SerchatAPI::getEmojiById(const QString& emojiId, bool useCache) {
    return m_apiClient->getEmojiById(emojiId, useCache);
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
// API Methods - Direct Messages
// ============================================================================

int SerchatAPI::getDMMessages(const QString& userId, int limit, const QString& before) {
    return m_apiClient->getDMMessages(userId, limit, before);
}

int SerchatAPI::sendDMMessage(const QString& userId, const QString& text, const QString& replyToId) {
    return m_apiClient->sendDMMessage(userId, text, replyToId);
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

    // Disconnect from real-time updates first
    disconnectSocket();

    // Clear all cached data to prevent account data leakage
    m_emojiCache->clear();
    m_userProfileCache->clear();
    m_serverMemberCache->clear();
    m_channelCache->clear();
    m_messageCache->clear();

    // Clear API client cache to prevent stale data from previous account
    m_apiClient->clearCache();

    // Clear all models
    m_messageModel->clear();
    m_serversModel->clear();
    m_channelsModel->clear();
    m_membersModel->clear();
    m_friendsModel->clear();
    m_rolesModel->clear();
    m_channelListModel->clear();

    // Clear presence and typing state
    m_onlineUsers.clear();

    // Delete all typing timers to prevent memory leak
    for (auto& channelTypers : m_typingUsers) {
        for (QTimer* timer : channelTypers) {
            timer->stop();
            timer->deleteLater();
        }
    }
    m_typingUsers.clear();

    // Clear unread state
    m_unreadState.clear();
    m_channelLastReadAt.clear();
    m_firstUnreadMessageId.clear();
    m_unreadStateVersion = 0;

    // Clear navigation state from settings
    m_settings->remove("lastServerId");
    m_settings->remove("lastChannelId");
    m_settings->remove("lastDMRecipientId");

    // Clear auth state from settings
    m_settings->setValue("loggedIn", false);
    m_settings->remove("username");
    m_settings->remove("authToken");
    m_settings->sync();

    // Clear runtime auth state
    m_authClient->clearAuthToken();

    // Reset current user and viewing state
    setCurrentUserId("");
    setViewingServerId("");
    setViewingChannelId("");
    setViewingDMRecipientId("");

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

void SerchatAPI::onAuthChangeLoginSuccessful(const QVariantMap& response) {
    qDebug() << "[SerchatAPI] Change login successful";
    // Update token if server provided a new one
    if (response.contains("token")) {
        m_settings->setValue("authToken", response["token"].toString());
    }
    emit changeLoginSuccessful();
}

void SerchatAPI::onAuthChangeLoginFailed(const QString& error) {
    qDebug() << "[SerchatAPI] Change login failed:" << error;
    emit changeLoginFailed(error);
}

void SerchatAPI::onAuthChangePasswordSuccessful(const QVariantMap& response) {
    qDebug() << "[SerchatAPI] Change password successful";
    // Update token if server provided a new one
    if (response.contains("token")) {
        m_settings->setValue("authToken", response["token"].toString());
    }
    emit changePasswordSuccessful();
}

void SerchatAPI::onAuthChangePasswordFailed(const QString& error) {
    qDebug() << "[SerchatAPI] Change password failed:" << error;
    emit changePasswordFailed(error);
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

// ============================================================================
// Server Roles API
// ============================================================================

int SerchatAPI::getServerRoles(const QString& serverId, bool useCache) {
    return m_apiClient->getServerRoles(serverId, useCache);
}

// ============================================================================
// Presence Tracking
// ============================================================================

bool SerchatAPI::isUserOnline(const QString& username) const {
    return m_onlineUsers.contains(username);
}

QStringList SerchatAPI::getOnlineUsers() const {
    return m_onlineUsers.values();
}

void SerchatAPI::handlePresenceState(const QVariantMap& presence) {
    // presence_state event provides initial list of online users
    // Format: { "online": ["username1", "username2", ...] }
    m_onlineUsers.clear();
    
    QVariantList users = presence.value("online").toList();
    for (const QVariant& user : users) {
        m_onlineUsers.insert(user.toString());
    }
    
    qDebug() << "[SerchatAPI] Presence state received:" << m_onlineUsers.size() << "users online";
    emit onlineUsersChanged();
}

void SerchatAPI::handleUserOnline(const QString& username) {
    if (!m_onlineUsers.contains(username)) {
        m_onlineUsers.insert(username);
        qDebug() << "[SerchatAPI] User came online:" << username;
        emit onlineUsersChanged();
    }
}

void SerchatAPI::handleUserOffline(const QString& username) {
    if (m_onlineUsers.remove(username)) {
        qDebug() << "[SerchatAPI] User went offline:" << username;
        emit onlineUsersChanged();
    }
}

// ============================================================================
// Model Population Handlers
// ============================================================================

void SerchatAPI::handleServersFetched(int requestId, const QVariantList& servers) {
    // Preload channel cache for all servers at startup
    // This ensures the channel list is available quickly when switching servers
    for (const QVariant& serverVar : servers) {
        QVariantMap server = serverVar.toMap();
        QString serverId = server.value("_id").toString();
        if (serverId.isEmpty()) {
            serverId = server.value("id").toString();
        }
        
        if (!serverId.isEmpty()) {
            // Trigger channel fetch for this server (will populate cache)
            m_channelCache->refreshChannels(serverId);
        }
    }
    
    qDebug() << "[SerchatAPI] Preloading channels for" << servers.size() << "servers";
    
    // Forward signal to QML
    emit serversFetched(requestId, servers);
}

void SerchatAPI::handleServerMembersFetched(int requestId, const QString& serverId, const QVariantList& members) {
    // Populate the members model with the fetched data
    m_membersModel->setItems(members);
    qDebug() << "[SerchatAPI] Members model populated with" << members.size() << "members for server:" << serverId;
    
    // Also populate user profile cache with member data
    // This helps resolve user mentions and avatars without per-user API calls
    m_userProfileCache->updateProfiles(members);
    
    // Update the server member cache with member data (includes roles)
    m_serverMemberCache->updateServerMembers(serverId, members);
    
    // Forward the signal to QML for any additional handling
    emit serverMembersFetched(requestId, serverId, members);
}

void SerchatAPI::handleServerRolesFetched(int requestId, const QString& serverId, const QVariantList& roles) {
    // Populate the roles model with the fetched data
    m_rolesModel->setItems(roles);
    qDebug() << "[SerchatAPI] Roles model populated with" << roles.size() << "roles for server:" << serverId;

    // Update the server member cache with role data
    m_serverMemberCache->updateServerRoles(serverId, roles);

    // Forward the signal to QML for any additional handling
    emit serverRolesFetched(requestId, serverId, roles);
}

void SerchatAPI::handleChannelsFetched(int requestId, const QString& serverId, const QVariantList& channels) {
    // Extract lastReadAt from each channel and store it
    for (const QVariant& chanVar : channels) {
        QVariantMap channel = chanVar.toMap();
        QString channelId = channel.value("_id").toString();
        if (channelId.isEmpty()) {
            channelId = channel.value("id").toString();
        }
        QString lastReadAt = channel.value("lastReadAt").toString();
        QString lastMessageAt = channel.value("lastMessageAt").toString();

        if (!channelId.isEmpty()) {
            // Store the lastReadAt timestamp for this channel
            setChannelLastReadAt(serverId, channelId, lastReadAt);

            // Determine if channel has unread messages
            QString key = serverId + ":" + channelId;
            bool hasUnread = false;
            if (!lastMessageAt.isEmpty()) {
                if (lastReadAt.isEmpty()) {
                    // Never read - has unread if there are any messages
                    hasUnread = true;
                } else {
                    QDateTime lastRead = QDateTime::fromString(lastReadAt, Qt::ISODate);
                    QDateTime lastMsg = QDateTime::fromString(lastMessageAt, Qt::ISODate);
                    hasUnread = lastMsg.isValid() && lastRead.isValid() && lastMsg > lastRead;
                }
            }

            bool previousState = m_unreadState.value(key, false);
            if (previousState != hasUnread) {
                m_unreadState[key] = hasUnread;
                m_unreadStateVersion++;
            }
        }
    }

    emit unreadStateVersionChanged();
    qDebug() << "[SerchatAPI] Extracted lastReadAt for" << channels.size() << "channels in server:" << serverId;

    // Update channel cache
    m_channelCache->loadChannels(serverId, channels);

    // Forward the signal to QML
    emit channelsFetched(requestId, serverId, channels);
}

void SerchatAPI::handleMessagesFetched(int requestId, const QString& serverId, const QString& channelId, const QVariantList& messages) {
    // API returns messages oldest-first, but UI needs newest-first (for BottomToTop ListView)
    // Reverse here to centralize this logic and avoid doing it in QML
    QVariantList reversedMessages;
    reversedMessages.reserve(messages.size());
    for (int i = messages.size() - 1; i >= 0; --i) {
        reversedMessages.append(messages.at(i));
    }

    // Calculate the first unread message based on timestamps
    // Note: This function handles messages in any order (compares all timestamps)
    calculateFirstUnreadMessage(serverId, channelId, reversedMessages);

    // Update message cache with reversed messages (newest-first order)
    m_messageCache->loadMessages(serverId, channelId, reversedMessages);

    // Forward reversed messages to QML (ready for display without further processing)
    emit messagesFetched(requestId, serverId, channelId, reversedMessages);
}

void SerchatAPI::handleDMMessagesFetched(int requestId, const QString& recipientId, const QVariantList& messages) {
    // API returns messages oldest-first, but UI needs newest-first (for BottomToTop ListView)
    // Reverse here to centralize this logic and avoid doing it in QML
    QVariantList reversedMessages;
    reversedMessages.reserve(messages.size());
    for (int i = messages.size() - 1; i >= 0; --i) {
        reversedMessages.append(messages.at(i));
    }

    // Forward reversed messages to QML (ready for display without further processing)
    emit dmMessagesFetched(requestId, recipientId, reversedMessages);
}

// ============================================================================
// Typing Indicator Tracking
// ============================================================================

QStringList SerchatAPI::getTypingUsers(const QString& serverId, const QString& channelId) const {
    Q_UNUSED(serverId);  // serverId not used since backend doesn't send it in typing events
    QString key = channelId;  // Just use channelId as key
    if (m_typingUsers.contains(key)) {
        return m_typingUsers[key].keys();
    }
    return QStringList();
}

QStringList SerchatAPI::getDMTypingUsers(const QString& recipientId) const {
    QString key = "dm:" + recipientId;
    if (m_typingUsers.contains(key)) {
        return m_typingUsers[key].keys();
    }
    return QStringList();
}

bool SerchatAPI::hasTypingUsers(const QString& serverId, const QString& channelId) const {
    Q_UNUSED(serverId);  // serverId not used since backend doesn't send it in typing events
    QString key = channelId;  // Just use channelId as key
    return m_typingUsers.contains(key) && !m_typingUsers[key].isEmpty();
}

bool SerchatAPI::hasDMTypingUsers(const QString& recipientId) const {
    QString key = "dm:" + recipientId;
    return m_typingUsers.contains(key) && !m_typingUsers[key].isEmpty();
}

void SerchatAPI::handleUserTyping(const QString& serverId, const QString& channelId, const QString& username) {
    // Note: serverId may be empty as backend only sends channelId
    // Use just channelId as the key since channels are globally unique
    QString key = channelId;  // Just use channelId as key
    
    // Check if user already has a typing timer
    if (m_typingUsers.contains(key) && m_typingUsers[key].contains(username)) {
        // Reset the existing timer
        m_typingUsers[key][username]->start(TYPING_TIMEOUT_MS);
    } else {
        // Create new timer for this user
        QTimer* timer = new QTimer(this);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, this, [this, key, username]() {
            removeTypingUser(key, username);
        });
        timer->start(TYPING_TIMEOUT_MS);
        
        m_typingUsers[key][username] = timer;
        
        // Emit signal for UI update (pass channelId as both for compatibility)
        emit typingUsersChanged(channelId, channelId);
    }
    
    // Also emit the raw event for any handlers that want it
    emit userTyping(serverId, channelId, username);
}

void SerchatAPI::handleDMTyping(const QString& username) {
    // For DMs, we use the username as both the key identifier and the typing user
    // The socket event gives us the username of who is typing
    QString key = "dm:" + username;
    
    // Check if user already has a typing timer
    if (m_typingUsers.contains(key) && m_typingUsers[key].contains(username)) {
        // Reset the existing timer
        m_typingUsers[key][username]->start(TYPING_TIMEOUT_MS);
    } else {
        // Create new timer for this user
        QTimer* timer = new QTimer(this);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, this, [this, key, username]() {
            removeTypingUser(key, username);
        });
        timer->start(TYPING_TIMEOUT_MS);
        
        m_typingUsers[key][username] = timer;
        
        // Emit signal for UI update
        emit dmTypingUsersChanged(username);
    }
    
    // Also emit the raw event for any handlers that want it
    emit dmTyping(username);
}

void SerchatAPI::removeTypingUser(const QString& key, const QString& username) {
    if (!m_typingUsers.contains(key)) return;
    
    // Delete and remove the timer
    if (m_typingUsers[key].contains(username)) {
        QTimer* timer = m_typingUsers[key].take(username);
        timer->deleteLater();
    }
    
    // Clean up empty maps
    if (m_typingUsers[key].isEmpty()) {
        m_typingUsers.remove(key);
    }
    
    // Emit appropriate signal based on key type
    if (key.startsWith("dm:")) {
        QString recipientId = key.mid(3);  // Remove "dm:" prefix
        emit dmTypingUsersChanged(recipientId);
    } else {
        // Key is just the channelId for server channels
        emit typingUsersChanged(key, key);  // Pass channelId as both params for compatibility
    }
}

// ============================================================================
// Unread State Tracking
// ============================================================================
//
// This section handles tracking which channels/DMs have unread messages.
// The system uses server-provided timestamps to determine unread status.
//
// Key functions:
// - markChannelAsRead(): Called when entering a channel, updates lastReadAt
// - handleChannelsFetched(): Extracts lastReadAt from API response
// - calculateFirstUnreadMessage(): Finds first message after lastReadAt
// - handleChannelUnread(): Handles real-time unread notifications from server
//
// See serchatapi.h for the full architecture documentation.
// ============================================================================

bool SerchatAPI::hasUnreadMessages(const QString& serverId, const QString& channelId) const {
    QString key = serverId + ":" + channelId;
    return m_unreadState.value(key, false);
}

bool SerchatAPI::hasDMUnreadMessages(const QString& recipientId) const {
    QString key = "dm:" + recipientId;
    return m_unreadState.value(key, false);
}

bool SerchatAPI::hasServerUnread(const QString& serverId) const {
    // Check if any channel in this server has unread messages
    QString prefix = serverId + ":";
    for (auto it = m_unreadState.constBegin(); it != m_unreadState.constEnd(); ++it) {
        if (it.key().startsWith(prefix) && it.value()) {
            return true;
        }
    }
    return false;
}

QString SerchatAPI::getFirstUnreadMessageId(const QString& serverId, const QString& channelId) const {
    QString key = serverId + ":" + channelId;
    return m_firstUnreadMessageId.value(key, QString());
}

void SerchatAPI::clearFirstUnreadMessageId(const QString& serverId, const QString& channelId) {
    QString key = serverId + ":" + channelId;
    if (m_firstUnreadMessageId.contains(key)) {
        m_firstUnreadMessageId.remove(key);
        emit firstUnreadMessageIdChanged(serverId, channelId, QString());
        qDebug() << "[SerchatAPI] Cleared first unread message ID for channel" << channelId;
    }
}

void SerchatAPI::markChannelAsRead(const QString& serverId, const QString& channelId) {
    QString key = serverId + ":" + channelId;
    bool hadUnread = m_unreadState.value(key, false);

    // Update local lastReadAt to current time - this is the key fix!
    // When we mark as read, we're saying "I've read everything up to now"
    QString currentTime = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    m_channelLastReadAt[key] = currentTime;
    qDebug() << "[SerchatAPI] Updated lastReadAt for channel" << channelId << "to" << currentTime;

    // Clear the first unread message ID since we've now read everything
    if (m_firstUnreadMessageId.contains(key)) {
        m_firstUnreadMessageId.remove(key);
        emit firstUnreadMessageIdChanged(serverId, channelId, QString());
    }

    if (hadUnread) {
        m_unreadState[key] = false;
        m_unreadStateVersion++;
        emit unreadStateVersionChanged();
        emit channelUnreadStateChanged(serverId, channelId, false);

        // Check if server still has any unread channels
        if (!hasServerUnread(serverId)) {
            emit serverUnreadStateChanged(serverId, false);
        }
    }

    // Notify the server via socket that we've read the channel
    m_socketClient->markChannelRead(serverId, channelId);
    qDebug() << "[SerchatAPI] Marked channel as read:" << channelId;
}

void SerchatAPI::clearDMUnread(const QString& recipientId) {
    QString key = "dm:" + recipientId;
    bool hadUnread = m_unreadState.value(key, false);

    if (hadUnread) {
        m_unreadState[key] = false;
        m_unreadStateVersion++;
        emit unreadStateVersionChanged();
        emit dmUnreadStateChanged(recipientId, false);
    }

    // Notify the server via socket
    m_socketClient->markDMRead(recipientId);
}

void SerchatAPI::setChannelLastReadAt(const QString& serverId, const QString& channelId, const QString& lastReadAt) {
    QString key = serverId + ":" + channelId;
    m_channelLastReadAt[key] = lastReadAt;
}

QString SerchatAPI::getChannelLastReadAt(const QString& serverId, const QString& channelId) const {
    QString key = serverId + ":" + channelId;
    return m_channelLastReadAt.value(key, QString());
}

void SerchatAPI::calculateFirstUnreadMessage(const QString& serverId, const QString& channelId, const QVariantList& messages) {
    QString key = serverId + ":" + channelId;
    QString lastReadAt = m_channelLastReadAt.value(key);

    qDebug() << "[SerchatAPI] Calculating first unread for channel" << channelId
             << "lastReadAt:" << lastReadAt << "messages count:" << messages.size();

    // If no lastReadAt, all messages are considered read (new user or first visit)
    if (lastReadAt.isEmpty()) {
        if (m_firstUnreadMessageId.contains(key)) {
            m_firstUnreadMessageId.remove(key);
            emit firstUnreadMessageIdChanged(serverId, channelId, QString());
        }
        return;
    }

    QDateTime lastReadTime = QDateTime::fromString(lastReadAt, Qt::ISODate);
    if (!lastReadTime.isValid()) {
        qDebug() << "[SerchatAPI] Invalid lastReadAt timestamp:" << lastReadAt;
        return;
    }

    // Messages come in newest-first order (from the API response reversed)
    // We need to find the OLDEST message that is newer than lastReadAt
    // That's the first unread message
    QString firstUnreadId;
    QDateTime firstUnreadTime;

    for (const QVariant& msgVar : messages) {
        QVariantMap msg = msgVar.toMap();
        QString msgId = msg.value("_id").toString();
        if (msgId.isEmpty()) {
            msgId = msg.value("id").toString();
        }
        QString createdAtStr = msg.value("createdAt").toString();
        QDateTime createdAt = QDateTime::fromString(createdAtStr, Qt::ISODate);

        if (!createdAt.isValid()) continue;

        // Skip messages that were sent before or at lastReadAt
        if (createdAt <= lastReadTime) continue;

        // This message is unread - check if it's older than our current first unread
        if (firstUnreadId.isEmpty() || createdAt < firstUnreadTime) {
            firstUnreadId = msgId;
            firstUnreadTime = createdAt;
        }
    }

    // Update the first unread message ID
    QString previousId = m_firstUnreadMessageId.value(key);
    if (previousId != firstUnreadId) {
        if (firstUnreadId.isEmpty()) {
            m_firstUnreadMessageId.remove(key);
        } else {
            m_firstUnreadMessageId[key] = firstUnreadId;
        }
        emit firstUnreadMessageIdChanged(serverId, channelId, firstUnreadId);
        qDebug() << "[SerchatAPI] First unread message ID for channel" << channelId << ":" << firstUnreadId;
    }
}

void SerchatAPI::handleChannelUnread(const QString& serverId, const QString& channelId,
                                      const QString& lastMessageAt, const QString& senderId) {
    // Ignore messages sent by the current user
    if (!m_currentUserId.isEmpty() && senderId == m_currentUserId) {
        qDebug() << "[SerchatAPI] Ignoring unread notification for own message in channel" << channelId;
        return;
    }
    
    // Ignore messages in the currently viewed channel (user is already reading them)
    if (!m_viewingChannelId.isEmpty() && channelId == m_viewingChannelId) {
        qDebug() << "[SerchatAPI] Ignoring unread notification for currently viewed channel" << channelId;
        // Still mark as read on server to keep sync
        m_socketClient->markChannelRead(serverId, channelId);
        return;
    }
    
    QString key = serverId + ":" + channelId;
    bool wasUnread = m_unreadState.value(key, false);
    
    // Set as unread
    m_unreadState[key] = true;
    
    // Emit state change if this is a new unread
    if (!wasUnread) {
        m_unreadStateVersion++;
        emit unreadStateVersionChanged();
        emit channelUnreadStateChanged(serverId, channelId, true);
        emit serverUnreadStateChanged(serverId, true);
    }
    
    // Forward the raw signal for any other handlers (for count tracking in QML)
    emit channelUnread(serverId, channelId, lastMessageAt, senderId);
}

void SerchatAPI::handleDMUnread(const QString& peer, int count) {
    // Ignore unread notifications for the currently viewed DM conversation
    if (!m_viewingDMRecipientId.isEmpty() && peer == m_viewingDMRecipientId) {
        qDebug() << "[SerchatAPI] Ignoring unread notification for currently viewed DM with" << peer;
        // Still mark as read on server to keep sync
        m_socketClient->markDMRead(peer);
        return;
    }
    
    QString key = "dm:" + peer;
    bool wasUnread = m_unreadState.value(key, false);
    bool isNowUnread = count > 0;
    
    m_unreadState[key] = isNowUnread;
    
    // Emit state change
    if (wasUnread != isNowUnread) {
        m_unreadStateVersion++;
        emit unreadStateVersionChanged();
        emit dmUnreadStateChanged(peer, isNowUnread);
    }
    
    // Forward the raw signal for any other handlers
    emit dmUnread(peer, count);
}

// ============================================================================
// Socket Connection Handlers (for cache refresh)
// ============================================================================

void SerchatAPI::handleSocketConnected() {
    qDebug() << "[SerchatAPI] Socket connected - marking caches as stale for refresh";
    
    // Mark all caches as stale so they'll refresh on next access
    m_emojiCache->markAllStale();
    m_userProfileCache->markAllStale();
    m_channelCache->markAllStale();
    m_messageCache->markAllStale();
    
    // Refresh the active channel immediately for fluid UX
    m_messageCache->refreshActiveChannel();
    
    // Forward signal to QML
    emit socketConnected();
}

void SerchatAPI::handleSocketDisconnected() {
    qDebug() << "[SerchatAPI] Socket disconnected";

    // Clear presence tracking since we'll get fresh state on reconnect
    m_onlineUsers.clear();

    // Clear typing indicators since they're no longer valid
    for (auto& channelTypers : m_typingUsers) {
        for (QTimer* timer : channelTypers) {
            timer->stop();
            timer->deleteLater();
        }
    }
    m_typingUsers.clear();

    // Forward signal to QML
    emit socketDisconnected();
}

// ============================================================================
// App Lifecycle Handling (for Ubuntu Touch suspension)
// ============================================================================

void SerchatAPI::handleApplicationStateChanged(Qt::ApplicationState state) {
    if (state == Qt::ApplicationActive) {
        // App resumed - check if socket needs reconnection
        // Cache refresh is handled by handleSocketConnected() when socket reconnects
        if (isLoggedIn() && hasValidAuthToken() && !isSocketConnected()) {
            qDebug() << "[SerchatAPI] App activated - socket disconnected, reconnecting...";
            m_socketClient->resetReconnectAttempts();
            connectSocket();
        }
    }
}

// ============================================================================
// Socket Event Handlers for Cache Updates
// ============================================================================

void SerchatAPI::handleServerMessageReceived(const QVariantMap& message) {
    // Extract channel ID and add to message cache
    QString channelId = message.value("channelId").toString();
    if (channelId.isEmpty()) {
        channelId = message.value("channel").toMap().value("_id").toString();
    }
    
    if (!channelId.isEmpty()) {
        m_messageCache->addMessage(channelId, message);
    }
    
    // Forward signal to QML
    emit serverMessageReceived(message);
}

void SerchatAPI::handleServerMessageEdited(const QVariantMap& message) {
    QString channelId = message.value("channelId").toString();
    if (channelId.isEmpty()) {
        channelId = message.value("channel").toMap().value("_id").toString();
    }
    
    if (!channelId.isEmpty()) {
        m_messageCache->updateMessage(channelId, message);
    }
    
    emit serverMessageEdited(message);
}

void SerchatAPI::handleServerMessageDeleted(const QString& messageId, const QString& channelId) {
    if (!channelId.isEmpty() && !messageId.isEmpty()) {
        m_messageCache->removeMessage(channelId, messageId);
    }
    
    emit serverMessageDeleted(messageId, channelId);
}

void SerchatAPI::handleChannelUpdated(const QString& serverId, const QVariantMap& channel) {
    if (!serverId.isEmpty()) {
        m_channelCache->updateChannel(serverId, channel);
    }
    
    emit channelUpdated(serverId, channel);
}

void SerchatAPI::handleChannelCreated(const QString& serverId, const QVariantMap& channel) {
    if (!serverId.isEmpty()) {
        m_channelCache->addChannel(serverId, channel);
    }
    
    emit channelCreated(serverId, channel);
}

void SerchatAPI::handleChannelDeleted(const QString& serverId, const QString& channelId) {
    if (!serverId.isEmpty() && !channelId.isEmpty()) {
        m_channelCache->removeChannel(serverId, channelId);
        m_messageCache->clearChannel(channelId);
    }
    
    emit channelDeleted(serverId, channelId);
}

void SerchatAPI::handleCategoryCreated(const QString& serverId, const QVariantMap& category) {
    if (!serverId.isEmpty()) {
        m_channelCache->addCategory(serverId, category);
    }
    
    emit categoryCreated(serverId, category);
}

void SerchatAPI::handleCategoryUpdated(const QString& serverId, const QVariantMap& category) {
    if (!serverId.isEmpty()) {
        m_channelCache->updateCategory(serverId, category);
    }
    
    emit categoryUpdated(serverId, category);
}

void SerchatAPI::handleCategoryDeleted(const QString& serverId, const QString& categoryId) {
    if (!serverId.isEmpty() && !categoryId.isEmpty()) {
        m_channelCache->removeCategory(serverId, categoryId);
    }
    
    emit categoryDeleted(serverId, categoryId);
}

void SerchatAPI::handleFriendsFetched(int requestId, const QVariantList& friends) {
    // Populate the friends model with the fetched data
    m_friendsModel->setItems(friends);
    
    // Forward the signal to QML
    emit friendsFetched(requestId, friends);
}

void SerchatAPI::handleFriendRemovedApi(int requestId, const QVariantMap& response) {
    emit friendRemovedApi(requestId, response);
}

void SerchatAPI::handleFriendAdded(const QVariantMap& friendData) {
    // Add to friends model
    m_friendsModel->append(friendData);
    emit friendAdded(friendData);
}

void SerchatAPI::handleFriendRemoved(const QString& username, const QString& userId) {
    // Remove from friends model
    m_friendsModel->removeItem(userId);
    emit friendRemoved(username, userId);
}

// ============================================================================
// Role event handlers for server member cache
// ============================================================================

void SerchatAPI::handleRoleCreated(const QString& serverId, const QVariantMap& role) {
    qDebug() << "[SerchatAPI] Role created in server:" << serverId;
    
    // Refresh server roles to get updated list
    // The cache will be updated when the fetch completes
    if (!serverId.isEmpty()) {
        getServerRoles(serverId, false);  // Force refresh
    }
    
    emit roleCreated(serverId, role);
}

void SerchatAPI::handleRoleUpdated(const QString& serverId, const QVariantMap& role) {
    qDebug() << "[SerchatAPI] Role updated in server:" << serverId;
    
    // Refresh server roles to get updated role data
    if (!serverId.isEmpty()) {
        getServerRoles(serverId, false);  // Force refresh
    }
    
    emit roleUpdated(serverId, role);
}

void SerchatAPI::handleRoleDeleted(const QString& serverId, const QString& roleId) {
    qDebug() << "[SerchatAPI] Role deleted in server:" << serverId << "roleId:" << roleId;
    
    // Refresh server roles to get updated list
    if (!serverId.isEmpty()) {
        getServerRoles(serverId, false);  // Force refresh
    }
    
    emit roleDeleted(serverId, roleId);
}

void SerchatAPI::handleRolesReordered(const QString& serverId, const QVariantList& rolePositions) {
    qDebug() << "[SerchatAPI] Roles reordered in server:" << serverId;
    
    // Refresh server roles to get new positions
    if (!serverId.isEmpty()) {
        getServerRoles(serverId, false);  // Force refresh
    }
    
    emit rolesReordered(serverId, rolePositions);
}

// ============================================================================
// Member event handlers for server member cache
// ============================================================================

void SerchatAPI::handleMemberAdded(const QString& serverId, const QString& userId) {
    qDebug() << "[SerchatAPI] Member added to server:" << serverId << "userId:" << userId;
    
    // Refresh server members to get the new member data
    // This ensures we have the full member object with roles
    if (!serverId.isEmpty()) {
        getServerMembers(serverId, false);  // Force refresh
    }
    
    emit memberAdded(serverId, userId);
}

void SerchatAPI::handleMemberRemoved(const QString& serverId, const QString& userId) {
    qDebug() << "[SerchatAPI] Member removed from server:" << serverId << "userId:" << userId;
    
    // Remove member from cache
    if (!serverId.isEmpty() && !userId.isEmpty()) {
        m_serverMemberCache->removeMember(serverId, userId);
    }
    
    emit memberRemoved(serverId, userId);
}

void SerchatAPI::handleMemberUpdated(const QString& serverId, const QString& userId, const QVariantMap& member) {
    qDebug() << "[SerchatAPI] Member updated in server:" << serverId << "userId:" << userId;
    
    // Update member in cache (includes updated roles)
    if (!serverId.isEmpty() && !member.isEmpty()) {
        m_serverMemberCache->updateMember(serverId, member);
    }
    
    emit memberUpdated(serverId, userId, member);
}