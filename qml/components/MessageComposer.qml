import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Content 1.1
import SerchatAPI 1.0
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
    
    // Context for typing indicators
    property string serverId: ""
    property string channelId: ""
    property string dmRecipientId: ""
    
    // Reply state
    property bool isReplying: false
    property string replyToMessageId: ""
    property string replyToSenderName: ""
    property string replyToText: ""
    
    // Edit state
    property bool isEditing: false
    property string editMessageId: ""
    property string editMessageText: ""
    
    // File upload state
    property var activeTransfer: null
    property bool uploading: false
    property int uploadRequestId: -1
    
    signal sendMessage(string message, string replyToId)
    signal editMessage(string messageId, string newText)
    signal attachmentClicked()
    signal emojiClicked()
    signal cancelReply()
    signal cancelEdit()
    
    width: parent ? parent.width : units.gu(40)
    height: contentColumn.height
    
    Column {
        id: contentColumn
        width: parent.width
        spacing: 0
        
        // Edit preview bar
        Rectangle {
            id: editBar
            width: parent.width
            height: isEditing ? editContent.height + units.gu(1.5) : 0
            color: Theme.palette.normal.base
            visible: isEditing
            clip: true
            
            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            Rectangle {
                id: editAccent
                width: units.gu(0.4)
                height: parent.height
                color: LomiriColors.orange
            }
            
            Column {
                id: editContent
                anchors.left: editAccent.right
                anchors.leftMargin: units.gu(1)
                anchors.right: closeEditButton.left
                anchors.rightMargin: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(0.2)
                
                Label {
                    text: i18n.tr("Edit message")
                    fontSize: "x-small"
                    font.bold: true
                    color: LomiriColors.orange
                }
                
                Label {
                    text: editMessageText.length > 100 ? editMessageText.substring(0, 100) + "..." : editMessageText
                    fontSize: "x-small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
            
            AbstractButton {
                id: closeEditButton
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
                    isEditing = false
                    editMessageId = ""
                    editMessageText = ""
                    inputField.text = ""
                    cancelEdit()
                }
            }
        }
        
        // Reply preview bar
        Rectangle {
            id: replyBar
            width: parent.width
            height: isReplying && !isEditing ? replyContent.height + units.gu(1.5) : 0
            color: Theme.palette.normal.base
            visible: isReplying && !isEditing
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
                    enabled: composer.enabled && !uploading
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: uploading ? "stock_clock" : "add"
                        color: enabled ? Theme.palette.normal.backgroundSecondaryText : 
                               Theme.palette.disabled.backgroundSecondaryText
                        
                        RotationAnimator {
                            target: parent
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: uploading
                        }
                    }
                    
                    onClicked: {
                        activeTransfer = filePicker.request()
                    }
                }
                
                // Text input
                TextField {
                    id: inputField
                    width: parent.width - attachmentButton.width - emojiButton.width - sendButton.width - units.gu(2)
                    placeholderText: composer.placeholderText
                    enabled: composer.enabled
                    
                    // Multi-line support would be nice but Lomiri TextField doesn't support it well
                    // For now, single line with enter to send
                    
                    // Send typing indicator when text changes
                    onTextChanged: {
                        if (text.length > 0 && composer.enabled) {
                            if (composer.dmRecipientId !== "") {
                                SerchatAPI.sendDMTyping(composer.dmRecipientId)
                            } else if (composer.serverId !== "" && composer.channelId !== "") {
                                SerchatAPI.sendTyping(composer.serverId, composer.channelId)
                            }
                        }
                    }
                    
                    onAccepted: {
                        if (text.trim().length > 0) {
                            if (isEditing) {
                                // Editing a message
                                editMessage(editMessageId, text.trim())
                                text = ""
                                isEditing = false
                                editMessageId = ""
                                editMessageText = ""
                            } else {
                                // Sending a new message
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
                        color: enabled ? (isEditing ? LomiriColors.orange : LomiriColors.blue) : Theme.palette.disabled.background
                        
                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2)
                        height: units.gu(2)
                        name: isEditing ? "save" : "send"
                        color: "white"
                    }
                    
                    onClicked: {
                        if (inputField.text.trim().length > 0) {
                            if (isEditing) {
                                // Editing a message
                                editMessage(editMessageId, inputField.text.trim())
                                inputField.text = ""
                                isEditing = false
                                editMessageId = ""
                                editMessageText = ""
                            } else {
                                // Sending a new message
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
    }
    
    // Public function to set reply state
    function setReplyTo(messageId, senderName, messageText) {
        replyToMessageId = messageId
        replyToSenderName = senderName
        replyToText = messageText
        isReplying = true
        inputField.forceActiveFocus()
    }
    
    // Public function to set edit state
    function setEditMode(messageId, messageText) {
        // Clear reply mode if active
        if (isReplying) {
            isReplying = false
            replyToMessageId = ""
            replyToSenderName = ""
            replyToText = ""
        }
        
        editMessageId = messageId
        editMessageText = messageText
        isEditing = true
        inputField.text = messageText
        inputField.forceActiveFocus()
        inputField.cursorPosition = messageText.length
    }
    
    function clear() {
        inputField.text = ""
        isReplying = false
        replyToMessageId = ""
        replyToSenderName = ""
        replyToText = ""
        isEditing = false
        editMessageId = ""
        editMessageText = ""
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
        serverId: composer.serverId
        
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
    
    // ContentHub integration for file picking
    ContentPeer {
        id: filePicker
        contentType: ContentType.Pictures
        handler: ContentHandler.Source
        selectionType: ContentTransfer.Single
    }
    
    ContentTransferHint {
        id: transferHint
        anchors.fill: parent
        activeTransfer: composer.activeTransfer
    }
    
    Connections {
        target: composer.activeTransfer
        onStateChanged: {
            if (composer.activeTransfer && composer.activeTransfer.state === ContentTransfer.Charged) {
                if (composer.activeTransfer.items.length > 0) {
                    var item = composer.activeTransfer.items[0]
                    var filePath = String(item.url).replace("file://", "")
                    handleFileSelected(filePath)
                }
            }
        }
    }
    
    Connections {
        target: SerchatAPI
        onFileUploadSuccess: {
            if (requestId === uploadRequestId) {
                // Insert file link at cursor position
                var fileMarkdown = "[%file%](" + url + ")"
                var cursorPos = inputField.cursorPosition
                var currentText = inputField.text
                
                // Add space before if there's already text and no trailing space
                var prefix = ""
                if (cursorPos > 0 && currentText.charAt(cursorPos - 1) !== " ") {
                    prefix = " "
                }
                
                inputField.text = currentText.substring(0, cursorPos) + prefix + fileMarkdown + currentText.substring(cursorPos)
                inputField.cursorPosition = cursorPos + prefix.length + fileMarkdown.length
                
                uploading = false
                uploadRequestId = -1
                inputField.forceActiveFocus()
            }
        }
        
        onFileUploadFailed: {
            if (requestId === uploadRequestId) {
                console.error("File upload failed:", error)
                // TODO: Show error to user
                uploading = false
                uploadRequestId = -1
            }
        }
    }
    
    function handleFileSelected(filePath) {
        uploading = true
        uploadRequestId = SerchatAPI.uploadFile(filePath)
    }
}
