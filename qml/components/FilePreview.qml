import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0

/*
 * FilePreview - Displays a file attachment with metadata and media previews
 *
 * Shows file name, size, and type with a download button.
 * For images and videos, shows a preview that can be tapped to open fullscreen.
 * Fetches metadata from the server to display accurate information.
 */
Item {
    id: filePreview

    property string filename: ""
    property string downloadUrl: ""
    property color borderColor: LomiriColors.ash
    property color backgroundColor: Qt.rgba(Theme.palette.normal.base.r,
                                            Theme.palette.normal.base.g,
                                            Theme.palette.normal.base.b, 0.3)

    // Metadata from server
    property string displayName: filename
    property string mimeType: ""
    property int fileSize: 0
    property bool isBinary: true
    property bool isLoading: true
    property bool hasError: false

    // Computed properties
    readonly property string sizeText: formatFileSize(fileSize)
    readonly property string typeText: getFileTypeText(mimeType, isBinary)
    readonly property string iconName: getFileIcon(mimeType, isBinary)
    readonly property bool isImage: mimeType.indexOf("image/") === 0
    readonly property bool isVideo: mimeType.indexOf("video/") === 0
    readonly property bool isMedia: isImage || isVideo
    // Images/videos are always previewable regardless of binary flag
    readonly property bool isPreviewable: isMedia

    // Signal to request opening the media viewer
    signal mediaViewRequested(string url, string name, string mime)

    // Full URL for API requests and downloads
    readonly property string fullDownloadUrl: {
        if (!downloadUrl || downloadUrl === "") return ""
        if (downloadUrl.indexOf("http://") === 0 || downloadUrl.indexOf("https://") === 0) {
            return downloadUrl
        }
        var baseUrl = SerchatAPI.apiBaseUrl
        if (baseUrl.charAt(baseUrl.length - 1) === "/") {
            baseUrl = baseUrl.substring(0, baseUrl.length - 1)
        }
        return baseUrl + downloadUrl
    }

    readonly property string metadataKey: SerchatAPI.fileMetadataCache ?
                                          SerchatAPI.fileMetadataCache.metadataKeyForUrl(downloadUrl) : ""

    width: parent ? Math.min(parent.width, units.gu(35)) : units.gu(35)
    height: contentColumn.height + units.gu(2)

    onMetadataKeyChanged: loadMetadata()

    Component.onCompleted: {
        loadMetadata()
    }

    Connections {
        target: SerchatAPI.fileMetadataCache

        onMetadataLoaded: function(loadedFilename) {
            if (loadedFilename === filePreview.metadataKey) {
                loadMetadata()
            }
        }

        onMetadataFetchFailed: function(failedFilename, error) {
            if (failedFilename === filePreview.metadataKey) {
                isLoading = false
                hasError = true
                console.warn("[FilePreview] Failed to fetch metadata:", error)
            }
        }
    }

    function loadMetadata() {
        if (!metadataKey || !SerchatAPI.fileMetadataCache) {
            isLoading = false
            hasError = false
            return
        }

        var metadata = SerchatAPI.fileMetadataCache.getMetadataForUrl(downloadUrl)
        if (metadata && (metadata.filename || metadata.mimeType || metadata.size !== undefined)) {
            applyMetadata(metadata)
            isLoading = false
            hasError = false
        } else {
            isLoading = true
            hasError = false
        }
    }

    function applyMetadata(metadata) {
        displayName = metadata.filename || filename
        fileSize = metadata.size || 0
        mimeType = metadata.mimeType || ""
        isBinary = metadata.isBinary !== undefined ? metadata.isBinary : true
    }

    function formatFileSize(bytes) {
        if (bytes === 0) return ""
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    function getFileTypeText(mime, binary) {
        if (!mime) return binary ? i18n.tr("Binary file") : i18n.tr("Text file")
        
        // Common MIME type mappings
        var typeMap = {
            "application/pdf": "PDF",
            "application/zip": "ZIP Archive",
            "application/x-tar": "TAR Archive",
            "application/gzip": "GZIP Archive",
            "application/json": "JSON",
            "application/xml": "XML",
            "text/plain": i18n.tr("Text file"),
            "text/html": "HTML",
            "text/css": "CSS",
            "text/javascript": "JavaScript",
            "image/png": "PNG Image",
            "image/jpeg": "JPEG Image",
            "image/gif": "GIF Image",
            "image/webp": "WebP Image",
            "image/svg+xml": "SVG Image",
            "audio/mpeg": "MP3 Audio",
            "audio/ogg": "OGG Audio",
            "audio/wav": "WAV Audio",
            "video/mp4": "MP4 Video",
            "video/webm": "WebM Video",
            "video/quicktime": "MOV Video"
        }

        if (typeMap[mime]) return typeMap[mime]
        
        // Extract general type from MIME
        var parts = mime.split("/")
        if (parts.length === 2) {
            var mainType = parts[0]
            var subType = parts[1]
            
            switch (mainType) {
                case "image": return subType.toUpperCase() + " " + i18n.tr("Image")
                case "audio": return subType.toUpperCase() + " " + i18n.tr("Audio")
                case "video": return subType.toUpperCase() + " " + i18n.tr("Video")
                case "text": return i18n.tr("Text file")
                case "application": return subType.toUpperCase()
            }
        }
        
        return mime
    }

    function getFileIcon(mime, binary) {
        if (!mime) return binary ? "document-save" : "text-x-generic"
        
        if (mime.indexOf("image/") === 0) return "image-x-generic"
        if (mime.indexOf("audio/") === 0) return "audio-x-generic"
        if (mime.indexOf("video/") === 0) return "video-x-generic"
        if (mime.indexOf("text/") === 0) return "text-x-generic"
        if (mime === "application/pdf") return "application-pdf"
        if (mime.indexOf("zip") !== -1 || mime.indexOf("tar") !== -1 || mime.indexOf("gzip") !== -1) {
            return "package-x-generic"
        }
        
        return "document-save"
    }

    Rectangle {
        id: container
        anchors.fill: parent
        radius: units.gu(1)
        color: backgroundColor
        border.width: 1
        border.color: borderColor

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: units.gu(1)
            }
            spacing: units.gu(0.5)

            // Media preview (image or video thumbnail)
            Item {
                id: mediaPreviewContainer
                width: parent.width
                height: visible ? Math.min(units.gu(25), mediaPreviewContent.height) : 0
                visible: isPreviewable && !isLoading && (isVideo || imagePreview.status === Image.Ready)
                clip: true

                // Clickable area to open fullscreen viewer
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[FilePreview] Media clicked, opening viewer:", fullDownloadUrl)
                        filePreview.mediaViewRequested(fullDownloadUrl, displayName, mimeType)
                    }
                }

                // Image preview
                Image {
                    id: imagePreview
                    anchors.centerIn: parent
                    width: parent.width
                    height: isImage && sourceSize.height > 0 ? 
                            Math.min(sourceSize.height * (width / sourceSize.width), units.gu(25)) : 0
                    visible: isImage
                    source: isImage && !isLoading ? fullDownloadUrl : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true

                    onStatusChanged: {
                        console.log("[FilePreview] Image status:", status, 
                                    "isImage:", isImage, "isLoading:", isLoading,
                                    "mimeType:", mimeType)
                    }
                }

                // Video thumbnail placeholder
                Rectangle {
                    id: videoThumbnail
                    anchors.centerIn: parent
                    width: parent.width
                    height: units.gu(15)
                    visible: isVideo
                    color: Qt.rgba(0, 0, 0, 0.8)
                    radius: units.gu(0.5)

                    // Play button overlay
                    Rectangle {
                        anchors.centerIn: parent
                        width: units.gu(6)
                        height: units.gu(6)
                        radius: width / 2
                        color: Qt.rgba(255, 255, 255, 0.3)
                        border.width: 2
                        border.color: "white"

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(3)
                            height: units.gu(3)
                            name: "media-playback-start"
                            color: "white"
                        }
                    }

                    // Video type label
                    Label {
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            margins: units.gu(1)
                        }
                        text: typeText
                        fontSize: "x-small"
                        color: "white"
                    }
                }

                // Item to measure content height
                Item {
                    id: mediaPreviewContent
                    width: parent.width
                    height: isImage ? imagePreview.height : (isVideo ? videoThumbnail.height : 0)
                }

                // Tap hint overlay
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: borderColor
                    radius: units.gu(0.5)

                    // "Tap to view" hint (shows briefly or on hover-like state)
                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        height: units.gu(3)
                        color: Qt.rgba(0, 0, 0, 0.5)
                        radius: units.gu(0.5)
                        visible: isImage && imagePreview.status === Image.Ready

                        Label {
                            anchors.centerIn: parent
                            text: i18n.tr("Tap to view")
                            fontSize: "x-small"
                            color: "white"
                        }
                    }
                }
            }

            // Loading indicator for media
            Item {
                width: parent.width
                height: units.gu(10)
                visible: isPreviewable && isImage && imagePreview.status === Image.Loading

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.1)
                    radius: units.gu(0.5)
                }

                ActivityIndicator {
                    anchors.centerIn: parent
                    running: parent.visible
                }
            }

            // File info row
            Row {
                width: parent.width
                spacing: units.gu(1)

                // File icon
                Icon {
                    id: fileIcon
                    width: units.gu(4)
                    height: units.gu(4)
                    name: iconName
                    color: Theme.palette.normal.baseText
                    anchors.verticalCenter: parent.verticalCenter
                }

                // File details
                Column {
                    width: parent.width - fileIcon.width - downloadButton.width - units.gu(2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.25)

                    // Filename
                    Label {
                        width: parent.width
                        text: displayName
                        fontSize: "small"
                        font.bold: true
                        elide: Text.ElideMiddle
                        color: Theme.palette.normal.baseText
                    }

                    // File info (type and size)
                    Row {
                        spacing: units.gu(0.5)
                        visible: !isLoading

                        Label {
                            text: typeText
                            fontSize: "x-small"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }

                        Label {
                            text: sizeText ? "•" : ""
                            fontSize: "x-small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            visible: sizeText !== ""
                        }

                        Label {
                            text: sizeText
                            fontSize: "x-small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            visible: sizeText !== ""
                        }
                    }

                    // Loading indicator
                    Label {
                        text: i18n.tr("Loading...")
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        visible: isLoading
                    }
                }

                // Download button
                AbstractButton {
                    id: downloadButton
                    width: units.gu(4)
                    height: units.gu(4)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: downloadButton.pressed ? LomiriColors.blue : "transparent"
                        border.width: 1
                        border.color: LomiriColors.blue

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2)
                        height: units.gu(2)
                        name: "save"
                        color: downloadButton.pressed ? "white" : LomiriColors.blue
                    }

                    onClicked: {
                        if (fullDownloadUrl) {
                            Qt.openUrlExternally(fullDownloadUrl)
                        }
                    }
                }
            }
        }
    }
}
