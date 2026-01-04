import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MessageView - Chat message display with input composer
 * Supports both server channels and DMs
 */
Rectangle {
    id: messageView
    
    // Server channel properties
    property string serverId: ""
    property string channelId: ""
    property string channelName: ""
    property string channelType: "text"
    property string channelDescription: ""
    
    // DM properties
    property string dmRecipientId: ""
    property string dmRecipientName: ""
    property string dmRecipientAvatar: ""
    
    // Computed property to check if we're in DM mode
    readonly property bool isDMMode: dmRecipientId !== "" && serverId === ""
    
    // Display title - shows DM recipient name or channel name
    readonly property string displayTitle: isDMMode ? dmRecipientName : channelName
    
    property var messages: []
    property bool loading: false
    property bool hasMoreMessages: true
    property string currentUserId: ""
    property bool showBackButton: false  // Whether to show back button for navigation
    
    // Permission checking
    property bool canSendMessages: true  // Default to true, can be overridden
    
    // User profile cache for sender names/avatars
    property var userProfiles: ({})
    
    // Track pending profile requests to avoid duplicates
    property var pendingProfileRequests: ({})
    
    signal sendMessage(string text, string replyToId)
    signal loadMoreMessages()
    signal messageReplyClicked(string messageId)
    signal userProfileClicked(string userId)
    signal backClicked()
    signal viewFullProfile(string userId)
    
    color: Theme.palette.normal.background
    
    // Channel header
    Rectangle {
        id: channelHeader
        anchors.top: parent.top
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
                        color: Theme.palette.normal.baseText
                    }
                    
                    onClicked: backClicked()
                }
                
                // Channel/DM icon or avatar
                Item {
                    id: headerIconContainer
                    width: units.gu(2.5)
                    height: units.gu(2.5)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    // Avatar for DMs
                    Components.Avatar {
                        anchors.fill: parent
                        visible: isDMMode
                        name: dmRecipientName
                        source: dmRecipientAvatar
                        showStatus: false
                    }
                    
                    // Icon for channels
                    Icon {
                        id: channelIcon
                        anchors.fill: parent
                        visible: !isDMMode
                        name: channelType === "voice" ? "audio-speakers-symbolic" : "edit"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
                
                // Channel name and description
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (backButton.visible ? backButton.width : 0) - headerIconContainer.width - headerActions.width - units.gu(4)
                    spacing: units.gu(0.2)
                    
                    Label {
                        text: displayTitle
                        font.bold: true
                        fontSize: "medium"
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    
                    Label {
                        text: isDMMode ? "" : channelDescription
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        elide: Text.ElideRight
                        width: parent.width
                        visible: !isDMMode && channelDescription !== ""
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
        
        // Content area (messages or welcome)
        Item {
            id: contentArea
            anchors.top: channelHeader.bottom
            anchors.bottom: composer.top
            width: parent.width
            
            // Messages list
            ListView {
                id: messageList
                anchors.fill: parent
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
                
                onAvatarClicked: openProfileSheet(senderId)
                onLongPressed: showMessageOptions(modelData)
                onReplyClicked: {
                    if (modelData.repliedMessage) {
                        scrollToMessage(modelData.repliedMessage._id)
                    }
                }
            }
            
            // Loading indicator / load more at visual top (footer in BottomToTop ListView)
            footer: Item {
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
            anchors.fill: parent
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
    }
    
    // Message composer
    Components.MessageComposer {
        id: composer
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0
        width: parent.width
        placeholderText: canSendMessages ? 
                         (isDMMode ? i18n.tr("Message @%1").arg(dmRecipientName) : i18n.tr("Message #%1").arg(displayTitle)) :
                         i18n.tr("You don't have permission to send messages")
        enabled: canSendMessages && (isDMMode || channelType === "text")
        
        onSendMessage: {
            messageView.sendMessage(message, replyToId)
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
    
    // Fetch profile for a sender if not cached
    function fetchProfileIfNeeded(senderId) {
        if (!senderId) return
        if (userProfiles[senderId]) return
        if (pendingProfileRequests[senderId]) return
        
        var requestId = SerchatAPI.getProfile(senderId)
        var newPending = pendingProfileRequests
        newPending[senderId] = requestId
        pendingProfileRequests = newPending
    }
    
    // Open profile sheet for a user
    function openProfileSheet(userId) {
        userProfileSheet.open(userId, userId === currentUserId)
    }
    
    // User profile sheet (bottom sheet popup)
    Components.UserProfileSheet {
        id: userProfileSheet
        anchors.fill: parent
        
        onViewFullProfileClicked: {
            viewFullProfile(userId)
        }
        
        onSendMessageClicked: {
            // TODO: Open DM conversation with user
            console.log("Opening DM with user:", userId)
        }
        
        onAddFriendClicked: {
            // TODO: Send friend request
            console.log("Adding friend:", userId)
        }
    }
    
    // Connections for keyboard visibility changes
    Connections {
        target: Qt.inputMethod
        
        onVisibleChanged: {
            if (Qt.inputMethod.visible) {
                scrollToBottom()
            }
        }
    }
    
    // Connections for profile loading
    Connections {
        target: SerchatAPI
        
        onProfileFetched: {
            // Find which sender this profile belongs to
            for (var senderId in pendingProfileRequests) {
                if (pendingProfileRequests[senderId] === requestId) {
                    // Update cache
                    var newProfiles = userProfiles
                    newProfiles[senderId] = profile
                    userProfiles = newProfiles
                    
                    // Remove from pending
                    var newPending = pendingProfileRequests
                    delete newPending[senderId]
                    pendingProfileRequests = newPending
                    
                    // Note: The ListView will update automatically when userProfiles changes
                    // No need to force refresh messages array
                    break
                }
            }
        }
        
        onProfileFetchFailed: {
            // Remove from pending on failure
            for (var senderId in pendingProfileRequests) {
                if (pendingProfileRequests[senderId] === requestId) {
                    var newPending = pendingProfileRequests
                    delete newPending[senderId]
                    pendingProfileRequests = newPending
                    break
                }
            }
        }
    }
    
    // Fetch profiles when messages change
    onMessagesChanged: {
        console.log("[MessageView] Messages changed, count:", messages.length)
        // Collect unique sender IDs
        var senderIds = {}
        for (var i = 0; i < messages.length; i++) {
            var senderId = messages[i].senderId
            if (senderId && !userProfiles[senderId] && !senderIds[senderId]) {
                senderIds[senderId] = true
            }
        }
        
        // Fetch profiles for unknown senders
        for (var id in senderIds) {
            fetchProfileIfNeeded(id)
        }
    }
}
