import QtQuick 2.7
import QtMultimedia 5.6
import Lomiri.Components 1.3

import SerchatAPI 1.0

/*
 * MediaViewer - Fullscreen popup for viewing images and videos
 *
 * Displays media content in a fullscreen overlay with:
 * - Pinch-to-zoom for images
 * - Video playback controls
 * - Download button
 * - Close button
 */
Rectangle {
    id: mediaViewer

    property string mediaUrl: ""
    property string filename: ""
    property string mimeType: ""
    property bool isVideo: mimeType.indexOf("video/") === 0
    property bool isImage: mimeType.indexOf("image/") === 0

    visible: false
    color: Qt.rgba(0, 0, 0, 0.95)
    z: 1000

    // Close on escape key
    Keys.onEscapePressed: close()

    function open(url, name, mime) {
        console.log("[MediaViewer] Opening:", url, name, mime)
        mediaUrl = url
        filename = name
        mimeType = mime || ""
        visible = true
        forceActiveFocus()

        console.log("[MediaViewer] isImage:", isImage, "isVideo:", isVideo)

        if (isVideo) {
            videoPlayer.source = mediaUrl
            videoPlayer.play()
        }
    }

    function close() {
        console.log("[MediaViewer] Closing")
        if (isVideo) {
            videoPlayer.stop()
            videoPlayer.source = ""
        }
        visible = false
        mediaUrl = ""
        filename = ""
        mimeType = ""
    }

    // Background tap to close
    MouseArea {
        anchors.fill: parent
        onClicked: mediaViewer.close()
    }

    // Header bar
    Rectangle {
        id: headerBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: units.gu(6)
        color: Qt.rgba(0, 0, 0, 0.7)
        z: 10

        Row {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(2)
            }
            spacing: units.gu(2)

            // Close button
            AbstractButton {
                width: units.gu(4)
                height: units.gu(4)

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.5)
                    height: units.gu(2.5)
                    name: "close"
                    color: "white"
                }

                onClicked: mediaViewer.close()
            }

            // Filename
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: filename
                color: "white"
                fontSize: "medium"
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, mediaViewer.width - units.gu(20))
            }
        }

        // Download button
        AbstractButton {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: units.gu(2)
            }
            width: units.gu(4)
            height: units.gu(4)

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: parent.pressed ? LomiriColors.blue : "transparent"
                border.width: 1
                border.color: "white"
            }

            Icon {
                anchors.centerIn: parent
                width: units.gu(2)
                height: units.gu(2)
                name: "save"
                color: "white"
            }

            onClicked: {
                if (mediaUrl) {
                    Qt.openUrlExternally(mediaUrl)
                }
            }
        }
    }

    // Image viewer with pinch-to-zoom
    Flickable {
        id: imageFlickable
        anchors {
            top: headerBar.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        visible: isImage && !isVideo
        clip: true
        contentWidth: Math.max(imageContent.width * imageContent.scale, width)
        contentHeight: Math.max(imageContent.height * imageContent.scale, height)
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: imageContent
            width: imageFlickable.width
            height: imageFlickable.height
            
            property real scale: 1.0
            property real minScale: 1.0
            property real maxScale: 4.0

            transform: Scale {
                origin.x: imageContent.width / 2
                origin.y: imageContent.height / 2
                xScale: imageContent.scale
                yScale: imageContent.scale
            }

            Image {
                id: fullImage
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                source: isImage ? mediaUrl : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true

                // Prevent closing when clicking on image
                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse.accepted = true
                    onDoubleClicked: {
                        if (imageContent.scale > 1.0) {
                            imageContent.scale = 1.0
                        } else {
                            imageContent.scale = 2.0
                        }
                    }
                }

                // Loading indicator
                ActivityIndicator {
                    anchors.centerIn: parent
                    running: fullImage.status === Image.Loading
                    visible: running
                }
            }

            PinchArea {
                anchors.fill: parent
                pinch.target: imageContent
                pinch.minimumScale: imageContent.minScale
                pinch.maximumScale: imageContent.maxScale

                onPinchUpdated: {
                    imageContent.scale = Math.max(imageContent.minScale, 
                        Math.min(imageContent.maxScale, imageContent.scale * pinch.scale / pinch.previousScale))
                }
            }
        }
    }

    // Video player
    Item {
        id: videoContainer
        anchors {
            top: headerBar.bottom
            bottom: videoControls.top
            left: parent.left
            right: parent.right
        }
        visible: isVideo

        Video {
            id: videoPlayer
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            autoPlay: false

            // Prevent closing when clicking on video
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    mouse.accepted = true
                    if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                        videoPlayer.pause()
                    } else {
                        videoPlayer.play()
                    }
                }
            }

            // Loading/error indicator
            ActivityIndicator {
                anchors.centerIn: parent
                running: videoPlayer.status === MediaPlayer.Loading
                visible: running
            }

            Label {
                anchors.centerIn: parent
                text: i18n.tr("Failed to load video")
                color: "white"
                visible: videoPlayer.status === MediaPlayer.InvalidMedia || videoPlayer.error !== MediaPlayer.NoError
            }
        }

        // Play button overlay (when paused)
        Rectangle {
            anchors.centerIn: parent
            width: units.gu(8)
            height: units.gu(8)
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: videoPlayer.playbackState !== MediaPlayer.PlayingState && 
                     videoPlayer.status !== MediaPlayer.Loading

            Icon {
                anchors.centerIn: parent
                width: units.gu(4)
                height: units.gu(4)
                name: "media-playback-start"
                color: "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: videoPlayer.play()
            }
        }
    }

    // Video controls
    Rectangle {
        id: videoControls
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: visible ? units.gu(8) : 0
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: isVideo

        Column {
            anchors.fill: parent
            anchors.margins: units.gu(1)
            spacing: units.gu(0.5)

            // Progress bar (simplified - tap to seek)
            Item {
                width: parent.width
                height: units.gu(3)

                // Background track
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    height: units.gu(0.5)
                    color: Qt.rgba(255, 255, 255, 0.3)
                    radius: height / 2

                    // Progress fill
                    Rectangle {
                        width: videoPlayer.duration > 0 ? 
                               parent.width * (videoPlayer.position / videoPlayer.duration) : 0
                        height: parent.height
                        color: LomiriColors.blue
                        radius: height / 2
                    }
                }

                // Tap to seek
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (videoPlayer.duration > 0) {
                            var seekPosition = (mouse.x / width) * videoPlayer.duration
                            videoPlayer.seek(seekPosition)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: units.gu(2)

                // Play/Pause button
                AbstractButton {
                    width: units.gu(4)
                    height: units.gu(4)

                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: videoPlayer.playbackState === MediaPlayer.PlayingState ? 
                              "media-playback-pause" : "media-playback-start"
                        color: "white"
                    }

                    onClicked: {
                        if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                            videoPlayer.pause()
                        } else {
                            videoPlayer.play()
                        }
                    }
                }

                // Time display
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: formatTime(videoPlayer.position) + " / " + formatTime(videoPlayer.duration)
                    color: "white"
                    fontSize: "small"

                    function formatTime(ms) {
                        var totalSeconds = Math.floor(ms / 1000)
                        var minutes = Math.floor(totalSeconds / 60)
                        var seconds = totalSeconds % 60
                        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                    }
                }
            }
        }
    }
}
