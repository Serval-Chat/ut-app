#include "userprofilecache.h"
#include "api/apiclient.h"
#include <QDebug>

UserProfileCache::UserProfileCache(QObject *parent)
    : QObject(parent)
{
}

void UserProfileCache::setApiClient(ApiClient* apiClient)
{
    if (m_apiClient) {
        disconnect(m_apiClient, nullptr, this, nullptr);
    }
    
    m_apiClient = apiClient;
    
    if (m_apiClient) {
        connect(m_apiClient, &ApiClient::profileFetched,
                this, &UserProfileCache::onProfileFetched);
        connect(m_apiClient, &ApiClient::profileFetchFailed,
                this, &UserProfileCache::onProfileFetchFailed);
    }
}

void UserProfileCache::setBaseUrl(const QString& baseUrl)
{
    m_baseUrl = baseUrl;
}

// ============================================================================
// QML-accessible methods
// ============================================================================

QVariantMap UserProfileCache::getProfile(const QString& userId)
{
    if (userId.isEmpty()) {
        return QVariantMap();
    }
    
    if (m_profiles.contains(userId)) {
        return m_profiles.value(userId);
    }
    
    // Not in cache - trigger fetch
    fetchProfile(userId);
    return QVariantMap();
}

QString UserProfileCache::getDisplayName(const QString& userId)
{
    if (userId.isEmpty()) {
        return QString();
    }
    
    if (m_profiles.contains(userId)) {
        QVariantMap profile = m_profiles.value(userId);
        
        // Prefer displayName, then username, then truncated ID
        QString displayName = profile.value("displayName").toString();
        if (!displayName.isEmpty()) {
            return displayName;
        }
        
        QString username = profile.value("username").toString();
        if (!username.isEmpty()) {
            return username;
        }
    } else {
        // Not in cache - trigger fetch
        fetchProfile(userId);
    }
    
    // Fallback: truncated user ID
    if (userId.length() > 8) {
        return userId.left(8) + "...";
    }
    return userId;
}

QString UserProfileCache::getAvatarUrl(const QString& userId)
{
    if (userId.isEmpty()) {
        return QString();
    }
    
    if (m_profiles.contains(userId)) {
        QVariantMap profile = m_profiles.value(userId);
        QString profilePicture = profile.value("profilePicture").toString();
        if (!profilePicture.isEmpty()) {
            return m_baseUrl + profilePicture;
        }
    } else {
        // Not in cache - trigger fetch
        fetchProfile(userId);
    }
    
    return QString();
}

bool UserProfileCache::hasProfile(const QString& userId) const
{
    return m_profiles.contains(userId);
}

void UserProfileCache::fetchProfile(const QString& userId)
{
    if (userId.isEmpty()) {
        return;
    }
    
    // Already in cache
    if (m_profiles.contains(userId)) {
        return;
    }
    
    // Already fetching
    if (m_fetchingProfiles.contains(userId)) {
        return;
    }
    
    // No API client configured
    if (!m_apiClient) {
        qWarning() << "[UserProfileCache] Cannot fetch profile - no API client configured";
        return;
    }
    
    qDebug() << "[UserProfileCache] Fetching unknown profile:" << userId;
    m_fetchingProfiles.insert(userId);
    
    int requestId = m_apiClient->getProfile(userId, true);
    m_pendingFetches.insert(requestId, userId);
}

void UserProfileCache::prefetchProfiles(const QVariantList& userIds)
{
    for (const QVariant& userIdVar : userIds) {
        QString userId = userIdVar.toString();
        if (!userId.isEmpty() && !m_profiles.contains(userId)) {
            fetchProfile(userId);
        }
    }
}

// ============================================================================
// C++ methods for cache management
// ============================================================================

void UserProfileCache::updateProfile(const QString& userId, const QVariantMap& profile)
{
    if (userId.isEmpty()) {
        qWarning() << "[UserProfileCache] Cannot update profile without user ID";
        return;
    }
    
    qDebug() << "[UserProfileCache] Updating profile:" << userId;
    
    m_profiles.insert(userId, profile);
    m_fetchingProfiles.remove(userId);
    
    bumpVersion();
    emit profileLoaded(userId);
}

void UserProfileCache::updateProfiles(const QVariantList& profiles)
{
    qDebug() << "[UserProfileCache] Bulk updating" << profiles.size() << "profiles";
    
    for (const QVariant& profileVar : profiles) {
        QVariantMap profile = profileVar.toMap();
        QString userId = extractId(profile);
        
        if (userId.isEmpty()) {
            continue;
        }
        
        m_profiles.insert(userId, profile);
        m_fetchingProfiles.remove(userId);
    }
    
    bumpVersion();
}

void UserProfileCache::clear()
{
    qDebug() << "[UserProfileCache] Clearing cache";
    m_profiles.clear();
    m_fetchingProfiles.clear();
    m_pendingFetches.clear();
    bumpVersion();
}

// ============================================================================
// Private slots
// ============================================================================

void UserProfileCache::onProfileFetched(int requestId, const QVariantMap& profile)
{
    QString userId = m_pendingFetches.take(requestId);
    
    if (userId.isEmpty()) {
        // Not our request - could be from other code using the API
        // Still try to cache it if it has an ID
        userId = extractId(profile);
        if (userId.isEmpty()) {
            return;
        }
    }
    
    qDebug() << "[UserProfileCache] Received profile:" << userId;
    
    m_fetchingProfiles.remove(userId);
    m_profiles.insert(userId, profile);
    
    bumpVersion();
    emit profileLoaded(userId);
}

void UserProfileCache::onProfileFetchFailed(int requestId, const QString& error)
{
    QString userId = m_pendingFetches.take(requestId);
    
    if (userId.isEmpty()) {
        // Not our request
        return;
    }
    
    qWarning() << "[UserProfileCache] Failed to fetch profile:" << userId << "-" << error;
    
    m_fetchingProfiles.remove(userId);
    emit profileFetchFailed(userId, error);
}

// ============================================================================
// Private helpers
// ============================================================================

void UserProfileCache::bumpVersion()
{
    m_version++;
    emit versionChanged();
}

QString UserProfileCache::extractId(const QVariantMap& profile)
{
    // Try common ID field names
    if (profile.contains("_id")) {
        return profile.value("_id").toString();
    }
    if (profile.contains("id")) {
        return profile.value("id").toString();
    }
    if (profile.contains("userId")) {
        return profile.value("userId").toString();
    }
    return QString();
}
