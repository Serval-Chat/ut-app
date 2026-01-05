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

    // Use C++ cache versions to trigger re-render when data changes
    property int emojiCacheVersion: SerchatAPI.emojiCache.version
    property int profileCacheVersion: SerchatAPI.userProfileCache.version

    // Check if the message is emoji-only using C++ (for larger display)
    readonly property bool isEmojiOnly: SerchatAPI.markdownParser.isEmojiOnly(text)

    // Emoji sizes based on context
    readonly property int normalEmojiSize: 20  // Same as text
    readonly property int largeEmojiSize: 32   // Larger for emoji-only messages
    readonly property int currentEmojiSize: isEmojiOnly ? largeEmojiSize : normalEmojiSize

    // The rendered HTML content (using C++ parser)
    // Dependencies on cache versions ensure re-render when data changes
    property string renderedHtml: {
        // Reference cache versions to ensure binding updates
        var ev = emojiCacheVersion
        var pv = profileCacheVersion
        return SerchatAPI.markdownParser.renderMarkdown(text, textColor, linkColor, codeBackground, currentEmojiSize)
    }

    implicitWidth: textLabel.implicitWidth
    implicitHeight: textLabel.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: textLabel.height

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

    signal userMentionClicked(string userId)
    signal channelMentionClicked(string channelId)
}
