#ifndef SERVERMEMBERCACHE_H
#define SERVERMEMBERCACHE_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

class ApiClient;

/**
 * @brief Cache for server membership data including roles.
 * 
 * This cache stores per-server member information, including which roles
 * each user has in each server. Since roles are server-specific (a user
 * can have different roles in different servers), this cache uses a
 * composite key of serverId:userId for member lookups.
 * 
 * Features:
 * - O(1) member lookup by serverId + userId
 * - Per-server role caching
 * - Automatic fetch for unknown members
 * - Version counter for QML binding invalidation
 * - Deduplication of in-flight fetch requests
 * 
 * Usage in QML:
 *   var member = SerchatAPI.serverMemberCache.getMember(serverId, userId)
 *   var roles = SerchatAPI.serverMemberCache.getMemberRoles(serverId, userId)
 *   var roleObjects = SerchatAPI.serverMemberCache.getMemberRoleObjects(serverId, userId)
 */
class ServerMemberCache : public QObject {
    Q_OBJECT
    
    // Version counter triggers QML re-rendering when cache updates
    Q_PROPERTY(int version READ version NOTIFY versionChanged)

public:
    explicit ServerMemberCache(QObject *parent = nullptr);
    ~ServerMemberCache() override = default;
    
    /**
     * @brief Set the API client for fetching data.
     * Must be called during initialization.
     */
    void setApiClient(ApiClient* apiClient);
    
    // ========================================================================
    // QML-accessible methods for server membership
    // ========================================================================
    
    /**
     * @brief Get member data for a user in a specific server.
     * @param serverId The server ID
     * @param userId The user's unique ID
     * @return QVariantMap with member data (including roles array) or empty if not found
     * 
     * If the member is not in cache, automatically triggers a fetch.
     */
    Q_INVOKABLE QVariantMap getMember(const QString& serverId, const QString& userId);
    
    /**
     * @brief Get role IDs for a user in a specific server.
     * @param serverId The server ID
     * @param userId The user's unique ID
     * @return QVariantList of role IDs or empty if not found
     */
    Q_INVOKABLE QVariantList getMemberRoleIds(const QString& serverId, const QString& userId);
    
    /**
     * @brief Get full role objects for a user in a specific server.
     * @param serverId The server ID
     * @param userId The user's unique ID
     * @return QVariantList of role objects (with permissions, colors, etc.)
     */
    Q_INVOKABLE QVariantList getMemberRoleObjects(const QString& serverId, const QString& userId);
    
    /**
     * @brief Check if a user has a specific role in a server.
     * @param serverId The server ID
     * @param userId The user's unique ID
     * @param roleId The role ID to check
     * @return true if user has the role
     */
    Q_INVOKABLE bool hasMemberRole(const QString& serverId, const QString& userId, const QString& roleId);
    
    /**
     * @brief Check if a user has a specific permission in a server.
     * This checks all roles the user has and returns true if any grants the permission.
     * @param serverId The server ID
     * @param userId The user's unique ID
     * @param permission Permission name (e.g., "sendMessages", "manageRoles")
     * @return true if user has the permission
     */
    Q_INVOKABLE bool hasPermission(const QString& serverId, const QString& userId, const QString& permission);
    
    /**
     * @brief Get the highest role color for a user in a server.
     * Used for coloring usernames in chat.
     * @param serverId The server ID
     * @param userId The user's unique ID
     * @return Color hex string or empty if no colored role
     */
    Q_INVOKABLE QString getMemberRoleColor(const QString& serverId, const QString& userId);
    
    /**
     * @brief Check if member data is cached for a user in a server.
     * Does NOT trigger a fetch.
     */
    Q_INVOKABLE bool hasMember(const QString& serverId, const QString& userId) const;
    
    /**
     * @brief Explicitly request fetch for a member.
     */
    Q_INVOKABLE void fetchMember(const QString& serverId, const QString& userId);
    
    // ========================================================================
    // QML-accessible methods for server roles
    // ========================================================================
    
    /**
     * @brief Get a specific role by ID.
     * @param serverId The server ID
     * @param roleId The role ID
     * @return QVariantMap with role data or empty if not found
     */
    Q_INVOKABLE QVariantMap getRole(const QString& serverId, const QString& roleId);
    
    /**
     * @brief Get all roles for a server.
     * @param serverId The server ID
     * @return QVariantList of role objects sorted by position
     */
    Q_INVOKABLE QVariantList getServerRoles(const QString& serverId);
    
