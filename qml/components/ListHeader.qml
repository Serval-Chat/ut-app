import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * ListHeader - Generic header bar for list views with title and optional actions
 * 
 * Used for consistency across ServerListView, ChannelListView, DMListView, etc.
 */
Rectangle {
    id: listHeader
    
    property string title: ""
    property bool showDropdownIcon: false
    property bool showBackButton: false
    property alias actions: actionsRow.children
    
    signal clicked()
    signal backClicked()
    
    width: parent ? parent.width : units.gu(26)
    height: units.gu(6)
    color: Qt.darker(Theme.palette.normal.background, 1.08)
    
    Row {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1.5)
        anchors.rightMargin: units.gu(1.5)
        spacing: units.gu(1)
        
        // Back button
        AbstractButton {
            id: backButton
            width: units.gu(4)
            height: parent.height
            visible: showBackButton
            
            Icon {
                anchors.centerIn: parent
                width: units.gu(2.5)
                height: units.gu(2.5)
                name: "back"
                color: Theme.palette.normal.baseText
            }
            
            onClicked: backClicked()
        }
        
        // Title
        Label {
            text: title
            font.bold: true
            fontSize: "medium"
            elide: Text.ElideRight
            width: parent.width - (backButton.visible ? backButton.width : 0) - 
                   (dropdownIcon.visible ? dropdownIcon.width : 0) - 
                   actionsRow.width - units.gu(2)
            anchors.verticalCenter: parent.verticalCenter
        }
        
        // Dropdown icon
        Icon {
            id: dropdownIcon
            width: units.gu(2)
            height: units.gu(2)
            name: "go-down"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.normal.backgroundSecondaryText
            visible: showDropdownIcon
        }
        
        // Actions container
        Row {
            id: actionsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: units.gu(0.5)
        }
    }
    
    // Click handler for header
    MouseArea {
        id: headerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: listHeader.clicked()
        enabled: !showBackButton  // Don't capture clicks if back button is shown
    }
    
    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: units.dp(1)
        color: Qt.darker(listHeader.color, 1.15)
    }
}
