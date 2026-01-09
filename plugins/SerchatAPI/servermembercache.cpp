#include "servermembercache.h"
#include "api/apiclient.h"
#include <QDebug>

ServerMemberCache::ServerMemberCache(QObject *parent)
    : QObject(parent)
{
}

void ServerMemberCache::setApiClient(ApiClient* apiClient)
{
    if (m_apiClient) {
        disconnect(m_apiClient, nullptr, this, nullptr);
    }
    
    m_apiClient = apiClient;
    
    if (m_apiClient) {
        connect(m_apiClient, &ApiClient::serverMembersFetched,
                this, &ServerMemberCache::onServerMembersFetched);
        connect(m_apiClient, &ApiClient::serverMembersFetchFailed,
                this, &ServerMemberCache::onServerMembersFetchFailed);
        connect(m_apiClient, &ApiClient::serverRolesFetched,
                this, &ServerMemberCache::onServerRolesFetched);
        connect(m_apiClient, &ApiClient::serverRolesFetchFailed,
                this, &ServerMemberCache::onServerRolesFetchFailed);
    }
}

// ============================================================================
// QML-accessible methods for server membership
// ============================================================================

QVariantMap ServerMemberCache::getMember(const QString& serverId, const QString& userId)
{
    if (serverId.isEmpty() || userId.isEmpty()) {
        return QVariantMap();
    }
    
    QString key = memberKey(serverId, userId);
    
    if (m_members.contains(key)) {
        return m_members.value(key);
    }
    
    // Not in cache - we can't fetch individual members, but we can fetch all members
    // The caller should ensure server members are loaded
    return QVariantMap();
}

QVariantList ServerMemberCache::getMemberRoleIds(const QString& serverId, const QString& userId)
{
    QVariantMap member = getMember(serverId, userId);
    if (member.isEmpty()) {
        return QVariantList();
    }
    
    return member.value("roles").toList();
}

QVariantList ServerMemberCache::getMemberRoleObjects(const QString& serverId, const QString& userId)
{
    QVariantList roleIds = getMemberRoleIds(serverId, userId);
    QVariantList roleObjects;
    
    if (roleIds.isEmpty()) {
        qDebug() << "[ServerMemberCache] getMemberRoleObjects: No role IDs found for" << userId << "in server" << serverId;
        qDebug() << "[ServerMemberCache] hasMember:" << hasMember(serverId, userId) << "hasServerRoles:" << hasServerRoles(serverId);
    }
    
    for (const QVariant& roleIdVar : roleIds) {
        QString roleId = roleIdVar.toString();
        QVariantMap role = getRole(serverId, roleId);
        if (!role.isEmpty()) {
            roleObjects.append(role);
        } else {
            qDebug() << "[ServerMemberCache] getMemberRoleObjects: Role not found:" << roleId << "for server" << serverId;
        }
    }
    
    // Sort by position descending (highest position = highest priority)
    std::sort(roleObjects.begin(), roleObjects.end(), [](const QVariant& a, const QVariant& b) {
        int posA = a.toMap().value("position", 0).toInt();
        int posB = b.toMap().value("position", 0).toInt();
        return posA > posB;
    });
    
    if (!roleIds.isEmpty()) {
        qDebug() << "[ServerMemberCache] getMemberRoleObjects: Found" << roleObjects.size() << "of" << roleIds.size() << "roles for user" << userId;
    }
    
    return roleObjects;
}

bool ServerMemberCache::hasMemberRole(const QString& serverId, const QString& userId, const QString& roleId)
{
    QVariantList roleIds = getMemberRoleIds(serverId, userId);
    
    for (const QVariant& id : roleIds) {
        if (id.toString() == roleId) {
            return true;
        }
    }
    
    return false;
}

bool ServerMemberCache::hasPermission(const QString& serverId, const QString& userId, const QString& permission)
{
    QVariantList roles = getMemberRoleObjects(serverId, userId);
    
    // Check roles from highest to lowest position
    for (const QVariant& roleVar : roles) {
        QVariantMap role = roleVar.toMap();
        QVariantMap permissions = role.value("permissions").toMap();
        
        // Administrator has all permissions
        if (permissions.value("administrator", false).toBool()) {
            return true;
        }
        
        // Check the specific permission
        if (permissions.contains(permission)) {
            return permissions.value(permission, false).toBool();
        }
    }
    
    return false;
}

QString ServerMemberCache::getMemberRoleColor(const QString& serverId, const QString& userId)
{
    QVariantList roles = getMemberRoleObjects(serverId, userId);
    
    // Return color from highest position role that has a color
    for (const QVariant& roleVar : roles) {
        QVariantMap role = roleVar.toMap();
        
        // Check for gradient colors first
        QVariantList colors = role.value("colors").toList();
        if (!colors.isEmpty()) {
            // Return first color for display purposes
            return colors.first().toString();
        }
        
        QString startColor = role.value("startColor").toString();
        if (!startColor.isEmpty()) {
            return startColor;
        }
        
        QString color = role.value("color").toString();
        if (!color.isEmpty() && color != "#99aab5") {  // Skip default gray
            return color;
        }
    }
    
    return QString();
}

