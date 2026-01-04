import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * EmojiPicker - Emoji selection popup with categories and custom emojis
 * Uses EmojiData singleton for centralized emoji data
 */
Rectangle {
    id: emojiPicker
    
    property string serverId: ""  // For server-specific custom emojis
    property var customEmojis: []  // Custom emojis from server
    property bool opened: false
    property string selectedCategory: "smileys"
    
    signal emojiSelected(string emoji, bool isCustom, string emojiId, string emojiUrl)
    signal closed()
    
    visible: opened
    width: units.gu(38)
    height: units.gu(35)
    radius: units.gu(1)
    color: Theme.palette.normal.background
    
    // Border
    border.width: units.dp(1)
    border.color: Theme.palette.normal.base
    
    // Use categories from EmojiData component
    property var emojiData: Components.EmojiData {}
    property var emojiCategories: emojiData.categories
    
    // Recently used emojis (would be persisted in settings)
    property var recentEmojis: ["😀", "👍", "❤️", "🎉", "🔥"]
    
    // Get emoji data for selected category from component
    function getEmojiDataForCategory(categoryId) {
        if (categoryId === "recent") return recentEmojis
        return emojiData.getEmojisByCategory(categoryId)
    }
    
    // Search functionality
    property string searchQuery: ""
    
    Column {
        anchors.fill: parent
        anchors.margins: units.gu(1)
        spacing: units.gu(0.5)
        
        // Search bar
        Rectangle {
            width: parent.width
            height: units.gu(4)
            radius: units.gu(0.5)
            color: Theme.palette.normal.base
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1)
                spacing: units.gu(0.5)
                
                Icon {
                    width: units.gu(2)
                    height: units.gu(2)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                TextField {
                    id: searchField
                    width: parent.width - units.gu(3)
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: i18n.tr("Search emojis")
                    onTextChanged: searchQuery = text
                }
            }
        }
        
        // Category tabs
        Row {
            width: parent.width
            height: units.gu(4)
            spacing: 0
            
            // Custom emoji tab (if server has custom emojis)
            Rectangle {
                width: parent.width / (emojiCategories.length + (customEmojis.length > 0 ? 1 : 0))
                height: parent.height
                color: selectedCategory === "custom" ? Theme.palette.normal.base : "transparent"
                visible: customEmojis.length > 0
                radius: units.gu(0.5)
                
                Label {
                    anchors.centerIn: parent
                    text: "⭐"
                    fontSize: "medium"
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: selectedCategory = "custom"
                }
            }
            
            Repeater {
                model: emojiCategories
                
                Rectangle {
                    width: parent.width / (emojiCategories.length + (customEmojis.length > 0 ? 1 : 0))
                    height: parent.height
                    color: selectedCategory === modelData.id ? Theme.palette.normal.base : "transparent"
                    radius: units.gu(0.5)
                    
                    Label {
                        anchors.centerIn: parent
                        text: modelData.icon
                        fontSize: "medium"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: selectedCategory = modelData.id
                    }
                }
            }
        }
        
        // Category label
        Item {
            width: parent.width
            height: units.gu(2.5)
            
            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (searchQuery) return i18n.tr("Search Results")
                    if (selectedCategory === "custom") return i18n.tr("Custom Emojis")
                    for (var i = 0; i < emojiCategories.length; i++) {
                        if (emojiCategories[i].id === selectedCategory) {
                            return emojiCategories[i].name
                        }
                    }
                    return ""
                }
                fontSize: "x-small"
                font.bold: true
                color: Theme.palette.normal.backgroundSecondaryText
            }
        }
        
        // Emoji grid
        GridView {
            id: emojiGrid
            width: parent.width
            height: parent.height - units.gu(11)
            cellWidth: units.gu(4.5)
            cellHeight: units.gu(4.5)
            clip: true
            
            model: {
                if (searchQuery) {
                    // Search across all categories using EmojiData
                    return emojiData.searchEmojis(searchQuery)
                }
                if (selectedCategory === "custom") {
                    return customEmojis
                }
                return getEmojiDataForCategory(selectedCategory)
            }
            
            delegate: Rectangle {
                width: emojiGrid.cellWidth
                height: emojiGrid.cellHeight
                color: mouseArea.pressed ? Theme.palette.normal.base : "transparent"
                radius: units.gu(0.5)
                
                // For Unicode emojis
                Label {
                    anchors.centerIn: parent
                    text: typeof modelData === "string" ? modelData : ""
                    fontSize: "large"
                    visible: typeof modelData === "string"
                }
                
                // For custom emojis (objects with url)
                Image {
                    anchors.centerIn: parent
                    width: units.gu(3)
                    height: units.gu(3)
                    source: (typeof modelData === "object" && modelData.url) ? 
                            SerchatAPI.apiBaseUrl + modelData.url : ""
                    visible: typeof modelData === "object"
                    fillMode: Image.PreserveAspectFit
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (typeof modelData === "string") {
                            // Unicode emoji
                            addToRecent(modelData)
                            emojiSelected(modelData, false, "", "")
                        } else if (typeof modelData === "object") {
                            // Custom emoji
                            emojiSelected(modelData.name, true, modelData._id || modelData.id, 
                                         SerchatAPI.apiBaseUrl + modelData.url)
                        }
                    }
                }
            }
        }
    }
    
    function addToRecent(emoji) {
        var recent = recentEmojis.slice()
        var index = recent.indexOf(emoji)
        if (index !== -1) {
            recent.splice(index, 1)
        }
        recent.unshift(emoji)
        if (recent.length > 20) {
            recent = recent.slice(0, 20)
        }
        recentEmojis = recent
    }
    
    function open() {
        opened = true
        searchField.text = ""
        searchQuery = ""
    }
    
    function close() {
        opened = false
        closed()
    }
}
