#include "apiclient.h"
#include <QDebug>

// ============================================================================
// Profile API
// ============================================================================

int ApiClient::getMyProfile() {
    return getProfile("me", true);
}

int ApiClient::getProfile(const QString& userId, bool useCache) {
    QString cacheKey = QStringLiteral("profile:%1").arg(userId);
    QString endpoint = (userId == "me") 
        ? "/api/v1/profile/me" 
        : QStringLiteral("/api/v1/profile/%1").arg(userId);
    
    RequestType type = (userId == "me") ? RequestType::MyProfile : RequestType::Profile;
    
    return startGetRequest(type, endpoint, cacheKey, useCache);
}
