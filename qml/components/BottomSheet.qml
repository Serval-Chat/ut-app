import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * BottomSheet - Reusable bottom sheet container component
 * 
 * Usage:
 *   BottomSheet {
 *       id: mySheet
 *       contentItem: Column { ... }
 *       onClosed: { ... }
 *   }
 *   
 *   mySheet.open()  // or set opened = true
 */
Item {
    id: bottomSheet
    
    // Whether the sheet is visible
    property bool opened: false
    
    // Content to display in the sheet
    property alias contentItem: contentLoader.sourceComponent
    
    // Maximum height as fraction of parent (0.0 - 1.0)
    property real maxHeightRatio: 0.7
    
    // Whether to show the drag handle
    property bool showHandle: true
    
    // Backdrop opacity when open
    property real backdropOpacity: 0.4
    
    // Animation duration
    property int animationDuration: 250
    
    // Sheet background color
    property color sheetColor: Theme.palette.normal.background
    
    signal closed()
    
    anchors.fill: parent
    visible: opened
    z: 1000
    
    // Open the sheet
    function open() {
        opened = true
    }
    
    // Close the sheet
    function close() {
        opened = false
        closed()
    }
    
    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: opened ? backdropOpacity : 0
        
        Behavior on opacity {
            NumberAnimation { duration: animationDuration }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: bottomSheet.close()
        }
    }
    
    // Sheet container
    Rectangle {
        id: sheet
        width: parent.width
        height: Math.min(contentLoader.item ? contentLoader.item.height + units.gu(3) : units.gu(20), 
                        parent.height * maxHeightRatio)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: opened ? 0 : -height
        radius: units.gu(2)
        color: sheetColor
        
        // Top rounded corners only - fill bottom
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.radius
            color: parent.color
        }
        
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        // Handle bar
        Rectangle {
            id: handleBar
            anchors.top: parent.top
            anchors.topMargin: units.gu(1)
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(5)
            height: units.gu(0.5)
            radius: height / 2
            color: Theme.palette.normal.base
            visible: showHandle
        }
        
        // Drag area for dismissal
        MouseArea {
            id: dragArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(4)
            
            property real startY: 0
            
            onPressed: startY = mouse.y
            
            onPositionChanged: {
                var delta = mouse.y - startY
                if (delta > 0) {
                    sheet.anchors.bottomMargin = -delta
                }
            }
            
            onReleased: {
                if (Math.abs(sheet.anchors.bottomMargin) > units.gu(10)) {
                    bottomSheet.close()
                }
                sheet.anchors.bottomMargin = opened ? 0 : -sheet.height
            }
        }
        
        // Content container
        Loader {
            id: contentLoader
            anchors.top: handleBar.visible ? handleBar.bottom : parent.top
            anchors.topMargin: units.gu(1)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: units.gu(1)
        }
    }
}
