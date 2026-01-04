import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * EmptyState - Reusable empty state placeholder
 * 
 * Shows an icon, title, and description when content is empty
 */
Item {
    id: emptyState
    
    property string iconName: "info"
    property string title: ""
    property string description: ""
    property alias actionButton: actionButtonLoader.sourceComponent
    
    width: parent ? parent.width : units.gu(40)
    height: contentColumn.height
    
    Column {
        id: contentColumn
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - units.gu(4), units.gu(40))
        spacing: units.gu(2)
        
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(8)
            height: units.gu(8)
            name: iconName
            color: Theme.palette.normal.backgroundSecondaryText
        }
        
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: title
            fontSize: "large"
            font.bold: true
            color: Theme.palette.normal.backgroundSecondaryText
            visible: title !== ""
        }
        
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: description
            fontSize: "small"
            color: Theme.palette.normal.backgroundSecondaryText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            width: parent.width
            visible: description !== ""
        }
        
        Loader {
            id: actionButtonLoader
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
