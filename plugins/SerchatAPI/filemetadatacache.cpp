#include "filemetadatacache.h"
#include "api/apiclient.h"

#include <QDebug>
#include <QUrl>

FileMetadataCache::FileMetadataCache(QObject* parent)
    : QObject(parent)
{
}

void FileMetadataCache::setApiClient(ApiClient* apiClient)
{
    if (m_apiClient) {
        disconnect(m_apiClient, nullptr, this, nullptr);
    }

    m_apiClient = apiClient;

    if (m_apiClient) {
        connect(m_apiClient, &ApiClient::fileMetadataFetched,
                this, &FileMetadataCache::onFileMetadataFetched);
        connect(m_apiClient, &ApiClient::fileMetadataFetchFailed,
                this, &FileMetadataCache::onFileMetadataFetchFailed);
    }
}

QString FileMetadataCache::metadataKeyForUrl(const QString& downloadUrl) const
{
    if (downloadUrl.isEmpty()) {
        return QString();
    }

    QString path = downloadUrl;
    const QUrl url(downloadUrl);
    if (url.isValid() && !url.scheme().isEmpty()) {
        path = url.path();
    }

    const int queryStart = path.indexOf('?');
    if (queryStart >= 0) {
        path = path.left(queryStart);
    }

    const QString filename = path.section('/', -1);
    return QUrl::fromPercentEncoding(filename.toUtf8());
}

QVariantMap FileMetadataCache::getMetadataForUrl(const QString& downloadUrl)
{
    const QString filename = metadataKeyForUrl(downloadUrl);
    if (filename.isEmpty()) {
        return QVariantMap();
    }

    if (m_metadata.contains(filename)) {
        return m_metadata.value(filename);
    }

    fetchMetadataForUrl(downloadUrl);
    return QVariantMap();
}

bool FileMetadataCache::hasMetadataForUrl(const QString& downloadUrl) const
{
    const QString filename = metadataKeyForUrl(downloadUrl);
    return !filename.isEmpty() && m_metadata.contains(filename);
}

void FileMetadataCache::fetchMetadataForUrl(const QString& downloadUrl)
{
    const QString filename = metadataKeyForUrl(downloadUrl);
    if (filename.isEmpty()) {
        return;
    }

    if (m_metadata.contains(filename) || m_fetchingMetadata.contains(filename)) {
        return;
    }

    if (!m_apiClient) {
        qWarning() << "[FileMetadataCache] Cannot fetch metadata - no API client configured";
        return;
    }

    m_fetchingMetadata.insert(filename);
    const int requestId = m_apiClient->getFileMetadata(filename, true);
    m_pendingRequests.insert(requestId, filename);
}

void FileMetadataCache::clear()
{
    m_metadata.clear();
    m_pendingRequests.clear();
    m_fetchingMetadata.clear();
}

void FileMetadataCache::onFileMetadataFetched(int requestId, const QString& filename, const QVariantMap& metadata)
{
    QString trackedFilename = m_pendingRequests.take(requestId);
    if (trackedFilename.isEmpty()) {
        trackedFilename = filename;
    }
    if (trackedFilename.isEmpty()) {
        return;
    }

    m_fetchingMetadata.remove(trackedFilename);
    m_metadata.insert(trackedFilename, metadata);
    emit metadataLoaded(trackedFilename);
}

void FileMetadataCache::onFileMetadataFetchFailed(int requestId, const QString& filename, const QString& error)
{
    QString trackedFilename = m_pendingRequests.take(requestId);
    if (trackedFilename.isEmpty()) {
        trackedFilename = filename;
    }
    if (trackedFilename.isEmpty()) {
        return;
    }

    m_fetchingMetadata.remove(trackedFilename);
    emit metadataFetchFailed(trackedFilename, error);
}
