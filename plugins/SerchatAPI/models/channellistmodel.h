#ifndef CHANNELLISTMODEL_H
#define CHANNELLISTMODEL_H

#include <QAbstractListModel>
#include <QVariantMap>
#include <QVariantList>
#include <QHash>

/**
 * @brief A hierarchical model for channels with category grouping.
 * 
 * This model presents a flat list to QML but internally manages:
 * - Categories as expandable headers
 * - Channels sorted within their categories
 * - Uncategorized channels at the top
 * - Real-time updates for add/remove/reorder operations
 * 
 * The model maintains proper ordering based on position fields and
 * handles dynamic updates without full model resets where possible.
 * 
 * Model roles:
 * - itemId: The _id of the channel or category
 * - name: Display name
 * - itemType: "channel" or "category"
 * - channelType: "text", "voice", etc. (only for channels)
 * - categoryId: Parent category ID (null for uncategorized/categories)
 * - position: Sort position
 * - icon: Custom icon name
 * - description: Channel description
 * - expanded: Whether category is expanded (only for categories)
 */
class ChannelListModel : public QAbstractListModel {
    Q_OBJECT
    
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString serverId READ serverId WRITE setServerId NOTIFY serverIdChanged)

public:
    enum Roles {
        ItemIdRole = Qt::UserRole + 1,
        NameRole,
        ItemTypeRole,      // "channel" or "category"
        ChannelTypeRole,   // "text", "voice", etc.
        CategoryIdRole,    // Parent category ID
        PositionRole,
        IconRole,
        DescriptionRole,
        ExpandedRole,      // For categories
        VisibleRole        // Whether item should be shown (respects category expansion)
    };
    Q_ENUM(Roles)

    explicit ChannelListModel(QObject *parent = nullptr);
    ~ChannelListModel() override;

    // QAbstractListModel implementation
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    
    // Properties
    int count() const { return m_displayItems.count(); }
    QString serverId() const { return m_serverId; }
    void setServerId(const QString& id);
    
    // ========================================================================
    // Data Operations
    // ========================================================================
    
    /**
     * @brief Set all categories at once.
     */
    Q_INVOKABLE void setCategories(const QVariantList& categories);
    
    /**
     * @brief Set all channels at once.
     */
    Q_INVOKABLE void setChannels(const QVariantList& channels);
    
    /**
     * @brief Clear all data.
     */
    Q_INVOKABLE void clear();
    
    /**
     * @brief Add a single category.
     */
    Q_INVOKABLE void addCategory(const QVariantMap& category);
    
    /**
     * @brief Update a category.
     */
    Q_INVOKABLE bool updateCategory(const QString& categoryId, const QVariantMap& category);
    
    /**
     * @brief Remove a category (channels become uncategorized).
     */
    Q_INVOKABLE bool removeCategory(const QString& categoryId);
    
    /**
     * @brief Add a single channel.
     */
    Q_INVOKABLE void addChannel(const QVariantMap& channel);
    
    /**
     * @brief Update a channel.
     */
    Q_INVOKABLE bool updateChannel(const QString& channelId, const QVariantMap& channel);
    
    /**
     * @brief Remove a channel.
     */
    Q_INVOKABLE bool removeChannel(const QString& channelId);
    
    /**
     * @brief Toggle category expansion state.
     */
    Q_INVOKABLE void toggleCategoryExpanded(const QString& categoryId);
    
    /**
     * @brief Set category expansion state.
     */
    Q_INVOKABLE void setCategoryExpanded(const QString& categoryId, bool expanded);
    
    /**
     * @brief Check if a category is expanded.
     */
    Q_INVOKABLE bool isCategoryExpanded(const QString& categoryId) const;
    
    /**
     * @brief Get channel by ID.
     */
    Q_INVOKABLE QVariantMap getChannel(const QString& channelId) const;
    
    /**
     * @brief Get category by ID.
     */
    Q_INVOKABLE QVariantMap getCategory(const QString& categoryId) const;
    
    /**
     * @brief Get all categories as a list.
     */
    Q_INVOKABLE QVariantList allCategories() const;
    
    /**
     * @brief Get all channels as a list.
     */
    Q_INVOKABLE QVariantList allChannels() const;

signals:
    void countChanged();
    void serverIdChanged();
    void categoryAdded(const QString& categoryId);
    void categoryUpdated(const QString& categoryId);
    void categoryRemoved(const QString& categoryId);
    void channelAdded(const QString& channelId);
    void channelUpdated(const QString& channelId);
    void channelRemoved(const QString& channelId);

private:
    // Internal data structure for display items
    struct DisplayItem {
        QString id;
        QString name;
        bool isCategory;
        QString channelType;      // For channels
        QString categoryId;       // For channels - parent category
        int position;
        QString icon;
        QString description;
        bool expanded;            // For categories
    };
    
    QString m_serverId;
    
    // Raw data storage
    QList<QVariantMap> m_categories;
    QList<QVariantMap> m_channels;
    QHash<QString, int> m_categoryIdToIndex;
    QHash<QString, int> m_channelIdToIndex;
    
    // Category expansion state (persists across rebuilds)
    QHash<QString, bool> m_expandedState;
    
    // Flattened display list
    QList<DisplayItem> m_displayItems;
    
    // Helper methods
    void rebuildDisplayList();
    QString extractId(const QVariantMap& item) const;
    int findDisplayIndex(const QString& id, bool isCategory) const;
    void sortCategories();
    void sortChannels();
};

#endif // CHANNELLISTMODEL_H
