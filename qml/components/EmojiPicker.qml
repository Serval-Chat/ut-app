import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0

/*
 * EmojiPicker - Emoji selection popup with categories and custom emojis
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
    
    // Standard emoji categories with representative emojis
    property var emojiCategories: [
        { id: "recent", name: i18n.tr("Recent"), icon: "🕐" },
        { id: "smileys", name: i18n.tr("Smileys"), icon: "😀" },
        { id: "people", name: i18n.tr("People"), icon: "👋" },
        { id: "animals", name: i18n.tr("Animals"), icon: "🐶" },
        { id: "food", name: i18n.tr("Food"), icon: "🍎" },
        { id: "travel", name: i18n.tr("Travel"), icon: "🚗" },
        { id: "activities", name: i18n.tr("Activities"), icon: "⚽" },
        { id: "objects", name: i18n.tr("Objects"), icon: "💡" },
        { id: "symbols", name: i18n.tr("Symbols"), icon: "❤️" },
        { id: "flags", name: i18n.tr("Flags"), icon: "🏳️" }
    ]
    
    // Emoji data by category
    property var emojiData: {
        "recent": recentEmojis,
        "smileys": [
            "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
            "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
            "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫",
            "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬",
            "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢",
            "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "🤯", "🤠", "🥳", "🥸",
            "😎", "🤓", "🧐", "😕", "😟", "🙁", "☹️", "😮", "😯", "😲",
            "😳", "🥺", "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱",
            "😖", "😣", "😞", "😓", "😩", "😫", "🥱", "😤", "😡", "😠",
            "🤬", "😈", "👿", "💀", "☠️", "💩", "🤡", "👹", "👺", "👻"
        ],
        "people": [
            "👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞",
            "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍",
            "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝",
            "🙏", "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂",
            "🦻", "👃", "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁️", "👅",
            "👄", "👶", "🧒", "👦", "👧", "🧑", "👱", "👨", "🧔", "👩",
            "🧓", "👴", "👵", "🙍", "🙎", "🙅", "🙆", "💁", "🙋", "🧏",
            "🙇", "🤦", "🤷", "👮", "🕵️", "💂", "🥷", "👷", "🤴", "👸"
        ],
        "animals": [
            "🐶", "🐕", "🦮", "🐕‍🦺", "🐩", "🐺", "🦊", "🦝", "🐱", "🐈",
            "🐈‍⬛", "🦁", "🐯", "🐅", "🐆", "🐴", "🐎", "🦄", "🦓", "🦌",
            "🦬", "🐮", "🐂", "🐃", "🐄", "🐷", "🐖", "🐗", "🐽", "🐏",
            "🐑", "🐐", "🐪", "🐫", "🦙", "🦒", "🐘", "🦣", "🦏", "🦛",
            "🐭", "🐁", "🐀", "🐹", "🐰", "🐇", "🐿️", "🦫", "🦔", "🦇",
            "🐻", "🐻‍❄️", "🐨", "🐼", "🦥", "🦦", "🦨", "🦘", "🦡", "🐾",
            "🦃", "🐔", "🐓", "🐣", "🐤", "🐥", "🐦", "🐧", "🕊️", "🦅",
            "🦆", "🦢", "🦉", "🦤", "🪶", "🦩", "🦚", "🦜", "🐸", "🐊"
        ],
        "food": [
            "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈",
            "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦",
            "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔",
            "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈",
            "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟",
            "🍕", "🫓", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘",
            "🫕", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤",
            "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧", "🍨"
        ],
        "travel": [
            "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐",
            "🛻", "🚚", "🚛", "🚜", "🦯", "🦽", "🦼", "🛴", "🚲", "🛵",
            "🏍️", "🛺", "🚨", "🚔", "🚍", "🚘", "🚖", "🚡", "🚠", "🚟",
            "🚃", "🚋", "🚞", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇",
            "🚊", "🚉", "✈️", "🛫", "🛬", "🛩️", "💺", "🛰️", "🚀", "🛸",
            "🚁", "🛶", "⛵", "🚤", "🛥️", "🛳️", "⛴️", "🚢", "⚓", "🪝",
            "⛽", "🚧", "🚦", "🚥", "🚏", "🗺️", "🗿", "🗽", "🗼", "🏰",
            "🏯", "🏟️", "🎡", "🎢", "🎠", "⛲", "⛱️", "🏖️", "🏝️", "🏜️"
        ],
        "activities": [
            "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱",
            "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳",
            "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷",
            "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🤼", "🤸", "⛹️",
            "🤺", "🤾", "🏌️", "🏇", "⛑️", "🧘", "🏄", "🏊", "🤽", "🚣",
            "🧗", "🚵", "🚴", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖️", "🏵️",
            "🎗️", "🎫", "🎟️", "🎪", "🤹", "🎭", "🩰", "🎨", "🎬", "🎤",
            "🎧", "🎼", "🎹", "🥁", "🪘", "🎷", "🎺", "🪗", "🎸", "🪕"
        ],
        "objects": [
            "💡", "🔦", "🏮", "🪔", "📱", "📲", "💻", "🖥️", "🖨️", "⌨️",
            "🖱️", "🖲️", "💽", "💾", "💿", "📀", "🧮", "🎥", "🎞️", "📽️",
            "🎬", "📺", "📷", "📸", "📹", "📼", "🔍", "🔎", "🕯️", "💵",
            "💴", "💶", "💷", "💰", "💳", "💎", "⚖️", "🪜", "🧰", "🪛",
            "🔧", "🔨", "⚒️", "🛠️", "⛏️", "🪚", "🔩", "⚙️", "🪤", "🧱",
            "⛓️", "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡️", "⚔️", "🛡️",
            "🚬", "⚰️", "🪦", "⚱️", "🏺", "🔮", "📿", "🧿", "💈", "⚗️",
            "🔭", "🔬", "🕳️", "🩹", "🩺", "💊", "💉", "🩸", "🧬", "🦠"
        ],
        "symbols": [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
            "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️",
            "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐",
            "⛎", "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐",
            "♑", "♒", "♓", "🆔", "⚛️", "🉑", "☢️", "☣️", "📴", "📳",
            "🈶", "🈚", "🈸", "🈺", "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️",
            "㊗️", "🈴", "🈵", "🈹", "🈲", "🅰️", "🅱️", "🆎", "🆑", "🅾️",
            "🆘", "❌", "⭕", "🛑", "⛔", "📛", "🚫", "💯", "💢", "♨️"
        ],
        "flags": [
            "🏳️", "🏴", "🏁", "🚩", "🎌", "🏴‍☠️", "🇦🇫", "🇦🇱", "🇩🇿", "🇦🇸",
            "🇦🇩", "🇦🇴", "🇦🇮", "🇦🇶", "🇦🇬", "🇦🇷", "🇦🇲", "🇦🇼", "🇦🇺", "🇦🇹",
            "🇦🇿", "🇧🇸", "🇧🇭", "🇧🇩", "🇧🇧", "🇧🇾", "🇧🇪", "🇧🇿", "🇧🇯", "🇧🇲",
            "🇧🇹", "🇧🇴", "🇧🇦", "🇧🇼", "🇧🇷", "🇮🇴", "🇻🇬", "🇧🇳", "🇧🇬", "🇧🇫",
            "🇧🇮", "🇰🇭", "🇨🇲", "🇨🇦", "🇮🇨", "🇨🇻", "🇧🇶", "🇰🇾", "🇨🇫", "🇹🇩",
            "🇨🇱", "🇨🇳", "🇨🇽", "🇨🇨", "🇨🇴", "🇰🇲", "🇨🇬", "🇨🇩", "🇨🇰", "🇨🇷",
            "🇨🇮", "🇭🇷", "🇨🇺", "🇨🇼", "🇨🇾", "🇨🇿", "🇩🇰", "🇩🇯", "🇩🇲", "🇩🇴",
            "🇪🇨", "🇪🇬", "🇸🇻", "🇬🇶", "🇪🇷", "🇪🇪", "🇸🇿", "🇪🇹", "🇪🇺", "🇫🇰"
        ]
    }
    
    // Recently used emojis (would be persisted in settings)
    property var recentEmojis: ["😀", "👍", "❤️", "🎉", "🔥"]
    
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
                    // Search across all categories
                    var results = []
                    for (var cat in emojiData) {
                        var emojis = emojiData[cat]
                        if (Array.isArray(emojis)) {
                            for (var i = 0; i < emojis.length; i++) {
                                if (results.indexOf(emojis[i]) === -1) {
                                    results.push(emojis[i])
                                }
                            }
                        }
                    }
                    return results
                }
                if (selectedCategory === "custom") {
                    return customEmojis
                }
                return emojiData[selectedCategory] || []
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
