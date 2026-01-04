import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0

Page {
    id: createServerPage
    
    header: PageHeader {
        id: header
        title: i18n.tr("Create a Server")
        
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
    }
    
    property bool creating: false
    
    ColumnLayout {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
        }
        spacing: units.gu(2)
        
        // Header
        Label {
            text: i18n.tr("Customize your server")
            fontSize: "x-large"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        Label {
            text: i18n.tr("Give your new server a personality with a name and an icon. You can always change these later.")
            fontSize: "small"
            color: Theme.palette.normal.backgroundSecondaryText
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        
        Item { Layout.preferredHeight: units.gu(2) }
        
        // Server icon placeholder
        Rectangle {
            Layout.preferredWidth: units.gu(10)
            Layout.preferredHeight: units.gu(10)
            Layout.alignment: Qt.AlignHCenter
            radius: width / 2
            color: Theme.palette.normal.base
            border.width: units.dp(2)
            border.color: Theme.palette.normal.backgroundSecondaryText
            border.style: Qt.DashLine
            
            Column {
                anchors.centerIn: parent
                spacing: units.gu(0.5)
                
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(3)
                    height: units.gu(3)
                    name: "camera-app-symbolic"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    text: i18n.tr("Upload")
                    fontSize: "x-small"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // TODO: Open image picker
                }
            }
        }
        
        Item { Layout.preferredHeight: units.gu(2) }
        
        // Server name input
        Label {
            text: i18n.tr("Server Name")
            fontSize: "small"
            font.bold: true
        }
        
        TextField {
            id: serverNameField
            Layout.fillWidth: true
            placeholderText: i18n.tr("My Awesome Server")
        }
        
        Label {
            text: i18n.tr("By creating a server, you agree to Serchat's Community Guidelines")
            fontSize: "x-small"
            color: Theme.palette.normal.backgroundSecondaryText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        
        Item { Layout.fillHeight: true }
        
        // Error message
        Label {
            id: errorLabel
            text: ""
            color: LomiriColors.red
            visible: text !== ""
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        
        // Create button
        Button {
            text: creating ? i18n.tr("Creating...") : i18n.tr("Create Server")
            color: LomiriColors.blue
            Layout.fillWidth: true
            enabled: serverNameField.text.trim().length > 0 && !creating
            
            onClicked: {
                createServer(serverNameField.text.trim())
            }
        }
    }
    
    function createServer(name) {
        creating = true
        errorLabel.text = ""
        // TODO: Implement actual create server API call
        console.log("Creating server:", name)
        
        // Simulate for now
        Qt.callLater(function() {
            creating = false
            errorLabel.text = i18n.tr("Server creation not yet implemented")
        })
    }
}
