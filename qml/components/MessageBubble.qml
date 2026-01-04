import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * MessageBubble - Displays a single chat message
 */
Item {
    id: messageBubble
    
    property string messageId: ""
    property string senderId: ""
    property string senderName: ""
    property string senderAvatar: ""
    property string text: ""
    property string timestamp: ""
    property bool isOwn: false
    property bool isEdited: false
    property bool showAvatar: true  // False when grouping consecutive messages
    property bool isReply: false
    property string replyToText: ""
    property string replyToSender: ""
    property var reactions: []
    
    signal avatarClicked(string senderId)
    signal longPressed()
    signal replyClicked()
    
    width: parent ? parent.width : units.gu(40)
    height: contentColumn.height + units.gu(0.5)
    
    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: units.gu(1.5)
        anchors.rightMargin: units.gu(1.5)
        spacing: units.gu(1)
        
        // Avatar column
        Item {
            width: units.gu(4.5)
            height: showAvatar ? units.gu(4.5) : units.gu(0.5)
            
            Avatar {
                id: avatar
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(4)
                height: units.gu(4)
                name: senderName
                source: senderAvatar
                visible: showAvatar
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: avatarClicked(senderId)
                }
            }
        }
        
        // Message content column
        Column {
            id: contentColumn
            width: parent.width - units.gu(6)
            spacing: units.gu(0.3)
            
            // Header (sender name + timestamp)
            Row {
                spacing: units.gu(1)
                visible: showAvatar
                
                Label {
                    id: nameLabel
                    text: senderName
                    font.bold: true
                    fontSize: "small"
                    color: isOwn ? LomiriColors.blue : Theme.palette.normal.baseText
                }
                
                Label {
                    id: timestampLabel
                    text: formatTimestamp(timestamp)
                    fontSize: "x-small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    anchors.baseline: nameLabel.baseline
                }
            }
            
            // Reply preview if this is a reply
            Rectangle {
                id: replyContainer
                width: parent.width
                height: replyColumn.height + units.gu(1)
                visible: isReply && replyToText !== ""
                color: Qt.rgba(Theme.palette.normal.base.r, 
                              Theme.palette.normal.base.g, 
                              Theme.palette.normal.base.b, 0.3)
                radius: units.gu(0.5)
                
                Rectangle {
                    width: units.gu(0.4)
                    height: parent.height
                    color: LomiriColors.blue
                    radius: units.gu(0.2)
                }
                
                Column {
                    id: replyColumn
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1.5)
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(1)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.2)
                    
                    Label {
                        text: replyToSender
                        fontSize: "x-small"
                        font.bold: true
                        color: LomiriColors.blue
                    }
                    
                    Label {
                        text: replyToText.length > 100 ? replyToText.substring(0, 100) + "..." : replyToText
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: replyClicked()
                }
            }
            
            // Message text
            Label {
                id: messageText
                width: parent.width
                text: messageBubble.text
                wrapMode: Text.Wrap
                fontSize: "small"
                color: Theme.palette.normal.baseText
                textFormat: Text.StyledText
                linkColor: LomiriColors.blue
                onLinkActivated: Qt.openUrlExternally(link)
            }
            
            // Edited indicator
            Label {
                text: i18n.tr("(edited)")
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
                visible: isEdited
            }
            
            // Reactions row
            Flow {
                id: reactionsFlow
                width: parent.width
                spacing: units.gu(0.5)
                visible: reactions.length > 0
                
                Repeater {
                    model: reactions
                    
                    Rectangle {
                        width: reactionRow.width + units.gu(1)
                        height: units.gu(2.5)
                        radius: units.gu(0.5)
                        color: Qt.rgba(Theme.palette.normal.base.r,
                                      Theme.palette.normal.base.g,
                                      Theme.palette.normal.base.b, 0.5)
                        
                        Row {
                            id: reactionRow
                            anchors.centerIn: parent
                            spacing: units.gu(0.3)
                            
                            Label {
                                text: modelData.emoji
                                fontSize: "small"
                            }
                            
                            Label {
                                text: modelData.count.toString()
                                fontSize: "x-small"
                                color: Theme.palette.normal.backgroundSecondaryText
                            }
                        }
                    }
                }
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onPressAndHold: longPressed()
        onClicked: mouse.accepted = false
    }
    
    function formatTimestamp(ts) {
        if (!ts) return ""
        var date = new Date(ts)
        var now = new Date()
        var isToday = date.toDateString() === now.toDateString()
        var yesterday = new Date(now)
        yesterday.setDate(yesterday.getDate() - 1)
        var isYesterday = date.toDateString() === yesterday.toDateString()
        
        var timeStr = date.toLocaleTimeString(Qt.locale(), "HH:mm")
        
        if (isToday) {
            return i18n.tr("Today at %1").arg(timeStr)
        } else if (isYesterday) {
            return i18n.tr("Yesterday at %1").arg(timeStr)
        } else {
            return date.toLocaleDateString(Qt.locale(), "dd/MM/yyyy") + " " + timeStr
        }
    }
}
