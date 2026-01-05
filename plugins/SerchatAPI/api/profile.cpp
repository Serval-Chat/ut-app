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

int ApiClient::updateDisplayName(const QString& displayName) {
    QJsonObject payload;
    payload["displayName"] = displayName;
    return startPatchRequest(RequestType::UpdateDisplayName, "/api/v1/profile/display-name", payload);
}

int ApiClient::updatePronouns(const QString& pronouns) {
    QJsonObject payload;
    payload["pronouns"] = pronouns;
    return startPatchRequest(RequestType::UpdatePronouns, "/api/v1/profile/pronouns", payload);
}

int ApiClient::updateBio(const QString& bio) {
    QJsonObject payload;
    payload["bio"] = bio;
    return startPatchRequest(RequestType::UpdateBio, "/api/v1/profile/bio", payload);
}

int ApiClient::uploadProfilePicture(const QString& filePath) {
    return startMultipartPostRequest(RequestType::UploadProfilePicture, "/api/v1/profile/picture", filePath, "profilePicture");
}

int ApiClient::uploadBanner(const QString& filePath) {
    return startMultipartPostRequest(RequestType::UploadBanner, "/api/v1/profile/banner", filePath, "banner");
}
