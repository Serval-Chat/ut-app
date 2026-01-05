import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * SearchOverlay - Overlay for searching messages in a channel/DM
 */
Rectangle {
    id: searchOverlay
    
    property string serverId: ""
    property string channelId: ""
    property string dmRecipientId: ""
    property bool isDMMode: dmRecipientId !== "" && serverId === ""
    
    property var searchResults: []
    property bool loading: false
    property string query: ""
    property bool opened: false
    
    signal resultClicked(string messageId)
    signal close()
    
    visible: opened
    color: Theme.palette.normal.background
    
    Column {
        anchors.fill: parent
        
        // Header with search field
        Rectangle {
            width: parent.width
            height: units.gu(6)
            color: Qt.darker(searchOverlay.color, 1.02)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1)
                anchors.rightMargin: units.gu(1)
                spacing: units.gu(1)
                
                // Back button
                AbstractButton {
                    width: units.gu(4)
                    height: parent.height
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "back"
                        color: Theme.palette.normal.baseText
                    }
                    
                    onClicked: {
                        opened = false
                        close()
                    }
                }
                
                // Search input
                TextField {
                    id: searchInput
                    width: parent.width - units.gu(10)
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: i18n.tr("Search messages...")
                    
                    onTextChanged: {
                        query = text
                        searchTimer.restart()
                    }
                    
                    onAccepted: performSearch()
                }
                
                // Clear button
                AbstractButton {
                    width: units.gu(4)
                    height: parent.height
                    visible: searchInput.text.length > 0
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2)
                        height: units.gu(2)
                        name: "close"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
                    onClicked: {
                        searchInput.text = ""
                        searchResults = []
                    }
                }
            }
            
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: units.dp(1)
                color: Qt.darker(searchOverlay.color, 1.1)
            }
        }
        
        // Search info
        Item {
            width: parent.width
            height: units.gu(4)
            visible: query.length > 0 && !loading
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                text: searchResults.length > 0 ? 
                      i18n.tr("%1 result(s) found", "%1 results found", searchResults.length).arg(searchResults.length) :
                      i18n.tr("No results found")
                fontSize: "small"
                color: Theme.palette.normal.backgroundSecondaryText
            }
        }
        
        // Loading indicator
        Item {
            width: parent.width
            height: units.gu(10)
            visible: loading
            
            Column {
                anchors.centerIn: parent
                spacing: units.gu(1)
                
                ActivityIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    running: loading
                }
                
                Label {
                    text: i18n.tr("Searching...")
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
            }
        }
        
        // Empty state
        Item {
            width: parent.width
            height: parent.height - units.gu(10)
            visible: query.length === 0 && !loading
            
            Column {
                anchors.centerIn: parent
                spacing: units.gu(2)
                width: parent.width - units.gu(4)
                
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(8)
                    height: units.gu(8)
                    name: "search"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Search Messages")
                    fontSize: "large"
                    font.bold: true
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Enter a search term to find messages in this channel")
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }
        }
        
        // Search results
        ListView {
            id: resultsList
            width: parent.width
            height: parent.height - units.gu(10)
            clip: true
            visible: searchResults.length > 0 && !loading
            cacheBuffer: units.gu(30)  // Performance optimization
            
            model: searchResults
            
            delegate: Rectangle {
                width: resultsList.width
                height: resultColumn.height + units.gu(2)
                color: mouseArea.pressed ? Qt.darker(searchOverlay.color, 1.05) : "transparent"
                
                Column {
                    id: resultColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: units.gu(2)
                    anchors.rightMargin: units.gu(2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.5)
                    
                    Row {
                        spacing: units.gu(1)
                        
                        // Sender avatar
                        Components.Avatar {
                            width: units.gu(3)
                            height: units.gu(3)
                            name: modelData.senderName || ""
                            source: modelData.senderAvatar || ""
                            showStatus: false
                        }
                        
                        Label {
                            text: modelData.senderName || i18n.tr("Unknown")
                            fontSize: "small"
                            font.bold: true
                        }
                        
                        Label {
                            text: SerchatAPI.markdownParser.formatTimestamp(modelData.createdAt)
                            fontSize: "x-small"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                    }
                    
                    // Message preview with highlighted query
                    Label {
                        text: highlightQuery(modelData.text || "", query)
                        textFormat: Text.StyledText
                        fontSize: "small"
                        wrapMode: Text.Wrap
                        width: parent.width
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    onClicked: resultClicked(modelData._id || modelData.id)
                }
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: units.dp(1)
                    color: Theme.palette.normal.base
                }
            }
        }
    }
    
    // Debounce timer for search
    Timer {
        id: searchTimer
        interval: 500
        onTriggered: {
            if (query.length >= 2) {
                performSearch()
            }
        }
    }
    
    function performSearch() {
        if (query.length < 2) {
            searchResults = []
            return
        }
        
        loading = true
        
        // API call - when search endpoint is implemented
        // For now, do a client-side search through existing messages
        // This would be replaced with: SerchatAPI.searchMessages(serverId, channelId, query)
        
        // Mock search - simulate delay
        mockSearchTimer.start()
    }
    
    Timer {
        id: mockSearchTimer
        interval: 300
        onTriggered: {
            loading = false
            // Mock results - would be replaced with actual API response
            searchResults = []
        }
    }
    
    function highlightQuery(text, searchTerm) {
        if (!text || !searchTerm) return text
        
        var escaped = text.replace(/&/g, '&amp;')
                         .replace(/</g, '&lt;')
                         .replace(/>/g, '&gt;')
        
        var regex = new RegExp("(" + searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ")", "gi")
        return escaped.replace(regex, '<b><font color="#3498db">$1</font></b>')
    }
    
    function open() {
        opened = true
        searchInput.forceActiveFocus()
    }
    
    // Focus input when opened
    onOpenedChanged: {
        if (opened) {
            searchInput.forceActiveFocus()
        } else {
            searchInput.text = ""
            searchResults = []
        }
    }
}
