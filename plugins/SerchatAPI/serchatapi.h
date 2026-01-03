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
