#ifndef IMAGECACHE_H
#define IMAGECACHE_H

#include <QQmlNetworkAccessManagerFactory>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QStandardPaths>

/**
 * @brief Custom QQmlNetworkAccessManagerFactory that enables disk caching for QML images.
 *
 * This factory creates QNetworkAccessManager instances with QNetworkDiskCache
 * configured, enabling persistent caching of network images loaded in QML.
 *
 * Usage:
 *   view->engine()->setNetworkAccessManagerFactory(new CachedNetworkAccessManagerFactory());
 */
class CachedNetworkAccessManagerFactory : public QQmlNetworkAccessManagerFactory {
public:
    QNetworkAccessManager* create(QObject* parent) override {
        QNetworkAccessManager* manager = new QNetworkAccessManager(parent);

        // Create disk cache in app's cache directory
        QNetworkDiskCache* diskCache = new QNetworkDiskCache(manager);
        QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/images";
        diskCache->setCacheDirectory(cacheDir);

        // Set max cache size to 50 MB
        diskCache->setMaximumCacheSize(50 * 1024 * 1024);

        manager->setCache(diskCache);

        return manager;
    }
};

#endif // IMAGECACHE_H
