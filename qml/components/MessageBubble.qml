import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MessageBubble - Displays a single chat message with swipe-to-reply
 */
Item {
    id: messageBubble
    
    property string messageId: ""
    property string senderId: ""
    property string senderName: ""
    property string senderAvatar: ""
    property string text: ""
    property string timestamp: ""
    property bool isOwn: false
    property bool isEdited: false
    property bool showAvatar: true  // False when grouping consecutive messages
    property bool isReply: false
    property string replyToText: ""
    property string replyToSender: ""
    property var reactions: []
    
    // Expose swipe state to parent for scroll locking
    property bool isSwipeActive: swipeArea.horizontalSwipeDetected
    
    signal avatarClicked(string senderId)
    signal replyRequested(string messageId, string messageText, string senderName)
    signal replyClicked()
    signal reactRequested(string messageId)
    signal reactionTapped(string messageId, string emoji, string emojiType, string emojiId)
    signal menuRequested(string messageId, string messageText, string senderName, string senderId, bool isOwn)
    signal copyRequested(string messageText)
    signal deleteRequested(string messageId)
    signal editRequested(string messageId, string messageText)
    
    width: parent ? parent.width : units.gu(40)
    height: swipeContainer.height
    
    // Swipe container for swipe-to-reply
    Item {
        id: swipeContainer
        width: parent.width
        height: contentRow.height + units.gu(0.5)
        
        // Background for visual feedback during swipe
        Rectangle {
            anchors.fill: parent
            color: swipeArea.isActive ? Qt.rgba(LomiriColors.blue.r, LomiriColors.blue.g, LomiriColors.blue.b, 0.1) : "transparent"
            
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
        
        // Reply indicator shown during swipe
        Item {
            id: replyIndicator
            anchors.right: parent.right
            anchors.rightMargin: units.gu(2)
            anchors.verticalCenter: parent.verticalCenter
            width: units.gu(4)
            height: units.gu(4)
            opacity: Math.min(1, Math.abs(contentRow.x) / units.gu(8))
            visible: contentRow.x < 0
            
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: LomiriColors.blue
                opacity: 0.2
            }
            
            Icon {
                anchors.centerIn: parent
                width: units.gu(2.5)
                height: units.gu(2.5)
                name: "mail-reply"
                color: LomiriColors.blue
            }
        }
        
        Row {
            id: contentRow
            x: 0
            z: 2  // Above swipeArea (z:1) so clicks reach interactive elements
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: units.gu(1.5)
            anchors.rightMargin: units.gu(1.5)
            width: parent.width - units.gu(3)
            spacing: units.gu(1)
            
            Behavior on x {
                NumberAnimation { 
                    duration: 200 
                    easing.type: Easing.OutCubic 
                }
            }
            
            // Avatar column
            Item {
                width: units.gu(4.5)
                height: showAvatar ? units.gu(4.5) : units.gu(0.5)
                
                Avatar {
                    id: avatar
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(4)
                    height: units.gu(4)
                    name: senderName
                    source: senderAvatar
                    visible: showAvatar
                }
                
                // Separate MouseArea with high z to capture clicks
                MouseArea {
                    anchors.fill: parent
                    visible: showAvatar
                    onClicked: avatarClicked(senderId)
                }
            }
            
            // Message content column
            Column {
                id: contentColumn
                width: parent.width - units.gu(6)
                spacing: units.gu(0.3)
                
                // Header (sender name + timestamp)
                Row {
                    spacing: units.gu(1)
                    visible: showAvatar
                    
                    // Name with clickable area
                    Item {
                        width: nameLabel.width
                        height: nameLabel.height
                        
                        Label {
                            id: nameLabel
                            text: senderName
                            font.bold: true
                            fontSize: "small"
                            color: isOwn ? LomiriColors.blue : Theme.palette.normal.baseText
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            z: 10
                            cursorShape: Qt.PointingHandCursor
                            onClicked: avatarClicked(senderId)
                        }
                    }
                    
                    Label {
                        id: timestampLabel
                        text: SerchatAPI.markdownParser.formatTimestamp(timestamp)
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
                
                // Reply preview if this is a reply
                Rectangle {
                    id: replyContainer
                    width: parent.width
                    height: replyColumn.height + units.gu(1)
                    visible: isReply && replyToText !== ""
                    color: Qt.rgba(Theme.palette.normal.base.r, 
                                  Theme.palette.normal.base.g, 
                                  Theme.palette.normal.base.b, 0.3)
                    radius: units.gu(0.5)
                    
                    Rectangle {
                        width: units.gu(0.4)
                        height: parent.height
                        color: LomiriColors.blue
                        radius: units.gu(0.2)
                    }
                    
                    Column {
                        id: replyColumn
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1.5)
                        anchors.right: parent.right
                        anchors.rightMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.2)
                        
                        Label {
                            text: replyToSender
                            fontSize: "x-small"
                            font.bold: true
                            color: LomiriColors.blue
                        }
                        
                        Label {
                            text: replyToText.length > 100 ? replyToText.substring(0, 100) + "..." : replyToText
                            fontSize: "x-small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: replyClicked()
                    }
                }
                
                // Message text with markdown rendering
                Components.MarkdownText {
                    id: messageText
                    width: parent.width
                    text: messageBubble.text
                    fontSize: "small"
                    textColor: Theme.palette.normal.baseText
                    
                    onUserMentionClicked: {
                        // Bubble up to parent - open profile for mentioned user
                        messageBubble.avatarClicked(userId)
                    }
                }
                
                // Edited indicator
                Label {
                    text: i18n.tr("(edited)")
                    fontSize: "x-small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    visible: isEdited
                }
                
                // Reactions row
                Flow {
                    id: reactionsFlow
                    width: parent.width
                    spacing: units.gu(0.5)
                    visible: reactions.length > 0
                    
                    Repeater {
                        model: reactions
                        
                        Rectangle {
                            width: reactionRow.width + units.gu(1)
                            height: units.gu(2.5)
                            radius: units.gu(0.5)
                            color: modelData.hasReacted ? 
                                   Qt.rgba(LomiriColors.blue.r, LomiriColors.blue.g, LomiriColors.blue.b, 0.3) :
                                   Qt.rgba(Theme.palette.normal.base.r,
                                          Theme.palette.normal.base.g,
                                          Theme.palette.normal.base.b, 0.5)
                            border.width: modelData.hasReacted ? units.dp(1) : 0
                            border.color: LomiriColors.blue
                            
                            Row {
                                id: reactionRow
                                anchors.centerIn: parent
                                spacing: units.gu(0.3)
                                
                                // Custom emoji image or unicode emoji
                                Item {
                                    width: units.gu(2)
                                    height: units.gu(2)
                                    
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.emojiUrl ? 
                                                (SerchatAPI.apiBaseUrl + modelData.emojiUrl) : ""
                                        visible: modelData.emojiType === "custom" && modelData.emojiUrl
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: modelData.emoji || ""
                                        fontSize: "small"
                                        visible: modelData.emojiType !== "custom" || !modelData.emojiUrl
                                    }
                                }
                                
                                Label {
                                    text: modelData.count ? modelData.count.toString() : "1"
                                    fontSize: "x-small"
                                    color: Theme.palette.normal.backgroundSecondaryText
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    reactionTapped(messageId, modelData.emoji || "", 
                                                   modelData.emojiType || "unicode",
                                                   modelData.emojiId || "")
                                }
                            }
                        }
                    }
                    
                    // Add reaction button
                    Rectangle {
                        width: units.gu(3)
                        height: units.gu(2.5)
                        radius: units.gu(0.5)
                        color: addReactionMA.pressed ? Theme.palette.normal.base : "transparent"
                        border.width: units.dp(1)
                        border.color: Theme.palette.normal.base
                        
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(1.5)
                            height: units.gu(1.5)
                            name: "add"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        MouseArea {
                            id: addReactionMA
                            anchors.fill: parent
                            onClicked: reactRequested(messageId)
                        }
                    }
                }
            }
        }
        
        // Swipe area for swipe-to-reply
        MouseArea {
            id: swipeArea
            anchors.fill: parent
            z: 1  // Below interactive elements
            
            // Allow clicks to pass through to children
            propagateComposedEvents: true
            
            property real startX: 0
            property real startY: 0
            property bool isActive: false
            property bool swipeTriggered: false
            property bool horizontalSwipeDetected: false
            property bool longPressTriggered: false
            
            onPressed: {
                startX = mouse.x
                startY = mouse.y
                isActive = false
                swipeTriggered = false
                horizontalSwipeDetected = false
                longPressTriggered = false
            }
            
            onPositionChanged: {
                var deltaX = mouse.x - startX
                var deltaY = mouse.y - startY
                
                // Detect if this is primarily a horizontal swipe
                // Only lock in once we've moved enough in one direction
                if (!horizontalSwipeDetected && !isActive) {
                    if (Math.abs(deltaX) > units.gu(1.5) && Math.abs(deltaX) > Math.abs(deltaY) * 2) {
                        horizontalSwipeDetected = true
                        isActive = true
                    }
                }
                
                if (!isActive) return
                
                // Only allow left swipe (negative delta) for reply
                if (deltaX < 0) {
                    // Limit the swipe distance
                    contentRow.x = Math.max(deltaX, -units.gu(12))
                    
                    // Check if swipe threshold reached
                    if (deltaX < -units.gu(8) && !swipeTriggered) {
                        swipeTriggered = true
                    }
                }
            }
            
            onReleased: {
                if (swipeTriggered) {
                    // Trigger reply
                    replyRequested(messageId, messageBubble.text, senderName)
                    mouse.accepted = true
                } else if (!horizontalSwipeDetected && !longPressTriggered) {
                    // Not a swipe or long press, let the click propagate
                    mouse.accepted = false
                }
                
                // Animate back to original position
                contentRow.x = 0
                isActive = false
                horizontalSwipeDetected = false
            }
            
            onCanceled: {
                contentRow.x = 0
                isActive = false
                horizontalSwipeDetected = false
            }
            
            // Simple clicks should propagate through
            onClicked: {
                mouse.accepted = false
            }
            
            // Long press for context menu (bottom sheet)
            onPressAndHold: {
                longPressTriggered = true
                isActive = false
                contentRow.x = 0
                horizontalSwipeDetected = false
                menuRequested(messageId, messageBubble.text, senderName, senderId, isOwn)
            }
        }
    }
    
}
