import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0

Page {
    id: homePage
    header: PageHeader {
        id: header
        title: i18n.tr('Serchat')

        Button {
            id: debugButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: i18n.tr("Debug")
            onClicked: {
                pageStack.push(Qt.resolvedUrl("DebugPage.qml"))
            }
        }
    }

    ColumnLayout {
        spacing: units.gu(2)
        anchors {
            margins: units.gu(2)
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Item {
            Layout.fillHeight: true
        }

        Label {
            id: version
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            text: i18n.tr("Version %1").arg(Qt.application.version)
        }
    }
}
