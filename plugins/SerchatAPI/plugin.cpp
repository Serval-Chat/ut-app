#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "serchatapi.h"
#include "models/messagemodel.h"
#include "models/genericlistmodel.h"

void SerchatAPIPlugin::registerTypes(const char *uri) {
    //@uri SerchatAPI
    
    // Register the main API singleton
    qmlRegisterSingletonType<SerchatAPI>(uri, 1, 0, "SerchatAPI", [](QQmlEngine*, QJSEngine*) -> QObject* { return new SerchatAPI; });
    
    // Register model types so they can be used in QML property declarations
    // These are exposed via the SerchatAPI singleton properties, not instantiated directly
    qmlRegisterUncreatableType<MessageModel>(uri, 1, 0, "MessageModel",
        "MessageModel is accessed via SerchatAPI.messageModel");
    qmlRegisterUncreatableType<GenericListModel>(uri, 1, 0, "GenericListModel",
        "GenericListModel is accessed via SerchatAPI model properties");
}
