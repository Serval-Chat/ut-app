#include <QGuiApplication>
#include <QCoreApplication>
#include <QUrl>
#include <QString>
#include <QQuickView>
#include <QQmlEngine>

#include "imagecache.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = new QGuiApplication(argc, (char**)argv);
    app->setApplicationName("serchat.alexanderrichards");
    app->setApplicationVersion(QStringLiteral(BUILD_VERSION));

    qDebug() << "Starting app from main.cpp";

    QQuickView *view = new QQuickView();

    // Enable disk caching for network images (avatars, emojis, etc.)
    view->engine()->setNetworkAccessManagerFactory(new CachedNetworkAccessManagerFactory());

    view->setSource(QUrl("qrc:/Main.qml"));
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->show();

    return app->exec();
}
