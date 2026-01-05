import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MessageActionSheet - Bottom sheet popup for message actions
 * 
 * Shows actions like Reply, React, Copy, Edit, Delete in a bottom sheet
 * similar to UserProfileSheet.
 */
Item {
    id: messageActionSheet
    
    // Message properties
    property string messageId: ""
    property string messageText: ""
    property string senderName: ""
    property string senderId: ""
    property bool isOwnMessage: false
    
    // Whether the sheet is currently visible
    property bool opened: false
    
    signal replyClicked(string messageId, string messageText, string senderName)
    signal reactClicked(string messageId)
    signal emojiSelected(string messageId, string emoji, bool isCustom, string emojiId)
    signal copyClicked(string messageText)
    signal editClicked(string messageId, string messageText)
    signal deleteClicked(string messageId)
    signal closed()
    
    // Cover the full parent area
    anchors.fill: parent
    visible: opened
    z: 1000
    
    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: opened ? 0.4 : 0
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: close()
        }
    }
    
    // Sheet container
    Rectangle {
        id: sheet
        width: parent.width
        height: Math.min(sheetContent.height + units.gu(2), parent.height * 0.8)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: opened ? 0 : -height
        radius: units.gu(2)
        color: Theme.palette.normal.background
        
        // Top rounded corners only
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.radius
            color: parent.color
        }
        
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        
        // Handle bar
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: units.gu(1)
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(5)
            height: units.gu(0.5)
            radius: height / 2
            color: Theme.palette.normal.base
        }
        
        // Sheet content
        Column {
            id: sheetContent
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: units.gu(2.5)
            spacing: units.gu(1.5)
            
            // Message preview
            Rectangle {
                width: parent.width - units.gu(4)
                anchors.horizontalCenter: parent.horizontalCenter
                height: previewColumn.height + units.gu(2)
                radius: units.gu(1)
                color: Theme.palette.normal.base
                
                Column {
                    id: previewColumn
                    width: parent.width - units.gu(2)
                    anchors.centerIn: parent
                    spacing: units.gu(0.5)
                    
                    Label {
                        text: senderName
                        fontSize: "small"
                        font.bold: true
                        color: Theme.palette.normal.baseText
                    }
                    
                    Label {
                        text: messageText.length > 100 ? messageText.substring(0, 100) + "..." : messageText
                        fontSize: "small"
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
            }
            
            // Quick reactions row
            Rectangle {
                width: parent.width - units.gu(4)
                anchors.horizontalCenter: parent.horizontalCenter
                height: units.gu(6)
                radius: units.gu(1)
                color: Theme.palette.normal.base
                
                Row {
                    anchors.centerIn: parent
                    spacing: units.gu(2)
                    
                    // Common quick reactions
                    Repeater {
                        model: ["👍", "❤️", "😂", "😮", "😢", "🎉"]
                        
                        Rectangle {
                            width: units.gu(5)
                            height: units.gu(5)
                            radius: width / 2
                            color: quickReactionMA.pressed ? 
                                   Qt.darker(Theme.palette.normal.base, 1.1) : "transparent"
                            
                            Label {
                                anchors.centerIn: parent
                                text: modelData
                                fontSize: "large"
                            }
                            
                            MouseArea {
                                id: quickReactionMA
                                anchors.fill: parent
                                onClicked: {
                                    emojiSelected(messageId, modelData, false, "")
                                    close()
                                }
                            }
                        }
                    }
                }
            }
            
            // Divider
            Rectangle {
                width: parent.width - units.gu(4)
                anchors.horizontalCenter: parent.horizontalCenter
                height: units.dp(1)
                color: Theme.palette.normal.base
            }
            
            // Action buttons
            Column {
                width: parent.width - units.gu(4)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                
                // Reply action
                Rectangle {
                    width: parent.width
                    height: units.gu(6)
                    color: replyMA.pressed ? Theme.palette.normal.base : "transparent"
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(2)
                        
                        Icon {
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: "mail-reply"
                            color: Theme.palette.normal.baseText
                        }
                        
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n.tr("Reply")
                            fontSize: "medium"
                            color: Theme.palette.normal.baseText
                        }
                    }
                    
                    MouseArea {
                        id: replyMA
                        anchors.fill: parent
                        onClicked: {
                            close()
                            replyClicked(messageId, messageText, senderName)
                        }
                    }
                }
                
                // React action (opens emoji picker)
                Rectangle {
                    width: parent.width
                    height: units.gu(6)
                    color: reactMA.pressed ? Theme.palette.normal.base : "transparent"
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(2)
                        
                        Icon {
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: "like"
                            color: Theme.palette.normal.baseText
                        }
                        
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n.tr("Add Reaction")
                            fontSize: "medium"
                            color: Theme.palette.normal.baseText
                        }
                    }
                    
                    MouseArea {
                        id: reactMA
                        anchors.fill: parent
                        onClicked: {
                            close()
                            reactClicked(messageId)
                        }
                    }
                }
                
                // Copy action
                Rectangle {
                    width: parent.width
                    height: units.gu(6)
                    color: copyMA.pressed ? Theme.palette.normal.base : "transparent"
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(2)
                        
                        Icon {
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: "edit-copy"
                            color: Theme.palette.normal.baseText
                        }
                        
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n.tr("Copy Text")
                            fontSize: "medium"
                            color: Theme.palette.normal.baseText
                        }
                    }
                    
                    MouseArea {
                        id: copyMA
                        anchors.fill: parent
                        onClicked: {
                            Clipboard.push(messageText)
                            close()
                            copyClicked(messageText)
                        }
                    }
                }
                
                // Edit action (only for own messages)
                Rectangle {
                    width: parent.width
                    height: units.gu(6)
                    color: editMA.pressed ? Theme.palette.normal.base : "transparent"
                    visible: isOwnMessage
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(2)
                        
                        Icon {
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: "edit"
                            color: Theme.palette.normal.baseText
                        }
                        
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n.tr("Edit Message")
                            fontSize: "medium"
                            color: Theme.palette.normal.baseText
                        }
                    }
                    
                    MouseArea {
                        id: editMA
                        anchors.fill: parent
                        onClicked: {
                            close()
                            editClicked(messageId, messageText)
                        }
                    }
                }
                
                // Delete action (only for own messages)
                Rectangle {
                    width: parent.width
                    height: units.gu(6)
                    color: deleteMA.pressed ? Theme.palette.normal.base : "transparent"
                    visible: isOwnMessage
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(2)
                        
                        Icon {
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: "delete"
                            color: LomiriColors.red
                        }
                        
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n.tr("Delete Message")
                            fontSize: "medium"
                            color: LomiriColors.red
                        }
                    }
                    
                    MouseArea {
                        id: deleteMA
                        anchors.fill: parent
                        onClicked: {
                            close()
                            deleteClicked(messageId)
                        }
                    }
                }
            }
            
            // Bottom padding
            Item {
                width: parent.width
                height: units.gu(2)
            }
        }
        
        // Drag to dismiss
        MouseArea {
            id: dragArea
            anchors.fill: parent
            propagateComposedEvents: true
            
            property real startY: 0
            property real currentOffset: 0
            
            onPressed: {
                startY = mouse.y
                currentOffset = 0
            }
            
            onPositionChanged: {
                currentOffset = mouse.y - startY
                if (currentOffset > 0) {
                    sheet.anchors.bottomMargin = -currentOffset
                }
            }
            
            onReleased: {
                if (currentOffset > units.gu(10)) {
                    close()
                } else {
                    sheet.anchors.bottomMargin = 0
                }
            }
            
            onClicked: mouse.accepted = false
        }
    }
    
    // Open the sheet for a message
    function open(msgId, msgText, sender, senderUserId, isOwn) {
        messageId = msgId
        messageText = msgText
        senderName = sender
        senderId = senderUserId
        isOwnMessage = isOwn
        opened = true
    }
    
    // Close the sheet
    function close() {
        opened = false
        closed()
    }
}
