#include "networkclient.h"
#include <QDebug>

NetworkClient::NetworkClient(QObject* parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_debug(false)
{
}

NetworkClient::~NetworkClient() {
    // Abort and clean up any pending replies
    for (QNetworkReply* reply : m_activeReplies) {
        reply->abort();
        reply->deleteLater();
    }
    m_activeReplies.clear();
}

void NetworkClient::setAuthToken(const QString& token) {
    m_authToken = token;
    if (m_debug) {
        qDebug() << "[NetworkClient] Auth token" << (token.isEmpty() ? "cleared" : "set");
    }
}

QNetworkReply* NetworkClient::get(const QUrl& url, const QVariantMap& headers) {
    QNetworkRequest request = createRequest(url, headers);
    logRequest("GET", url);
    QNetworkReply* reply = m_networkManager->get(request);
    trackReply(reply);
    return reply;
}

QNetworkReply* NetworkClient::post(const QUrl& url, const QByteArray& data, const QVariantMap& headers) {
    QNetworkRequest request = createRequest(url, headers);
    logRequest("POST", url, data);
    QNetworkReply* reply = m_networkManager->post(request, data);
    trackReply(reply);
    return reply;
}

QNetworkReply* NetworkClient::put(const QUrl& url, const QByteArray& data, const QVariantMap& headers) {
    QNetworkRequest request = createRequest(url, headers);
    logRequest("PUT", url, data);
    QNetworkReply* reply = m_networkManager->put(request, data);
    trackReply(reply);
    return reply;
}

QNetworkReply* NetworkClient::patch(const QUrl& url, const QByteArray& data, const QVariantMap& headers) {
    QNetworkRequest request = createRequest(url, headers);
    logRequest("PATCH", url, data);
    QNetworkReply* reply = m_networkManager->sendCustomRequest(request, "PATCH", data);
    trackReply(reply);
    return reply;
}

QNetworkReply* NetworkClient::deleteResource(const QUrl& url, const QVariantMap& headers) {
    QNetworkRequest request = createRequest(url, headers);
    logRequest("DELETE", url);
    QNetworkReply* reply = m_networkManager->deleteResource(request);
    trackReply(reply);
    return reply;
}

void NetworkClient::trackReply(QNetworkReply* reply) {
    m_activeReplies.insert(reply);
    connect(reply, &QNetworkReply::finished, this, &NetworkClient::onReplyFinished);
}

void NetworkClient::onReplyFinished() {
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    m_activeReplies.remove(reply);

    int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (m_debug) {
        // Peek at data without consuming it - use peek() instead of readAll()
        QByteArray preview = reply->peek(1024);
        qDebug() << "[NetworkClient] Response:" << reply->url().toString()
                 << "Status:" << statusCode
                 << "Preview:" << preview.left(500);
    }

    // Detect 401 Unauthorized - token has expired or is invalid
    if (statusCode == 401 && hasAuthToken()) {
        qDebug() << "[NetworkClient] 401 Unauthorized detected - token may be expired";
        emit authTokenExpired();
    }
    // Note: Caller is responsible for reading data and deleting the reply
}

void NetworkClient::logRequest(const QString& method, const QUrl& url, const QByteArray& data) {
    if (m_debug) {
        if (data.isEmpty()) {
            qDebug() << "[NetworkClient] Request:" << method << url.toString();
        } else {
            // Don't log sensitive data like passwords
            QString dataStr = QString::fromUtf8(data);
            if (dataStr.contains("password", Qt::CaseInsensitive)) {
                qDebug() << "[NetworkClient] Request:" << method << url.toString() << "Data: [REDACTED]";
            } else {
                qDebug() << "[NetworkClient] Request:" << method << url.toString() << "Data:" << data.left(500);
            }
        }
    }
}

QNetworkRequest NetworkClient::createRequest(const QUrl& url, const QVariantMap& headers) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setHeader(QNetworkRequest::UserAgentHeader, "Serchat/1.0");

    // Add Authorization header if token is available
    if (!m_authToken.isEmpty()) {
        request.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(m_authToken).toUtf8());
    }

    // Add custom headers
    for (auto it = headers.constBegin(); it != headers.constEnd(); ++it) {
        request.setRawHeader(it.key().toUtf8(), it.value().toString().toUtf8());
    }

    return request;
}