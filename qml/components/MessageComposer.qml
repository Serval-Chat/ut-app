import QtQuick 2.7
import Lomiri.Components 1.3
import "." as Components

/*
 * MessageComposer - Text input with send button and optional attachment/emoji pickers
 */
Item {
    id: composer
    
    property string placeholderText: i18n.tr("Send a message...")
    property string text: inputField.text
    property bool enabled: true
    property bool showAttachmentButton: true
    property bool showEmojiButton: true
    property alias textField: inputField
    
    // Custom emojis for the server (passed from parent)
    property var customEmojis: ({})
    
    // Reply state
    property bool isReplying: false
    property string replyToMessageId: ""
    property string replyToSenderName: ""
    property string replyToText: ""
    
    signal sendMessage(string message, string replyToId)
    signal attachmentClicked()
    signal emojiClicked()
    signal cancelReply()
    
    width: parent ? parent.width : units.gu(40)
    height: contentColumn.height
    
    Column {
        id: contentColumn
        width: parent.width
        spacing: 0
        
        // Reply preview bar
        Rectangle {
            id: replyBar
            width: parent.width
            height: isReplying ? replyContent.height + units.gu(1.5) : 0
            color: Theme.palette.normal.base
            visible: isReplying
            clip: true
            
            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            Rectangle {
                id: replyAccent
                width: units.gu(0.4)
                height: parent.height
                color: LomiriColors.blue
            }
            
            Column {
                id: replyContent
                anchors.left: replyAccent.right
                anchors.leftMargin: units.gu(1)
                anchors.right: closeReplyButton.left
                anchors.rightMargin: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(0.2)
                
                Label {
                    text: i18n.tr("Replying to %1").arg(replyToSenderName)
                    fontSize: "x-small"
                    font.bold: true
                    color: LomiriColors.blue
                }
                
                Label {
                    text: replyToText.length > 100 ? replyToText.substring(0, 100) + "..." : replyToText
                    fontSize: "x-small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
            
            AbstractButton {
                id: closeReplyButton
                width: units.gu(4)
                height: parent.height
                anchors.right: parent.right
                
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2)
                    height: units.gu(2)
                    name: "close"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                onClicked: {
                    isReplying = false
                    replyToMessageId = ""
                    replyToSenderName = ""
                    replyToText = ""
                    cancelReply()
                }
            }
        }
        
        // Main composer row
        Rectangle {
            width: parent.width
            height: inputRow.height + units.gu(1.5)
            color: Theme.palette.normal.base
            
            Row {
                id: inputRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: units.gu(1)
                anchors.rightMargin: units.gu(1)
                spacing: units.gu(0.5)
                
                // Attachment button
                AbstractButton {
                    id: attachmentButton
                    width: units.gu(4)
                    height: units.gu(4)
                    visible: showAttachmentButton
                    enabled: composer.enabled
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "add"
                        color: enabled ? Theme.palette.normal.backgroundSecondaryText : 
                               Theme.palette.disabled.backgroundSecondaryText
                    }
                    
                    onClicked: attachmentClicked()
                }
                
                // Text input
                TextField {
                    id: inputField
                    width: parent.width - attachmentButton.width - emojiButton.width - sendButton.width - units.gu(2)
                    placeholderText: composer.placeholderText
                    enabled: composer.enabled
                    
                    // Multi-line support would be nice but Lomiri TextField doesn't support it well
                    // For now, single line with enter to send
                    
                    onAccepted: {
                        if (text.trim().length > 0) {
                            sendMessage(text.trim(), isReplying ? replyToMessageId : "")
                            text = ""
                            if (isReplying) {
                                isReplying = false
                                replyToMessageId = ""
                                replyToSenderName = ""
                                replyToText = ""
                            }
                        }
                    }
                    
                    Keys.onReturnPressed: {
                        if (event.modifiers & Qt.ShiftModifier) {
                            // TODO: Insert newline when multiline is supported
                            event.accepted = false
                        } else {
                            accepted()
                        }
                    }
                }
                
                // Emoji button
                AbstractButton {
                    id: emojiButton
                    width: units.gu(4)
                    height: units.gu(4)
                    visible: showEmojiButton
                    enabled: composer.enabled
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "like"
                        color: emojiPicker.visible ? LomiriColors.blue :
                               (enabled ? Theme.palette.normal.backgroundSecondaryText : 
                               Theme.palette.disabled.backgroundSecondaryText)
                    }
                    
                    onClicked: {
                        emojiPicker.visible = !emojiPicker.visible
                        emojiClicked()
                    }
                }
                
                // Send button
                AbstractButton {
                    id: sendButton
                    width: units.gu(4)
                    height: units.gu(4)
                    enabled: composer.enabled && inputField.text.trim().length > 0
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: enabled ? LomiriColors.blue : Theme.palette.disabled.background
                        
                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2)
                        height: units.gu(2)
                        name: "send"
                        color: "white"
                    }
                    
                    onClicked: {
                        if (inputField.text.trim().length > 0) {
                            sendMessage(inputField.text.trim(), isReplying ? replyToMessageId : "")
                            inputField.text = ""
                            if (isReplying) {
                                isReplying = false
                                replyToMessageId = ""
                                replyToSenderName = ""
                                replyToText = ""
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Public function to set reply state
    function setReplyTo(messageId, senderName, messageText) {
        replyToMessageId = messageId
        replyToSenderName = senderName
        replyToText = messageText
        isReplying = true
        inputField.forceActiveFocus()
    }
    
    function clear() {
        inputField.text = ""
        isReplying = false
        replyToMessageId = ""
        replyToSenderName = ""
        replyToText = ""
        emojiPicker.visible = false
    }
    
    // Emoji picker popup
    Components.EmojiPicker {
        id: emojiPicker
        
        // Position above the composer, aligned with emoji button
        anchors.bottom: contentColumn.top
        anchors.bottomMargin: units.gu(1)
        anchors.right: parent.right
        anchors.rightMargin: units.gu(1)
        
        visible: false
        customEmojis: composer.customEmojis
        
        onEmojiSelected: {
            // Insert emoji at cursor position
            var cursorPos = inputField.cursorPosition
            var currentText = inputField.text
            inputField.text = currentText.substring(0, cursorPos) + emoji + currentText.substring(cursorPos)
            inputField.cursorPosition = cursorPos + emoji.length
        }
        
        onClosed: {
            emojiPicker.visible = false
        }
    }
}
