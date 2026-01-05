#ifndef MESSAGEMODEL_H
#define MESSAGEMODEL_H

#include <QAbstractListModel>
#include <QVariantMap>
#include <QDateTime>
#include <QHash>

// Forward declaration
class UserProfileCache;

/**
 * @brief High-performance C++ model for chat messages.
 * 
 * This model provides significant advantages over QML JavaScript arrays:
 * 
 * 1. PROPER MODEL SIGNALS: Uses beginInsertRows/endInsertRows, dataChanged,
 *    etc. which preserve ListView scroll position during updates.
 * 
 * 2. PERFORMANCE: C++ is compiled machine code, much faster than QML's
 *    JavaScript interpreter for operations like:
 *    - Finding messages by ID (uses QHash for O(1) lookup)
 *    - Updating message properties (reactions, edit status)
 *    - Sorting and filtering
 * 
 * 3. MEMORY EFFICIENCY: Messages are stored in contiguous memory with
 *    proper C++ data structures instead of QML's variant boxing.
 * 
 * 4. THREAD SAFETY: Model operations can be safely called from any thread.
 * 
 * Usage in QML:
 *   ListView {
 *       model: SerchatAPI.messageModel
 *       delegate: MessageBubble {
 *           messageId: model.id
 *           text: model.text
 *           senderId: model.senderId
 *           // ... etc
 *       }
 *   }
 */
class MessageModel : public QAbstractListModel {
    Q_OBJECT
    
    // Properties exposed to QML
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool hasMoreMessages READ hasMoreMessages WRITE setHasMoreMessages NOTIFY hasMoreMessagesChanged)
    Q_PROPERTY(QString channelId READ channelId NOTIFY channelIdChanged)
    Q_PROPERTY(QString serverId READ serverId NOTIFY serverIdChanged)
    Q_PROPERTY(bool isDMMode READ isDMMode NOTIFY isDMModeChanged)

