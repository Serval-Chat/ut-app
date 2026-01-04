#include "messagemodel.h"
#include <QDebug>

MessageModel::MessageModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_isDMMode(false)
    , m_hasMoreMessages(true)
{
}

MessageModel::~MessageModel()
{
}

// ============================================================================
// QAbstractListModel Implementation
// ============================================================================

int MessageModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_messages.count();
}

QVariant MessageModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_messages.count())
        return QVariant();
    
    const Message& msg = m_messages.at(index.row());
    const QVariantMap& data = msg.data;
    
    switch (role) {
    case IdRole:
        return msg.id;
    case TextRole:
        return data.value("text").toString();
    case SenderIdRole:
        return data.value("senderId").toString();
    case SenderNameRole:
        return getSenderName(data.value("senderId").toString());
    case SenderAvatarRole:
        return getSenderAvatar(data.value("senderId").toString());
    case TimestampRole:
        return data.value("createdAt");
    case IsEditedRole:
        return data.value("isEdited", false).toBool();
    case ReplyToIdRole:
        return data.value("replyToId").toString();
    case RepliedMessageRole:
        return data.value("repliedMessage");
    case ReactionsRole:
        return data.value("reactions", QVariantList());
    case AttachmentsRole:
        return data.value("attachments", QVariantList());
    case IsTempMessageRole:
        return msg.id.startsWith("temp_");
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> MessageModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[TextRole] = "text";
    roles[SenderIdRole] = "senderId";
    roles[SenderNameRole] = "senderName";
    roles[SenderAvatarRole] = "senderAvatar";
    roles[TimestampRole] = "timestamp";
    roles[IsEditedRole] = "isEdited";
    roles[ReplyToIdRole] = "replyToId";
    roles[RepliedMessageRole] = "repliedMessage";
    roles[ReactionsRole] = "reactions";
    roles[AttachmentsRole] = "attachments";
    roles[IsTempMessageRole] = "isTempMessage";
    return roles;
}

// ============================================================================
// Model Properties
// ============================================================================

void MessageModel::setHasMoreMessages(bool hasMore)
{
    if (m_hasMoreMessages != hasMore) {
        m_hasMoreMessages = hasMore;
        emit hasMoreMessagesChanged();
    }
}

// ============================================================================
// Channel/DM Context
// ============================================================================

void MessageModel::setChannel(const QString& serverId, const QString& channelId)
{
    if (m_serverId == serverId && m_channelId == channelId && !m_isDMMode)
        return;
    
    clear();
    
    m_serverId = serverId;
    m_channelId = channelId;
    m_dmRecipientId.clear();
    m_isDMMode = false;
    m_hasMoreMessages = true;
    
    emit serverIdChanged();
    emit channelIdChanged();
    emit isDMModeChanged();
    emit hasMoreMessagesChanged();
}

void MessageModel::setDMRecipient(const QString& recipientId)
{
    if (m_dmRecipientId == recipientId && m_isDMMode)
        return;
    
    clear();
    
    m_serverId.clear();
    m_channelId.clear();
    m_dmRecipientId = recipientId;
    m_isDMMode = true;
    m_hasMoreMessages = true;
    
    emit serverIdChanged();
    emit channelIdChanged();
    emit isDMModeChanged();
    emit hasMoreMessagesChanged();
}

void MessageModel::clear()
{
    if (m_messages.isEmpty())
        return;
    
    beginResetModel();
    m_messages.clear();
    m_idToIndex.clear();
    endResetModel();
    
    emit countChanged();
}

// ============================================================================
// Message Operations - These use proper model signals!
// ============================================================================

void MessageModel::prependMessage(const QVariantMap& message)
{
    QString id = extractId(message);
    if (id.isEmpty()) {
        qWarning() << "[MessageModel] Cannot prepend message without ID";
        return;
    }
    
    // Check for duplicates
    if (m_idToIndex.contains(id)) {
        qDebug() << "[MessageModel] Skipping duplicate message:" << id;
        return;
    }
    
    // Use proper model signals - this is the key to preserving scroll!
    beginInsertRows(QModelIndex(), 0, 0);
    
    Message msg;
    msg.id = id;
    msg.data = message;
    m_messages.prepend(msg);
    
    // Rebuild index map (prepend shifts all indices)
    rebuildIndexMap();
    
    endInsertRows();
    
    emit countChanged();
    emit messageAdded(id, true);
}

void MessageModel::appendMessages(const QVariantList& messages)
{
    if (messages.isEmpty())
        return;
    
    // Filter out duplicates
    QList<Message> toAdd;
    for (const QVariant& v : messages) {
        QVariantMap msgData = v.toMap();
        QString id = extractId(msgData);
        if (!id.isEmpty() && !m_idToIndex.contains(id)) {
            Message msg;
            msg.id = id;
            msg.data = msgData;
            toAdd.append(msg);
        }
    }
    
    if (toAdd.isEmpty())
        return;
    
    int first = m_messages.count();
    int last = first + toAdd.count() - 1;
    
    // Use proper model signals
    beginInsertRows(QModelIndex(), first, last);
    
    for (const Message& msg : toAdd) {
        m_idToIndex[msg.id] = m_messages.count();
        m_messages.append(msg);
    }
    
    endInsertRows();
    
    emit countChanged();
    for (const Message& msg : toAdd) {
        emit messageAdded(msg.id, false);
    }
}

