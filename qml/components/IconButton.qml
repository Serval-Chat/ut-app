import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * IconButton - Reusable icon button with hover/press states
 * 
 * Common pattern used throughout the app for toolbar buttons
 */
AbstractButton {
    id: iconButton
    
    property string iconName: "info"
    property color iconColor: Theme.palette.normal.backgroundSecondaryText
    property color activeColor: LomiriColors.blue
    property bool active: false
    property int iconSize: units.gu(2.5)
    property bool showBackground: false
    property color backgroundColor: Theme.palette.normal.base
    
    width: units.gu(4)
    height: units.gu(4)
    
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: showBackground && (parent.pressed || parent.active) ? 
               backgroundColor : "transparent"
        visible: showBackground
    }
    
    Icon {
        anchors.centerIn: parent
        width: iconSize
        height: iconSize
        name: iconName
        color: active ? activeColor : 
               (iconButton.pressed ? activeColor : iconColor)
    }
}
