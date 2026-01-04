#include "genericlistmodel.h"
#include <QDebug>

GenericListModel::GenericListModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_idField("_id")
    , m_nextRole(Qt::UserRole + 1)
{
}

GenericListModel::GenericListModel(const QString& idField, QObject *parent)
    : QAbstractListModel(parent)
    , m_idField(idField)
    , m_nextRole(Qt::UserRole + 1)
{
}

GenericListModel::~GenericListModel()
{
}

// ============================================================================
// QAbstractListModel Implementation
// ============================================================================

int GenericListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.count();
}

QVariant GenericListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.count())
        return QVariant();
    
    const QVariantMap& item = m_items.at(index.row());
    
    // Map role to item key
    if (m_roleToKey.contains(role)) {
        QString key = m_roleToKey[role];
        return item.value(key);
    }
    
    return QVariant();
}

QHash<int, QByteArray> GenericListModel::roleNames() const
{
    return m_roleNames;
}

// ============================================================================
// Properties
// ============================================================================

void GenericListModel::setIdField(const QString& field)
{
    if (m_idField != field) {
        m_idField = field;
        rebuildIndexMap();
        emit idFieldChanged();
    }
}

// ============================================================================
// Data Operations
// ============================================================================

void GenericListModel::setItems(const QVariantList& items)
{
    beginResetModel();
    
    m_items.clear();
    m_idToIndex.clear();
    
    // Auto-detect roles from first item if not already set
    if (!items.isEmpty() && m_roleNames.isEmpty()) {
        ensureRolesFromItem(items.first().toMap());
    }
    
    for (int i = 0; i < items.count(); ++i) {
        QVariantMap item = items[i].toMap();
        QString id = extractId(item);
        if (!id.isEmpty()) {
            m_idToIndex[id] = i;
        }
        m_items.append(item);
    }
    
    endResetModel();
    emit countChanged();
}

void GenericListModel::clear()
{
    if (m_items.isEmpty())
        return;
    
    beginResetModel();
    m_items.clear();
    m_idToIndex.clear();
    endResetModel();
    
    emit countChanged();
}

void GenericListModel::append(const QVariantMap& item)
{
    ensureRolesFromItem(item);
    
    QString id = extractId(item);
    if (!id.isEmpty() && m_idToIndex.contains(id)) {
        // Item already exists, update instead
        updateItem(id, item);
        return;
    }
    
    int index = m_items.count();
    
    beginInsertRows(QModelIndex(), index, index);
    m_items.append(item);
    if (!id.isEmpty()) {
        m_idToIndex[id] = index;
    }
    endInsertRows();
    
    emit countChanged();
    emit itemAdded(id, index);
}

void GenericListModel::appendItems(const QVariantList& items)
{
    if (items.isEmpty())
        return;
    
    // Filter duplicates and auto-detect roles
    QList<QVariantMap> toAdd;
    for (const QVariant& v : items) {
        QVariantMap item = v.toMap();
        ensureRolesFromItem(item);
        
        QString id = extractId(item);
        if (id.isEmpty() || !m_idToIndex.contains(id)) {
            toAdd.append(item);
        }
    }
    
    if (toAdd.isEmpty())
        return;
    
    int first = m_items.count();
    int last = first + toAdd.count() - 1;
    
    beginInsertRows(QModelIndex(), first, last);
    for (const QVariantMap& item : toAdd) {
        QString id = extractId(item);
        if (!id.isEmpty()) {
            m_idToIndex[id] = m_items.count();
        }
        m_items.append(item);
    }
    endInsertRows();
    
    emit countChanged();
    for (const QVariantMap& item : toAdd) {
        emit itemAdded(extractId(item), m_items.count() - toAdd.count() + toAdd.indexOf(item));
    }
}

void GenericListModel::prepend(const QVariantMap& item)
{
    ensureRolesFromItem(item);
    
    QString id = extractId(item);
    if (!id.isEmpty() && m_idToIndex.contains(id)) {
        updateItem(id, item);
        return;
    }
    
    beginInsertRows(QModelIndex(), 0, 0);
    m_items.prepend(item);
    rebuildIndexMap();
    endInsertRows();
    
    emit countChanged();
    emit itemAdded(id, 0);
}

void GenericListModel::insert(int index, const QVariantMap& item)
{
    if (index < 0 || index > m_items.count())
        index = m_items.count();
    
    ensureRolesFromItem(item);
    
    QString id = extractId(item);
    if (!id.isEmpty() && m_idToIndex.contains(id)) {
        updateItem(id, item);
        return;
    }
    
    beginInsertRows(QModelIndex(), index, index);
    m_items.insert(index, item);
    rebuildIndexMap();
    endInsertRows();
    
    emit countChanged();
    emit itemAdded(id, index);
}

bool GenericListModel::updateItem(const QString& id, const QVariantMap& item)
{
    if (!m_idToIndex.contains(id))
        return false;
    
    int index = m_idToIndex[id];
    m_items[index] = item;
    
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex);
    emit itemUpdated(id);
    
    return true;
}

