import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0

/*
 * MarkdownText - Renders text with markdown formatting and custom emojis
 * 
 * Supports:
 * - Bold (**text** or __text__)
 * - Italic (*text* or _text_)
 * - Strikethrough (~~text~~)
 * - Underline (__text__ when not bold)
 * - Code (`code`)
 * - Code blocks (```code```)
 * - Headers (# ## ### ####)
 * - Blockquotes (> text)
 * - Unordered lists (- item or * item)
 * - Ordered lists (1. item)
 * - Links ([text](url) and automatic URL detection)
 * - Spoilers (||text||)
 * - Custom emojis (<emoji:id>)
 * - Unicode emoji rendering
 * - Mentions (@username)
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
    property var customEmojis: ({})  // Map of emojiId -> emoji object
    property var userProfiles: ({})  // Map of userId -> user profile object for mention rendering
    property bool selectable: false
    property int wrapMode: Text.Wrap
    property int maximumLineCount: -1
    
    // Force re-render when customEmojis changes by including its keys count
    property int emojiCacheVersion: Object.keys(customEmojis).length
    
    // Force re-render when userProfiles changes
    property int userProfilesVersion: Object.keys(userProfiles).length
    
    // Check if the message is emoji-only (for larger display)
    readonly property bool isEmojiOnly: checkIsEmojiOnly(text)
    
    // Emoji sizes based on context
    readonly property int normalEmojiSize: 20  // Same as text
    readonly property int largeEmojiSize: 32   // Larger for emoji-only messages
    readonly property int currentEmojiSize: isEmojiOnly ? largeEmojiSize : normalEmojiSize
    
    // The rendered HTML content (depends on text, emoji cache, user profiles, and emoji size)
    property string renderedHtml: renderMarkdown(text, emojiCacheVersion, userProfilesVersion, currentEmojiSize)
    
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
    signal unknownEmojiFound(string emojiId)  // Signal to request emoji fetch
    
    // Track pending emoji requests to avoid duplicates
    property var pendingEmojiRequests: ({})
    
    // Check if the message contains only emojis (Unicode or custom)
    // Returns true if the message is emoji-only, false otherwise
    function checkIsEmojiOnly(input) {
        if (!input || input.length === 0) return false
        
        // Remove whitespace
        var trimmed = input.trim()
        if (trimmed.length === 0) return false
        
        // Pattern to match custom emojis: <emoji:xxx> or :shortcode:
        var customEmojiPattern = /<emoji:[a-zA-Z0-9]+>|:[a-zA-Z0-9_]+:/g
        
        // Remove custom emojis first
        var withoutCustom = trimmed.replace(customEmojiPattern, '')
        
        // Remove whitespace after removing custom emojis
        withoutCustom = withoutCustom.replace(/\s+/g, '')
        
        // If only custom emojis remain, it's emoji-only
        if (withoutCustom.length === 0) return true
        
        // Check remaining content for Unicode emojis only
        // This regex matches most common emoji ranges
        // Unicode emoji ranges: emoticons, dingbats, symbols, flags, etc.
        var remaining = withoutCustom
        
        // Process string character by character (handling surrogate pairs)
        var i = 0
        while (i < remaining.length) {
            var code = remaining.charCodeAt(i)
            
            // Check for surrogate pair (emoji often use these)
            if (code >= 0xD800 && code <= 0xDBFF && i + 1 < remaining.length) {
                var nextCode = remaining.charCodeAt(i + 1)
                if (nextCode >= 0xDC00 && nextCode <= 0xDFFF) {
                    // Valid surrogate pair - skip both chars
                    i += 2
                    continue
                }
            }
            
            // Check for common emoji Unicode ranges (BMP)
            if (
                // Emoticons and symbols
                (code >= 0x2600 && code <= 0x27BF) ||
                // Dingbats
                (code >= 0x2700 && code <= 0x27BF) ||
                // Miscellaneous Symbols
                (code >= 0x2300 && code <= 0x23FF) ||
                // Enclosed alphanumerics
                (code >= 0x2460 && code <= 0x24FF) ||
                // Box drawing (for certain symbols)
                (code >= 0x2500 && code <= 0x257F) ||
                // Geometric shapes
                (code >= 0x25A0 && code <= 0x25FF) ||
                // Misc symbols and arrows
                (code >= 0x2B00 && code <= 0x2BFF) ||
                // Regional indicators (flags)
                (code >= 0x1F1E0 && code <= 0x1F1FF) ||
                // Variation selectors (VS15, VS16)
                (code === 0xFE0E || code === 0xFE0F) ||
                // Zero-width joiner
                (code === 0x200D) ||
                // Skin tone modifiers
                (code >= 0x1F3FB && code <= 0x1F3FF)
            ) {
                i++
                continue
            }
            
            // Any other character means it's not emoji-only
            return false
        }
        
        return true
    }
    
    // Parse and render markdown to HTML
    // cacheVersion and userVersion are used to force re-render when data changes
    // emojiSize determines the size of emoji images
    function renderMarkdown(input, cacheVersion, userVersion, emojiSize) {
        if (!input) return ""
        
        var html = input
        var size = emojiSize || normalEmojiSize
        
        // First, extract and preserve custom emoji tags before HTML escaping
        // Store them with placeholders
        // Emoji format: <emoji:emojiId> where emojiId is the database ID
        var emojiPlaceholders = []
        var unknownEmojis = []
        
        html = html.replace(/<emoji:([a-zA-Z0-9]+)>/g, function(match, emojiId) {
            var placeholder = "___EMOJI_" + emojiPlaceholders.length + "___"
            var emojiUrl = ""
            
            // Check if we have this emoji in our cache
            if (customEmojis && customEmojis[emojiId]) {
                var emoji = customEmojis[emojiId]
                // emoji.imageUrl is like "/uploads/emojis/xxx.png"
                emojiUrl = SerchatAPI.apiBaseUrl + emoji.imageUrl
            } else {
                // Emoji not in cache - queue for fetch and show loading placeholder
                console.log("[MarkdownText] Unknown emoji:", emojiId)
                if (!pendingEmojiRequests[emojiId]) {
                    unknownEmojis.push(emojiId)
                }
                // Show a loading/unknown placeholder
                emojiPlaceholders.push('<img src="" width="' + size + '" height="' + size + '" style="vertical-align: -0.5em; background-color: #e0e0e0; border-radius: 3px;" alt=":' + emojiId + ':" />')
                return placeholder
            }
            
            emojiPlaceholders.push('<img src="' + emojiUrl + '" width="' + size + '" height="' + size + '" style="vertical-align: -0.5em;" />')
            return placeholder
        })
        
        // Extract user mentions before HTML escaping
        // Format: <userid:'{user_id}'> where user_id is the database ID
        var userMentionPlaceholders = []
        html = html.replace(/<userid:'([a-zA-Z0-9]+)'>/g, function(match, userId) {
            var placeholder = "___USERMENTION_" + userMentionPlaceholders.length + "___"
            var displayName = "@" + userId.substring(0, 8) + "..."  // Default fallback
            
            // Try to get username from userProfiles
            if (userProfiles && userProfiles[userId]) {
                var profile = userProfiles[userId]
                displayName = "@" + (profile.displayName || profile.username || userId.substring(0, 8))
            }
            
            // Create clickable mention link
            userMentionPlaceholders.push('<a href="user:' + userId + '" style="color: ' + linkColor + '; font-weight: bold; background-color: rgba(88, 101, 242, 0.2); padding: 0 2px; border-radius: 3px;">' + displayName + '</a>')
            return placeholder
        })
        
        // Extract at-everyone mentions, and format them like user mentions
        // Format: <everyone>
        html = html.replace(/<everyone>/g, function(match) {
            var placeholder = "___USERMENTION_" + userMentionPlaceholders.length + "___"
            var displayName = "@everyone"
            // At-everyone does not need to be clickable, but does need to look identical to other user mentions
            userMentionPlaceholders.push('<span style="color: ' + linkColor + '; font-weight: bold; background-color: rgba(88, 101, 242, 0.2); padding: 0 2px; border-radius: 3px;">' + displayName + '</span>')
            return placeholder
        })

        // Extract markdown-style links [text](url) before escaping
        var urlPlaceholders = []
        html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, function(match, text, url) {
            var placeholder = "___URL_" + urlPlaceholders.length + "___"
            urlPlaceholders.push('<a href="' + url + '">' + text + '</a>')
            return placeholder
        })
        
        // Extract plain URLs before escaping to preserve them
        html = html.replace(/(https?:\/\/[^\s<>"]+)/g, function(match, url) {
            var placeholder = "___URL_" + urlPlaceholders.length + "___"
            urlPlaceholders.push('<a href="' + url + '">' + url + '</a>')
            return placeholder
        })
        
        // Now escape HTML for the rest of the content
        html = escapeHtml(html)
        
        // Code blocks (``` ```) - must be done before inline code
        html = html.replace(/```([^`]+)```/g, function(match, code) {
            return '<pre style="background-color: ' + codeBackground + '; padding: 4px; font-family: monospace;">' + code.trim() + '</pre>'
        })
        
        // Inline code (`code`)
        html = html.replace(/`([^`]+)`/g, function(match, code) {
            return '<code style="background-color: ' + codeBackground + '; padding: 2px 4px; font-family: monospace;">' + code + '</code>'
        })
        
        // Headers (# ## ### etc.) - process line by line
        // Must come before bold/italic to avoid conflicts
        var lines = html.split('<br>')
        if (lines.length === 1) lines = html.split('\n')
        
        html = lines.map(function(line) {
            // H1: # Header
            if (/^#{1}\s+(.+)$/.test(line)) {
                return line.replace(/^#{1}\s+(.+)$/, '<span style="font-size: x-large; font-weight: bold; display: block; margin: 8px 0;">$1</span>')
            }
            // H2: ## Header
            if (/^#{2}\s+(.+)$/.test(line)) {
                return line.replace(/^#{2}\s+(.+)$/, '<span style="font-size: large; font-weight: bold; display: block; margin: 6px 0;">$1</span>')
            }
            // H3: ### Header
            if (/^#{3}\s+(.+)$/.test(line)) {
                return line.replace(/^#{3}\s+(.+)$/, '<span style="font-size: medium; font-weight: bold; display: block; margin: 4px 0;">$1</span>')
            }
            // H4+: #### Header (and more)
            if (/^#{4,}\s+(.+)$/.test(line)) {
                return line.replace(/^#{4,}\s+(.+)$/, '<span style="font-weight: bold; display: block; margin: 2px 0;">$1</span>')
            }
            // Blockquotes: > text
            if (/^&gt;\s+(.+)$/.test(line)) {
                return line.replace(/^&gt;\s+(.+)$/, '<span style="border-left: 4px solid ' + linkColor + '; padding-left: 12px; margin-left: 4px; display: block; opacity: 0.8;">$1</span>')
            }
            // Unordered lists: - item or * item
            if (/^[-*]\s+(.+)$/.test(line)) {
                return line.replace(/^[-*]\s+(.+)$/, '<span style="display: block; margin-left: 16px;">• $1</span>')
            }
            // Ordered lists: 1. item
            if (/^(\d+)\.\s+(.+)$/.test(line)) {
                return line.replace(/^(\d+)\.\s+(.+)$/, '<span style="display: block; margin-left: 16px;">$1. $2</span>')
            }
            return line
        }).join('<br>')
        
        // Spoilers (||text||)
        html = html.replace(/\|\|([^|]+)\|\|/g, '<span style="background-color: ' + textColor + '; color: ' + textColor + ';">$1</span>')
        
        // Underline (++text++)
        html = html.replace(/\+\+([^+]+)\+\+/g, '<u>$1</u>')
        
        // Bold (**text** or __text__)
        html = html.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>')
        html = html.replace(/__([^_]+)__/g, '<b>$1</b>')
        
        // Italic (*text* or _text_) - use simpler regex without lookbehind for Qt 5.12 compatibility
        html = html.replace(/(^|[^*\w])\*([^*]+)\*([^*\w]|$)/g, '$1<i>$2</i>$3')
        html = html.replace(/(^|[^_\w])_([^_]+)_([^_\w]|$)/g, '$1<i>$2</i>$3')
        
        // Strikethrough (~~text~~)
        html = html.replace(/~~([^~]+)~~/g, '<s>$1</s>')
        
        // User mentions (@username)
        html = html.replace(/@([a-zA-Z0-9_]+)/g, function(match, username) {
            return '<a href="user:' + username + '" style="color: ' + linkColor + '; font-weight: bold;">@' + username + '</a>'
        })
        
        // Channel references (#channel)
        html = html.replace(/#([a-zA-Z0-9_-]+)/g, function(match, channel) {
            return '<a href="channel:' + channel + '" style="color: ' + linkColor + ';">#' + channel + '</a>'
        })
        
        // Restore URL placeholders
        for (var i = 0; i < urlPlaceholders.length; i++) {
            html = html.replace("___URL_" + i + "___", urlPlaceholders[i])
        }
        
        // Restore emoji placeholders
        for (var j = 0; j < emojiPlaceholders.length; j++) {
            html = html.replace("___EMOJI_" + j + "___", emojiPlaceholders[j])
        }
        
        // Restore user mention placeholders
        for (var m = 0; m < userMentionPlaceholders.length; m++) {
            html = html.replace("___USERMENTION_" + m + "___", userMentionPlaceholders[m])
        }
        
        // Newlines to <br> (if not already converted during header processing)
        if (html.indexOf('<br>') === -1) {
            html = html.replace(/\n/g, '<br>')
        }
        
        // Request unknown emojis to be fetched
        for (var k = 0; k < unknownEmojis.length; k++) {
            var eid = unknownEmojis[k]
            if (!pendingEmojiRequests[eid]) {
                pendingEmojiRequests[eid] = true
                unknownEmojiFound(eid)
            }
        }
        
        return html
    }
    
    function escapeHtml(text) {
        return text.replace(/&/g, '&amp;')
                  .replace(/</g, '&lt;')
                  .replace(/>/g, '&gt;')
                  .replace(/"/g, '&quot;')
    }
}
