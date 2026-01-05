#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "serchatapi.h"
#include "models/messagemodel.h"
#include "models/genericlistmodel.h"
#include "models/channellistmodel.h"
#include "emojicache.h"
#include "userprofilecache.h"
#include "markdownparser.h"

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
    qmlRegisterUncreatableType<ChannelListModel>(uri, 1, 0, "ChannelListModel",
        "ChannelListModel is accessed via SerchatAPI.channelListModel");
    
    // Register cache types for global emoji and user profile caching
    qmlRegisterUncreatableType<EmojiCache>(uri, 1, 0, "EmojiCache",
        "EmojiCache is accessed via SerchatAPI.emojiCache");
    qmlRegisterUncreatableType<UserProfileCache>(uri, 1, 0, "UserProfileCache",
        "UserProfileCache is accessed via SerchatAPI.userProfileCache");

    // Register markdown parser for text rendering (accessed via SerchatAPI)
    qmlRegisterUncreatableType<MarkdownParser>(uri, 1, 0, "MarkdownParser",
        "MarkdownParser is accessed via SerchatAPI.markdownParser");
}
