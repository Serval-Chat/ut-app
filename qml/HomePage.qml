import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: homePage
    
    // Hide default header - we use custom headers in views
    header: Item { height: 0 }
    
    // State management
    property string currentServerId: ""
    property string currentServerName: ""
    property string currentServerOwnerId: ""
    property string currentChannelId: ""
    property string currentChannelName: ""
    property string currentChannelType: "text"
    property var currentChannelPermissions: ({})  // Channel-specific permission overrides
    property string currentUserId: ""
    property string currentUserName: ""
    property string currentUserAvatar: ""
    
    // DM state
    property string currentDMRecipientId: ""
    property string currentDMRecipientName: ""
    property string currentDMRecipientAvatar: ""
    
    // Computed permission for current channel
    // For now, simple check: owner always can send, channels without explicit deny allow sending
    readonly property bool canSendInCurrentChannel: {
        // DMs always allow sending
        if (currentDMRecipientId !== "") return true
        // No server/channel selected
        if (currentServerId === "" || currentChannelId === "") return false
        // Server owner can always send
        if (currentUserId === currentServerOwnerId) return true
        // For now, allow sending in all channels (proper permission checking needs member roles)
        // The server will reject unauthorized messages anyway
        return true
    }
    
    // View mode for mobile: "servers", "channels", "messages"
    property string mobileViewMode: "servers"
    
    // Data stores
    property var servers: []
    property var channels: []
    property var categories: []
    property var messages: []
    property var userProfiles: ({})
    property var unreadCounts: ({})
    
    // DM data stores
    property var dmConversations: []
    property var dmUnreadCounts: ({})
    
    // Loading states
    property bool loadingServers: false
    property bool loadingChannels: false
    property bool loadingMessages: false
    property bool hasMoreMessages: true
    
    // Responsive layout threshold
    readonly property bool isWideScreen: width >= units.gu(200)
    readonly property bool isMediumScreen: width >= units.gu(150) && !isWideScreen
    readonly property bool isSmallScreen: !isWideScreen && !isMediumScreen
    
    // Sidebar width calculations for mobile overlay mode
    readonly property real serverListWidth: units.gu(7)
    readonly property real channelListWidth: units.gu(26)
    
    // Animation duration for smooth transitions
    readonly property int animationDuration: 250
    
    // Calculate sidebar positions for small screen sliding panel
    readonly property real totalSidebarWidth: serverListWidth + channelListWidth
    readonly property real sidebarX: {
        if (!isSmallScreen) return 0  // Fixed position on wide/medium screens
        switch (mobileViewMode) {
            case "servers": return 0  // Sidebar at edge, content will overlap channel list
            case "channels": return 0  // Show both sidebars
            case "messages": return -totalSidebarWidth  // Hide sidebars off-screen
            default: return 0
        }
    }
    
    // Calculate main content position for small screens - slides with sidebar
    readonly property real mainContentX: {
        if (!isSmallScreen) return serverListWidth + channelListWidth
        switch (mobileViewMode) {
            case "servers": return serverListWidth  // Shows after server list (overlaps channel)
            case "channels": return totalSidebarWidth  // Shows after both sidebars
            case "messages": return 0  // Full screen
            default: return 0
        }
    }
    
    // Calculate visible sidebar width for drop shadow positioning
    readonly property real visibleSidebarWidth: {
        if (!isSmallScreen) return totalSidebarWidth
        switch (mobileViewMode) {
            case "servers": return serverListWidth
            case "channels": return totalSidebarWidth
            case "messages": return 0
            default: return 0
        }
    }
    
    // Shadow position for smooth animation
    property real shadowLeftMargin: visibleSidebarWidth
    
    Behavior on shadowLeftMargin {
        NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
    }
    
    // Main content area (message view + placeholder) - rendered first so sidebars appear on top
    Item {
        id: mainContentArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        
        // On small screens, this slides with the sidebar
        // On wide/medium screens, it's fixed after sidebars
        x: mainContentX
        width: parent.width - (isSmallScreen ? 0 : (serverListWidth + channelListWidth))
        
        Behavior on x {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        Behavior on width {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        // Message view (main content area)
        Components.MessageView {
            id: messageView
            anchors.fill: parent
            visible: currentChannelId !== "" || currentDMRecipientId !== ""
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            // Server channel properties
            serverId: currentServerId
            channelId: currentChannelId
            channelName: currentChannelName
            channelType: currentChannelType
            
            // DM properties
            dmRecipientId: currentDMRecipientId
            dmRecipientName: currentDMRecipientName
            dmRecipientAvatar: currentDMRecipientAvatar
            
            messages: homePage.messages
            loading: loadingMessages
            hasMoreMessages: homePage.hasMoreMessages
            currentUserId: homePage.currentUserId
            userProfiles: homePage.userProfiles
            showBackButton: isSmallScreen && mobileViewMode === "messages"
            canSendMessages: homePage.canSendInCurrentChannel
            
            onBackClicked: {
                mobileViewMode = "channels"
            }
            
            onSendMessage: {
                sendMessageToChannel(text, replyToId)
            }
            
            onLoadMoreMessages: {
                loadOlderMessages()
            }
            
            onUserProfileClicked: {
                pageStack.push(Qt.resolvedUrl("ProfilePage.qml"), {
                    userId: userId
                })
            }
            
            onViewFullProfile: {
                pageStack.push(Qt.resolvedUrl("ProfilePage.qml"), {
                    userId: userId
                })
            }
        }
        
        // Empty state placeholder (always visible when no channel/DM selected)
        Rectangle {
            id: placeholderView
            anchors.fill: parent
            visible: currentChannelId === "" && currentDMRecipientId === ""
            opacity: visible ? 1 : 0
            color: Theme.palette.normal.background
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            // Header with back button for small screens
            Rectangle {
                id: placeholderHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: units.gu(6)
                color: Qt.darker(parent.color, 1.02)
                visible: isSmallScreen && mobileViewMode === "messages"
                
                AbstractButton {
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1.5)
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(4)
                    height: parent.height
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "back"
                        color: Theme.palette.normal.baseText
                    }
                    
                    onClicked: mobileViewMode = "channels"
                }
                
                Label {
                    anchors.centerIn: parent
                    text: currentServerId === "" ? i18n.tr("Direct Messages") : currentServerName
                    fontSize: "medium"
                    color: Theme.palette.normal.baseText
                }
            }
            
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: placeholderHeader.visible ? placeholderHeader.height / 2 : 0
                spacing: units.gu(2)
                width: Math.min(parent.width - units.gu(4), units.gu(40))
                
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(10)
                    height: units.gu(10)
                    name: currentServerId === "" ? "message" : "edit"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentServerId === "" ? 
                          i18n.tr("Select a conversation") : 
                          i18n.tr("Select a channel")
                    fontSize: "large"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentServerId === "" ?
                          i18n.tr("Choose a conversation from the list or start a new one") :
                          i18n.tr("Pick a channel from the list to start chatting")
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }
        }
    }
    
    // Semi-transparent overlay for dimming content when sidebar is open on small screens
    Rectangle {
        id: sidebarOverlay
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Position overlay at the content area's x position
        x: mainContentX
        width: parent.width
        color: "#000000"
        opacity: {
            if (!isSmallScreen) return 0
            if (mobileViewMode === "messages") return 0
            // Show overlay when sidebar is visible
            return 0.5
        }
        visible: opacity > 0
        z: 5
        
        Behavior on opacity {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        Behavior on x {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: parent.visible && (currentChannelId !== "" || currentDMRecipientId !== "")
            onClicked: {
                mobileViewMode = "messages"
            }
        }
    }
    
    // Sliding sidebar container
    Item {
        id: sidebarContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: totalSidebarWidth
        x: sidebarX
        z: 10
        
        Behavior on x {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        // Drop shadow for depth on small screens
        Row {
            anchors.left: parent.left
            anchors.leftMargin: shadowLeftMargin
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: isSmallScreen && mobileViewMode !== "messages"
            
            Repeater {
                model: 8
                Rectangle {
                    width: units.gu(0.25)
                    height: parent.height
                    color: "#000000"
                    opacity: (8 - index) * 0.02
                }
            }
        }
        
        // Server sidebar
        Components.ServerListView {
            id: serverList
            anchors.left: parent.left
            height: parent.height
            width: serverListWidth
            // Always visible on wide screens, or on small screens when sidebar is showing
            visible: isWideScreen || isMediumScreen || (isSmallScreen && mobileViewMode !== "messages")
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            servers: homePage.servers
            selectedServerId: currentServerId
            
            onServerSelected: {
                currentServerId = serverId
                currentServerName = serverName
                currentServerOwnerId = ownerId
                currentChannelId = ""
                currentChannelName = ""
                loadChannels(serverId)
                
                if (isSmallScreen) {
                    mobileViewMode = "channels"
                }
            }
            
            onHomeClicked: {
                currentServerId = ""
                currentServerName = ""
                currentServerOwnerId = ""
                currentChannelId = ""
                currentDMRecipientId = ""
                currentDMRecipientName = ""
                currentDMRecipientAvatar = ""
                channels = []
                categories = []
                homePage.messages = []
                
                // On small screens, go to channels view to show DM list
                if (isSmallScreen) {
                    mobileViewMode = "channels"
                }
                
                // Load DM conversations (friends list)
                loadDMConversations()
            }
            
            onAddServerClicked: {
                pageStack.push(Qt.resolvedUrl("JoinServerPage.qml"))
            }
            
            onSettingsClicked: {
                pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
        }
        
        // DM list (visible when Home is selected instead of a server)
        Components.DMListView {
            id: dmListView
            anchors.left: serverList.right
            height: parent.height
            width: channelListWidth
            // Visible when no server selected (Home mode), but only in channels mode on small screens
            visible: currentServerId === "" && (!isSmallScreen || mobileViewMode === "channels")
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            conversations: homePage.dmConversations
            unreadCounts: homePage.dmUnreadCounts
            selectedConversationId: currentDMRecipientId
            currentUserName: homePage.currentUserName
            currentUserAvatar: homePage.currentUserAvatar
            
            onConversationSelected: {
                // Clear channel state when switching to DM
                currentChannelId = ""
                currentChannelName = ""
                currentChannelType = "text"
                
                // Set DM state
                currentDMRecipientId = recipientId
                currentDMRecipientName = recipientName
                currentDMRecipientAvatar = recipientAvatar
                loadDMMessages(recipientId)
                
                if (isSmallScreen) {
                    mobileViewMode = "messages"
                }
            }
            
            onBackClicked: {
                mobileViewMode = "servers"
            }
            
            onCreateDMClicked: {
                // TODO: Open create DM dialog
                console.log("Create DM clicked")
            }
        }
        
        // Channel sidebar (visible when server selected)
        Components.ChannelListView {
            id: channelList
            anchors.left: serverList.right
            height: parent.height
            width: channelListWidth
            // Visible when a server is selected, but only in channels mode on small screens
            visible: currentServerId !== "" && (!isSmallScreen || mobileViewMode === "channels")
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            serverId: currentServerId
            serverName: currentServerName
            selectedChannelId: currentChannelId
            channels: homePage.channels
            categories: homePage.categories
            currentUserName: homePage.currentUserName
            currentUserAvatar: homePage.currentUserAvatar
            
            onChannelSelected: {
                // Leave old channel if we were in one
                if (currentServerId && currentChannelId) {
                    SerchatAPI.leaveChannel(currentServerId, currentChannelId)
                }
                
                // Clear DM state when switching to channel
                currentDMRecipientId = ""
                currentDMRecipientName = ""
                currentDMRecipientAvatar = ""
                
                // Clear messages immediately when switching channels
                homePage.messages = []
                
                currentChannelId = channelId
                currentChannelName = channelName
                currentChannelType = channelType
                loadMessages(currentServerId, channelId)
                
                if (isSmallScreen) {
                    mobileViewMode = "messages"
                }
            }
            
            onBackClicked: {
                mobileViewMode = "servers"
            }
            
            onServerSettingsClicked: {
                pageStack.push(Qt.resolvedUrl("ServerSettingsPage.qml"), {
                    serverId: currentServerId,
                    serverName: currentServerName
                })
            }
        }
    }
    
    // Edge swipe gesture handler for revealing sidebar on small screens
    MouseArea {
        id: edgeSwipeArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: units.gu(2)
        visible: isSmallScreen && mobileViewMode === "messages"
        z: 15
        
        property real startX: 0
        property bool dragging: false
        
        onPressed: {
            startX = mouse.x
            dragging = true
        }
        
        onPositionChanged: {
            if (dragging && mouse.x - startX > units.gu(4)) {
                mobileViewMode = "channels"
                dragging = false
            }
        }
        
        onReleased: {
            dragging = false
        }
    }
    
    // Loading overlay
    Rectangle {
        anchors.fill: parent
        z: 100
        color: Qt.rgba(Theme.palette.normal.background.r,
                      Theme.palette.normal.background.g,
                      Theme.palette.normal.background.b, 0.8)
        visible: loadingServers && servers.length === 0
        
        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)
            
            ActivityIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.parent.visible
            }
            
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Loading...")
                color: Theme.palette.normal.foreground
            }
        }
    }
    
    // ========================================================================
    // API Connections
    // ========================================================================
    
    Connections {
        target: SerchatAPI
        
        // Profile
        onMyProfileFetched: {
            currentUserId = profile.id || ""
            currentUserName = profile.displayName || profile.username || ""
            
            // Set avatar URL - profilePicture contains the full path
            if (profile.profilePicture) {
                currentUserAvatar = SerchatAPI.apiBaseUrl + profile.profilePicture
            }
            
            // Cache own profile
            var profiles = Object.assign({}, userProfiles)
            profiles[profile.id] = profile
            userProfiles = profiles
        }
        
        onMyProfileFetchFailed: {
            console.log("Failed to fetch profile:", error)
        }
        
        // Servers
        onServersFetched: {
            loadingServers = false
            homePage.servers = servers
            
            // Auto-select first server if none selected
            if (servers.length > 0 && currentServerId === "") {
                var firstServer = servers[0]
                currentServerId = firstServer._id || firstServer.id
                currentServerName = firstServer.name
                loadChannels(currentServerId)
            }
        }
        
        onServersFetchFailed: {
            loadingServers = false
            console.log("Failed to fetch servers:", error)
        }
        
        // Channels
        onChannelsFetched: {
            if (serverId === currentServerId) {
                loadingChannels = false
                
                // Separate channels and categories
                var chans = []
                var cats = []
                
                for (var i = 0; i < channels.length; i++) {
                    var item = channels[i]
                    if (item.type === "category") {
                        cats.push(item)
                    } else {
                        chans.push(item)
                    }
                }
                
                homePage.channels = chans
                homePage.categories = cats
                
                // Auto-select first text channel
                if (channels.length > 0 && currentChannelId === "") {
                    for (var j = 0; j < channels.length; j++) {
                        if (channels[j].type === "text") {
                            var ch = channels[j]
                            currentChannelId = ch._id || ch.id
                            currentChannelName = ch.name
                            currentChannelType = ch.type
                            loadMessages(currentServerId, currentChannelId)
                            break
                        }
                    }
                }
            }
        }
        
        onChannelsFetchFailed: {
            if (serverId === currentServerId) {
                loadingChannels = false
                console.log("Failed to fetch channels:", error)
            }
        }
        
        // Messages
        onMessagesFetched: function(requestId, serverId, channelId, fetchedMessages) {
            console.log("[HomePage] Messages fetched for channel:", channelId, "current:", currentChannelId, "count:", fetchedMessages.length)
            if (channelId === currentChannelId) {
                loadingMessages = false
                
                // API returns oldest first, but we need newest first (index 0 = bottom with BottomToTop)
                var reversedMessages = fetchedMessages.slice().reverse()
                
                // Check if this is a pagination request (loading older messages)
                // by seeing if we already have messages and this is from "before" query
                if (homePage.messages.length > 0 && reversedMessages.length > 0) {
                    // This is pagination - append older messages at the end
                    homePage.messages = homePage.messages.concat(reversedMessages)
                } else {
                    // Initial load - replace all messages
                    homePage.messages = reversedMessages
                }
                console.log("[HomePage] Messages updated, total:", homePage.messages.length)
                
                // Check if there are more messages
                hasMoreMessages = fetchedMessages.length >= 50
            } else {
                console.log("[HomePage] Ignoring messages for old channel:", channelId)
            }
        }
        
        onMessagesFetchFailed: {
            if (channelId === currentChannelId) {
                loadingMessages = false
                console.log("Failed to fetch messages:", error)
            }
        }
        
        onMessageSent: {
            console.log("[HomePage] Message sent via HTTP:", message._id)
            
            // The HTTP response contains the real message. We need to:
            // 1. Remove any temp message with matching text
            // 2. Check if Socket.IO already delivered this message
            var msgId = String(message._id || message.id || "")
            var newMessages = []
            var foundTempMessage = false
            var alreadyHasRealMessage = false
            
            // First pass: check if we already have the real message from Socket.IO
            for (var i = 0; i < homePage.messages.length; i++) {
                var existingId = String(homePage.messages[i]._id || homePage.messages[i].id || "")
                if (existingId === msgId) {
                    alreadyHasRealMessage = true
                    break
                }
            }
            
            // Second pass: build new array, replacing temp message if needed
            for (var j = 0; j < homePage.messages.length; j++) {
                var msg = homePage.messages[j]
                var id = String(msg._id || msg.id || "")
                
                // Skip the temp message
                if (id.indexOf("temp_") === 0 && msg.text === message.text && !foundTempMessage) {
                    foundTempMessage = true
                    // Only add real message if Socket.IO hasn't delivered it yet
                    if (!alreadyHasRealMessage) {
                        newMessages.push(message)
                    }
                } else {
                    newMessages.push(msg)
                }
            }
            
            // If no temp message was found and we don't have it from Socket.IO, prepend
            if (!foundTempMessage && !alreadyHasRealMessage) {
                newMessages = [message].concat(newMessages)
            }
            
            homePage.messages = newMessages
        }
        
        onMessageSendFailed: {
            console.log("Failed to send message:", error)
            // Remove temp message
            var newMessages = []
            for (var i = 0; i < homePage.messages.length; i++) {
                var msg = homePage.messages[i]
                if (!(msg._id && msg._id.toString().indexOf("temp_") === 0)) {
                    newMessages.push(msg)
                }
            }
            homePage.messages = newMessages
        }
        
        // Friends (for DM list)
        onFriendsFetched: {
            console.log("[HomePage] Friends fetched:", friends.length)
            // Transform friends list into DM conversations format
            var conversations = []
            for (var i = 0; i < friends.length; i++) {
                var friend = friends[i]
                conversations.push({
                    recipientId: friend._id || friend.id,
                    recipientName: friend.displayName || friend.username,
                    recipientAvatar: friend.profilePicture ? SerchatAPI.apiBaseUrl + friend.profilePicture : "",
                    lastMessageAt: friend.latestMessageAt || "",
                    customStatus: friend.customStatus
                })
            }
            // Sort by most recent message
            conversations.sort(function(a, b) {
                if (!a.lastMessageAt) return 1
                if (!b.lastMessageAt) return -1
                return new Date(b.lastMessageAt) - new Date(a.lastMessageAt)
            })
            dmConversations = conversations
        }
        
        onFriendsFetchFailed: {
            console.log("[HomePage] Failed to fetch friends:", error)
        }
        
        // Server management
        onServerJoined: {
            console.log("[HomePage] Joined server:", serverId)
            // Refresh servers list
            SerchatAPI.getServers(false)
        }
        
        onServerJoinFailed: {
            console.log("[HomePage] Failed to join server:", error)
        }
        
        onServerCreated: {
            console.log("[HomePage] Created server:", server.name)
            // Refresh servers list
            SerchatAPI.getServers(false)
        }
        
        onServerCreateFailed: {
            console.log("[HomePage] Failed to create server:", error)
        }
        
        // ====================================================================
        // Real-time Socket.IO Events
        // ====================================================================
        
        onSocketConnected: {
            console.log("[HomePage] Socket connected")
            // Join all servers we're a member of
            for (var i = 0; i < servers.length; i++) {
                var serverId = servers[i]._id || servers[i].id
                SerchatAPI.joinServer(serverId)
            }
            
            // Join current channel if any
            if (currentServerId && currentChannelId) {
                SerchatAPI.joinChannel(currentServerId, currentChannelId)
            }
        }
        
        onSocketDisconnected: {
            console.log("[HomePage] Socket disconnected")
        }
        
        onSocketReconnecting: {
            console.log("[HomePage] Socket reconnecting, attempt:", attempt)
        }
        
        onSocketError: {
            console.log("[HomePage] Socket error:", message)
        }
        
        // Real-time server messages
        onServerMessageReceived: {
            console.log("[HomePage] Server message received:", message._id, "channelId:", message.channelId)
            
            // Only add if it's for the current channel
            // channelId might be an ObjectId string or plain string - compare as strings
            var msgChannelId = String(message.channelId || "")
            var currChannelId = String(currentChannelId || "")
            console.log("[HomePage] Comparing channels - message:", msgChannelId, "current:", currChannelId)
            
            if (msgChannelId === currChannelId && msgChannelId !== "") {
                // Check if we already have this message (from HTTP response or duplicate Socket.IO)
                var isDuplicate = false
                var newId = String(message._id || message.id || "")
                var tempMessageIndex = -1
                
                for (var i = 0; i < homePage.messages.length; i++) {
                    var existingId = String(homePage.messages[i]._id || homePage.messages[i].id || "")
                    if (existingId === newId) {
                        isDuplicate = true
                        break
                    }
                    // Also track if there's a temp message with same text (our own message)
                    if (existingId.indexOf("temp_") === 0 && 
                        homePage.messages[i].text === message.text &&
                        tempMessageIndex === -1) {
                        tempMessageIndex = i
                    }
                }
                
                if (!isDuplicate) {
                    // If we found a matching temp message, replace it
                    if (tempMessageIndex !== -1) {
                        var newMessages = homePage.messages.slice()
                        newMessages[tempMessageIndex] = message
                        homePage.messages = newMessages
                        console.log("[HomePage] Replaced temp message with real message")
                    } else {
                        // Add new message at index 0 (displayed at bottom with BottomToTop)
                        homePage.messages = [message].concat(homePage.messages)
                        console.log("[HomePage] Added message to list, new count:", homePage.messages.length)
                    }
                } else {
                    console.log("[HomePage] Skipping duplicate message:", newId)
                }
            }
        }
        
        onServerMessageEdited: {
            console.log("[HomePage] Server message edited:", message._id)
            
            // Update message in the list
            var msgId = message._id || message.id
            var newMessages = []
            for (var i = 0; i < messages.length; i++) {
                var existingId = messages[i]._id || messages[i].id
                if (existingId === msgId) {
                    newMessages.push(message)
                } else {
                    newMessages.push(messages[i])
                }
            }
            homePage.messages = newMessages
        }
        
        onServerMessageDeleted: {
            console.log("[HomePage] Server message deleted:", messageId)
            
            // Remove message from the list
            var newMessages = []
            for (var i = 0; i < messages.length; i++) {
                var existingId = messages[i]._id || messages[i].id
                if (existingId !== messageId) {
                    newMessages.push(messages[i])
                }
            }
            homePage.messages = newMessages
        }
        
        // Channel unread notifications
        onChannelUnread: {
            console.log("[HomePage] Channel unread:", serverId, channelId)
            
            // Update unread counts
            var newCounts = Object.assign({}, unreadCounts)
            var key = serverId + ":" + channelId
            newCounts[key] = (newCounts[key] || 0) + 1
            unreadCounts = newCounts
        }
        
        // DM unread notifications
        onDmUnread: {
            console.log("[HomePage] DM unread:", peer, count)
            
            var newCounts = Object.assign({}, dmUnreadCounts)
            newCounts[peer] = count
            dmUnreadCounts = newCounts
        }
        
        // Direct message events
        onDirectMessageReceived: {
            console.log("[HomePage] DM received:", message._id)
            
            // If currently in DM with this user, add message
            var senderId = String(message.senderId || "")
            var receiverId = String(message.receiverId || "")
            var currRecipient = String(currentDMRecipientId || "")
            
            if (currRecipient !== "" && (currRecipient === senderId || currRecipient === receiverId)) {
                var isDuplicate = false
                var newId = String(message._id || message.id || "")
                for (var i = 0; i < messages.length; i++) {
                    var existingId = String(messages[i]._id || messages[i].id || "")
                    if (existingId === newId) {
                        isDuplicate = true
                        break
                    }
                }
                
                if (!isDuplicate) {
                    // Add new message at index 0 (displayed at bottom with BottomToTop)
                    homePage.messages = [message].concat(homePage.messages)
                    console.log("[HomePage] Added DM to list, new count:", homePage.messages.length)
                }
            }
        }
        
        // User presence
        onUserOnline: {
            console.log("[HomePage] User online:", username)
            // TODO: Update user status in UI
        }
        
        onUserOffline: {
            console.log("[HomePage] User offline:", username)
            // TODO: Update user status in UI
        }
        
        // Typing indicators
        onUserTyping: {
            if (serverId === currentServerId && channelId === currentChannelId) {
                console.log("[HomePage] User typing in channel:", username)
                // TODO: Show typing indicator in MessageView
            }
        }
        
        onDmTyping: {
            console.log("[HomePage] User typing in DM:", username)
            // TODO: Show typing indicator in DM view
        }
        
        // Channel updates
        onChannelCreated: {
            console.log("[HomePage] Channel created in server:", serverId)
            if (serverId === currentServerId) {
                // Refresh channels list
                loadChannels(serverId)
            }
        }
        
        onChannelDeleted: {
            console.log("[HomePage] Channel deleted:", channelId)
            if (serverId === currentServerId) {
                // If we're viewing the deleted channel, go back
                if (channelId === currentChannelId) {
                    currentChannelId = ""
                    currentChannelName = ""
                    homePage.messages = []
                }
                // Refresh channels list
                loadChannels(serverId)
            }
        }
        
        onChannelUpdated: {
            console.log("[HomePage] Channel updated in server:", serverId)
            if (serverId === currentServerId) {
                // Refresh channels list
                loadChannels(serverId)
            }
        }
        
        // Reaction updates
        onReactionAdded: {
            console.log("[HomePage] Reaction added to message:", messageId)
            updateMessageReactions(messageId, reactions)
        }
        
        onReactionRemoved: {
            console.log("[HomePage] Reaction removed from message:", messageId)
            updateMessageReactions(messageId, reactions)
        }
        
        // Friend events
        onFriendAdded: {
            console.log("[HomePage] Friend added:", friendData.username)
            // TODO: Update friends list if visible
            // Could refresh DM conversations list
        }
        
        onFriendRemoved: {
            console.log("[HomePage] Friend removed:", username)
            // TODO: Update friends list if visible
            // If currently in DM with this friend, may want to notify user
        }
        
        onIncomingRequestAdded: {
            console.log("[HomePage] Incoming friend request from:", request.from)
            // TODO: Show notification or update friend requests badge
        }
        
        onIncomingRequestRemoved: {
            console.log("[HomePage] Friend request removed from:", from)
            // TODO: Update friend requests list if visible
        }
    }
    
    // ========================================================================
    // Data Loading Functions
    // ========================================================================
    
    function loadServers() {
        loadingServers = true
        SerchatAPI.getServers()
    }
    
    function loadDMConversations() {
        // Load friends list which serves as DM conversations
        SerchatAPI.getFriends()
    }
    
    function loadChannels(serverId) {
        // Leave current channel if any
        if (currentServerId && currentChannelId) {
            SerchatAPI.leaveChannel(currentServerId, currentChannelId)
        }
        
        loadingChannels = true
        homePage.messages = []  // Clear messages when loading new server
        currentChannelId = ""
        currentChannelName = ""
        SerchatAPI.getChannels(serverId)
    }
    
    function loadMessages(serverId, channelId) {
        if (!serverId || !channelId) return
        
        loadingMessages = true
        homePage.messages = []  // Clear messages when loading new channel
        hasMoreMessages = true
        
        // Join the channel room for real-time updates
        SerchatAPI.joinChannel(serverId, channelId)
        
        SerchatAPI.getMessages(serverId, channelId, 50, "")
    }
    
    function loadOlderMessages() {
        if (loadingMessages || !hasMoreMessages || homePage.messages.length === 0) return
        
        loadingMessages = true
        
        // Get the oldest message ID
        var oldestId = homePage.messages[homePage.messages.length - 1]._id || homePage.messages[homePage.messages.length - 1].id
        SerchatAPI.getMessages(currentServerId, currentChannelId, 50, oldestId)
    }
    
    function sendMessageToChannel(text, replyToId) {
        if (!currentServerId || !currentChannelId || !text) return
        
        // Optimistically add message to view
        var newMessage = {
            _id: "temp_" + Date.now(),
            serverId: currentServerId,
            channelId: currentChannelId,
            senderId: currentUserId,
            text: text,
            createdAt: new Date().toISOString(),
            replyToId: replyToId || null
        }
        
        homePage.messages = [newMessage].concat(homePage.messages)
        
        // Send via API
        SerchatAPI.sendMessage(currentServerId, currentChannelId, text, replyToId || "")
    }
    
    function loadDMMessages(recipientId) {
        if (!recipientId) return
        
        loadingMessages = true
        homePage.messages = []
        hasMoreMessages = true
        
        // TODO: Implement DM message fetching when API is ready
        // SerchatAPI.getDMMessages(recipientId, 50, "")
        loadingMessages = false
    }
    
    // Update reactions for a message
    function updateMessageReactions(messageId, reactions) {
        var newMessages = []
        for (var i = 0; i < homePage.messages.length; i++) {
            var msg = homePage.messages[i]
            var existingId = msg._id || msg.id
            if (existingId === messageId) {
                // Create new object with updated reactions
                var updatedMsg = Object.assign({}, msg)
                updatedMsg.reactions = reactions
                newMessages.push(updatedMsg)
            } else {
                newMessages.push(msg)
            }
        }
        homePage.messages = newMessages
    }
    
    // Note: Channel room joining is handled in loadMessages() function
    
    // ========================================================================
    // Initialization
    // ========================================================================
    
    Component.onCompleted: {
        // Fetch user profile
        SerchatAPI.getMyProfile()
        
        // Load servers
        loadServers()
    }
}