bool GenericListModel::updateItemProperty(const QString& id, const QString& property, const QVariant& value)
{
    if (!m_idToIndex.contains(id))
        return false;
    
    int index = m_idToIndex[id];
    m_items[index][property] = value;
    
    // Find the role for this property
    QVector<int> roles;
    for (auto it = m_roleToKey.begin(); it != m_roleToKey.end(); ++it) {
        if (it.value() == property) {
            roles << it.key();
            break;
        }
    }
    
    QModelIndex modelIndex = createIndex(index, 0);
    emit dataChanged(modelIndex, modelIndex, roles);
    emit itemUpdated(id);
    
    return true;
}

bool GenericListModel::removeItem(const QString& id)
{
    if (!m_idToIndex.contains(id))
        return false;
    
    int index = m_idToIndex[id];
    
    beginRemoveRows(QModelIndex(), index, index);
    m_items.removeAt(index);
    rebuildIndexMap();
    endRemoveRows();
    
    emit countChanged();
    emit itemRemoved(id);
    
    return true;
}

void GenericListModel::removeAt(int index)
{
    if (index < 0 || index >= m_items.count())
        return;
    
    QString id = extractId(m_items[index]);
    
    beginRemoveRows(QModelIndex(), index, index);
    m_items.removeAt(index);
    rebuildIndexMap();
    endRemoveRows();
    
    emit countChanged();
    emit itemRemoved(id);
}

bool GenericListModel::contains(const QString& id) const
{
    return m_idToIndex.contains(id);
}

QVariantMap GenericListModel::get(const QString& id) const
{
    if (!m_idToIndex.contains(id))
        return QVariantMap();
    return m_items.at(m_idToIndex[id]);
}

QVariantMap GenericListModel::getAt(int index) const
{
    if (index < 0 || index >= m_items.count())
        return QVariantMap();
    return m_items.at(index);
}

int GenericListModel::indexOf(const QString& id) const
{
    return m_idToIndex.value(id, -1);
}

void GenericListModel::move(int from, int to)
{
    if (from < 0 || from >= m_items.count() || to < 0 || to >= m_items.count() || from == to)
        return;
    
    // QAbstractListModel::beginMoveRows expects slightly different semantics
    int dest = to > from ? to + 1 : to;
    
    if (!beginMoveRows(QModelIndex(), from, from, QModelIndex(), dest))
        return;
    
    m_items.move(from, to);
    rebuildIndexMap();
    
    endMoveRows();
}

QVariantList GenericListModel::toList() const
{
    QVariantList result;
    for (const QVariantMap& item : m_items) {
        result.append(item);
    }
    return result;
}

// ============================================================================
// Role Management
// ============================================================================

void GenericListModel::setRoleMapping(const QHash<QString, QString>& mapping)
{
    beginResetModel();
    
    m_roleNames.clear();
    m_roleToKey.clear();
    m_nextRole = Qt::UserRole + 1;
    
    for (auto it = mapping.begin(); it != mapping.end(); ++it) {
        int role = m_nextRole++;
        m_roleNames[role] = it.key().toUtf8();
        m_roleToKey[role] = it.value();
    }
    
    endResetModel();
}

void GenericListModel::autoDetectRoles(const QVariantMap& sampleItem)
{
    ensureRolesFromItem(sampleItem);
}

// ============================================================================
// Private Helpers
// ============================================================================

QString GenericListModel::extractId(const QVariantMap& item) const
{
    // Try the configured ID field first
    QString id = item.value(m_idField).toString();
    
    // Fall back to common alternatives
    if (id.isEmpty() && m_idField != "_id")
        id = item.value("_id").toString();
    if (id.isEmpty() && m_idField != "id")
        id = item.value("id").toString();
    
    return id;
}

void GenericListModel::rebuildIndexMap()
{
    m_idToIndex.clear();
    for (int i = 0; i < m_items.count(); ++i) {
        QString id = extractId(m_items[i]);
        if (!id.isEmpty()) {
            m_idToIndex[id] = i;
        }
    }
}

void GenericListModel::ensureRolesFromItem(const QVariantMap& item)
{
    // Add any new keys as roles
    bool rolesAdded = false;
    
    for (auto it = item.begin(); it != item.end(); ++it) {
        QString key = it.key();
        
        // Check if we already have a role for this key
        bool found = false;
        for (auto roleIt = m_roleToKey.begin(); roleIt != m_roleToKey.end(); ++roleIt) {
            if (roleIt.value() == key) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            int role = m_nextRole++;
            m_roleNames[role] = key.toUtf8();
            m_roleToKey[role] = key;
            rolesAdded = true;
        }
    }
    
    // Note: In Qt 5, we can't dynamically add roles after data is set
    // without a full model reset. For best performance, set roles before data.
}
