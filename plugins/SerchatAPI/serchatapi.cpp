#include <QDebug>
#include <QDateTime>

#include "serchatapi.h"
#include "network/networkclient.h"
#include "auth/authclient.h"
#include "api/apiclient.h"

SerchatAPI::SerchatAPI() {
    // Initialize persistent storage
    m_settings = new QSettings("alexanderrichards", "serchat", this);

    // Initialize network and API clients
    m_networkClient = new NetworkClient(this);
    m_authClient = new AuthClient(m_networkClient, this);
    m_apiClient = new ApiClient(m_networkClient, this);

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

    // Connect network client for automatic 401 handling
    connect(m_networkClient, &NetworkClient::authTokenExpired,
            this, &SerchatAPI::onNetworkAuthTokenExpired);

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
// API Methods
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
// Cache Management
// ============================================================================

void SerchatAPI::setProfileCacheTTL(int seconds) {
    m_apiClient->setCacheTTL(seconds);
}

void SerchatAPI::clearProfileCache() {
    m_apiClient->clearCache();
}

void SerchatAPI::clearProfileCacheFor(const QString& userId) {
    m_apiClient->clearCacheFor(userId);
}

bool SerchatAPI::hasProfileCached(const QString& userId) const {
    return m_apiClient->hasCachedProfile(userId);
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
    }

    // Store token - AuthClient already has it, but we persist for app restart
    if (userData.contains("token")) {
        m_settings->setValue("authToken", userData["token"].toString());
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
    clearAuthState();
    emit authTokenInvalid();
}
