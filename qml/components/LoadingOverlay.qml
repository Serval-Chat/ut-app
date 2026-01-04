import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * LoadingOverlay - Reusable loading overlay with activity indicator and message
 * 
 * Usage:
 *   LoadingOverlay {
 *       visible: isLoading
 *       message: i18n.tr("Signing in...")
 *   }
 */
Rectangle {
    id: loadingOverlay
    
    property string message: i18n.tr("Loading...")
    property bool blockInteraction: true
    
    color: Qt.rgba(Theme.palette.normal.background.r,
                  Theme.palette.normal.background.g,
                  Theme.palette.normal.background.b, 0.85)
    z: 100
    
    Column {
        anchors.centerIn: parent
        spacing: units.gu(2)
        
        ActivityIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: loadingOverlay.visible
        }
        
        Label {
            text: message
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.palette.normal.foreground
        }
    }
    
    // Block interaction while loading
    MouseArea {
        anchors.fill: parent
        enabled: blockInteraction
    }
}
