#include "authclient.h"
#include "../network/networkclient.h"
#include <QDebug>

AuthClient::AuthClient(NetworkClient* networkClient, QObject* parent)
    : ApiBase(parent)
    , m_networkClient(networkClient)
{
}

AuthClient::~AuthClient() {
    cancelPendingRequests();
}

void AuthClient::setAuthToken(const QString& token) {
    m_authToken = token;

    // Also update NetworkClient so authenticated requests include the token
    if (m_networkClient) {
        m_networkClient->setAuthToken(token);
    } else {
        qWarning() << "[AuthClient] Warning: NetworkClient is null, cannot set auth token";
    }
}

void AuthClient::clearAuthToken() {
    // setAuthToken already handles updating NetworkClient
    setAuthToken(QString());
}

void AuthClient::cancelPendingRequests() {
    abortReply(m_loginReply);
    abortReply(m_registerReply);
    abortReply(m_changeLoginReply);
    abortReply(m_changePasswordReply);
}

void AuthClient::abortReply(QPointer<QNetworkReply>& reply) {
    if (reply) {
        reply->abort();
        reply->deleteLater();
        reply = nullptr;
    }
}

void AuthClient::login(const QString& login, const QString& password) {
    // Input validation
    if (login.isEmpty() || password.isEmpty()) {
        emit loginFailed("Login and password cannot be empty");
        return;
    }

    if (m_baseUrl.isEmpty()) {
        emit networkError("Base URL not set");
        return;
    }

    // Cancel any existing login request
    abortReply(m_loginReply);

    QVariantMap loginData;
    loginData["login"] = login;
    loginData["password"] = password;

    QUrl url = buildUrl(m_baseUrl, "/api/v1/auth/login");
    QByteArray jsonData = serializeToJson(loginData);

    m_loginReply = m_networkClient->post(url, jsonData);
    connect(m_loginReply, &QNetworkReply::finished, this, &AuthClient::onLoginReplyFinished);
}

void AuthClient::registerUser(const QString& login, const QString& username, 
                               const QString& password, const QString& inviteToken) {
    // Input validation
    if (login.isEmpty() || username.isEmpty() || password.isEmpty()) {
        emit registerFailed("Login, username, and password cannot be empty");
        return;
    }

    if (m_baseUrl.isEmpty()) {
        emit networkError("Base URL not set");
        return;
    }

    // Cancel any existing registration request
    abortReply(m_registerReply);

    QVariantMap registerData;
    registerData["login"] = login;
    registerData["username"] = username;
    registerData["password"] = password;
    registerData["invite"] = inviteToken;

    QUrl url = buildUrl(m_baseUrl, "/api/v1/auth/register");
    QByteArray jsonData = serializeToJson(registerData);

    m_registerReply = m_networkClient->post(url, jsonData);
    connect(m_registerReply, &QNetworkReply::finished, this, &AuthClient::onRegisterReplyFinished);
}

void AuthClient::onLoginReplyFinished() {
    QNetworkReply* reply = m_loginReply;
    m_loginReply = nullptr;

    if (!reply) return;

    ApiResult result = handleReply(reply);
    reply->deleteLater();

    if (!result.success) {
        // Provide more specific error messages for login
        QString errorMsg = result.errorMessage;
        if (result.statusCode == 401) {
            errorMsg = "Invalid credentials";
        } else if (result.statusCode == 403) {
            errorMsg = "Account banned";
            // Additional ban info could be in result.data["ban"]
        }
        emit loginFailed(errorMsg);
        return;
    }

    // Validate response contains required token
    if (!result.data.contains("token")) {
        emit loginFailed("Invalid response: missing token");
        return;
    }

    setAuthToken(result.data["token"].toString());
    emit loginSuccessful(result.data);
}

