import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0

/*
 * MarkdownText - Renders text with markdown formatting and custom emojis
 *
 * This component uses SerchatAPI.markdownParser (C++) for all text processing,
 * providing better performance than the previous JavaScript implementation.
 *
 * Supports:
 * - Bold, italic, underline, strikethrough
 * - Code blocks and inline code
 * - Headers, blockquotes, lists
 * - Links (markdown and auto-detected URLs)
 * - Spoilers
 * - Custom emojis (<emoji:id>)
 * - User mentions (<userid:'id'>)
 * - Channel references (#channel)
 * - Emoji-only messages with larger emoji display
 */
Item {
    id: markdownText

    property string text: ""
    property string fontSize: "small"
    property color textColor: Theme.palette.normal.baseText
    property color linkColor: LomiriColors.blue
    property color codeBackground: Qt.rgba(Theme.palette.normal.base.r,
                                           Theme.palette.normal.base.g,
                                           Theme.palette.normal.base.b, 0.5)
    property bool selectable: false
    property int wrapMode: Text.Wrap
    property int maximumLineCount: -1

    property int renderVersion: 0

    readonly property var referencedEmojiIds: extractReferencedIds(text, /<emoji:([a-zA-Z0-9]+)>/g)
    readonly property var referencedUserIds: extractReferencedIds(text, /<userid:'([a-zA-Z0-9]+)'>/g)

    // Check if the message is emoji-only using C++ (for larger display)
    // Use text without files to avoid false negatives
    readonly property bool isEmojiOnly: SerchatAPI.markdownParser.isEmojiOnly(text)

    // Emoji sizes based on context
    readonly property int normalEmojiSize: 20  // Same as text
    readonly property int largeEmojiSize: 32   // Larger for emoji-only messages
    readonly property int currentEmojiSize: isEmojiOnly ? largeEmojiSize : normalEmojiSize

    // The rendered HTML content (using C++ parser)
    property string renderedHtml: {
        // Create explicit dependencies on all relevant properties
        var _text = text
        var _renderVersion = renderVersion
        var _emojiSize = currentEmojiSize
        var _textColor = textColor
        var _linkColor = linkColor
        var _codeBackground = codeBackground
        
        // Render text without file markers
        return SerchatAPI.markdownParser.renderMarkdown(_text, _textColor, _linkColor, _codeBackground, _emojiSize)
    }

    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: contentColumn.height

    Column {
        id: contentColumn
        width: parent.width
        spacing: units.gu(1)

        // Text content (if any text remains after removing file markers)
        Label {
            id: textLabel
            width: parent.width
            text: renderedHtml
            textFormat: Text.RichText  // Use RichText for full HTML support including images
            fontSize: markdownText.isEmojiOnly ? "large" : markdownText.fontSize
            color: markdownText.textColor
            linkColor: markdownText.linkColor
            wrapMode: markdownText.wrapMode
            maximumLineCount: markdownText.maximumLineCount
            elide: maximumLineCount > 0 ? Text.ElideRight : Text.ElideNone
            lineHeight: 1.4  // Increase line height to accommodate emojis
            visible: renderedHtml.length > 0

            onLinkActivated: {
                if (link.startsWith("user:")) {
                    // User mention clicked
                    var userId = link.substring(5)
                    userMentionClicked(userId)
                } else if (link.startsWith("channel:")) {
                    // Channel reference clicked
                    var channelId = link.substring(8)
                    channelMentionClicked(channelId)
                } else {
                    // External link
                    Qt.openUrlExternally(link)
                }
            }
        }
    }

    Connections {
        target: SerchatAPI.emojiCache

        onEmojiLoaded: function(emojiId) {
            if (containsId(referencedEmojiIds, emojiId)) {
                renderVersion++
            }
        }
    }

    Connections {
        target: SerchatAPI.userProfileCache

        onProfileLoaded: function(userId) {
            if (containsId(referencedUserIds, userId)) {
                renderVersion++
            }
        }
    }

    function extractReferencedIds(value, regex) {
        var ids = []
        var match = null
        regex.lastIndex = 0

        while ((match = regex.exec(value)) !== null) {
            if (ids.indexOf(match[1]) < 0) {
                ids.push(match[1])
            }
        }

        return ids
    }

    function containsId(ids, id) {
        return ids && id && ids.indexOf(id) >= 0
    }

    signal userMentionClicked(string userId)
    signal channelMentionClicked(string channelId)
}
