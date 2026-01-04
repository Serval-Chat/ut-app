import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * CategoryHeader - Expandable category header for channels
 */
Item {
    id: categoryHeader
    
    property string categoryId: ""
    property string categoryName: ""
    property bool expanded: true
    property bool canManage: false
    
    signal toggleExpanded()
    signal addChannelClicked()
    signal settingsClicked()
    
    width: parent ? parent.width : units.gu(25)
    height: units.gu(3.5)
    
    Row {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1)
        anchors.rightMargin: units.gu(1)
        spacing: units.gu(0.5)
        
        // Expand/collapse icon
        Icon {
            id: expandIcon
            width: units.gu(1.5)
            height: units.gu(1.5)
            anchors.verticalCenter: parent.verticalCenter
            name: "go-down"
            rotation: expanded ? 0 : -90
            color: Theme.palette.normal.backgroundSecondaryText
            
            Behavior on rotation {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }
        
        // Category name
        Label {
            id: categoryNameLabel
            text: categoryName.toUpperCase()
            fontSize: "x-small"
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.normal.backgroundSecondaryText
            elide: Text.ElideRight
            width: parent.width - expandIcon.width - actionButtons.width - units.gu(2)
        }
        
        // Action buttons (visible on hover if user can manage)
        Row {
            id: actionButtons
            spacing: units.gu(0.5)
            anchors.verticalCenter: parent.verticalCenter
            opacity: canManage && mouseArea.containsMouse ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
            
            Icon {
                width: units.gu(2)
                height: units.gu(2)
                name: "add"
                color: Theme.palette.normal.backgroundSecondaryText
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: addChannelClicked()
                }
            }
            
            Icon {
                width: units.gu(2)
                height: units.gu(2)
                name: "settings"
                color: Theme.palette.normal.backgroundSecondaryText
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: settingsClicked()
                }
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleExpanded()
    }
}
