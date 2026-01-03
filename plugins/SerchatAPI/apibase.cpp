#include "apibase.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDebug>

ApiBase::ApiBase(QObject* parent) : QObject(parent) {}

QUrl ApiBase::buildUrl(const QString& baseUrl, const QString& endpoint, const QVariantMap& params) const {
    // Ensure proper URL joining (handle trailing/leading slashes)
    QString base = baseUrl;
    QString path = endpoint;
    if (base.endsWith('/') && path.startsWith('/')) {
        path = path.mid(1);
    } else if (!base.endsWith('/') && !path.startsWith('/')) {
        path = '/' + path;
    }

    QUrl url(base + path);

    if (!params.isEmpty()) {
        QUrlQuery query;
        for (auto it = params.constBegin(); it != params.constEnd(); ++it) {
            query.addQueryItem(it.key(), it.value().toString());
        }
        url.setQuery(query);
    }

    return url;
}

QVariantMap ApiBase::parseJsonResponse(const QByteArray& data) const {
    if (data.isEmpty()) {
        return QVariantMap();
    }

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError) {
        qWarning() << "[ApiBase] JSON parse error:" << error.errorString();
        return QVariantMap();
    }

    if (doc.isObject()) {
        return doc.object().toVariantMap();
    }

    // If it's an array, wrap it
    if (doc.isArray()) {
        QVariantMap wrapper;
        wrapper["items"] = doc.array().toVariantList();
        return wrapper;
    }

    return QVariantMap();
}

QByteArray ApiBase::serializeToJson(const QVariantMap& data) const {
    QJsonObject obj = QJsonObject::fromVariantMap(data);
    QJsonDocument doc(obj);
    return doc.toJson(QJsonDocument::Compact);
}

ApiResult ApiBase::handleReply(QNetworkReply* reply) const {
    ApiResult result;

    if (!reply) {
        result.errorMessage = "Invalid reply object";
        return result;
    }

    result.statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QByteArray responseData = reply->readAll();
    result.data = parseJsonResponse(responseData);

    // Check for network-level errors
    if (reply->error() != QNetworkReply::NoError) {
        result.success = false;
        result.errorMessage = extractErrorMessage(result.data, result.statusCode, reply->errorString());
        return result;
    }

    // Check for HTTP error status codes
    if (result.statusCode >= 400) {
        result.success = false;
        result.errorMessage = extractErrorMessage(result.data, result.statusCode);
        return result;
    }

    result.success = true;
    return result;
}

QString ApiBase::extractErrorMessage(const QVariantMap& response, int statusCode, const QString& networkError) const {
    // Try common error field names
    static const QStringList errorFields = {"error", "message", "detail", "error_description"};

    for (const QString& field : errorFields) {
        if (response.contains(field)) {
            QVariant value = response[field];
            if (value.type() == QVariant::String) {
                return value.toString();
            } else if (value.type() == QVariant::Map) {
                // Nested error object
                QVariantMap nested = value.toMap();
                if (nested.contains("message")) {
                    return nested["message"].toString();
                }
            }
        }
    }

    // Fall back to network error string
    if (!networkError.isEmpty()) {
        return QStringLiteral("Network error: %1").arg(networkError);
    }

    // Generate default message based on status code
    switch (statusCode) {
        case 400: return "Bad request";
        case 401: return "Authentication required";
        case 403: return "Access forbidden";
        case 404: return "Resource not found";
        case 409: return "Conflict";
        case 422: return "Validation failed";
        case 429: return "Too many requests";
        case 500: return "Internal server error";
        case 502: return "Bad gateway";
        case 503: return "Service unavailable";
        default: return QStringLiteral("Request failed (HTTP %1)").arg(statusCode);
    }
}