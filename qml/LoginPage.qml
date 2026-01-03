import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0

Page {
    id: loginPage
    header: PageHeader {
        id: header
        title: i18n.tr('Login')
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
            text: i18n.tr('Welcome to Serchat')
            fontSize: "large"
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: usernameField
            placeholderText: i18n.tr('Email/Login')
            Layout.fillWidth: true
        }

        TextField {
            id: passwordField
            placeholderText: i18n.tr('Password')
            echoMode: TextInput.Password
            Layout.fillWidth: true
        }

        Button {
            id: loginButton
            text: i18n.tr('Login')
            color: LomiriColors.orange
            Layout.fillWidth: true
            onClicked: {
                SerchatAPI.login(usernameField.text, passwordField.text)
            }
        }

        Label {
            id: errorLabel
            text: ""
            color: "red"
            visible: text !== ""
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Connections {
        target: SerchatAPI
        onLoginSuccessful: {
            pageStack.push(Qt.resolvedUrl("HomePage.qml"))
        }
        onLoginFailed: {
            errorLabel.text = reason
        }
    }
}
