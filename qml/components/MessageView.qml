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
    
    // Messages now come from C++ MessageModel (SerchatAPI.messageModel)
    // These properties are for backwards compatibility during transition
    property alias messages: messageList.model
    property bool loading: false
    property bool hasMoreMessages: SerchatAPI.messageModel.hasMoreMessages
    property string currentUserId: ""
    property bool showBackButton: false  // Whether to show back button for navigation
    
    // Permission checking
    property bool canSendMessages: true  // Default to true, can be overridden
    
    // User profile cache for sender names/avatars
    property var userProfiles: ({})
    
    // Track pending profile requests to avoid duplicates
    property var pendingProfileRequests: ({})
    
    // Members panel visibility
    property bool showMembersPanel: false
    
    // Custom emojis for markdown rendering
    property var customEmojis: ({})
    
    // Expose the message list for external scroll control
    property alias messageList: messageList
    
    signal sendMessage(string text, string replyToId)
    signal loadMoreMessages()
    signal messageReplyClicked(string messageId)
    signal userProfileClicked(string userId)
    signal backClicked()
    signal viewFullProfile(string userId)
    signal openDMWithUser(string recipientId, string recipientName, string recipientAvatar)
    signal sendFriendRequest(string userId, string username)
    
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
                            color: searchOverlay.opened ? LomiriColors.blue : Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        onClicked: {
                            searchOverlay.open()
                        }
                    }
                    
                    // Members/info button (only for server channels)
                    AbstractButton {
                        width: units.gu(4)
                        height: units.gu(4)
                        visible: !isDMMode
                        
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            name: "contact-group"
                            color: showMembersPanel ? LomiriColors.blue : Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        onClicked: {
                            showMembersPanel = !showMembersPanel
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
                
                // Performance optimizations for slower devices
                cacheBuffer: units.gu(100)  // Cache items beyond viewport
                maximumFlickVelocity: 4000
                flickDeceleration: 1500
            
            model: SerchatAPI.messageModel
            
            // Lock scrolling when message bubble is swiping
            property bool swipeLockActive: false
            interactive: !swipeLockActive
            
            // Scroll position management for model updates (edits, deletes, reactions)
            property bool preserveScrollPosition: false
            property real savedContentY: 0
            property real savedContentHeight: 0
            property int savedMessageCount: 0
            
            // Timer to restore scroll position after model change completes
            // Using multiple stages to handle different QML update timing
            Timer {
                id: scrollRestoreTimer
                interval: 16  // ~1 frame at 60fps
                repeat: false
                onTriggered: {
                    if (messageList.preserveScrollPosition && messageList.savedContentHeight > 0) {
                        // Calculate delta and adjust position
                        var heightDelta = messageList.contentHeight - messageList.savedContentHeight
                        messageList.contentY = messageList.savedContentY + heightDelta
                        console.log("[MessageView] Scroll restore attempt 1: delta=" + heightDelta + " newY=" + messageList.contentY)
                        // Schedule second attempt for layout stabilization
                        scrollRestoreTimer2.restart()
                    }
                }
            }
            
            Timer {
                id: scrollRestoreTimer2
                interval: 16
                repeat: false
                onTriggered: {
                    if (messageList.preserveScrollPosition && messageList.savedContentHeight > 0) {
                        var heightDelta = messageList.contentHeight - messageList.savedContentHeight
                        messageList.contentY = messageList.savedContentY + heightDelta
                        messageList.preserveScrollPosition = false
                        console.log("[MessageView] Scroll restore final: delta=" + heightDelta + " newY=" + messageList.contentY)
                    }
                }
            }
            
            // Save scroll position before model update
            function saveScrollPosition() {
                savedContentY = contentY
                savedContentHeight = contentHeight
                savedMessageCount = SerchatAPI.messageModel.count
                preserveScrollPosition = true
                console.log("[MessageView] Saved scroll: contentY=" + savedContentY + " contentHeight=" + savedContentHeight + " count=" + savedMessageCount)
            }
            
            // Called when we want to scroll to bottom for new messages
            function scrollToBottomOnNewMessage() {
                preserveScrollPosition = false
            }
            
            // Watch for model changes and trigger scroll restore
            onCountChanged: {
                console.log("[MessageView] Count changed to " + count + ", preserveScroll=" + preserveScrollPosition)
                if (preserveScrollPosition) {
                    scrollRestoreTimer.restart()
                }
            }
            
            // Also watch contentHeight as backup
            onContentHeightChanged: {
                if (preserveScrollPosition && savedContentHeight > 0 && !scrollRestoreTimer.running) {
                    scrollRestoreTimer.restart()
                }
            }
            
            delegate: Components.MessageBubble {
                id: messageDelegate
                width: messageList.width
                // Use C++ model role names directly (no modelData needed)
                messageId: model.id || ""
                senderId: model.senderId || ""
                senderName: model.senderName || getSenderName(model.senderId)
                senderAvatar: model.senderAvatar || getSenderAvatar(model.senderId)
                text: model.text || ""  // Raw text - MarkdownText handles all formatting
                timestamp: model.timestamp || ""
                isOwn: model.senderId === currentUserId
                isEdited: model.isEdited || false
                showAvatar: shouldShowAvatar(index)
                isReply: model.replyToId ? true : false
                replyToText: model.repliedMessage ? model.repliedMessage.text : ""
                replyToSender: model.repliedMessage ? getSenderName(model.repliedMessage.senderId) : ""
                reactions: model.reactions || []
                customEmojis: messageView.customEmojis
                userProfiles: messageView.userProfiles
                
                // Bind swipe state to list scroll lock
                onIsSwipeActiveChanged: {
                    messageList.swipeLockActive = isSwipeActive
                }
                
                onAvatarClicked: openProfileSheet(senderId)
                onReplyRequested: {
                    // Set up reply in composer (messageId, senderName, messageText)
                    composer.setReplyTo(messageId, senderName, messageText)
                }
                onReplyClicked: {
                    if (model.repliedMessage) {
                        scrollToMessage(model.repliedMessage._id)
                    }
                }
                onReactRequested: {
                    showReactionPicker(messageId)
                }
                onReactionTapped: {
                    // Toggle reaction - add if not reacted, remove if already reacted
                    toggleReaction(messageId, emoji, emojiType, emojiId)
                }
                onMenuRequested: {
                    // Open bottom sheet action menu
                    messageActionSheet.open(messageId, messageText, senderName, senderId, isOwn)
                }
                onCopyRequested: {
                    console.log("[MessageView] Text copied to clipboard")
                }
                onDeleteRequested: {
                    deleteMessage(messageId)
                }
                onEditRequested: {
                    // TODO: Implement edit message
                    console.log("[MessageView] Edit message:", messageId)
                }
            }
            
            // Loading indicator / load more at visual top (footer in BottomToTop ListView)
            footer: Item {
                width: messageList.width
                height: loading ? units.gu(6) : (hasMoreMessages ? units.gu(4) : units.gu(12))
                
                ActivityIndicator {
                    anchors.centerIn: parent
                    running: loading
                    visible: loading
                }
                
                // "Load more" button when there are more messages
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
                
                // "Beginning of channel" message when all messages loaded
                Column {
                    anchors.centerIn: parent
                    spacing: units.gu(1)
                    visible: !loading && !hasMoreMessages && SerchatAPI.messageModel.count > 0
                    
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: units.gu(5)
                        height: units.gu(5)
                        name: isDMMode ? "contact" : "edit"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isDMMode ? 
                              i18n.tr("This is the beginning of your conversation with %1").arg(dmRecipientName) :
                              i18n.tr("This is the beginning of #%1").arg(channelName)
                        fontSize: "small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        width: messageList.width - units.gu(4)
                    }
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
            visible: SerchatAPI.messageModel.count === 0 && !loading
            
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
        var messageModel = SerchatAPI.messageModel
        if (index >= messageModel.count - 1) return true  // First message (reversed list)
        
        // Get messages from model using getMessageAt
        var currentMsg = messageModel.getMessageAt(index)
        var prevMsg = messageModel.getMessageAt(index + 1)  // Previous in time (above in view)
        
        if (!currentMsg || !prevMsg) return true
        
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
    
    // Show message context menu (legacy - now handled by MessageBubble)
    function showMessageOptions(message) {
        // Now handled directly in MessageBubble via context menu
        composer.setReplyTo(message._id || message.id, 
                           getSenderName(message.senderId),
                           message.text)
    }
    
    // Show reaction picker for a message
    function showReactionPicker(messageId) {
        reactionPickerSheet.open(messageId)
    }
    
    // Toggle reaction on a message (uses existing API methods)
    function toggleReaction(messageId, emoji, emojiType, emojiId) {
        console.log("[MessageView] Toggle reaction:", messageId, emoji, emojiType, emojiId)
        // Find the message using C++ model's O(1) lookup
        var message = SerchatAPI.messageModel.getMessage(messageId)
        
        // Check if we already reacted with this emoji
        var hasReacted = false
        if (message && message.reactions) {
            for (var j = 0; j < message.reactions.length; j++) {
                var r = message.reactions[j]
                if ((r.emoji === emoji || r.emojiId === emojiId) && r.hasReacted) {
                    hasReacted = true
                    break
                }
            }
        }
        
        // Use the message type based on whether it's a DM or server message
        var messageType = isDMMode ? "dm" : "server"
        
        if (hasReacted) {
            // Remove reaction
            if (isDMMode) {
                SerchatAPI.removeReaction(messageId, messageType, emoji)
            } else {
                SerchatAPI.removeReaction(messageId, messageType, emoji, serverId, channelId)
            }
        } else {
            // Add reaction
            if (isDMMode) {
                SerchatAPI.addReaction(messageId, messageType, emoji)
            } else {
                SerchatAPI.addReaction(messageId, messageType, emoji, serverId, channelId)
            }
        }
    }
    
    // Add reaction to a message
    function addReaction(messageId, emoji, emojiType, emojiId) {
        console.log("[MessageView] Add reaction:", messageId, emoji, emojiType, emojiId)
        var messageType = isDMMode ? "dm" : "server"
        
        if (isDMMode) {
            SerchatAPI.addReaction(messageId, messageType, emoji)
        } else {
            SerchatAPI.addReaction(messageId, messageType, emoji, serverId, channelId)
        }
    }
    
    // Delete a message
    function deleteMessage(messageId) {
        // TODO: Implement message deletion via API
        console.log("[MessageView] Delete message:", messageId)
        if (isDMMode) {
            SerchatAPI.deleteDirectMessage(messageId)
        } else {
            SerchatAPI.deleteServerMessage(serverId, channelId, messageId)
        }
    }
    
    // Scroll to a specific message
    function scrollToMessage(messageId) {
        var index = SerchatAPI.messageModel.indexOfMessage(messageId)
        if (index >= 0) {
            messageList.positionViewAtIndex(index, ListView.Center)
            // TODO: Highlight the message briefly
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
            // Open DM with user
            var profile = userProfileSheet.userProfile
            var recipientName = profile.displayName || profile.username || ""
            var recipientAvatar = profile.profilePicture ? 
                                  (SerchatAPI.apiBaseUrl + profile.profilePicture) : ""
            openDMWithUser(userId, recipientName, recipientAvatar)
        }
        
        onAddFriendClicked: {
            // Send friend request
            var profile = userProfileSheet.userProfile
            var username = profile.username || ""
            sendFriendRequest(userId, username)
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
                    // Update QML cache
                    var newProfiles = userProfiles
                    newProfiles[senderId] = profile
                    userProfiles = newProfiles

                    // Sync profile to C++ MessageModel for proper sender name resolution
                    SerchatAPI.messageModel.updateUserProfile(senderId, profile)

                    // Remove from pending
                    var newPending = pendingProfileRequests
                    delete newPending[senderId]
                    pendingProfileRequests = newPending

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
    
    // Connect to C++ model signals for profile fetching
    Connections {
        target: SerchatAPI.messageModel
        
        // When a message is added, check if we need to fetch the sender's profile
        onMessageAdded: {
            console.log("[MessageView] Message added:", messageId, "isNew:", isNewMessage)
            var message = SerchatAPI.messageModel.getMessage(messageId)
            if (message && message.senderId) {
                fetchProfileIfNeeded(message.senderId)
            }
        }
        
        onCountChanged: {
            console.log("[MessageView] Model count changed to:", SerchatAPI.messageModel.count)
        }
    }
    
    // Search overlay
    Components.SearchOverlay {
        id: searchOverlay
        anchors.fill: parent
        channelId: messageView.channelId
        dmRecipientId: messageView.dmRecipientId
        
        onResultClicked: {
            searchOverlay.opened = false
            scrollToMessage(messageId)
        }
    }
    
    // Members list panel (slides in from right)
    Rectangle {
        id: membersPanel
        anchors.top: channelHeader.bottom
        anchors.bottom: composer.top
        anchors.right: parent.right
        width: showMembersPanel && !isDMMode ? Math.min(units.gu(32), parent.width * 0.4) : 0
        color: Qt.darker(messageView.color, 1.04)
        clip: true
        visible: width > 0
        
        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        
        // Left border
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: units.dp(1)
            color: Qt.darker(messageView.color, 1.1)
        }
        
        Components.MembersListView {
            anchors.fill: parent
            anchors.leftMargin: units.dp(1)
            serverId: messageView.serverId
            currentUserId: messageView.currentUserId
            
            onMemberClicked: {
                openProfileSheet(userId)
            }
        }
    }
    
    // Message action sheet (bottom sheet popup for message options)
    Components.MessageActionSheet {
        id: messageActionSheet
        anchors.fill: parent
        
        onReplyClicked: {
            composer.setReplyTo(messageId, senderName, messageText)
        }
        
        onReactClicked: {
            showReactionPicker(messageId)
        }
        
        onEmojiSelected: {
            addReaction(messageId, emoji, "unicode", "")
        }
        
        onCopyClicked: {
            console.log("[MessageView] Text copied from action sheet")
        }
        
        onEditClicked: {
            console.log("[MessageView] Edit message:", messageId)
            // TODO: Implement edit UI
        }
        
        onDeleteClicked: {
            deleteMessage(messageId)
        }
    }
    
    // Reaction picker sheet (bottom sheet for full emoji picker)
    Components.ReactionPickerSheet {
        id: reactionPickerSheet
        anchors.fill: parent
        customEmojis: messageView.customEmojis
        
        onReactionSelected: {
            addReaction(messageId, emoji, emojiType, emojiId)
        }
    }
}
