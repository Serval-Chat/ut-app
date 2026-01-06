import QtQuick 2.7
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3

/*
 * LucideIcon - Render Lucide icons with proper theming
 * 
 * Loads SVG icons from the Lucide icon library and applies
 * theme-appropriate colors.
 * 
 * Usage:
 *   LucideIcon {
 *       name: "shield-check"
 *       width: units.gu(3)
 *       height: units.gu(3)
 *       color: Theme.palette.normal.foregroundText
 *   }
 */
Item {
    id: root
    
    // The kebab-case name of the Lucide icon (e.g., "shield-check", "user-circle")
    property string name: ""
    
    // Color to apply to the icon (respects theme)
    property color color: Theme.palette.normal.foregroundText
    
    // Opacity of the icon
    property real iconOpacity: 1.0
    
    // Whether to show a fallback if icon not found
    property bool showFallback: true
    
    width: units.gu(3)
    height: units.gu(3)
    
    // Load the SVG image
    Image {
        id: svgImage
        anchors.fill: parent
        source: name ? "qrc:/assets/lucide/lucide/icons/" + name + ".svg" : ""
        sourceSize.width: width
        sourceSize.height: height
        visible: false
        cache: true
        asynchronous: true
        
        onStatusChanged: {
            if (status === Image.Error && showFallback) {
                console.warn("[LucideIcon] Failed to load icon:", name)
            }
        }
    }
    
    // Apply color overlay to match theme
    ColorOverlay {
        id: colorOverlay
        anchors.fill: svgImage
        source: svgImage
        color: root.color
        opacity: iconOpacity
        visible: svgImage.status === Image.Ready
    }
    
    // Fallback icon when image fails to load
    Icon {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8
        name: "help"
        color: root.color
        visible: showFallback && svgImage.status === Image.Error
    }
}