bool ServerMemberCache::hasMember(const QString& serverId, const QString& userId) const
{
    return m_members.contains(memberKey(serverId, userId));
}

void ServerMemberCache::fetchMember(const QString& serverId, const QString& userId)
{
    // We can only fetch all server members, not individual ones
    // So this triggers a full server members fetch if needed
    if (serverId.isEmpty()) {
        return;
    }
    
    // If we have no members for this server at all, fetch them
    // Otherwise, the member might just not exist in that server
    bool hasAnyMembers = false;
    for (auto it = m_members.constBegin(); it != m_members.constEnd(); ++it) {
        if (it.key().startsWith(serverId + ":")) {
            hasAnyMembers = true;
            break;
        }
    }
    
    if (!hasAnyMembers && !m_fetchingMembers.contains(serverId)) {
        fetchServerMembers(serverId);
    }
    
    // Also ensure roles are fetched - they're needed to display role objects
    if (!hasServerRoles(serverId) && !m_fetchingServerRoles.contains(serverId)) {
        fetchServerRoles(serverId);
    }
}

void ServerMemberCache::fetchServerMembers(const QString& serverId)
{
    if (serverId.isEmpty() || !m_apiClient) {
        return;
    }
    
    if (m_fetchingMembers.contains(serverId)) {
        return;
    }
    
    qDebug() << "[ServerMemberCache] Fetching members for server:" << serverId;
    m_fetchingMembers.insert(serverId);
    
    int requestId = m_apiClient->getServerMembers(serverId, false);
    m_pendingMemberFetches.insert(requestId, serverId);
}

// ============================================================================
// QML-accessible methods for server roles
// ============================================================================

QVariantMap ServerMemberCache::getRole(const QString& serverId, const QString& roleId)
{
    if (serverId.isEmpty() || roleId.isEmpty()) {
        return QVariantMap();
    }
    
    QString key = roleKey(serverId, roleId);
    return m_roles.value(key);
}

QVariantList ServerMemberCache::getServerRoles(const QString& serverId)
{
    if (serverId.isEmpty()) {
        return QVariantList();
    }
    
    QVariantList result;
    QSet<QString> roleIds = m_serverRoles.value(serverId);
    
    for (const QString& roleId : roleIds) {
        QString key = roleKey(serverId, roleId);
        if (m_roles.contains(key)) {
            result.append(m_roles.value(key));
        }
    }
    
    // Sort by position descending
    std::sort(result.begin(), result.end(), [](const QVariant& a, const QVariant& b) {
        int posA = a.toMap().value("position", 0).toInt();
        int posB = b.toMap().value("position", 0).toInt();
        return posA > posB;
    });
    
    return result;
}

bool ServerMemberCache::hasServerRoles(const QString& serverId) const
{
    return m_serverRoles.contains(serverId) && !m_serverRoles.value(serverId).isEmpty();
}

void ServerMemberCache::fetchServerRoles(const QString& serverId)
{
    if (serverId.isEmpty() || !m_apiClient) {
        return;
    }
    
    if (m_fetchingServerRoles.contains(serverId)) {
        return;
    }
    
    qDebug() << "[ServerMemberCache] Fetching roles for server:" << serverId;
    m_fetchingServerRoles.insert(serverId);
    
    int requestId = m_apiClient->getServerRoles(serverId, false);
    m_pendingRoleFetches.insert(requestId, serverId);
}

// ============================================================================
// C++ methods for cache management
// ============================================================================

void ServerMemberCache::updateMember(const QString& serverId, const QVariantMap& member)
{
    QString userId = extractUserId(member);
    if (serverId.isEmpty() || userId.isEmpty()) {
        qWarning() << "[ServerMemberCache] Cannot update member without server/user ID";
        return;
    }
    
    QString key = memberKey(serverId, userId);
    m_members.insert(key, member);
    
    bumpVersion();
    emit memberLoaded(serverId, userId);
}

void ServerMemberCache::updateServerMembers(const QString& serverId, const QVariantList& members)
{
    if (serverId.isEmpty()) {
        return;
    }
    
    qDebug() << "[ServerMemberCache] Updating" << members.size() << "members for server:" << serverId;
    
    // Clear existing members for this server first
    QStringList keysToRemove;
    for (auto it = m_members.constBegin(); it != m_members.constEnd(); ++it) {
        if (it.key().startsWith(serverId + ":")) {
            keysToRemove.append(it.key());
        }
    }
    for (const QString& key : keysToRemove) {
        m_members.remove(key);
    }
    
    // Insert new members
    for (const QVariant& memberVar : members) {
        QVariantMap member = memberVar.toMap();
        QString userId = extractUserId(member);
        
        if (userId.isEmpty()) {
            continue;
        }
        
        QString key = memberKey(serverId, userId);
        m_members.insert(key, member);
    }
    
    m_fetchingMembers.remove(serverId);
    bumpVersion();
}

