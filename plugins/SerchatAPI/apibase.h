#ifndef APIBASE_H
#define APIBASE_H

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <QNetworkReply>

/**
 * @brief Represents the result of an API call.
 * 
 * Use this to standardize success/error handling across all API clients.
 */
struct ApiResult {
    bool success = false;
    int statusCode = 0;
    QVariantMap data;
    QString errorMessage;

    /// Check if this is an authentication error (401)
    bool isAuthError() const { return statusCode == 401; }
    /// Check if this is a client error (4xx)
    bool isClientError() const { return statusCode >= 400 && statusCode < 500; }
    /// Check if this is a server error (5xx)
    bool isServerError() const { return statusCode >= 500; }
};

/**
 * @brief Base class for API clients providing common utilities.
 * 
 * Provides URL building, JSON parsing, and standardized response handling.
 * Subclasses should use handleReply() for consistent error handling.
 */
class ApiBase : public QObject {
    Q_OBJECT

public:
    explicit ApiBase(QObject* parent = nullptr);
    virtual ~ApiBase() = default;

protected:
    /// Build a URL with optional query parameters
    QUrl buildUrl(const QString& baseUrl, const QString& endpoint, const QVariantMap& params = {}) const;
    
    /// Parse JSON response data into a QVariantMap
    QVariantMap parseJsonResponse(const QByteArray& data) const;
    
    /// Serialize a QVariantMap to JSON bytes
    QByteArray serializeToJson(const QVariantMap& data) const;

    /**
     * @brief Process a network reply into a standardized ApiResult.
     * 
     * Handles common error scenarios:
     * - Network errors
     * - HTTP error status codes
     * - JSON parsing
     * - Error message extraction from response body
     * 
     * @param reply The completed QNetworkReply (will NOT be deleted by this method)
     * @return ApiResult containing success status, data, or error information
     */
    ApiResult handleReply(QNetworkReply* reply) const;

    /**
     * @brief Extract error message from response or generate default.
     * 
     * Looks for common error fields: "error", "message", "detail"
     */
    QString extractErrorMessage(const QVariantMap& response, int statusCode, const QString& networkError = {}) const;
};

#endif // APIBASE_H