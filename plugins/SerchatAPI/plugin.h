#ifndef SERCHATAPI_PLUGIN_H
#define SERCHATAPI_PLUGIN_H

#include <QQmlExtensionPlugin>

class SerchatAPIPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri);
};

#endif
