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
    property string currentChannelId: ""
    property string currentChannelName: ""
    property string currentChannelType: "text"
    property string currentUserId: ""
    property string currentUserName: ""
    property string currentUserAvatar: ""
    
    // DM state
    property string currentDMRecipientId: ""
    property string currentDMRecipientName: ""
    property string currentDMRecipientAvatar: ""
    
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
    readonly property bool isWideScreen: width >= units.gu(80)
    readonly property bool isMediumScreen: width >= units.gu(50) && width < units.gu(80)
    
    // Main layout
    Row {
        anchors.fill: parent
        
        // Server sidebar (always visible on wide screens, conditionally on mobile)
        Components.ServerListView {
            id: serverList
            height: parent.height
            visible: isWideScreen || mobileViewMode === "servers"
            width: visible ? units.gu(7) : 0
            
            servers: homePage.servers
            selectedServerId: currentServerId
            
            onServerSelected: {
                currentServerId = serverId
                currentServerName = serverName
                currentChannelId = ""
                currentChannelName = ""
                loadChannels(serverId)
                
                if (!isWideScreen) {
                    mobileViewMode = "channels"
                }
            }
            
            onHomeClicked: {
                currentServerId = ""
                currentServerName = ""
                currentChannelId = ""
                currentDMRecipientId = ""
                currentDMRecipientName = ""
                currentDMRecipientAvatar = ""
                channels = []
                categories = []
                messages = []
                
                // On non-wide screens, go to channels view to show DM list
                if (!isWideScreen) {
                    mobileViewMode = "channels"
                }
                
                // TODO: Load DM conversations from API
                // loadDMConversations()
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
            height: parent.height
            visible: (isWideScreen || isMediumScreen || mobileViewMode === "channels") && currentServerId === ""
            width: visible ? units.gu(26) : 0
            
            conversations: homePage.dmConversations
            unreadCounts: homePage.dmUnreadCounts
            selectedConversationId: currentDMRecipientId
            currentUserName: homePage.currentUserName
            currentUserAvatar: homePage.currentUserAvatar
            showBackButton: !serverList.visible
            
            onConversationSelected: {
                currentDMRecipientId = recipientId
                currentDMRecipientName = recipientName
                currentDMRecipientAvatar = recipientAvatar
                loadDMMessages(recipientId)
                
                if (!isWideScreen && !isMediumScreen) {
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
        
        // Channel sidebar (visible on medium+ screens when server selected, or on mobile)
        Components.ChannelListView {
            id: channelList
            height: parent.height
            visible: (isWideScreen || isMediumScreen || mobileViewMode === "channels") && currentServerId !== ""
            width: visible ? units.gu(26) : 0
            
            serverId: currentServerId
            serverName: currentServerName
            selectedChannelId: currentChannelId
            channels: homePage.channels
            categories: homePage.categories
            currentUserName: homePage.currentUserName
            currentUserAvatar: homePage.currentUserAvatar
            showBackButton: !serverList.visible  // Show back button when server list is hidden
            
            onChannelSelected: {
                currentChannelId = channelId
                currentChannelName = channelName
                currentChannelType = channelType
                loadMessages(currentServerId, channelId)
                
                if (!isWideScreen && !isMediumScreen) {
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
        
        // Message view (main content area)
        Components.MessageView {
            id: messageView
            height: parent.height
            width: parent.width - (serverList.visible ? serverList.width : 0) - (channelList.visible ? channelList.width : 0) - (dmListView.visible ? dmListView.width : 0)
            visible: (isWideScreen || isMediumScreen || mobileViewMode === "messages") && (currentChannelId !== "" || currentDMRecipientId !== "")
            
            serverId: currentServerId
            channelId: currentChannelId
            channelName: currentChannelName
            channelType: currentChannelType
            messages: homePage.messages
            loading: loadingMessages
            hasMoreMessages: homePage.hasMoreMessages
            currentUserId: homePage.currentUserId
            userProfiles: homePage.userProfiles
            showBackButton: !channelList.visible  // Show back button when channel list is hidden
            
            onBackClicked: {
                if (isMediumScreen) {
                    mobileViewMode = "channels"
                } else {
                    mobileViewMode = "channels"
                }
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
        }
        
        // Empty state when no channel/DM selected
        Rectangle {
            height: parent.height
            width: {
                // On wide screen, fill remaining space when no channel/DM selected
                if (isWideScreen) {
                    // Home view with no DM selected
                    if (currentServerId === "" && currentDMRecipientId === "") {
                        return parent.width - serverList.width - dmListView.width
                    }
                    // Server selected but no channel
                    if (currentServerId !== "" && currentChannelId === "") {
                        return parent.width - serverList.width - channelList.width
                    }
                    return 0
                }
                // On mobile/medium, show when in messages view with nothing selected
                if (mobileViewMode === "messages" && currentChannelId === "" && currentDMRecipientId === "") {
                    return parent.width - (serverList.visible ? serverList.width : 0) - (channelList.visible ? channelList.width : 0) - (dmListView.visible ? dmListView.width : 0)
                }
                return 0
            }
            visible: width > 0
            color: Theme.palette.normal.background
            
            Column {
                anchors.centerIn: parent
                spacing: units.gu(2)
                
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
                    width: Math.min(parent.parent.width - units.gu(4), units.gu(40))
                }
            }
        }
    }
    
    // Loading overlay
    Rectangle {
        anchors.fill: parent
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
        onMessagesFetched: {
            if (channelId === currentChannelId) {
                loadingMessages = false
                
                // Append to existing messages for pagination
                if (homePage.messages.length === 0) {
                    homePage.messages = messages
                } else {
                    // Older messages - append at end (messages displayed bottom-to-top)
                    homePage.messages = homePage.messages.concat(messages)
                }
                
                // Check if there are more messages
                hasMoreMessages = messages.length >= 50
            }
        }
        
        onMessagesFetchFailed: {
            if (channelId === currentChannelId) {
                loadingMessages = false
                console.log("Failed to fetch messages:", error)
            }
        }
        
        onMessageSent: {
            // Replace temp message with real one
            var newMessages = []
            var found = false
            
            for (var i = 0; i < messages.length; i++) {
                var msg = messages[i]
                if (msg._id && msg._id.toString().indexOf("temp_") === 0 && 
                    msg.text === message.text && !found) {
                    // Replace temp with actual message
                    newMessages.push(message)
                    found = true
                } else {
                    newMessages.push(msg)
                }
            }
            
            // If not found (rare), prepend
            if (!found) {
                newMessages = [message].concat(newMessages)
            }
            
            messages = newMessages
        }
        
        onMessageSendFailed: {
            console.log("Failed to send message:", error)
            // Remove temp message
            var newMessages = []
            for (var i = 0; i < messages.length; i++) {
                var msg = messages[i]
                if (!(msg._id && msg._id.toString().indexOf("temp_") === 0)) {
                    newMessages.push(msg)
                }
            }
            messages = newMessages
        }
    }
    
    // ========================================================================
    // Data Loading Functions
    // ========================================================================
    
    function loadServers() {
        loadingServers = true
        SerchatAPI.getServers()
    }
    
    function loadChannels(serverId) {
        loadingChannels = true
        messages = []
        currentChannelId = ""
        currentChannelName = ""
        SerchatAPI.getChannels(serverId)
    }
    
    function loadMessages(serverId, channelId) {
        if (!serverId || !channelId) return
        
        loadingMessages = true
        messages = []
        hasMoreMessages = true
        
        SerchatAPI.getMessages(serverId, channelId, 50, "")
    }
    
    function loadOlderMessages() {
        if (loadingMessages || !hasMoreMessages || messages.length === 0) return
        
        loadingMessages = true
        
        // Get the oldest message ID
        var oldestId = messages[messages.length - 1]._id || messages[messages.length - 1].id
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
        
        messages = [newMessage].concat(messages)
        
        // Send via API
        SerchatAPI.sendMessage(currentServerId, currentChannelId, text, replyToId || "")
    }
    
    function loadDMMessages(recipientId) {
        if (!recipientId) return
        
        loadingMessages = true
        messages = []
        hasMoreMessages = true
        
        // TODO: Implement DM message fetching when API is ready
        // SerchatAPI.getDMMessages(recipientId, 50, "")
        loadingMessages = false
    }
    
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
