#include "messagemodel.h"
#include "../userprofilecache.h"
#include <QDebug>
#include <QTimer>

MessageModel::MessageModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_userProfileCache(nullptr)
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
    case ShowAvatarRole:
        return msg.showAvatar;
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
    roles[ShowAvatarRole] = "showAvatar";
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
    recalculateAvatarGrouping();
    
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
    recalculateAvatarGrouping();
    
    endInsertRows();
    
    emit countChanged();
    emit dataChanged(createIndex(0, 0), createIndex(m_messages.count() - 1, 0), { ShowAvatarRole });
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
    recalculateAvatarGrouping();
    
    // Emit dataChanged for the affected row
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex);
    if (index > 0) {
        emit dataChanged(createIndex(index - 1, 0), createIndex(index - 1, 0), { ShowAvatarRole });
    }
    
    emit messageUpdated(newId);
}

bool MessageModel::updateMessage(const QString& messageId, const QVariantMap& updatedMessage)
{
    if (!m_idToIndex.contains(messageId))
        return false;
    
    int index = m_idToIndex[messageId];
    m_messages[index].data = updatedMessage;
    recalculateAvatarGrouping();
    
    // Emit dataChanged - this is the key to updating without scroll reset!
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex);
    if (index > 0) {
        emit dataChanged(createIndex(index - 1, 0), createIndex(index - 1, 0), { ShowAvatarRole });
    }
    
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

QVariantList MessageModel::applyReactionDelta(const QString& messageId, const QVariantMap& reaction,
                                              bool added, const QString& currentUserId)
{
    if (!m_idToIndex.contains(messageId))
        return QVariantList();

    int index = m_idToIndex[messageId];
    QVariantList reactions = m_messages[index].data.value("reactions").toList();
    int reactionIndex = -1;

    for (int i = 0; i < reactions.count(); ++i) {
        if (reactionsMatch(reactions.at(i).toMap(), reaction)) {
            reactionIndex = i;
            break;
        }
    }

    const QString userId = reaction.value("userId").toString();
    const bool isCurrentUser = !currentUserId.isEmpty() && userId == currentUserId;

    if (added) {
        if (reactionIndex >= 0) {
            QVariantMap aggregate = reactions.at(reactionIndex).toMap();
            aggregate["count"] = aggregate.value("count", 0).toInt() + 1;
            if (isCurrentUser) {
                aggregate["hasReacted"] = true;
            }
            reactions[reactionIndex] = aggregate;
        } else {
            reactions.append(aggregateReactionFromDelta(reaction, currentUserId));
        }
    } else if (reactionIndex >= 0) {
        QVariantMap aggregate = reactions.at(reactionIndex).toMap();
        const int count = aggregate.value("count", 1).toInt() - 1;

        if (count <= 0) {
            reactions.removeAt(reactionIndex);
        } else {
            aggregate["count"] = count;
            if (isCurrentUser) {
                aggregate["hasReacted"] = false;
            }
            reactions[reactionIndex] = aggregate;
        }
    }

    updateReactions(messageId, reactions);
    return reactions;
}

bool MessageModel::deleteMessage(const QString& messageId)
{
    if (!m_idToIndex.contains(messageId))
        return false;
    
    int index = m_idToIndex[messageId];

    beginRemoveRows(QModelIndex(), index, index);
    
    m_messages.removeAt(index);
    rebuildIndexMap();
    recalculateAvatarGrouping();
    
    endRemoveRows();
    
    emit countChanged();
    emit messageDeleted(messageId);

    if (index > 0 && index - 1 < m_messages.count()) {
        QModelIndex affectedIndex = createIndex(index - 1, 0);
        emit dataChanged(affectedIndex, affectedIndex, { ShowAvatarRole });
    }

    return true;
}

