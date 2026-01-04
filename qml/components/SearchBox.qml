import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * SearchBox - Reusable search input field with icon
 * 
 * Used for searching members, messages, friends, etc.
 */
Rectangle {
    id: searchBox
    
    property alias text: searchField.text
    property alias placeholderText: searchField.placeholderText
    property alias searchField: searchField
    property bool showIcon: true
    
    signal accepted()
    
    height: units.gu(4.5)
    radius: units.gu(0.5)
    color: Qt.darker(Theme.palette.normal.background, 1.15)
    
    Row {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1)
        anchors.rightMargin: units.gu(1)
        spacing: units.gu(0.5)
        
        Icon {
            width: units.gu(2)
            height: units.gu(2)
            name: "search"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.normal.backgroundSecondaryText
            visible: showIcon
        }
        
        TextField {
            id: searchField
            width: parent.width - (showIcon ? units.gu(3) : 0) - (clearButton.visible ? clearButton.width : 0)
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: i18n.tr("Search...")
            
            onAccepted: searchBox.accepted()
        }
        
        // Clear button
        AbstractButton {
            id: clearButton
            width: units.gu(3)
            height: units.gu(3)
            anchors.verticalCenter: parent.verticalCenter
            visible: searchField.text.length > 0
            
            Icon {
                anchors.centerIn: parent
                width: units.gu(1.8)
                height: units.gu(1.8)
                name: "close"
                color: Theme.palette.normal.backgroundSecondaryText
            }
            
            onClicked: {
                searchField.text = ""
                searchField.forceActiveFocus()
            }
        }
    }
}
