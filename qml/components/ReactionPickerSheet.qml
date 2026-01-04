import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0

/*
 * ReactionPickerSheet - Bottom sheet for selecting emoji reactions
 * Uses the same bottom sheet pattern as UserProfileSheet
 */
Item {
    id: reactionPickerSheet
    
    property string messageId: ""
    property var customEmojis: ({})
    property bool opened: false
    
    signal reactionSelected(string messageId, string emoji, string emojiType, string emojiId)
    signal closed()
    
    visible: opened
    z: 1000
    
    // Open the sheet
    function open(msgId) {
        messageId = msgId
        opened = true
        openAnimation.start()
    }
    
    // Close the sheet
    function close() {
        closeAnimation.start()
    }
    
    // Backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, backdropOpacity)
        opacity: 0
        
        property real backdropOpacity: 0.4
        
        MouseArea {
            anchors.fill: parent
            onClicked: close()
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Sheet container
    Rectangle {
        id: sheet
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(parent.height * 0.7, units.gu(55))
        color: Theme.palette.normal.background
        radius: units.gu(2)
        
        // Only round top corners
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.radius
            color: parent.color
        }
        
        y: parent.height  // Start off-screen
        
        // Handle bar
        Rectangle {
            id: handleBar
            anchors.top: parent.top
            anchors.topMargin: units.gu(1)
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(5)
            height: units.gu(0.5)
            radius: height / 2
            color: Theme.palette.normal.base
        }
        
        // Drag area for dismissal
        MouseArea {
            id: dragArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(4)
            
            property real startY: 0
            
            onPressed: startY = mouse.y
            
            onPositionChanged: {
                var delta = mouse.y - startY
                if (delta > 0) {
                    sheet.y = delta
                }
            }
            
            onReleased: {
                if (sheet.y > units.gu(10)) {
                    close()
                } else {
                    sheet.y = 0
                }
            }
        }
        
        // Title
        Label {
            id: titleLabel
            anchors.top: handleBar.bottom
            anchors.topMargin: units.gu(1)
            anchors.horizontalCenter: parent.horizontalCenter
            text: i18n.tr("Add Reaction")
            fontSize: "large"
            font.bold: true
        }
        
        // Quick reactions row (most common)
        Row {
            id: quickReactionsRow
            anchors.top: titleLabel.bottom
            anchors.topMargin: units.gu(1.5)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(2)
            
            property var quickEmojis: ["👍", "❤️", "😂", "😮", "😢", "🎉", "🔥", "👀"]
            
            Repeater {
                model: quickReactionsRow.quickEmojis
                
                AbstractButton {
                    width: units.gu(5)
                    height: units.gu(5)
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: units.gu(1)
                        color: parent.pressed ? Theme.palette.normal.base : "transparent"
                    }
                    
                    Label {
                        anchors.centerIn: parent
                        text: modelData
                        fontSize: "x-large"
                    }
                    
                    onClicked: {
                        reactionSelected(messageId, modelData, "unicode", "")
                        close()
                    }
                }
            }
        }
        
        // Divider
        Rectangle {
            id: divider
            anchors.top: quickReactionsRow.bottom
            anchors.topMargin: units.gu(1)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: units.gu(2)
            height: units.dp(1)
            color: Theme.palette.normal.base
        }
        
        // Emoji picker (embedded, not popup)
        Item {
            id: emojiPickerContainer
            anchors.top: divider.bottom
            anchors.topMargin: units.gu(1)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: units.gu(1)
            
            // Category tabs
            Row {
                id: categoryTabs
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: units.gu(5)
                
                property string selectedCategory: "smileys"
                
                property var categories: [
                    { id: "custom", icon: "⭐" },
                    { id: "smileys", icon: "😀" },
                    { id: "people", icon: "👋" },
                    { id: "animals", icon: "🐶" },
                    { id: "food", icon: "🍎" },
                    { id: "objects", icon: "💡" },
                    { id: "symbols", icon: "❤️" }
                ]
                
                Repeater {
                    model: categoryTabs.categories
                    
                    AbstractButton {
                        width: parent.width / categoryTabs.categories.length
                        height: parent.height
                        
                        Rectangle {
                            anchors.fill: parent
                            color: categoryTabs.selectedCategory === modelData.id ? 
                                   Qt.rgba(LomiriColors.blue.r, LomiriColors.blue.g, LomiriColors.blue.b, 0.2) : 
                                   "transparent"
                        }
                        
                        Label {
                            anchors.centerIn: parent
                            text: modelData.icon
                            fontSize: "medium"
                        }
                        
                        // Selection indicator
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: units.dp(2)
                            color: LomiriColors.blue
                            visible: categoryTabs.selectedCategory === modelData.id
                        }
                        
                        onClicked: categoryTabs.selectedCategory = modelData.id
                    }
                }
            }
            
            // Emoji grid
            GridView {
                id: emojiGrid
                anchors.top: categoryTabs.bottom
                anchors.topMargin: units.gu(1)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                
                cellWidth: units.gu(6)
                cellHeight: units.gu(6)
                
                model: getEmojisForCategory(categoryTabs.selectedCategory)
                
                delegate: AbstractButton {
                    width: emojiGrid.cellWidth
                    height: emojiGrid.cellHeight
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: units.gu(0.3)
                        radius: units.gu(0.5)
                        color: parent.pressed ? Theme.palette.normal.base : "transparent"
                    }
                    
                    // For custom emojis, show image; for unicode, show text
                    Item {
                        anchors.centerIn: parent
                        width: units.gu(4)
                        height: units.gu(4)
                        
                        Image {
                            anchors.fill: parent
                            source: modelData.isCustom ? (SerchatAPI.apiBaseUrl + modelData.imageUrl) : ""
                            visible: modelData.isCustom
                            fillMode: Image.PreserveAspectFit
                        }
                        
                        Label {
                            anchors.centerIn: parent
                            text: modelData.isCustom ? "" : modelData.emoji
                            fontSize: "large"
                            visible: !modelData.isCustom
                        }
                    }
                    
                    onClicked: {
                        if (modelData.isCustom) {
                            reactionSelected(messageId, modelData.name, "custom", modelData.id)
                        } else {
                            reactionSelected(messageId, modelData.emoji, "unicode", "")
                        }
                        close()
                    }
                }
            }
        }
        
        Behavior on y {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
    }
    
    // Open animation
    SequentialAnimation {
        id: openAnimation
        
        PropertyAction { target: reactionPickerSheet; property: "visible"; value: true }
        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: 1; duration: 200 }
            NumberAnimation { target: sheet; property: "y"; to: 0; duration: 250; easing.type: Easing.OutQuad }
        }
    }
    
    // Close animation
    SequentialAnimation {
        id: closeAnimation
        
        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: 200 }
            NumberAnimation { target: sheet; property: "y"; to: reactionPickerSheet.height; duration: 200; easing.type: Easing.InQuad }
        }
        PropertyAction { target: reactionPickerSheet; property: "opened"; value: false }
        PropertyAction { target: reactionPickerSheet; property: "visible"; value: false }
        ScriptAction { script: closed() }
    }
    
    // Get emojis for a category
    function getEmojisForCategory(category) {
        if (category === "custom") {
            // Return custom emojis from the server
            var customList = []
            for (var id in customEmojis) {
                var emoji = customEmojis[id]
                customList.push({
                    isCustom: true,
                    id: id,
                    name: emoji.name || id,
                    imageUrl: emoji.imageUrl || ""
                })
            }
            return customList
        }
        
        // Unicode emoji categories
        var emojiSets = {
            "smileys": [
                "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
                "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
                "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔",
                "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "😌",
                "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🤧",
                "🥵", "🥶", "🥴", "😵", "🤯", "🤠", "🥳", "😎", "🤓", "🧐",
                "😕", "😟", "🙁", "☹️", "😮", "😯", "😲", "😳", "🥺", "😦",
                "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞"
            ],
            "people": [
                "👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞",
                "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎",
                "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏",
                "✍️", "💅", "🤳", "💪", "🦾", "🦿", "👂", "👃", "🧠", "👀",
                "👁️", "👅", "👄", "👶", "🧒", "👦", "👧", "🧑", "👱", "👨"
            ],
            "animals": [
                "🐶", "🐕", "🐩", "🐺", "🦊", "🦝", "🐱", "🐈", "🦁", "🐯",
                "🐅", "🐆", "🐴", "🐎", "🦄", "🦓", "🐮", "🐂", "🐃", "🐄",
                "🐷", "🐖", "🐗", "🐏", "🐑", "🐐", "🐪", "🐫", "🦒", "🐘",
                "🦏", "🦛", "🐭", "🐁", "🐀", "🐹", "🐰", "🐇", "🐿️", "🦔",
                "🦇", "🐻", "🐨", "🐼", "🦘", "🐾", "🦃", "🐔", "🐓", "🐣"
            ],
            "food": [
                "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈",
                "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦",
                "🥬", "🥒", "🌶️", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🥐",
                "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🥞", "🧇", "🥓"
            ],
            "objects": [
                "💡", "🔦", "📱", "💻", "🖥️", "🖨️", "⌨️", "🖱️", "💾", "💿",
                "📀", "🎥", "📺", "📷", "📸", "📹", "🔍", "💵", "💴", "💶",
                "💷", "💰", "💳", "💎", "🔧", "🔨", "🛠️", "⚙️", "🔫", "💣"
            ],
            "symbols": [
                "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
                "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "✨", "⭐",
                "🌟", "💫", "⚡", "🔥", "💥", "💯", "✅", "❌", "❓", "❗"
            ]
        }
        
        var emojis = emojiSets[category] || []
        return emojis.map(function(e) {
            return { emoji: e, isCustom: false }
        })
    }
}
