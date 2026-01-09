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
    
    property bool loading: false
    property bool hasMoreMessages: SerchatAPI.messageModel.hasMoreMessages
    property string currentUserId: ""
    property bool showBackButton: false  // Whether to show back button for navigation
    
    // Permission checking
    property bool canSendMessages: true  // Default to true, can be overridden
    
    // Members panel visibility
    property bool showMembersPanel: false
    
    // Expose the message list for external scroll control
    property alias messageList: messageList
    
    signal sendMessage(string text, string replyToId)
    signal loadMoreMessages()
    signal userProfileClicked(string userId)
    signal backClicked()
    signal viewFullProfile(string userId, string serverId)
    signal openDMWithUser(string recipientId, string recipientName, string recipientAvatar)
    signal sendFriendRequest(string userId, string username)
    signal removeFriend(string userId)
    
    color: Theme.palette.normal.background

    // Listen for first unread message ID changes from C++
    // The C++ side calculates this based on timestamps when messages are loaded
    Connections {
        target: SerchatAPI

        onFirstUnreadMessageIdChanged: function(sId, chId, msgId) {
            // Update the divider position when C++ calculates the first unread message
            if (sId === serverId && chId === channelId) {
                messageList.firstUnreadMessageId = msgId
                console.log("[MessageView] First unread message ID set to:", msgId)
            }
        }
    }
    
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
            anchors.bottom: typingIndicator.top
            width: parent.width
            
            // Messages list
            ListView {
                id: messageList
                anchors.fill: parent
                anchors.leftMargin: units.gu(1)
                anchors.rightMargin: units.gu(1)
                
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
                
                // Track the first unread message ID for "NEW MESSAGES" divider
                // This is set by C++ after calculating based on timestamps
                property string firstUnreadMessageId: ""

                delegate: Item {
                    id: messageDelegateContainer
                    width: messageList.width
                    height: messageBubble.height + (newMessagesDivider.visible ? newMessagesDivider.height : 0)

                    // Show "NEW MESSAGES" divider above this message if it's the first unread
                    // The firstUnreadMessageId is calculated by C++ based on lastReadAt timestamps
                    property bool isFirstUnread: {
                        if (messageList.firstUnreadMessageId === "") return false
                        // Check if this message is the first unread message
                        var msgId = model.id || ""
                        return msgId === messageList.firstUnreadMessageId
                    }
                    
                    // "NEW MESSAGES" divider
                    Rectangle {
                        id: newMessagesDivider
                        width: parent.width
                        height: visible ? units.gu(3) : 0
                        visible: messageDelegateContainer.isFirstUnread
                        color: "transparent"
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: units.gu(1)
                            
                            Rectangle {
                                width: (messageDelegateContainer.width - newMessagesLabel.width - units.gu(4)) / 2
                                height: units.dp(1)
                                color: "#f04747"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Label {
                                id: newMessagesLabel
                                text: i18n.tr("NEW MESSAGES")
                                fontSize: "x-small"
                                font.bold: true
                                color: "#f04747"
                            }
                            
                            Rectangle {
                                width: (messageDelegateContainer.width - newMessagesLabel.width - units.gu(4)) / 2
                                height: units.dp(1)
                                color: "#f04747"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    
                    Components.MessageBubble {
                        id: messageBubble
                        width: parent.width
                        anchors.top: newMessagesDivider.visible ? newMessagesDivider.bottom : parent.top
                        // Use C++ model role names directly - senderName/Avatar come from UserProfileCache via MessageModel
                        messageId: model.id || ""
                        senderId: model.senderId || ""
                        senderName: model.senderName || i18n.tr("Unknown")
                        senderAvatar: model.senderAvatar || ""
                        text: model.text || ""  // Raw text - MarkdownText handles all formatting
                        timestamp: model.timestamp || ""
                        isOwn: model.senderId === currentUserId
                        isEdited: model.isEdited || false
                        showAvatar: SerchatAPI.messageModel.shouldShowAvatar(index)
                        isReply: model.replyToId ? true : false
                        replyToText: model.repliedMessage ? model.repliedMessage.text : ""
                        replyToSender: model.repliedMessage ? getSenderName(model.repliedMessage.senderId) : ""
                        reactions: model.reactions || []
                        
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
                        onMediaViewRequested: {
                            openMediaViewer(url, name, mime)
                        }
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
                    text: i18n.tr("This is the start of the #%1 channel. There are no messages yet.").arg(channelName)
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }
        }
    }
    
    // Typing indicator bar
    Rectangle {
        id: typingIndicator
        anchors.bottom: composer.top
        width: parent.width
        height: typingLabel.visible ? units.gu(3) : 0
        color: Qt.darker(messageView.color, 1.02)
        clip: true
        
        Behavior on height {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
        
        property var typingUsers: []
        property int typingVersion: 0
        
        // Update typing users list
        function updateTypingUsers() {
            if (isDMMode) {
                // DM typing events use username, not userId
                typingUsers = SerchatAPI.getDMTypingUsers(dmRecipientName)
            } else if (serverId !== "" && channelId !== "") {
                typingUsers = SerchatAPI.getTypingUsers(serverId, channelId)
            } else {
                typingUsers = []
            }
            typingVersion++
        }
        
        Row {
            anchors.left: parent.left
            anchors.leftMargin: units.gu(1.5)
            anchors.verticalCenter: parent.verticalCenter
            spacing: units.gu(0.5)
            
            // Animated typing dots
            Row {
                spacing: units.gu(0.3)
                visible: typingLabel.visible
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 3
                    Rectangle {
                        width: units.gu(0.8)
                        height: units.gu(0.8)
                        radius: width / 2
                        color: Theme.palette.normal.backgroundSecondaryText

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: typingLabel.visible
                            NumberAnimation { to: 0.3; duration: 300; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: index * 150 }
                        }
                    }
                }
            }

            Label {
                id: typingLabel
                visible: typingIndicator.typingUsers.length > 0
                anchors.verticalCenter: parent.verticalCenter
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
                text: {
                    var v = typingIndicator.typingVersion  // Force binding update
                    var users = typingIndicator.typingUsers
                    if (users.length === 0) return ""
                    if (users.length === 1) return i18n.tr("%1 is typing...").arg(users[0])
                    if (users.length === 2) return i18n.tr("%1 and %2 are typing...").arg(users[0]).arg(users[1])
                    return i18n.tr("%1 and %2 others are typing...").arg(users[0]).arg(users.length - 1)
                }
            }
        }
        
        // Connection for typing updates
        Connections {
            target: SerchatAPI
            
            onTypingUsersChanged: {
                // Backend doesn't send serverId, so serverId === channelId
                // Just compare channelId
                if (channelId === messageView.channelId) {
                    typingIndicator.updateTypingUsers()
                }
            }
            
            onDmTypingUsersChanged: {
                // The signal sends username, but we have recipientId - check both
                if (recipientId === messageView.dmRecipientId || recipientId === messageView.dmRecipientName) {
                    typingIndicator.updateTypingUsers()
                }
            }
        }
        
        // Update when channel/DM changes
        Connections {
            target: messageView
            onChannelIdChanged: typingIndicator.updateTypingUsers()
            onDmRecipientIdChanged: typingIndicator.updateTypingUsers()
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
        
        // Pass context for typing indicators
        serverId: messageView.serverId
        channelId: messageView.channelId
        dmRecipientId: messageView.dmRecipientId
        
        onSendMessage: {
            // Clear the "NEW MESSAGES" divider when user sends a message
            messageList.firstUnreadMessageId = ""
            // Also clear in C++ so it doesn't reappear on next load
            if (messageView.serverId && messageView.channelId) {
                SerchatAPI.clearFirstUnreadMessageId(messageView.serverId, messageView.channelId)
            }
            messageView.sendMessage(message, replyToId)
        }
    }
    
    // Get sender name from C++ cache for reply previews (not from model roles)
    function getSenderName(senderId) {
        if (!senderId) return i18n.tr("Unknown")
        
        // Use C++ cache - it auto-fetches if not present
        var displayName = SerchatAPI.userProfileCache.getDisplayName(senderId)
        return displayName || i18n.tr("Unknown")
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
    
    // Open profile sheet for a user
    // Passes serverId when in server context for role display
    function openProfileSheet(userId) {
        userProfileSheet.open(userId, serverId)
    }
    
    // User profile sheet (bottom sheet popup)
    Components.UserProfileSheet {
        id: userProfileSheet
        anchors.fill: parent
        
        onViewFullProfileClicked: {
            viewFullProfile(userId, serverId)
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
        
        onRemoveFriendClicked: {
            // Remove friend
            removeFriend(userId)
        }
        
        onEditProfileClicked: {
            // Open profile edit page
            pageStack.push(Qt.resolvedUrl("../EditProfilePage.qml"), {
                userProfile: userProfileSheet.userProfile
            })
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
    
    // Connect to C++ caches for re-rendering when profiles/emojis load
    Connections {
        target: SerchatAPI.userProfileCache
        
        onVersionChanged: {
            // Force delegate re-binding when profiles are loaded
            // The ListView will automatically update via role bindings
        }
    }
    
    Connections {
        target: SerchatAPI.emojiCache
        
        onVersionChanged: {
            // MarkdownText components will re-render via emojiCacheVersion binding
        }
    }
    
    // Connect to C++ model signals
    Connections {
        target: SerchatAPI.messageModel
        
        // When a message is added, prefetch the sender's profile if needed
        onMessageAdded: {
            var message = SerchatAPI.messageModel.getMessage(messageId)
            if (message && message.senderId) {
                // Cache will auto-fetch if not present
                SerchatAPI.userProfileCache.fetchProfile(message.senderId)
            }
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
        serverId: messageView.serverId
        
        onReactionSelected: {
            addReaction(messageId, emoji, emojiType, emojiId)
        }
    }
    
    // Media viewer for fullscreen image/video viewing
    Components.MediaViewer {
        id: mediaViewer
        anchors.fill: parent
    }
    
    // Function to open media viewer
    function openMediaViewer(url, name, mime) {
        mediaViewer.open(url, name, mime)
    }
}