    /**
     * @brief Check if roles are cached for a server.
     */
    Q_INVOKABLE bool hasServerRoles(const QString& serverId) const;
    
    /**
     * @brief Explicitly fetch roles for a server.
     */
    Q_INVOKABLE void fetchServerRoles(const QString& serverId);
    
    /**
     * @brief Explicitly fetch all members for a server.
     */
    Q_INVOKABLE void fetchServerMembers(const QString& serverId);
    
    /**
     * @brief Get version counter for QML binding invalidation.
     */
    int version() const { return m_version; }
    
    // ========================================================================
    // C++ methods for cache management
    // ========================================================================
    
    /**
     * @brief Update a single member in the cache.
     * @param serverId The server ID
     * @param member The member data (must contain userId/user._id and roles)
     */
    void updateMember(const QString& serverId, const QVariantMap& member);
    
    /**
     * @brief Bulk update members for a server.
     * Called when server members list is fetched.
     */
    void updateServerMembers(const QString& serverId, const QVariantList& members);
    
    /**
     * @brief Update roles for a server.
     * Called when server roles are fetched.
     */
    void updateServerRoles(const QString& serverId, const QVariantList& roles);
    
    /**
     * @brief Remove a member from cache (when they leave a server).
     */
    void removeMember(const QString& serverId, const QString& userId);
    
    /**
     * @brief Clear all cached data for a server.
     */
    void clearServer(const QString& serverId);
    
    /**
     * @brief Clear all cached data.
     */
    void clear();

signals:
    /**
     * @brief Emitted when the cache version changes.
     */
    void versionChanged();
    
    /**
     * @brief Emitted when a member has been loaded.
     */
    void memberLoaded(const QString& serverId, const QString& userId);
    
    /**
     * @brief Emitted when a member fetch fails.
     */
    void memberFetchFailed(const QString& serverId, const QString& userId, const QString& error);
    
    /**
     * @brief Emitted when roles for a server have been loaded.
     */
    void serverRolesLoaded(const QString& serverId);
    
    /**
     * @brief Emitted when roles fetch fails.
     */
    void serverRolesFetchFailed(const QString& serverId, const QString& error);

private slots:
    /**
     * @brief Handle successful server members fetch.
     */
    void onServerMembersFetched(int requestId, const QString& serverId, const QVariantList& members);
    
    /**
     * @brief Handle failed server members fetch.
     */
    void onServerMembersFetchFailed(int requestId, const QString& serverId, const QString& error);
    
    /**
     * @brief Handle successful server roles fetch.
     */
    void onServerRolesFetched(int requestId, const QString& serverId, const QVariantList& roles);
    
    /**
     * @brief Handle failed server roles fetch.
     */
    void onServerRolesFetchFailed(int requestId, const QString& serverId, const QString& error);

private:
    // Member storage: "serverId:userId" -> member data
    QHash<QString, QVariantMap> m_members;
    
    // Role storage: "serverId:roleId" -> role data
    QHash<QString, QVariantMap> m_roles;
    
    // Quick lookup: serverId -> set of roleIds (for hasServerRoles check)
    QHash<QString, QSet<QString>> m_serverRoles;
    
    // Track pending fetch requests
    // For members: "serverId:userId" -> true
    QSet<QString> m_fetchingMembers;
    QSet<QString> m_fetchingServerRoles;
    
    // Pending request tracking
    QHash<int, QString> m_pendingMemberFetches;  // requestId -> serverId
    QHash<int, QString> m_pendingRoleFetches;    // requestId -> serverId
    
    // API client for fetching
    ApiClient* m_apiClient = nullptr;
    
    // Version counter for QML
    int m_version = 0;
    
    /**
     * @brief Increment version and emit signal.
     */
    void bumpVersion();
    
    /**
     * @brief Generate composite key for member lookup.
     */
    static QString memberKey(const QString& serverId, const QString& userId);
    
    /**
     * @brief Generate composite key for role lookup.
     */
    static QString roleKey(const QString& serverId, const QString& roleId);
    
    /**
     * @brief Extract user ID from member data.
     */
    static QString extractUserId(const QVariantMap& member);
    
    /**
     * @brief Extract role ID from role data.
     */
    static QString extractRoleId(const QVariantMap& role);
};

#endif // SERVERMEMBERCACHE_H
