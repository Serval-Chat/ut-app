import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "." as Components

Rectangle {
    property string icon: ""
    property string name: ""
    property color badgeColor: Theme.palette.normal.base

    width: badgeRow.width + units.gu(1.5)
    height: units.gu(3)
    radius: units.gu(0.5)
    color: badgeColor

    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: units.gu(0.5)
        
        // Render Lucide icon
        Components.LucideIcon {
            name: icon
            width: units.gu(2)
            height: units.gu(2)
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            showFallback: false
        }
        
        Label {
            text: name
            fontSize: "x-small"
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}