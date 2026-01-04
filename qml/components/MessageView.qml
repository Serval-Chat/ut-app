import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MessageView - Chat message display with input composer
 */
Rectangle {
    id: messageView
    
    property string serverId: ""
    property string channelId: ""
    property string channelName: ""
    property string channelType: "text"
    property string channelDescription: ""
    property var messages: []
    property bool loading: false
    property bool hasMoreMessages: true
    property string currentUserId: ""
    property bool showBackButton: false  // Whether to show back button for navigation
    
    // User profile cache for sender names/avatars
    property var userProfiles: ({})
    
    signal sendMessage(string text, string replyToId)
    signal loadMoreMessages()
    signal messageReplyClicked(string messageId)
    signal userProfileClicked(string userId)
    signal backClicked()
    
    color: Theme.palette.normal.background
    
    Column {
        anchors.fill: parent
        
        // Channel header
        Rectangle {
            id: channelHeader
            width: parent.width
            height: units.gu(6)
            color: Qt.darker(messageView.color, 1.02)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.5)
                anchors.rightMargin: units.gu(1.5)
                spacing: units.gu(1)
                
                // Back button (for mobile)
                AbstractButton {
                    id: backButton
                    width: units.gu(4)
                    height: parent.height
                    visible: showBackButton  // Show when channel list is hidden
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "back"
                        color: Theme.palette.normal.foreground
                    }
                    
                    onClicked: backClicked()
                }
                
                // Channel icon
                Icon {
                    id: channelIcon
                    width: units.gu(2.5)
                    height: units.gu(2.5)
                    anchors.verticalCenter: parent.verticalCenter
                    name: channelType === "voice" ? "audio-speakers-symbolic" : "edit"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                // Channel name and description
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (backButton.visible ? backButton.width : 0) - channelIcon.width - headerActions.width - units.gu(4)
                    spacing: units.gu(0.2)
                    
                    Label {
                        text: channelName
                        font.bold: true
                        fontSize: "medium"
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    
                    Label {
                        text: channelDescription
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        elide: Text.ElideRight
                        width: parent.width
                        visible: channelDescription !== ""
                    }
                }
                
                // Header action buttons
                Row {
                    id: headerActions
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(1)
                    
                    // Search button
                    AbstractButton {
                        width: units.gu(4)
                        height: units.gu(4)
                        
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            name: "search"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        onClicked: {
                            // TODO: Implement search
                        }
                    }
                    
                    // Members/info button
                    AbstractButton {
                        width: units.gu(4)
                        height: units.gu(4)
                        
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            name: "contact-group"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        onClicked: {
                            // TODO: Show members panel
                        }
                    }
                }
            }
            
            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: units.dp(1)
                color: Qt.darker(messageView.color, 1.1)
            }
        }
        
        // Messages list
        ListView {
            id: messageList
            width: parent.width
            height: parent.height - channelHeader.height - composer.height
            clip: true
            verticalLayoutDirection: ListView.BottomToTop
            spacing: units.gu(0.3)
            
            model: messages
            
            delegate: Components.MessageBubble {
                width: messageList.width
                messageId: modelData._id || modelData.id || ""
                senderId: modelData.senderId || ""
                senderName: getSenderName(modelData.senderId)
                senderAvatar: getSenderAvatar(modelData.senderId)
                text: formatMessageText(modelData.text || "")
                timestamp: modelData.createdAt || ""
                isOwn: modelData.senderId === currentUserId
                isEdited: modelData.isEdited || false
                showAvatar: shouldShowAvatar(index)
                isReply: modelData.replyToId ? true : false
                replyToText: modelData.repliedMessage ? modelData.repliedMessage.text : ""
                replyToSender: modelData.repliedMessage ? getSenderName(modelData.repliedMessage.senderId) : ""
                reactions: modelData.reactions || []
                
                onAvatarClicked: userProfileClicked(senderId)
                onLongPressed: showMessageOptions(modelData)
                onReplyClicked: {
                    if (modelData.repliedMessage) {
                        scrollToMessage(modelData.repliedMessage._id)
                    }
                }
            }
            
            // Loading indicator at top
            header: Item {
                width: messageList.width
                height: loading ? units.gu(6) : (hasMoreMessages ? units.gu(4) : 0)
                
                ActivityIndicator {
                    anchors.centerIn: parent
                    running: loading
                    visible: loading
                }
                
                Label {
                    anchors.centerIn: parent
                    text: i18n.tr("Load more messages")
                    fontSize: "small"
                    color: LomiriColors.blue
                    visible: !loading && hasMoreMessages
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: loadMoreMessages()
                    }
                }
            }
            
            // Auto-scroll behavior
            onCountChanged: {
                if (atYEnd) {
                    positionViewAtBeginning()
                }
            }
            
            // Pull to load more (debounced)
            property bool loadingTriggered: false
            
            onContentYChanged: {
                if (contentY < -units.gu(8) && !loading && hasMoreMessages && !loadingTriggered) {
                    loadingTriggered = true
                    loadMoreMessages()
                }
                if (contentY >= 0) {
                    loadingTriggered = false
                }
            }
        }
        
        // Welcome message when channel is empty
        Item {
            width: parent.width
            height: parent.height - channelHeader.height - composer.height
            visible: messages.length === 0 && !loading
            
            Column {
                anchors.centerIn: parent
                spacing: units.gu(2)
                width: parent.width - units.gu(4)
                
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(8)
                    height: units.gu(8)
                    name: "edit"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Welcome to #%1!").arg(channelName)
                    fontSize: "large"
                    font.bold: true
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("This is the start of the #%1 channel.").arg(channelName)
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }
        }
        
        // Message composer
        Components.MessageComposer {
            id: composer
            width: parent.width
            placeholderText: i18n.tr("Message #%1").arg(channelName)
            enabled: channelType === "text"
            
            onSendMessage: {
                messageView.sendMessage(message, replyToId)
            }
        }
    }
    
    // Get sender name from cache or fallback
    function getSenderName(senderId) {
        if (!senderId) return i18n.tr("Unknown")
        
        if (userProfiles[senderId]) {
            return userProfiles[senderId].displayName || 
                   userProfiles[senderId].username || 
                   i18n.tr("Unknown")
        }
        
        // Request profile if not cached
        // SerchatAPI.getProfile(senderId)
        return senderId.substring(0, 8) + "..."
    }
    
    // Get sender avatar from cache
    function getSenderAvatar(senderId) {
        if (!senderId || !userProfiles[senderId]) return ""
        
        var profile = userProfiles[senderId]
        if (profile.profilePicture) {
            return SerchatAPI.apiBaseUrl + profile.profilePicture
        }
        return ""
    }
    
    // Check if we should show avatar for message grouping
    function shouldShowAvatar(index) {
        if (index >= messages.length - 1) return true  // First message (reversed list)
        
        var currentMsg = messages[index]
        var prevMsg = messages[index + 1]  // Previous in time (above in view)
        
        // Show avatar if different sender
        if (currentMsg.senderId !== prevMsg.senderId) return true
        
        // Show avatar if more than 5 minutes apart
        var currentTime = new Date(currentMsg.createdAt).getTime()
        var prevTime = new Date(prevMsg.createdAt).getTime()
        if (currentTime - prevTime > 5 * 60 * 1000) return true
        
        return false
    }
    
    // Format message text (links, mentions, etc.)
    function formatMessageText(text) {
        if (!text) return ""
        
        // Escape HTML
        var escaped = text.replace(/&/g, '&amp;')
                         .replace(/</g, '&lt;')
                         .replace(/>/g, '&gt;')
        
        // Convert URLs to links
        var urlRegex = /(https?:\/\/[^\s]+)/g
        escaped = escaped.replace(urlRegex, '<a href="$1">$1</a>')
        
        // Convert newlines to <br>
        escaped = escaped.replace(/\n/g, '<br>')
        
        return escaped
    }
    
    // Show message context menu
    function showMessageOptions(message) {
        // TODO: Implement message options (reply, edit, delete, react)
        composer.setReplyTo(message._id || message.id, 
                           getSenderName(message.senderId),
                           message.text)
    }
    
    // Scroll to a specific message
    function scrollToMessage(messageId) {
        for (var i = 0; i < messages.length; i++) {
            if (messages[i]._id === messageId || messages[i].id === messageId) {
                messageList.positionViewAtIndex(i, ListView.Center)
                // TODO: Highlight the message briefly
                break
            }
        }
    }
    
    // Public function to set reply mode
    function setReplyTo(messageId, senderName, messageText) {
        composer.setReplyTo(messageId, senderName, messageText)
    }
    
    // Scroll to bottom
    function scrollToBottom() {
        messageList.positionViewAtBeginning()
    }
}
