import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * ServerListView - Vertical list of server icons
 */
Rectangle {
    id: serverList
    
    property string selectedServerId: ""
    property var servers: []
    property var unreadCounts: ({})  // serverId -> count
    property var mentionServers: ({})  // serverId -> hasMention
    
    signal serverSelected(string serverId, string serverName, string ownerId)
    signal homeClicked()
    signal addServerClicked()
    signal settingsClicked()
    
    color: Qt.darker(Theme.palette.normal.background, 1.15)
    width: units.gu(7)
    
    // Calculate required bottom margin to prevent overlap with settings area
    readonly property real requiredBottomMargin: bottomSettingsArea.height + bottomSettingsArea.anchors.bottomMargin
    
    Flickable {
        id: serverFlickable
        anchors.fill: parent
        anchors.topMargin: units.gu(1)
        anchors.bottomMargin: requiredBottomMargin  // Dynamic calculation to prevent overlap
        contentHeight: serverColumn.height
        clip: true
        
        Column {
            id: serverColumn
            width: parent.width
            spacing: units.gu(1)
            
            // Home / DMs button
            Item {
                width: parent.width
                height: units.gu(6)
                
                Rectangle {
                    id: homeButton
                    anchors.centerIn: parent
                    width: units.gu(5)
                    height: units.gu(5)
                    radius: selectedServerId === "" ? units.gu(1.5) : width / 2
                    color: selectedServerId === "" ? LomiriColors.blue : Theme.palette.normal.base
                    
                    Behavior on radius {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "message"
                        color: "white"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedServerId = ""
                            homeClicked()
                        }
                        onContainsMouseChanged: {
                            if (selectedServerId !== "") {
                                homeButton.radius = containsMouse ? units.gu(1.5) : homeButton.width / 2
                            }
                        }
                    }
                }
                
                // Selection indicator for home
                Rectangle {
                    width: units.gu(0.5)
                    height: selectedServerId === "" ? units.gu(4) : 0
                    radius: width / 2
                    color: Theme.palette.normal.foreground
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: selectedServerId === ""
                    
                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }
            
            // Separator
            Rectangle {
                width: units.gu(4)
                height: units.dp(2)
                color: Theme.palette.normal.base
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Server list
            Repeater {
                model: servers
                
                Components.ServerIcon {
                    serverId: modelData._id || modelData.id || ""
                    serverName: modelData.name || ""
                    iconUrl: modelData.icon ? (SerchatAPI.apiBaseUrl + modelData.icon) : ""
                    selected: selectedServerId === serverId
                    unreadCount: unreadCounts[serverId] || 0
                    hasMention: mentionServers[serverId] || false
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    property string serverOwnerId: modelData.ownerId || ""
                    
                    onClicked: {
                        selectedServerId = serverId
                        serverSelected(serverId, serverName, serverOwnerId)
                    }
                }
            }
            
            // Add server button
            Item {
                width: parent.width
                height: units.gu(6)
                
                Rectangle {
                    id: addServerButton
                    anchors.centerIn: parent
                    width: units.gu(5)
                    height: units.gu(5)
                    radius: addServerMouse.containsMouse ? units.gu(1.5) : width / 2
                    color: addServerMouse.containsMouse ? "#43b581" : Theme.palette.normal.base
                    
                    Behavior on radius {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "add"
                        color: addServerMouse.containsMouse ? "white" : "#43b581"
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                    
                    MouseArea {
                        id: addServerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addServerClicked()
                    }
                }
            }
        }
    }
    
    // Bottom user/settings area
    Column {
        id: bottomSettingsArea
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: units.gu(1)
        spacing: units.gu(1)
        
        // Separator
        Rectangle {
            width: units.gu(4)
            height: units.dp(2)
            color: Theme.palette.normal.base
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Settings button
        Rectangle {
            id: settingsButton
            width: units.gu(5)
            height: units.gu(5)
            radius: settingsMouse.containsMouse ? units.gu(1.5) : width / 2
            color: settingsMouse.containsMouse ? Theme.palette.normal.base : "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            
            Behavior on radius {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            Icon {
                anchors.centerIn: parent
                width: units.gu(2.5)
                height: units.gu(2.5)
                name: "settings"
                color: Theme.palette.normal.backgroundSecondaryText
            }
            
            MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsClicked()
            }
        }
    }
    
    // Public function to refresh the server list
    function refresh() {
        SerchatAPI.getServers(false)  // Force refresh, don't use cache
    }
}