void ServerMemberCache::updateServerRoles(const QString& serverId, const QVariantList& roles)
{
    if (serverId.isEmpty()) {
        return;
    }
    
    qDebug() << "[ServerMemberCache] Updating" << roles.size() << "roles for server:" << serverId;
    
    // Clear existing roles for this server
    QSet<QString> oldRoleIds = m_serverRoles.value(serverId);
    for (const QString& roleId : oldRoleIds) {
        m_roles.remove(roleKey(serverId, roleId));
    }
    m_serverRoles.remove(serverId);
    
    // Insert new roles
    QSet<QString> newRoleIds;
    for (const QVariant& roleVar : roles) {
        QVariantMap role = roleVar.toMap();
        QString roleId = extractRoleId(role);
        
        if (roleId.isEmpty()) {
            continue;
        }
        
        QString key = roleKey(serverId, roleId);
        m_roles.insert(key, role);
        newRoleIds.insert(roleId);
    }
    
    m_serverRoles.insert(serverId, newRoleIds);
    m_fetchingServerRoles.remove(serverId);
    
    bumpVersion();
    emit serverRolesLoaded(serverId);
}

void ServerMemberCache::removeMember(const QString& serverId, const QString& userId)
{
    QString key = memberKey(serverId, userId);
    if (m_members.remove(key) > 0) {
        bumpVersion();
    }
}

void ServerMemberCache::clearServer(const QString& serverId)
{
    if (serverId.isEmpty()) {
        return;
    }
    
    // Remove all members for this server
    QStringList keysToRemove;
    for (auto it = m_members.constBegin(); it != m_members.constEnd(); ++it) {
        if (it.key().startsWith(serverId + ":")) {
            keysToRemove.append(it.key());
        }
    }
    for (const QString& key : keysToRemove) {
        m_members.remove(key);
    }
    
    // Remove all roles for this server
    QSet<QString> roleIds = m_serverRoles.take(serverId);
    for (const QString& roleId : roleIds) {
        m_roles.remove(roleKey(serverId, roleId));
    }
    
    bumpVersion();
}

void ServerMemberCache::clear()
{
    qDebug() << "[ServerMemberCache] Clearing cache";
    m_members.clear();
    m_roles.clear();
    m_serverRoles.clear();
    m_fetchingMembers.clear();
    m_fetchingServerRoles.clear();
    m_pendingMemberFetches.clear();
    m_pendingRoleFetches.clear();
    bumpVersion();
}

// ============================================================================
// Private slots
// ============================================================================

void ServerMemberCache::onServerMembersFetched(int requestId, const QString& serverId, const QVariantList& members)
{
    // Handle both our requests and external requests
    m_pendingMemberFetches.remove(requestId);
    updateServerMembers(serverId, members);
}

void ServerMemberCache::onServerMembersFetchFailed(int requestId, const QString& serverId, const QString& error)
{
    m_pendingMemberFetches.remove(requestId);
    m_fetchingMembers.remove(serverId);
    
    qWarning() << "[ServerMemberCache] Failed to fetch members for" << serverId << ":" << error;
    emit memberFetchFailed(serverId, QString(), error);
}

void ServerMemberCache::onServerRolesFetched(int requestId, const QString& serverId, const QVariantList& roles)
{
    m_pendingRoleFetches.remove(requestId);
    updateServerRoles(serverId, roles);
}

void ServerMemberCache::onServerRolesFetchFailed(int requestId, const QString& serverId, const QString& error)
{
    m_pendingRoleFetches.remove(requestId);
    m_fetchingServerRoles.remove(serverId);
    
    qWarning() << "[ServerMemberCache] Failed to fetch roles for" << serverId << ":" << error;
    emit serverRolesFetchFailed(serverId, error);
}

// ============================================================================
// Private helpers
// ============================================================================

void ServerMemberCache::bumpVersion()
{
    m_version++;
    emit versionChanged();
}

QString ServerMemberCache::memberKey(const QString& serverId, const QString& userId)
{
    return serverId + ":" + userId;
}

QString ServerMemberCache::roleKey(const QString& serverId, const QString& roleId)
{
    return serverId + ":" + roleId;
}

QString ServerMemberCache::extractUserId(const QVariantMap& member)
{
    // Backend returns member with embedded user object
    // Structure: { _id: memberId, userId: userId, user: { _id, username, ... }, roles: [...] }
    
    // Try userId field first
    QString userId = member.value("userId").toString();
    if (!userId.isEmpty()) {
        return userId;
    }
    
    // Try nested user object
    QVariantMap user = member.value("user").toMap();
    if (!user.isEmpty()) {
        if (user.contains("_id")) {
            return user.value("_id").toString();
        }
        if (user.contains("id")) {
            return user.value("id").toString();
        }
    }
    
    return QString();
}

QString ServerMemberCache::extractRoleId(const QVariantMap& role)
{
    if (role.contains("_id")) {
        return role.value("_id").toString();
    }
    if (role.contains("id")) {
        return role.value("id").toString();
    }
    return QString();
}
