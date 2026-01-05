import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * UserPanel - Reusable user info panel with avatar, name, status and actions
 * 
 * Used in ChannelListView and DMListView sidebar bottoms
 */
Rectangle {
    id: userPanel
    
    property string userName: ""
    property string userAvatar: ""
    property string userStatus: "online"
    
    signal settingsClicked()
    signal profileClicked()
    
    height: units.gu(6.5)
    color: Qt.darker(Theme.palette.normal.background, 1.18)
    
    MouseArea {
        anchors.fill: parent
        onClicked: profileClicked()
    }
    
    Row {
        anchors.fill: parent
        anchors.margins: units.gu(1)
        spacing: units.gu(1)
        
        // User avatar
        Avatar {
            id: avatarItem
            width: units.gu(4)
            height: units.gu(4)
            anchors.verticalCenter: parent.verticalCenter
            name: userName
            source: userAvatar
            showStatus: true
            status: userStatus
        }
        
        // User info
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - avatarItem.width - units.gu(2)
            spacing: units.gu(0.2)
            
            Label {
                text: userName
                fontSize: "small"
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
            }
            
            Label {
                text: userStatus === "online" ? i18n.tr("Online") :
                      userStatus === "idle" ? i18n.tr("Idle") :
                      userStatus === "dnd" ? i18n.tr("Do Not Disturb") :
                      i18n.tr("Offline")
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
