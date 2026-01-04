#ifndef GENERICLISTMODEL_H
#define GENERICLISTMODEL_H

#include <QAbstractListModel>
#include <QVariantMap>
#include <QVariantList>
#include <QHash>

/**
 * @brief A generic C++ list model for QML.
 * 
 * This model can be used for servers, channels, members, friends, etc.
 * It provides:
 * - Proper QAbstractListModel signals (preserves scroll position)
 * - O(1) item lookup by ID
 * - Dynamic role names (configurable per instance)
 * - Efficient batch operations
 * 
 * Usage in QML:
 *   ListView {
 *       model: SerchatAPI.serversModel
 *       delegate: ServerItem {
 *           name: model.name
 *           icon: model.icon
 *       }
 *   }
 */
class GenericListModel : public QAbstractListModel {
    Q_OBJECT
    
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString idField READ idField WRITE setIdField NOTIFY idFieldChanged)

public:
    explicit GenericListModel(QObject *parent = nullptr);
    explicit GenericListModel(const QString& idField, QObject *parent = nullptr);
    ~GenericListModel() override;

    // QAbstractListModel implementation
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    
    // Properties
    int count() const { return m_items.count(); }
    QString idField() const { return m_idField; }
    void setIdField(const QString& field);
    
    // ========================================================================
    // Data Operations
    // ========================================================================
    
    /**
     * @brief Set all items at once (replaces existing).
     * More efficient than clear() + append() for initial load.
     */
    Q_INVOKABLE void setItems(const QVariantList& items);
    
    /**
     * @brief Clear all items.
     */
    Q_INVOKABLE void clear();
    
    /**
     * @brief Append a single item.
     */
    Q_INVOKABLE void append(const QVariantMap& item);
    
    /**
     * @brief Append multiple items.
     */
    Q_INVOKABLE void appendItems(const QVariantList& items);
    
    /**
     * @brief Prepend a single item.
     */
    Q_INVOKABLE void prepend(const QVariantMap& item);
    
    /**
     * @brief Insert item at index.
     */
    Q_INVOKABLE void insert(int index, const QVariantMap& item);
    
    /**
     * @brief Update an existing item by ID.
     * Returns true if item was found and updated.
     */
    Q_INVOKABLE bool updateItem(const QString& id, const QVariantMap& item);
    
    /**
     * @brief Update a single property of an item.
     * More efficient than updateItem for single-field updates.
     */
    Q_INVOKABLE bool updateItemProperty(const QString& id, const QString& property, const QVariant& value);
    
    /**
     * @brief Remove an item by ID.
     * Returns true if item was found and removed.
     */
    Q_INVOKABLE bool removeItem(const QString& id);
    
    /**
     * @brief Remove item at index.
     */
    Q_INVOKABLE void removeAt(int index);
    
    /**
     * @brief Check if an item exists by ID.
     */
    Q_INVOKABLE bool contains(const QString& id) const;
    
    /**
     * @brief Get item by ID.
     */
    Q_INVOKABLE QVariantMap get(const QString& id) const;
    
    /**
     * @brief Get item at index.
     */
    Q_INVOKABLE QVariantMap getAt(int index) const;
    
    /**
     * @brief Get index of item by ID.
     * Returns -1 if not found.
     */
    Q_INVOKABLE int indexOf(const QString& id) const;
    
    /**
     * @brief Move item from one position to another.
     */
    Q_INVOKABLE void move(int from, int to);
    
    /**
     * @brief Get all items as a list.
     */
    Q_INVOKABLE QVariantList toList() const;
    
    // ========================================================================
    // Role Management
    // ========================================================================
    
    /**
     * @brief Set role names dynamically.
     * Keys are role names, values are the property keys in item maps.
     * Call this before setting any data.
     */
    void setRoleMapping(const QHash<QString, QString>& mapping);
    
    /**
     * @brief Auto-detect roles from first item's keys.
     * Useful when item structure is not known in advance.
     */
    Q_INVOKABLE void autoDetectRoles(const QVariantMap& sampleItem);

signals:
    void countChanged();
    void idFieldChanged();
    void itemAdded(const QString& id, int index);
    void itemUpdated(const QString& id);
    void itemRemoved(const QString& id);

private:
    QString m_idField;
    QList<QVariantMap> m_items;
    QHash<QString, int> m_idToIndex;
    
    // Role management
    QHash<int, QByteArray> m_roleNames;
    QHash<int, QString> m_roleToKey;  // Maps role enum to item key
    int m_nextRole;
    
    QString extractId(const QVariantMap& item) const;
    void rebuildIndexMap();
    void ensureRolesFromItem(const QVariantMap& item);
};

#endif // GENERICLISTMODEL_H
