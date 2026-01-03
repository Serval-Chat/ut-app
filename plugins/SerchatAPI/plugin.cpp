#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "serchatapi.h"

void SerchatAPIPlugin::registerTypes(const char *uri) {
    //@uri SerchatAPI
    qmlRegisterSingletonType<SerchatAPI>(uri, 1, 0, "SerchatAPI", [](QQmlEngine*, QJSEngine*) -> QObject* { return new SerchatAPI; });
}
