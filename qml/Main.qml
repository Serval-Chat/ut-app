import QtQuick 2.7
import Lomiri.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0

import SerchatAPI 1.0

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'serchat.alexanderrichards'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    PageStack {
        id: pageStack
        anchors.fill: parent
        Component.onCompleted: {
            if(SerchatAPI.isLoggedIn())
                pageStack.push(Qt.resolvedUrl("HomePage.qml"))
            else
                pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
        }
    }
}
