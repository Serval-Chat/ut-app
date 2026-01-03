#ifndef AUTHCLIENT_H
#define AUTHCLIENT_H

#include <QObject>
#include <QVariantMap>
#include <QNetworkReply>
#include <QPointer>

#include "../apibase.h"

class NetworkClient;

/**
 * @brief Handles authentication operations (login, register, token management).
 * 
 * This client is responsible for:
 * - User authentication (login/logout)
 * - User registration
 * - Storing the current auth token (single source of truth)
 * 
 * Note: This class does NOT persist tokens - that's the responsibility of
 * the parent SerchatAPI class via QSettings.
 */
class AuthClient : public ApiBase {
    Q_OBJECT

public:
    explicit AuthClient(NetworkClient* networkClient, QObject* parent = nullptr);
    ~AuthClient();

    /// Authenticate user with login/email and password
    void login(const QString& login, const QString& password);
    
    /// Register a new user account
    void registerUser(const QString& login, const QString& username, 
                      const QString& password, const QString& inviteToken);

    /// Cancel any pending authentication requests
    void cancelPendingRequests();

    // Configuration
    void setBaseUrl(const QString& baseUrl) { m_baseUrl = baseUrl; }
    QString baseUrl() const { return m_baseUrl; }

    // Token management (in-memory only, not persisted)
    void setAuthToken(const QString& token);
    QString authToken() const { return m_authToken; }
    void clearAuthToken();

signals:
    /// Emitted on successful login with user data and token
    void loginSuccessful(const QVariantMap& userData);
    /// Emitted when login fails
    void loginFailed(const QString& error);
    /// Emitted on successful registration with user data and token  
    void registerSuccessful(const QVariantMap& userData);
    /// Emitted when registration fails
    void registerFailed(const QString& error);
    /// Emitted on network-level error (no response from server)
    void networkError(const QString& error);

private slots:
    void onLoginReplyFinished();
    void onRegisterReplyFinished();

private:
    NetworkClient* m_networkClient;
    QString m_baseUrl;
    QString m_authToken;
    
    // Using QPointer for safe reply tracking
    QPointer<QNetworkReply> m_loginReply;
    QPointer<QNetworkReply> m_registerReply;

    void abortReply(QPointer<QNetworkReply>& reply);
};

#endif // AUTHCLIENT_H