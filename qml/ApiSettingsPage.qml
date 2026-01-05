import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0

Page {
    id: apiSettingsPage
    
    header: PageHeader {
        id: header
        title: i18n.tr("API Settings")
        
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
    }
    
    ColumnLayout {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
        }
        spacing: units.gu(2)
        
        Label {
            text: i18n.tr("Server URL")
            fontSize: "small"
            font.bold: true
        }
        
        TextField {
            id: apiUrlField
            Layout.fillWidth: true
            text: SerchatAPI.apiBaseUrl
            placeholderText: i18n.tr("https://catfla.re")
            inputMethodHints: Qt.ImhUrlCharactersOnly
        }
        
        Label {
            text: i18n.tr("Only change this if you're connecting to a self-hosted Serchat instance.")
            fontSize: "x-small"
            color: Theme.palette.normal.backgroundSecondaryText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        
        Button {
            text: i18n.tr("Save")
            color: LomiriColors.blue
            Layout.fillWidth: true
            enabled: apiUrlField.text.trim().length > 0
            
            onClicked: {
                var url = apiUrlField.text.trim()
                // Remove trailing slash
                if (url.endsWith("/")) {
                    url = url.substring(0, url.length - 1)
                }
                SerchatAPI.apiBaseUrl = url
                pageStack.pop()
            }
        }
        
        Item { Layout.preferredHeight: units.gu(2) }
        
        // Preset servers
        Label {
            text: i18n.tr("Quick Presets")
            fontSize: "small"
            font.bold: true
        }
        
        Button {
            text: i18n.tr("Official Server")
            Layout.fillWidth: true
            onClicked: {
                apiUrlField.text = "https://catfla.re"
            }
        }
        
        Button {
            text: i18n.tr("Local Development")
            Layout.fillWidth: true
            onClicked: {
                apiUrlField.text = "http://localhost:8001"
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Connection test
        Label {
            text: i18n.tr("Connection Status")
            fontSize: "small"
            font.bold: true
        }
        
        Row {
            spacing: units.gu(1)
            Layout.fillWidth: true
            
            Rectangle {
                id: statusIndicator
                width: units.gu(1.5)
                height: units.gu(1.5)
                radius: width / 2
                color: connectionStatus === "connected" ? "#43b581" :
                       connectionStatus === "connecting" ? "#faa61a" : "#f04747"
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Label {
                text: connectionStatus === "connected" ? i18n.tr("Connected") :
                      connectionStatus === "connecting" ? i18n.tr("Connecting...") :
                      i18n.tr("Not connected")
                fontSize: "small"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        Button {
            text: i18n.tr("Test Connection")
            Layout.fillWidth: true
            onClicked: testConnection()
        }
    }
    
    property string connectionStatus: "unknown"
    
    function testConnection() {
        connectionStatus = "connecting"
        // TODO: Implement actual connection test
        // For now, just check if we're logged in
        Qt.callLater(function() {
            connectionStatus = SerchatAPI.loggedIn ? "connected" : "disconnected"
        })
    }
    
    Component.onCompleted: {
        connectionStatus = SerchatAPI.loggedIn ? "connected" : "disconnected"
    }
}