public:
    /**
     * @brief Role names for accessing message data in QML delegates.
     */
    enum MessageRoles {
        IdRole = Qt::UserRole + 1,  // _id or id
        TextRole,                    // text content
        SenderIdRole,               // senderId
        SenderNameRole,             // cached sender name (from user profiles)
        SenderAvatarRole,           // cached sender avatar
        TimestampRole,              // createdAt
        IsEditedRole,               // isEdited flag
        ReplyToIdRole,              // replyToId if this is a reply
        RepliedMessageRole,         // nested repliedMessage object
        ReactionsRole,              // reactions array
        AttachmentsRole,            // attachments array
        IsTempMessageRole,          // true if this is a pending optimistic message
    };
    Q_ENUM(MessageRoles)

    explicit MessageModel(QObject *parent = nullptr);
    ~MessageModel() override;

    // ========================================================================
    // QAbstractListModel implementation
    // ========================================================================
    
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ========================================================================
    // Model Properties (exposed to QML)
    // ========================================================================
    
    int count() const { return m_messages.count(); }
    bool hasMoreMessages() const { return m_hasMoreMessages; }
    void setHasMoreMessages(bool hasMore);
    QString channelId() const { return m_channelId; }
    QString serverId() const { return m_serverId; }
    bool isDMMode() const { return m_isDMMode; }

    // ========================================================================
    // Message Operations (for C++ usage and QML Q_INVOKABLE)
    // ========================================================================
    
    /**
     * @brief Set the current channel context.
     * Clears existing messages and prepares for new channel.
     */
    Q_INVOKABLE void setChannel(const QString& serverId, const QString& channelId);
    
    /**
     * @brief Set DM mode with recipient.
     * Clears existing messages and prepares for DM conversation.
     */
    Q_INVOKABLE void setDMRecipient(const QString& recipientId);
    
    /**
     * @brief Clear all messages.
     */
    Q_INVOKABLE void clear();
    
    /**
     * @brief Prepend a message (new messages go to index 0 for BottomToTop ListView).
     * Uses proper model signals to preserve scroll position.
     */
    Q_INVOKABLE void prependMessage(const QVariantMap& message);
    
    /**
     * @brief Append messages (older messages loaded during pagination).
     * Uses proper model signals to preserve scroll position.
     */
    Q_INVOKABLE void appendMessages(const QVariantList& messages);
    
    /**
     * @brief Replace a temporary message with the real server response.
     * Preserves scroll position by using dataChanged instead of remove+insert.
     */
    Q_INVOKABLE void replaceTempMessage(const QString& tempId, const QVariantMap& realMessage);
    
    /**
     * @brief Update a message (e.g., after edit).
     * Uses dataChanged signal to preserve scroll position.
     */
    Q_INVOKABLE bool updateMessage(const QString& messageId, const QVariantMap& updatedMessage);
    
    /**
     * @brief Update message reactions without replacing entire message.
     * Uses dataChanged signal to preserve scroll position.
     */
    Q_INVOKABLE bool updateReactions(const QString& messageId, const QVariantList& reactions);
    
    /**
     * @brief Delete a message by ID.
     * Uses proper beginRemoveRows/endRemoveRows signals.
     */
    Q_INVOKABLE bool deleteMessage(const QString& messageId);
    
    /**
     * @brief Check if a message with given ID exists.
     * O(1) lookup using internal hash table.
     */
    Q_INVOKABLE bool hasMessage(const QString& messageId) const;
    
    /**
     * @brief Get message data by ID.
     * O(1) lookup using internal hash table.
     */
    Q_INVOKABLE QVariantMap getMessage(const QString& messageId) const;
    
    /**
     * @brief Get the index of a message by ID.
     * O(1) lookup using internal hash table.
     */
    Q_INVOKABLE int indexOfMessage(const QString& messageId) const;
    
    /**
     * @brief Get oldest message ID (for pagination).
     */
    Q_INVOKABLE QString oldestMessageId() const;

    /**
     * @brief Get newest message ID (for tracking last read position).
     * In a BottomToTop ListView, newest message is at index 0.
     */
    Q_INVOKABLE QString newestMessageId() const;

    /**
     * @brief Get message data by index.
     * For use in QML when you need to access adjacent messages.
     */
    Q_INVOKABLE QVariantMap getMessageAt(int index) const;

    // ========================================================================
    // User Profile Cache (for sender names/avatars)
    // ========================================================================
    
    /**
     * @brief Set the user profile cache for sender name/avatar lookups.
     * Uses the shared UserProfileCache for all profile resolution.
     */
    void setUserProfileCache(UserProfileCache* cache);

signals:
    void countChanged();
    void hasMoreMessagesChanged();
    void channelIdChanged();
    void serverIdChanged();
    void isDMModeChanged();
    
    // Signals for external coordination
    void messageAdded(const QString& messageId, bool isNewMessage);
    void messageUpdated(const QString& messageId);
    void messageDeleted(const QString& messageId);

private:
    /**
     * @brief Internal message data structure.
     * Storing as QVariantMap maintains compatibility with existing code
     * while allowing efficient operations.
     */
    struct Message {
        QString id;
        QVariantMap data;
    };
    
    // Message storage - QList provides fast prepend/append
    QList<Message> m_messages;
    
    // Fast ID -> index lookup (O(1) instead of O(n))
    QHash<QString, int> m_idToIndex;
    
    // User profile cache for sender name/avatar resolution (shared with SerchatAPI)
    UserProfileCache* m_userProfileCache;
    
    // Current channel context
    QString m_serverId;
    QString m_channelId;
    QString m_dmRecipientId;
    bool m_isDMMode;
    bool m_hasMoreMessages;
    
    // Helper to rebuild index map after structural changes
    void rebuildIndexMap();
    
    // Helper to extract message ID from data
    static QString extractId(const QVariantMap& message);
    
    // Helper to get sender name from profile cache
    QString getSenderName(const QString& senderId) const;
    QString getSenderAvatar(const QString& senderId) const;
};

#endif // MESSAGEMODEL_H