void MessageModel::deleteMessageDeferred(const QString& messageId)
{
    // Use QTimer::singleShot to defer to next event loop iteration
    // This ensures we're completely out of any delegate context
    QTimer::singleShot(0, this, [this, messageId]() {
        deleteMessage(messageId);
    });
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

QString MessageModel::newestMessageId() const
{
    if (m_messages.isEmpty())
        return QString();
    // In a BottomToTop ListView, newest message is at index 0
    return m_messages.first().id;
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

void MessageModel::setUserProfileCache(UserProfileCache* cache)
{
    if (m_userProfileCache) {
        disconnect(m_userProfileCache, nullptr, this, nullptr);
    }
    
    m_userProfileCache = cache;
    
    if (m_userProfileCache) {
        // When profile cache updates, notify relevant rows
        connect(m_userProfileCache, &UserProfileCache::profileLoaded,
                this, [this](const QString& userId) {
            // Find all messages from this sender and update
            QVector<int> roles;
            roles << SenderNameRole << SenderAvatarRole;
            
            for (int i = 0; i < m_messages.count(); ++i) {
                if (m_messages[i].data.value("senderId").toString() == userId) {
                    emit dataChanged(createIndex(i, 0), createIndex(i, 0), roles);
                }
            }
        });
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

void MessageModel::recalculateAvatarGrouping()
{
    for (int i = 0; i < m_messages.count(); ++i) {
        m_messages[i].showAvatar = calculateShowAvatar(i);
    }
}

bool MessageModel::calculateShowAvatar(int index) const
{
    if (index < 0 || index >= m_messages.count()) {
        return true;
    }
    if (index >= m_messages.count() - 1) {
        return true;
    }

    const QVariantMap& currentMsg = m_messages.at(index).data;
    const QVariantMap& prevMsg = m_messages.at(index + 1).data;

    QString currentSender = currentMsg.value("senderId").toString();
    QString prevSender = prevMsg.value("senderId").toString();
    if (currentSender != prevSender) {
        return true;
    }

    QDateTime currentTime = parseTimestamp(currentMsg.value("createdAt"));
    QDateTime prevTime = parseTimestamp(prevMsg.value("createdAt"));

    if (currentTime.isValid() && prevTime.isValid()) {
        qint64 diffMs = currentTime.toMSecsSinceEpoch() - prevTime.toMSecsSinceEpoch();
        if (diffMs > 5 * 60 * 1000) {
            return true;
        }
    }

    return false;
}

QDateTime MessageModel::parseTimestamp(const QVariant& timestamp)
{
    if (timestamp.type() == QVariant::DateTime) {
        return timestamp.toDateTime();
    }

    QString timestampText = timestamp.toString();
    QDateTime dateTime = QDateTime::fromString(timestampText, Qt::ISODate);
    if (!dateTime.isValid()) {
        dateTime = QDateTime::fromString(timestampText, Qt::ISODateWithMs);
    }
    return dateTime;
}

QString MessageModel::extractId(const QVariantMap& message)
{
    // Support "_id" (MongoDB), "id", and "messageId" (WebSocket) formats
    QString id = message.value("_id").toString();
    if (id.isEmpty()) {
        id = message.value("id").toString();
    }
    if (id.isEmpty()) {
        id = message.value("messageId").toString();
    }
    return id;
}

bool MessageModel::reactionsMatch(const QVariantMap& existingReaction, const QVariantMap& reaction)
{
    const QString existingEmojiId = existingReaction.value("emojiId").toString();
    const QString emojiId = reaction.value("emojiId").toString();
    if (!existingEmojiId.isEmpty() || !emojiId.isEmpty()) {
        return existingEmojiId == emojiId;
    }

    const QString existingEmojiType = existingReaction.value("emojiType", QStringLiteral("unicode")).toString();
    const QString emojiType = reaction.value("emojiType", QStringLiteral("unicode")).toString();
    return existingEmojiType == emojiType
        && existingReaction.value("emoji").toString() == reaction.value("emoji").toString();
}

QVariantMap MessageModel::aggregateReactionFromDelta(const QVariantMap& reaction, const QString& currentUserId)
{
    QVariantMap aggregate;
    aggregate["emoji"] = reaction.value("emoji");
    aggregate["emojiType"] = reaction.value("emojiType", QStringLiteral("unicode"));
    aggregate["emojiId"] = reaction.value("emojiId");
    aggregate["emojiUrl"] = reaction.value("emojiUrl", reaction.value("imageUrl"));
    aggregate["count"] = 1;

    const QString userId = reaction.value("userId").toString();
    aggregate["hasReacted"] = !currentUserId.isEmpty() && userId == currentUserId;
    return aggregate;
}

QString MessageModel::getSenderName(const QString& senderId) const
{
    if (senderId.isEmpty())
        return QString();
    
    if (!m_userProfileCache)
        return senderId;  // Fallback to ID if no cache
    
    // Use the shared UserProfileCache - returns empty if not cached (triggers auto-fetch)
    QString displayName = m_userProfileCache->getDisplayName(senderId);
    return displayName.isEmpty() ? QString() : displayName;
}

QString MessageModel::getSenderAvatar(const QString& senderId) const
{
    if (senderId.isEmpty())
        return QString();

    if (!m_userProfileCache)
        return QString();

    // Use the shared UserProfileCache - returns empty if not cached (triggers auto-fetch)
    return m_userProfileCache->getAvatarUrl(senderId);
}

bool MessageModel::shouldShowAvatar(int index) const
{
    if (index < 0 || index >= m_messages.count()) {
        return true;
    }
    return m_messages.at(index).showAvatar;
}

bool MessageModel::addRealMessage(const QVariantMap& message)
{
    QString msgId = extractId(message);
    if (msgId.isEmpty()) {
        qWarning() << "[MessageModel] Cannot add message without ID";
        return false;
    }

    // Check if real message already exists (duplicate from WebSocket vs HTTP)
    if (m_idToIndex.contains(msgId)) {
        qDebug() << "[MessageModel] Duplicate message ignored:" << msgId;
        return false;
    }

    // Look for temp message with matching text
    QString msgText = message.value("text").toString();
    for (int i = 0; i < m_messages.count(); ++i) {
        const Message& existingMsg = m_messages.at(i);
        if (existingMsg.id.startsWith(QStringLiteral("temp_"))) {
            QString existingText = existingMsg.data.value("text").toString();
            if (existingText == msgText) {
                // Found matching temp message - replace it
                qDebug() << "[MessageModel] Replacing temp message with real message:" << msgId;
                replaceTempMessage(existingMsg.id, message);
                return true;
            }
        }
    }

    // No matching temp message found - prepend the real message
    qDebug() << "[MessageModel] Adding real message (no temp found):" << msgId;
    prependMessage(message);
    return true;
}

void MessageModel::removeAllTempMessages()
{
    // Iterate backwards for safe removal
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages.at(i).id.startsWith(QStringLiteral("temp_"))) {
            qDebug() << "[MessageModel] Removing temp message:" << m_messages.at(i).id;
            deleteMessage(m_messages.at(i).id);
        }
    }
}
