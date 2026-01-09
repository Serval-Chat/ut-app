import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MemberListItem - Reusable member list item for MembersListView
 * 
 * Displays a member with avatar, name, status, and optional custom status text.
 * Used to avoid code duplication between online and offline member lists.
 */
Rectangle {
    id: memberItem
    
    property var member: ({})
    property string serverOwnerId: ""
    property string currentUserId: ""
    property bool isOffline: false
    property color panelColor: Theme.palette.normal.background
    
    signal clicked(string memberId)
    
    width: parent ? parent.width : units.gu(30)
    height: units.gu(5)
    color: mouseArea.pressed ? Qt.darker(panelColor, 1.2) : "transparent"
    
    // Computed properties
    // API returns: { _id, serverId, userId, roles, user: { _id, username, displayName, profilePicture, customStatus } }
    readonly property var userInfo: member.user || {}
    readonly property string memberId: userInfo._id || member.userId || member._id || ""
    readonly property bool isCurrentUser: memberId === currentUserId
    readonly property bool isServerOwner: memberId === serverOwnerId && serverOwnerId !== ""
    readonly property string displayName: userInfo.displayName || userInfo.username || i18n.tr("Unknown")
    readonly property string avatarSource: userInfo.profilePicture ? SerchatAPI.apiBaseUrl + userInfo.profilePicture : ""
    readonly property string memberStatus: isOffline ? "offline" : (userInfo.customStatus ? (userInfo.customStatus.status || "online") : "online")
    readonly property string customStatusText: userInfo.customStatus && userInfo.customStatus.text ? userInfo.customStatus.text : ""
    
    Row {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1.5)
        anchors.rightMargin: units.gu(1.5)
        spacing: units.gu(1)
        
        Components.Avatar {
            width: units.gu(4)
            height: units.gu(4)
            anchors.verticalCenter: parent.verticalCenter
            name: memberItem.displayName
            source: memberItem.avatarSource
            showStatus: true
            status: memberItem.memberStatus
        }
        
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - units.gu(6)
            spacing: units.gu(0.2)
            
            Row {
                width: parent.width
                spacing: units.gu(0.5)
                
                Label {
                    text: memberItem.isServerOwner ? "👑 " + memberItem.displayName : memberItem.displayName
                    fontSize: "small"
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                    color: isOffline ? Theme.palette.normal.backgroundSecondaryText : Theme.palette.normal.baseText
                }
            }
            
            Label {
                text: memberItem.customStatusText
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
                elide: Text.ElideRight
                width: parent.width
                visible: text !== "" && !isOffline
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: memberItem.clicked(memberItem.memberId)
    }
}
