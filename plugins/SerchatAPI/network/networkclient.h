#ifndef NETWORKCLIENT_H
#define NETWORKCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QVariantMap>
#include <QSet>

/**
 * @brief Low-level HTTP client with automatic auth header injection.
 * 
 * This class handles all HTTP communication and provides:
 * - Automatic Bearer token injection
 * - Debug logging (non-destructive)
 * - 401 detection for token expiration
 */
class NetworkClient : public QObject {
    Q_OBJECT

public:
    explicit NetworkClient(QObject* parent = nullptr);
    ~NetworkClient();

    /// Set the Bearer token for authenticated requests
    void setAuthToken(const QString& token);
    QString authToken() const { return m_authToken; }
    bool hasAuthToken() const { return !m_authToken.isEmpty(); }

    /// Enable/disable request/response debug logging
    void setDebug(bool debug) { m_debug = debug; }
    bool debug() const { return m_debug; }

    // HTTP methods - return QNetworkReply* that caller must manage
    QNetworkReply* get(const QUrl& url, const QVariantMap& headers = {});
    QNetworkReply* post(const QUrl& url, const QByteArray& data, const QVariantMap& headers = {});
    QNetworkReply* post(const QUrl& url, QHttpMultiPart* multiPart, const QVariantMap& headers = {});
    QNetworkReply* put(const QUrl& url, const QByteArray& data, const QVariantMap& headers = {});
    QNetworkReply* patch(const QUrl& url, const QByteArray& data, const QVariantMap& headers = {});
    QNetworkReply* deleteResource(const QUrl& url, const QVariantMap& headers = {});

signals:
    /// Emitted when any request receives a 401 Unauthorized response
    void authTokenExpired();

private slots:
    void onReplyFinished();

private:
    QNetworkAccessManager* m_networkManager;
    QString m_authToken;
    bool m_debug = false;
    QSet<QNetworkReply*> m_activeReplies;

    QNetworkRequest createRequest(const QUrl& url, const QVariantMap& headers = {});
    void trackReply(QNetworkReply* reply);
    void logRequest(const QString& method, const QUrl& url, const QByteArray& data = {});
};

#endif // NETWORKCLIENT_H