#include "channellistmodel.h"
#include <QDebug>
#include <algorithm>

ChannelListModel::ChannelListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

ChannelListModel::~ChannelListModel()
{
}

// ============================================================================
// QAbstractListModel Implementation
// ============================================================================

int ChannelListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_displayItems.count();
}

QVariant ChannelListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_displayItems.count())
        return QVariant();
    
    const DisplayItem& item = m_displayItems.at(index.row());
    
    switch (role) {
    case ItemIdRole:
        return item.id;
    case NameRole:
        return item.name;
    case ItemTypeRole:
        return item.isCategory ? QStringLiteral("category") : QStringLiteral("channel");
    case ChannelTypeRole:
        return item.channelType;
    case CategoryIdRole:
        return item.categoryId;
    case PositionRole:
        return item.position;
    case IconRole:
        return item.icon;
    case DescriptionRole:
        return item.description;
    case ExpandedRole:
        return item.expanded;
    case VisibleRole:
        // Categories are always visible
        // Channels are visible if uncategorized or their category is expanded
        if (item.isCategory)
            return true;
        if (item.categoryId.isEmpty())
            return true;
        return m_expandedState.value(item.categoryId, true);
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> ChannelListModel::roleNames() const
{
    static QHash<int, QByteArray> roles = {
        { ItemIdRole, "itemId" },
        { NameRole, "name" },
        { ItemTypeRole, "itemType" },
        { ChannelTypeRole, "channelType" },
        { CategoryIdRole, "categoryId" },
        { PositionRole, "position" },
        { IconRole, "icon" },
        { DescriptionRole, "description" },
        { ExpandedRole, "expanded" },
        { VisibleRole, "visible" }
    };
    return roles;
}

// ============================================================================
// Properties
// ============================================================================

void ChannelListModel::setServerId(const QString& id)
{
    if (m_serverId != id) {
        m_serverId = id;
        // Don't clear data here - let the caller set new data
        emit serverIdChanged();
    }
}

// ============================================================================
// Data Operations - Bulk
// ============================================================================

void ChannelListModel::setCategories(const QVariantList& categories)
{
    m_categories.clear();
    m_categoryIdToIndex.clear();
    
    for (int i = 0; i < categories.count(); ++i) {
        QVariantMap cat = categories[i].toMap();
        QString id = extractId(cat);
        if (!id.isEmpty()) {
            m_categoryIdToIndex[id] = m_categories.count();
            m_categories.append(cat);
            
            // Initialize expansion state if not already set
            if (!m_expandedState.contains(id)) {
                m_expandedState[id] = true;
            }
        }
    }
    
    sortCategories();
    rebuildDisplayList();
}

void ChannelListModel::setChannels(const QVariantList& channels)
{
    m_channels.clear();
    m_channelIdToIndex.clear();
    
    for (int i = 0; i < channels.count(); ++i) {
        QVariantMap ch = channels[i].toMap();
        // Skip items that are actually categories (type == "category")
        if (ch.value("type").toString() == "category")
            continue;
            
        QString id = extractId(ch);
        if (!id.isEmpty()) {
            m_channelIdToIndex[id] = m_channels.count();
            m_channels.append(ch);
        }
    }
    
    sortChannels();
    rebuildDisplayList();
}

void ChannelListModel::clear()
{
    if (m_displayItems.isEmpty())
        return;
    
    beginResetModel();
    m_categories.clear();
    m_channels.clear();
    m_categoryIdToIndex.clear();
    m_channelIdToIndex.clear();
    m_displayItems.clear();
    // Keep expansion state for when data is reloaded
    endResetModel();
    
    emit countChanged();
}

// ============================================================================
// Data Operations - Single Items
// ============================================================================

void ChannelListModel::addCategory(const QVariantMap& category)
{
    QString id = extractId(category);
    if (id.isEmpty())
        return;
    
    // Check if already exists
    if (m_categoryIdToIndex.contains(id)) {
        updateCategory(id, category);
        return;
    }
    
    m_categoryIdToIndex[id] = m_categories.count();
    m_categories.append(category);
    
    // Initialize expansion state
    if (!m_expandedState.contains(id)) {
        m_expandedState[id] = true;
    }
    
    sortCategories();
    rebuildDisplayList();
    
    emit categoryAdded(id);
}

bool ChannelListModel::updateCategory(const QString& categoryId, const QVariantMap& category)
{
    if (!m_categoryIdToIndex.contains(categoryId))
        return false;
    
    int idx = m_categoryIdToIndex[categoryId];
    m_categories[idx] = category;
    
    // Check if position changed - need to resort
    sortCategories();
    rebuildDisplayList();
    
    emit categoryUpdated(categoryId);
    return true;
}

bool ChannelListModel::removeCategory(const QString& categoryId)
{
    if (!m_categoryIdToIndex.contains(categoryId))
        return false;
    
    int idx = m_categoryIdToIndex[categoryId];
    m_categories.removeAt(idx);
    
    // Rebuild index map
    m_categoryIdToIndex.clear();
    for (int i = 0; i < m_categories.count(); ++i) {
        QString id = extractId(m_categories[i]);
        if (!id.isEmpty()) {
            m_categoryIdToIndex[id] = i;
        }
    }
    
    // Move channels from this category to uncategorized
    for (int i = 0; i < m_channels.count(); ++i) {
        if (m_channels[i].value("categoryId").toString() == categoryId) {
            m_channels[i]["categoryId"] = QString();
        }
    }
    
    rebuildDisplayList();
    
    emit categoryRemoved(categoryId);
    return true;
}

void ChannelListModel::addChannel(const QVariantMap& channel)
{
    QString id = extractId(channel);
    if (id.isEmpty())
        return;
    
    // Skip if this is actually a category
    if (channel.value("type").toString() == "category")
        return;
    
    // Check if already exists
    if (m_channelIdToIndex.contains(id)) {
        updateChannel(id, channel);
        return;
    }
    
    m_channelIdToIndex[id] = m_channels.count();
    m_channels.append(channel);
    
    sortChannels();
    rebuildDisplayList();
    
    emit channelAdded(id);
}

bool ChannelListModel::updateChannel(const QString& channelId, const QVariantMap& channel)
{
    if (!m_channelIdToIndex.contains(channelId))
        return false;
    
    int idx = m_channelIdToIndex[channelId];
    m_channels[idx] = channel;
    
    // Check if position or category changed - need to resort
    sortChannels();
    rebuildDisplayList();
    
    emit channelUpdated(channelId);
    return true;
}

bool ChannelListModel::removeChannel(const QString& channelId)
{
    if (!m_channelIdToIndex.contains(channelId))
        return false;
    
    int idx = m_channelIdToIndex[channelId];
    m_channels.removeAt(idx);
    
    // Rebuild index map
    m_channelIdToIndex.clear();
    for (int i = 0; i < m_channels.count(); ++i) {
        QString id = extractId(m_channels[i]);
        if (!id.isEmpty()) {
            m_channelIdToIndex[id] = i;
        }
    }
    
    rebuildDisplayList();
    
    emit channelRemoved(channelId);
    return true;
}

// ============================================================================
// Category Expansion
// ============================================================================

void ChannelListModel::toggleCategoryExpanded(const QString& categoryId)
{
    bool current = m_expandedState.value(categoryId, true);
    setCategoryExpanded(categoryId, !current);
}

void ChannelListModel::setCategoryExpanded(const QString& categoryId, bool expanded)
{
    if (m_expandedState.value(categoryId, true) == expanded)
        return;
    
    m_expandedState[categoryId] = expanded;
    
    // Find the category in display list and emit dataChanged for it and its children
    int catIndex = findDisplayIndex(categoryId, true);
    if (catIndex >= 0) {
        // Update category's expanded state
        m_displayItems[catIndex].expanded = expanded;
        QModelIndex catModelIndex = createIndex(catIndex, 0);
        emit dataChanged(catModelIndex, catModelIndex, { ExpandedRole });
        
        // Update visibility of all channels in this category
        QVector<int> roles = { VisibleRole };
        for (int i = catIndex + 1; i < m_displayItems.count(); ++i) {
            const DisplayItem& item = m_displayItems[i];
            if (item.isCategory)
                break;  // Reached next category
            if (item.categoryId == categoryId) {
                QModelIndex idx = createIndex(i, 0);
                emit dataChanged(idx, idx, roles);
            }
        }
    }
}

bool ChannelListModel::isCategoryExpanded(const QString& categoryId) const
{
    return m_expandedState.value(categoryId, true);
}

// ============================================================================
// Getters
// ============================================================================

QVariantMap ChannelListModel::getChannel(const QString& channelId) const
{
    if (!m_channelIdToIndex.contains(channelId))
        return QVariantMap();
    return m_channels.at(m_channelIdToIndex[channelId]);
}

QVariantMap ChannelListModel::getCategory(const QString& categoryId) const
{
    if (!m_categoryIdToIndex.contains(categoryId))
        return QVariantMap();
    return m_categories.at(m_categoryIdToIndex[categoryId]);
}

QVariantList ChannelListModel::allCategories() const
{
    QVariantList result;
    for (const QVariantMap& cat : m_categories) {
        result.append(cat);
    }
    return result;
}

QVariantList ChannelListModel::allChannels() const
{
    QVariantList result;
    for (const QVariantMap& ch : m_channels) {
        result.append(ch);
    }
    return result;
}

// ============================================================================
// Private Helpers
// ============================================================================

QString ChannelListModel::extractId(const QVariantMap& item) const
{
    QString id = item.value("_id").toString();
    if (id.isEmpty())
        id = item.value("id").toString();
    return id;
}

int ChannelListModel::findDisplayIndex(const QString& id, bool isCategory) const
{
    for (int i = 0; i < m_displayItems.count(); ++i) {
        if (m_displayItems[i].id == id && m_displayItems[i].isCategory == isCategory)
            return i;
    }
    return -1;
}

void ChannelListModel::sortCategories()
{
    std::sort(m_categories.begin(), m_categories.end(),
              [](const QVariantMap& a, const QVariantMap& b) {
                  return a.value("position", 0).toInt() < b.value("position", 0).toInt();
              });
    
    // Rebuild index map
    m_categoryIdToIndex.clear();
    for (int i = 0; i < m_categories.count(); ++i) {
        QString id = extractId(m_categories[i]);
        if (!id.isEmpty()) {
            m_categoryIdToIndex[id] = i;
        }
    }
}

void ChannelListModel::sortChannels()
{
    std::sort(m_channels.begin(), m_channels.end(),
              [](const QVariantMap& a, const QVariantMap& b) {
                  // First sort by category presence (uncategorized first)
                  QString catA = a.value("categoryId").toString();
                  QString catB = b.value("categoryId").toString();
                  if (catA.isEmpty() && !catB.isEmpty()) return true;
                  if (!catA.isEmpty() && catB.isEmpty()) return false;
                  // Then by position within category
                  return a.value("position", 0).toInt() < b.value("position", 0).toInt();
              });
    
    // Rebuild index map
    m_channelIdToIndex.clear();
    for (int i = 0; i < m_channels.count(); ++i) {
        QString id = extractId(m_channels[i]);
        if (!id.isEmpty()) {
            m_channelIdToIndex[id] = i;
        }
    }
}

void ChannelListModel::rebuildDisplayList()
{
    beginResetModel();
    m_displayItems.clear();
    
    // Build a map of categoryId -> channels
    QHash<QString, QList<int>> categoryChannels;  // categoryId -> channel indices
    QList<int> uncategorizedChannels;
    
    for (int i = 0; i < m_channels.count(); ++i) {
        QString catId = m_channels[i].value("categoryId").toString();
        if (catId.isEmpty()) {
            uncategorizedChannels.append(i);
        } else {
            categoryChannels[catId].append(i);
        }
    }
    
    // Add uncategorized channels first
    for (int idx : uncategorizedChannels) {
        const QVariantMap& ch = m_channels[idx];
        DisplayItem item;
        item.id = extractId(ch);
        item.name = ch.value("name").toString();
        item.isCategory = false;
        item.channelType = ch.value("type").toString();
        item.categoryId = QString();
        item.position = ch.value("position", 0).toInt();
        item.icon = ch.value("icon").toString();
        item.description = ch.value("description").toString();
        item.expanded = false;
        m_displayItems.append(item);
    }
    
    // Add categories and their channels
    for (const QVariantMap& cat : m_categories) {
        QString catId = extractId(cat);
        
        // Add category header
        DisplayItem catItem;
        catItem.id = catId;
        catItem.name = cat.value("name").toString();
        catItem.isCategory = true;
        catItem.channelType = QString();
        catItem.categoryId = QString();
        catItem.position = cat.value("position", 0).toInt();
        catItem.icon = QString();
        catItem.description = QString();
        catItem.expanded = m_expandedState.value(catId, true);
        m_displayItems.append(catItem);
        
        // Add channels in this category
        if (categoryChannels.contains(catId)) {
            // Channels are already sorted, but let's ensure order within category
            QList<int>& channelIndices = categoryChannels[catId];
            std::sort(channelIndices.begin(), channelIndices.end(),
                      [this](int a, int b) {
                          return m_channels[a].value("position", 0).toInt() 
                               < m_channels[b].value("position", 0).toInt();
                      });
            
            for (int idx : channelIndices) {
                const QVariantMap& ch = m_channels[idx];
                DisplayItem item;
                item.id = extractId(ch);
                item.name = ch.value("name").toString();
                item.isCategory = false;
                item.channelType = ch.value("type").toString();
                item.categoryId = catId;
                item.position = ch.value("position", 0).toInt();
                item.icon = ch.value("icon").toString();
                item.description = ch.value("description").toString();
                item.expanded = false;
                m_displayItems.append(item);
            }
        }
    }
    
    endResetModel();
    emit countChanged();
}
