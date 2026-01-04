import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0

Page {
    id: joinServerPage
    
    header: PageHeader {
        id: header
        title: i18n.tr("Add a Server")
        
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
    }
    
    property bool joining: false
    
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
            text: i18n.tr("Join a Server")
            fontSize: "x-large"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        Label {
            text: i18n.tr("Enter an invite code or link to join an existing server")
            fontSize: "small"
            color: Theme.palette.normal.backgroundSecondaryText
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        
        Item { Layout.preferredHeight: units.gu(2) }
        
        // Invite code input
        Label {
            text: i18n.tr("Invite Code")
            fontSize: "small"
            font.bold: true
        }
        
        TextField {
            id: inviteCodeField
            Layout.fillWidth: true
            placeholderText: i18n.tr("Enter invite code or link")
            inputMethodHints: Qt.ImhNoAutoUppercase
        }
        
        Label {
            text: i18n.tr("Invites look like: abc123 or https://serchat.app/invite/abc123")
            fontSize: "x-small"
            color: Theme.palette.normal.backgroundSecondaryText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        
        Item { Layout.preferredHeight: units.gu(1) }
        
        Button {
            text: joining ? i18n.tr("Joining...") : i18n.tr("Join Server")
            color: LomiriColors.blue
            Layout.fillWidth: true
            enabled: inviteCodeField.text.trim().length > 0 && !joining
            
            onClicked: {
                var code = inviteCodeField.text.trim()
                // Extract code from URL if needed
                var urlMatch = code.match(/invite\/([a-zA-Z0-9]+)/)
                if (urlMatch) {
                    code = urlMatch[1]
                }
                joinServer(code)
            }
        }
        
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
        
        Item { Layout.preferredHeight: units.gu(2) }
        
        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: units.dp(1)
            color: Theme.palette.normal.base
        }
        
        Item { Layout.preferredHeight: units.gu(2) }
        
        // Create server option
        Label {
            text: i18n.tr("Or create your own")
            fontSize: "small"
            color: Theme.palette.normal.backgroundSecondaryText
            Layout.alignment: Qt.AlignHCenter
        }
        
        Button {
            text: i18n.tr("Create a Server")
            Layout.fillWidth: true
            
            onClicked: {
                pageStack.push(Qt.resolvedUrl("CreateServerPage.qml"))
            }
        }
        
        Item { Layout.fillHeight: true }
    }
    
    function joinServer(code) {
        joining = true
        errorLabel.text = ""
        // TODO: Implement actual join server API call
        console.log("Joining server with code:", code)
        
        // Simulate for now
        Qt.callLater(function() {
            joining = false
            // On success: pageStack.pop()
            errorLabel.text = i18n.tr("Server join not yet implemented")
        })
    }
}
