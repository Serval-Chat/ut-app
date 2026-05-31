#ifndef FILEMETADATACACHE_H
#define FILEMETADATACACHE_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <QString>

class ApiClient;

class FileMetadataCache : public QObject {
    Q_OBJECT

public:
    explicit FileMetadataCache(QObject* parent = nullptr);
    ~FileMetadataCache() override = default;

    void setApiClient(ApiClient* apiClient);

    Q_INVOKABLE QString metadataKeyForUrl(const QString& downloadUrl) const;
    Q_INVOKABLE QVariantMap getMetadataForUrl(const QString& downloadUrl);
    Q_INVOKABLE bool hasMetadataForUrl(const QString& downloadUrl) const;
    Q_INVOKABLE void fetchMetadataForUrl(const QString& downloadUrl);

    void clear();

signals:
    void metadataLoaded(const QString& filename);
    void metadataFetchFailed(const QString& filename, const QString& error);

private slots:
    void onFileMetadataFetched(int requestId, const QString& filename, const QVariantMap& metadata);
    void onFileMetadataFetchFailed(int requestId, const QString& filename, const QString& error);

private:
    ApiClient* m_apiClient = nullptr;
    QHash<QString, QVariantMap> m_metadata;
    QHash<int, QString> m_pendingRequests;
    QSet<QString> m_fetchingMetadata;
};

#endif // FILEMETADATACACHE_H