void MessageModel::replaceTempMessage(const QString& tempId, const QVariantMap& realMessage)
{
    if (!m_idToIndex.contains(tempId)) {
        // Temp message not found, just prepend the real one
        prependMessage(realMessage);
        return;
    }
    
    int index = m_idToIndex[tempId];
    QString newId = extractId(realMessage);
    
    // Check if real message already exists (race condition)
    if (m_idToIndex.contains(newId) && newId != tempId) {
        // Just remove the temp message
        deleteMessage(tempId);
        return;
    }
    
    // Update in place - uses dataChanged which preserves scroll!
    m_idToIndex.remove(tempId);
    m_messages[index].id = newId;
    m_messages[index].data = realMessage;
    m_idToIndex[newId] = index;
    
    // Emit dataChanged for the affected row
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex);
    
    emit messageUpdated(newId);
}

bool MessageModel::updateMessage(const QString& messageId, const QVariantMap& updatedMessage)
{
    if (!m_idToIndex.contains(messageId))
        return false;
    
    int index = m_idToIndex[messageId];
    m_messages[index].data = updatedMessage;
    
    // Emit dataChanged - this is the key to updating without scroll reset!
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex);
    
    emit messageUpdated(messageId);
    return true;
}

bool MessageModel::updateReactions(const QString& messageId, const QVariantList& reactions)
{
    if (!m_idToIndex.contains(messageId))
        return false;
    
    int index = m_idToIndex[messageId];
    m_messages[index].data["reactions"] = reactions;
    
    // Only emit change for reactions role - more efficient
    QModelIndex modelIndex = createIndex(index, 0);
    QVector<int> roles;
    roles << ReactionsRole;
    emit dataChanged(modelIndex, modelIndex, roles);
    
    return true;
}

bool MessageModel::deleteMessage(const QString& messageId)
{
    if (!m_idToIndex.contains(messageId))
        return false;
    
    int index = m_idToIndex[messageId];
    
    // Use proper model signals
    beginRemoveRows(QModelIndex(), index, index);
    
    m_messages.removeAt(index);
    rebuildIndexMap();
    
    endRemoveRows();
    
    emit countChanged();
    emit messageDeleted(messageId);
    return true;
}

bool MessageModel::hasMessage(const QString& messageId) const
{
    return m_idToIndex.contains(messageId);
}

QVariantMap MessageModel::getMessage(const QString& messageId) const
{
    if (!m_idToIndex.contains(messageId))
        return QVariantMap();
    
    return m_messages.at(m_idToIndex[messageId]).data;
}

int MessageModel::indexOfMessage(const QString& messageId) const
{
    return m_idToIndex.value(messageId, -1);
}

QString MessageModel::oldestMessageId() const
{
    if (m_messages.isEmpty())
        return QString();
    return m_messages.last().id;
}

QVariantMap MessageModel::getMessageAt(int index) const
{
    if (index < 0 || index >= m_messages.count())
        return QVariantMap();
    return m_messages.at(index).data;
}

// ============================================================================
// User Profile Cache
// ============================================================================

void MessageModel::setUserProfiles(const QVariantMap& profiles)
{
    m_userProfiles = profiles;
    
    // Notify all rows that sender name/avatar may have changed
    if (!m_messages.isEmpty()) {
        QVector<int> roles;
        roles << SenderNameRole << SenderAvatarRole;
        emit dataChanged(createIndex(0, 0), createIndex(m_messages.count() - 1, 0), roles);
    }
}

void MessageModel::updateUserProfile(const QString& userId, const QVariantMap& profile)
{
    m_userProfiles[userId] = profile;
    
    // Find all messages from this sender and update
    QVector<int> roles;
    roles << SenderNameRole << SenderAvatarRole;
    
    for (int i = 0; i < m_messages.count(); ++i) {
        if (m_messages[i].data.value("senderId").toString() == userId) {
            emit dataChanged(createIndex(i, 0), createIndex(i, 0), roles);
        }
    }
}

// ============================================================================
// Private Helpers
// ============================================================================

void MessageModel::rebuildIndexMap()
{
    m_idToIndex.clear();
    for (int i = 0; i < m_messages.count(); ++i) {
        m_idToIndex[m_messages[i].id] = i;
    }
}

QString MessageModel::extractId(const QVariantMap& message)
{
    // Support both "_id" (MongoDB) and "id" formats
    QString id = message.value("_id").toString();
    if (id.isEmpty()) {
        id = message.value("id").toString();
    }
    return id;
}

QString MessageModel::getSenderName(const QString& senderId) const
{
    if (senderId.isEmpty())
        return QString();
    
    QVariantMap profile = m_userProfiles.value(senderId).toMap();
    if (profile.isEmpty())
        return senderId;  // Fallback to ID if no profile cached
    
    QString displayName = profile.value("displayName").toString();
    if (!displayName.isEmpty())
        return displayName;
    
    return profile.value("username", senderId).toString();
}

QString MessageModel::getSenderAvatar(const QString& senderId) const
{
    if (senderId.isEmpty())
        return QString();
    
    QVariantMap profile = m_userProfiles.value(senderId).toMap();
    return profile.value("profilePicture").toString();
}
