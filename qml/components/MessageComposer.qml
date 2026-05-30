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
    property var pendingAttachments: []
    
    signal sendMessage(string message, string replyToId, var attachments)
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
            id: attachmentBar
            width: parent.width
            height: pendingAttachments.length > 0 ? attachmentRow.height + units.gu(1) : 0
            color: Theme.palette.normal.base
            visible: pendingAttachments.length > 0
            clip: true

            Row {
                id: attachmentRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: units.gu(1)
                anchors.rightMargin: units.gu(1)
                spacing: units.gu(0.5)

                Repeater {
                    model: pendingAttachments

                    Rectangle {
                        height: units.gu(3)
                        width: Math.min(attachmentName.width + removeAttachmentButton.width + units.gu(2), composer.width - units.gu(2))
                        radius: units.gu(0.5)
                        color: Qt.rgba(LomiriColors.blue.r, LomiriColors.blue.g, LomiriColors.blue.b, 0.16)

                        Label {
                            id: attachmentName
                            anchors.left: parent.left
                            anchors.leftMargin: units.gu(0.75)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - removeAttachmentButton.width - units.gu(1.5))
                            text: modelData.name || modelData.attachmentId || i18n.tr("Attachment")
                            fontSize: "x-small"
                            elide: Text.ElideMiddle
                        }

                        AbstractButton {
                            id: removeAttachmentButton
                            width: units.gu(3)
                            height: parent.height
                            anchors.right: parent.right

                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(1.5)
                                height: units.gu(1.5)
                                name: "close"
                            }

                            onClicked: removeAttachment(index)
                        }
                    }
                }
            }
        }

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
                    
                    onAccepted: submitCurrentInput()
                    
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
                    enabled: composer.enabled && canSubmit()
                    
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
                    
                    onClicked: submitCurrentInput()
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
        pendingAttachments = []
    }

    function canSubmit() {
        if (isEditing) {
            return inputField.text.trim().length > 0
        }
        return inputField.text.trim().length > 0 || pendingAttachments.length > 0
    }

    function submitCurrentInput() {
        if (!canSubmit()) return

        if (isEditing) {
            editMessage(editMessageId, inputField.text.trim())
            inputField.text = ""
            isEditing = false
            editMessageId = ""
            editMessageText = ""
            return
        }

        var attachmentsToSend = pendingAttachments.slice()
        sendMessage(inputField.text.trim(), isReplying ? replyToMessageId : "", attachmentsToSend)
        inputField.text = ""
        pendingAttachments = []
        if (isReplying) {
            isReplying = false
            replyToMessageId = ""
            replyToSenderName = ""
            replyToText = ""
        }
    }

    function removeAttachment(index) {
        var nextAttachments = pendingAttachments.slice()
        nextAttachments.splice(index, 1)
        pendingAttachments = nextAttachments
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
                var uploadedAttachment = attachment || {}
                if (!uploadedAttachment.attachmentId && url) {
                    var parts = url.split("/")
                    var filename = parts.length > 0 ? parts[parts.length - 1] : url
                    uploadedAttachment = {
                        attachmentId: filename,
                        type: "file",
                        mimeType: "application/octet-stream",
                        name: filename,
                        size: 0,
                        url: url
                    }
                }
                var nextAttachments = pendingAttachments.slice()
                nextAttachments.push(uploadedAttachment)
                pendingAttachments = nextAttachments
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