void AuthClient::onRegisterReplyFinished() {
    QNetworkReply* reply = m_registerReply;
    m_registerReply = nullptr;

    if (!reply) return;

    ApiResult result = handleReply(reply);
    reply->deleteLater();

    if (!result.success) {
        // Provide more specific error messages for registration
        QString errorMsg = result.errorMessage;
        if (result.statusCode == 400) {
            errorMsg = result.data.contains("error") 
                ? result.data["error"].toString() 
                : "Invalid registration data";
        } else if (result.statusCode == 403) {
            errorMsg = "Invalid invite token";
        } else if (result.statusCode == 409) {
            errorMsg = "Username or email already taken";
        }
        emit registerFailed(errorMsg);
        return;
    }

    // Validate response contains required token
    if (!result.data.contains("token")) {
        emit registerFailed("Invalid response: missing token");
        return;
    }

    m_authToken = result.data["token"].toString();
    emit registerSuccessful(result.data);
}

void AuthClient::changeLogin(const QString& newLogin, const QString& password) {
    // Input validation
    if (newLogin.isEmpty() || password.isEmpty()) {
        emit changeLoginFailed("New login and password cannot be empty");
        return;
    }

    if (m_baseUrl.isEmpty()) {
        emit networkError("Base URL not set");
        return;
    }

    // Cancel any existing changeLogin request
    abortReply(m_changeLoginReply);

    QVariantMap requestData;
    requestData["newLogin"] = newLogin;
    requestData["password"] = password;

    QUrl url = buildUrl(m_baseUrl, "/api/v1/auth/login");
    QByteArray jsonData = serializeToJson(requestData);

    m_changeLoginReply = m_networkClient->patch(url, jsonData);
    connect(m_changeLoginReply, &QNetworkReply::finished, this, &AuthClient::onChangeLoginReplyFinished);
}

void AuthClient::changePassword(const QString& currentPassword, const QString& newPassword) {
    // Input validation
    if (currentPassword.isEmpty() || newPassword.isEmpty()) {
        emit changePasswordFailed("Current and new password cannot be empty");
        return;
    }

    if (m_baseUrl.isEmpty()) {
        emit networkError("Base URL not set");
        return;
    }

    // Cancel any existing changePassword request
    abortReply(m_changePasswordReply);

    QVariantMap requestData;
    requestData["currentPassword"] = currentPassword;
    requestData["newPassword"] = newPassword;

    QUrl url = buildUrl(m_baseUrl, "/api/v1/auth/password");
    QByteArray jsonData = serializeToJson(requestData);

    m_changePasswordReply = m_networkClient->patch(url, jsonData);
    connect(m_changePasswordReply, &QNetworkReply::finished, this, &AuthClient::onChangePasswordReplyFinished);
}

void AuthClient::onChangeLoginReplyFinished() {
    QNetworkReply* reply = m_changeLoginReply;
    m_changeLoginReply = nullptr;

    if (!reply) return;

    ApiResult result = handleReply(reply);
    reply->deleteLater();

    if (!result.success) {
        // Provide more specific error messages for change login
        QString errorMsg = result.errorMessage;
        if (result.statusCode == 400) {
            errorMsg = "Invalid login format";
        } else if (result.statusCode == 401) {
            errorMsg = "Invalid password";
        } else if (result.statusCode == 409) {
            errorMsg = "Login already taken";
        }
        emit changeLoginFailed(errorMsg);
        return;
    }

    // Update token if provided (server may issue new token)
    if (result.data.contains("token")) {
        setAuthToken(result.data["token"].toString());
    }

    emit changeLoginSuccessful(result.data);
}

void AuthClient::onChangePasswordReplyFinished() {
    QNetworkReply* reply = m_changePasswordReply;
    m_changePasswordReply = nullptr;

    if (!reply) return;

    ApiResult result = handleReply(reply);
    reply->deleteLater();

    if (!result.success) {
        // Provide more specific error messages for change password
        QString errorMsg = result.errorMessage;
        if (result.statusCode == 400) {
            errorMsg = "Invalid password format";
        } else if (result.statusCode == 401) {
            errorMsg = "Invalid current password";
        }
        emit changePasswordFailed(errorMsg);
        return;
    }

    // Update token if provided (server may issue new token)
    if (result.data.contains("token")) {
        setAuthToken(result.data["token"].toString());
    }

    emit changePasswordSuccessful(result.data);
}
