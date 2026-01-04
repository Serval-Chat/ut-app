import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * SectionHeader - Reusable section header with optional action buttons
 * 
 * Used in settings pages, channel lists, etc.
 */
Item {
    id: sectionHeader
    
    property string title: ""
    property color titleColor: Theme.palette.normal.foreground
    property bool bold: true
    property bool uppercase: false
    property string fontSize: "small"
    property alias actions: actionsRow.children
    
    width: parent ? parent.width : units.gu(30)
    height: units.gu(4)
    
    Label {
        anchors.left: parent.left
        anchors.leftMargin: units.gu(1.5)
        anchors.verticalCenter: parent.verticalCenter
        text: uppercase ? title.toUpperCase() : title
        fontSize: sectionHeader.fontSize
        font.bold: bold
        color: titleColor
    }
    
    Row {
        id: actionsRow
        anchors.right: parent.right
        anchors.rightMargin: units.gu(1.5)
        anchors.verticalCenter: parent.verticalCenter
        spacing: units.gu(0.5)
    }
}
