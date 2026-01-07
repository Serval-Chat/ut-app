#include "markdownparser.h"
#include "emojicache.h"
#include "userprofilecache.h"

#include <QRegularExpression>
#include <QDateTime>
#include <QStringList>
#include <QDebug>

MarkdownParser::MarkdownParser(QObject *parent)
    : QObject(parent)
{
}

void MarkdownParser::setEmojiCache(EmojiCache* cache)
{
    m_emojiCache = cache;
}

void MarkdownParser::setUserProfileCache(UserProfileCache* cache)
{
    m_userProfileCache = cache;
}

void MarkdownParser::setBaseUrl(const QString& baseUrl)
{
    m_baseUrl = baseUrl;
}

QString MarkdownParser::escapeHtml(const QString& text) const
{
    QString result = text;
    result.replace(QStringLiteral("&"), QStringLiteral("&amp;"));
    result.replace(QStringLiteral("<"), QStringLiteral("&lt;"));
    result.replace(QStringLiteral(">"), QStringLiteral("&gt;"));
    result.replace(QStringLiteral("\""), QStringLiteral("&quot;"));
    return result;
}

QString MarkdownParser::colorFromString(const QString& text) const
{
    // Predefined color palette for consistency
    static const QStringList colors = {
        QStringLiteral("#7289da"),  // Discord blurple
        QStringLiteral("#43b581"),  // Green
        QStringLiteral("#faa61a"),  // Gold
        QStringLiteral("#f04747"),  // Red
        QStringLiteral("#9b59b6"),  // Purple
        QStringLiteral("#e91e63"),  // Pink
        QStringLiteral("#00bcd4"),  // Cyan
        QStringLiteral("#ff9800")   // Orange
    };

    QString name = text.isEmpty() ? QStringLiteral("user") : text;

    // Simple hash function
    int hash = 0;
    for (int i = 0; i < name.length(); ++i) {
        hash = name.at(i).unicode() + ((hash << 5) - hash);
    }

    return colors.at(qAbs(hash) % colors.size());
}

QString MarkdownParser::getInitials(const QString& name) const
{
    QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return QStringLiteral("?");
    }

    QStringList parts = trimmed.split(QStringLiteral(" "), QString::SkipEmptyParts);

    if (parts.size() >= 2) {
        // Two or more words: take first letter of each
        return (parts[0].left(1) + parts[1].left(1)).toUpper();
    } else {
        // Single word: take first two characters
        return trimmed.left(2).toUpper();
    }
}

bool MarkdownParser::isEmojiCodepoint(uint codepoint)
{
    // Check for common emoji Unicode ranges
    return (
        // Emoticons and symbols
        (codepoint >= 0x2600 && codepoint <= 0x27BF) ||
        // Dingbats
        (codepoint >= 0x2700 && codepoint <= 0x27BF) ||
        // Miscellaneous Symbols
        (codepoint >= 0x2300 && codepoint <= 0x23FF) ||
        // Enclosed alphanumerics
        (codepoint >= 0x2460 && codepoint <= 0x24FF) ||
        // Geometric shapes
        (codepoint >= 0x25A0 && codepoint <= 0x25FF) ||
        // Misc symbols and arrows
        (codepoint >= 0x2B00 && codepoint <= 0x2BFF) ||
        // Regional indicators (flags)
        (codepoint >= 0x1F1E0 && codepoint <= 0x1F1FF) ||
        // Emoticons (supplemental)
        (codepoint >= 0x1F600 && codepoint <= 0x1F64F) ||
        // Misc Symbols and Pictographs
        (codepoint >= 0x1F300 && codepoint <= 0x1F5FF) ||
        // Transport and Map Symbols
        (codepoint >= 0x1F680 && codepoint <= 0x1F6FF) ||
        // Supplemental Symbols and Pictographs
        (codepoint >= 0x1F900 && codepoint <= 0x1F9FF) ||
        // Symbols and Pictographs Extended-A
        (codepoint >= 0x1FA00 && codepoint <= 0x1FA6F) ||
        // Variation selectors (VS15, VS16)
        (codepoint == 0xFE0E || codepoint == 0xFE0F) ||
        // Zero-width joiner
        (codepoint == 0x200D) ||
        // Skin tone modifiers
        (codepoint >= 0x1F3FB && codepoint <= 0x1F3FF)
    );
}

bool MarkdownParser::isEmojiOnly(const QString& input) const
{
    if (input.isEmpty()) {
        return false;
    }

    QString trimmed = input.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }

    // Remove custom emoji tags: <emoji:xxx> or :shortcode:
    static QRegularExpression customEmojiRegex(QStringLiteral("<emoji:[a-zA-Z0-9]+>|:[a-zA-Z0-9_]+:"));
    QString withoutCustom = trimmed;
    withoutCustom.remove(customEmojiRegex);

    // Remove whitespace
    withoutCustom.remove(QRegularExpression(QStringLiteral("\\s+")));

    // If only custom emojis remain, it's emoji-only
    if (withoutCustom.isEmpty()) {
        return true;
    }

    // Check remaining content for Unicode emojis only
    // Process string character by character using QChar/QString iteration
    int i = 0;
    while (i < withoutCustom.length()) {
        uint codepoint;
        QChar ch = withoutCustom.at(i);

        // Check for surrogate pair
        if (ch.isHighSurrogate() && i + 1 < withoutCustom.length()) {
            QChar low = withoutCustom.at(i + 1);
            if (low.isLowSurrogate()) {
                codepoint = QChar::surrogateToUcs4(ch, low);
                i += 2;

                // Check if this supplementary codepoint is an emoji
                if (!isEmojiCodepoint(codepoint)) {
                    return false;
                }
                continue;
            }
        }

        // Single BMP character
        codepoint = ch.unicode();
        i++;

        if (!isEmojiCodepoint(codepoint)) {
            return false;
        }
    }

    return true;
}

bool MarkdownParser::hasFileAttachments(const QString& input) const
{
    if (input.isEmpty()) {
        return false;
    }
    
    // Match [%file%](url) pattern - url can be relative or absolute
    static QRegularExpression fileRegex(QStringLiteral("\\[%file%\\]\\(([^)]+)\\)"));
    bool hasMatch = fileRegex.match(input).hasMatch();
    
    // Debug logging
    if (input.contains(QStringLiteral("%file%")) || input.contains(QStringLiteral("/download"))) {
        qDebug() << "[MarkdownParser] hasFileAttachments check for:" << input;
        qDebug() << "[MarkdownParser] Pattern match result:" << hasMatch;
    }
    
    return hasMatch;
}

QVariantList MarkdownParser::extractFileAttachments(const QString& input) const
{
    QVariantList attachments;
    
    if (input.isEmpty()) {
        return attachments;
    }
    
    // Match [%file%](url) pattern - url can be absolute (https://...) or relative (/api/v1/...)
    // Captures the full URL for download
    static QRegularExpression fileRegex(QStringLiteral("\\[%file%\\]\\(((?:https?://[^/]+)?/api/v1/(?:files/)?download/[^)]+)\\)"));
    QRegularExpressionMatchIterator it = fileRegex.globalMatch(input);
    
    qDebug() << "[MarkdownParser] extractFileAttachments input:" << input;
    
    while (it.hasNext()) {
        QRegularExpressionMatch match = it.next();
        QString downloadUrl = match.captured(1);
        
        // Extract filename from URL path
        QString filename = downloadUrl;
        int lastSlash = downloadUrl.lastIndexOf(QLatin1Char('/'));
        if (lastSlash >= 0 && lastSlash < downloadUrl.length() - 1) {
            filename = downloadUrl.mid(lastSlash + 1);
        }
        
        qDebug() << "[MarkdownParser] Extracted file attachment:" << filename << "URL:" << downloadUrl;
        
        QVariantMap attachment;
        attachment[QStringLiteral("filename")] = filename;
        attachment[QStringLiteral("downloadUrl")] = downloadUrl;
        attachments.append(attachment);
    }
    
    qDebug() << "[MarkdownParser] Total attachments found:" << attachments.size();
    
    return attachments;
}

QString MarkdownParser::removeFileAttachments(const QString& input) const
{
    if (input.isEmpty()) {
        return input;
    }
    
    QString result = input;
    
    // Remove [%file%](/api/v1/download/{filename}) patterns
    static QRegularExpression fileRegex(QStringLiteral("\\[%file%\\]\\([^)]+\\)"));
    result.remove(fileRegex);
    
    // Clean up any resulting double newlines or trailing whitespace
    static QRegularExpression multipleNewlines(QStringLiteral("\\n{3,}"));
    result.replace(multipleNewlines, QStringLiteral("\n\n"));
    
    return result.trimmed();
}

QString MarkdownParser::formatTimestamp(const QString& timestamp) const
{
    if (timestamp.isEmpty()) {
        return QString();
    }

    QDateTime dateTime = QDateTime::fromString(timestamp, Qt::ISODate);
    if (!dateTime.isValid()) {
        // Try with milliseconds format
        dateTime = QDateTime::fromString(timestamp, Qt::ISODateWithMs);
    }
    if (!dateTime.isValid()) {
        return timestamp; // Return as-is if parsing fails
    }

    // Convert to local time
    dateTime = dateTime.toLocalTime();

    QDateTime now = QDateTime::currentDateTime();
    QDate today = now.date();
    QDate yesterday = today.addDays(-1);
    QDate messageDate = dateTime.date();

    QString timeStr = dateTime.toString(QStringLiteral("HH:mm"));

    if (messageDate == today) {
        return tr("Today at %1").arg(timeStr);
    } else if (messageDate == yesterday) {
        return tr("Yesterday at %1").arg(timeStr);
    } else {
        return dateTime.toString(QStringLiteral("dd/MM/yyyy")) + QStringLiteral(" ") + timeStr;
    }
}

QString MarkdownParser::processCustomEmojis(const QString& text, int emojiSize) const
{
    QString result = text;
    static QRegularExpression emojiRegex(QStringLiteral("<emoji:([a-zA-Z0-9]+)>"));

    int offset = 0;
    QRegularExpressionMatchIterator it = emojiRegex.globalMatch(text);

    while (it.hasNext()) {
        QRegularExpressionMatch match = it.next();
        QString emojiId = match.captured(1);
        QString replacement;

        // Get emoji URL from cache
        QString emojiUrl;
        if (m_emojiCache) {
            emojiUrl = m_emojiCache->getEmojiUrl(emojiId);
        }

        if (!emojiUrl.isEmpty()) {
            replacement = QStringLiteral("<img src=\"%1\" width=\"%2\" height=\"%2\" style=\"vertical-align: -0.5em;\" />")
                .arg(emojiUrl)
                .arg(emojiSize);
        } else {
            // Placeholder for loading emoji
            replacement = QStringLiteral("<img src=\"\" width=\"%1\" height=\"%1\" style=\"vertical-align: -0.5em; background-color: #e0e0e0; border-radius: 3px;\" alt=\":%2:\" />")
                .arg(emojiSize)
                .arg(emojiId);
        }

        int start = match.capturedStart() + offset;
        int length = match.capturedLength();
        result.replace(start, length, replacement);
        offset += replacement.length() - length;
    }

    return result;
}

QString MarkdownParser::processUserMentions(const QString& text, const QColor& linkColor) const
{
    QString result = text;
    QString colorStr = linkColor.name();

    // Process <userid:'id'> format
    static QRegularExpression userIdRegex(QStringLiteral("<userid:'([a-zA-Z0-9]+)'>"));

    int offset = 0;
    QRegularExpressionMatchIterator it = userIdRegex.globalMatch(text);

    while (it.hasNext()) {
        QRegularExpressionMatch match = it.next();
        QString userId = match.captured(1);

        // Get display name from cache
        QString displayName = QStringLiteral("@");
        if (m_userProfileCache) {
            displayName += m_userProfileCache->getDisplayName(userId);
        } else {
            displayName += userId;
        }

        QString replacement = QStringLiteral("<a href=\"user:%1\" style=\"color: %2; font-weight: bold; background-color: rgba(88, 101, 242, 0.2); padding: 0 2px; border-radius: 3px;\">%3</a>")
            .arg(userId, colorStr, displayName);

        int start = match.capturedStart() + offset;
        int length = match.capturedLength();
        result.replace(start, length, replacement);
        offset += replacement.length() - length;
    }

    // Process <everyone> format
    static QRegularExpression everyoneRegex(QStringLiteral("<everyone>"));
    result.replace(everyoneRegex, QStringLiteral("<span style=\"color: %1; font-weight: bold; background-color: rgba(88, 101, 242, 0.2); padding: 0 2px; border-radius: 3px;\">@everyone</span>").arg(colorStr));

    return result;
}

QString MarkdownParser::renderMarkdown(const QString& input,
                                        const QColor& textColor,
                                        const QColor& linkColor,
                                        const QColor& codeBackground,
                                        int emojiSize) const
{
    if (input.isEmpty()) {
        return QString();
    }

    QString html = input;
    QString linkColorStr = linkColor.name();
    QString textColorStr = textColor.name();
    QString codeBackgroundStr = codeBackground.name();

    // ========================================================================
    // Phase 1: Extract special content before HTML escaping
    // ========================================================================

    // Store placeholders for content that shouldn't be escaped
    QStringList emojiPlaceholders;
    QStringList userMentionPlaceholders;
    QStringList urlPlaceholders;

    // Extract custom emojis
    static QRegularExpression emojiRegex(QStringLiteral("<emoji:([a-zA-Z0-9]+)>"));
    QRegularExpressionMatchIterator emojiIt = emojiRegex.globalMatch(html);
    while (emojiIt.hasNext()) {
        QRegularExpressionMatch match = emojiIt.next();
        QString emojiId = match.captured(1);
        QString placeholder = QStringLiteral("EMOJIPLACEHOLDER%1EMOJIPLACEHOLDER").arg(emojiPlaceholders.size());

        QString emojiUrl;
        if (m_emojiCache) {
            emojiUrl = m_emojiCache->getEmojiUrl(emojiId);
        }

        QString replacement;
        if (!emojiUrl.isEmpty()) {
            replacement = QStringLiteral("<img src=\"%1\" width=\"%2\" height=\"%2\" style=\"vertical-align: -0.5em;\" />")
                .arg(emojiUrl)
                .arg(emojiSize);
        } else {
            replacement = QStringLiteral("<img src=\"\" width=\"%1\" height=\"%1\" style=\"vertical-align: -0.5em; background-color: #e0e0e0; border-radius: 3px;\" alt=\":%2:\" />")
                .arg(emojiSize)
                .arg(emojiId);
        }

        emojiPlaceholders.append(replacement);
        html.replace(match.captured(0), placeholder);
    }

    // Extract user mentions (<userid:'id'>)
    static QRegularExpression userIdRegex(QStringLiteral("<userid:'([a-zA-Z0-9]+)'>"));
    QRegularExpressionMatchIterator userIt = userIdRegex.globalMatch(html);
    while (userIt.hasNext()) {
        QRegularExpressionMatch match = userIt.next();
        QString userId = match.captured(1);
        QString placeholder = QStringLiteral("___USERMENTION_%1___").arg(userMentionPlaceholders.size());

        QString displayName = QStringLiteral("@");
        if (m_userProfileCache) {
            displayName += m_userProfileCache->getDisplayName(userId);
        } else {
            displayName += userId;
        }

        QString replacement = QStringLiteral("<a href=\"user:%1\" style=\"color: %2; font-weight: bold; background-color: rgba(88, 101, 242, 0.2); padding: 0 2px; border-radius: 3px;\">%3</a>")
            .arg(userId, linkColorStr, displayName);

        userMentionPlaceholders.append(replacement);
        html.replace(match.captured(0), placeholder);
    }

    // Extract <everyone>
    static QRegularExpression everyoneRegex(QStringLiteral("<everyone>"));
    html.replace(everyoneRegex, [&]() -> QString {
        QString placeholder = QStringLiteral("___USERMENTION_%1___").arg(userMentionPlaceholders.size());
        QString replacement = QStringLiteral("<span style=\"color: %1; font-weight: bold; background-color: rgba(88, 101, 242, 0.2); padding: 0 2px; border-radius: 3px;\">@everyone</span>")
            .arg(linkColorStr);
        userMentionPlaceholders.append(replacement);
        return placeholder;
    }());

    // Extract markdown links [text](url)
    static QRegularExpression mdLinkRegex(QStringLiteral("\\[([^\\]]+)\\]\\(([^)]+)\\)"));
    QRegularExpressionMatchIterator linkIt = mdLinkRegex.globalMatch(html);
    while (linkIt.hasNext()) {
        QRegularExpressionMatch match = linkIt.next();
        QString text = match.captured(1);
        QString url = match.captured(2);
        QString placeholder = QStringLiteral("___URL_%1___").arg(urlPlaceholders.size());

        QString replacement = QStringLiteral("<a href=\"%1\">%2</a>").arg(url, text);
        urlPlaceholders.append(replacement);
        html.replace(match.captured(0), placeholder);
    }

    // Extract plain URLs
    static QRegularExpression urlRegex(QStringLiteral("(https?://[^\\s<>\"]+)"));
    QRegularExpressionMatchIterator plainUrlIt = urlRegex.globalMatch(html);
    while (plainUrlIt.hasNext()) {
        QRegularExpressionMatch match = plainUrlIt.next();
        QString url = match.captured(1);
        QString placeholder = QStringLiteral("___URL_%1___").arg(urlPlaceholders.size());

        QString replacement = QStringLiteral("<a href=\"%1\">%1</a>").arg(url);
        urlPlaceholders.append(replacement);
        html.replace(match.captured(0), placeholder);
    }

    // ========================================================================
    // Phase 2: Escape HTML
    // ========================================================================
    html = escapeHtml(html);

    // ========================================================================
    // Phase 3: Apply markdown formatting
    // ========================================================================

    // Code blocks (``` ```)
    static QRegularExpression codeBlockRegex(QStringLiteral("```([^`]+)```"));
    html.replace(codeBlockRegex, QStringLiteral("<pre style=\"background-color: %1; padding: 4px; font-family: monospace;\">\\1</pre>").arg(codeBackgroundStr));

    // Inline code (`code`)
    static QRegularExpression inlineCodeRegex(QStringLiteral("`([^`]+)`"));
    html.replace(inlineCodeRegex, QStringLiteral("<code style=\"background-color: %1; padding: 2px 4px; font-family: monospace;\">\\1</code>").arg(codeBackgroundStr));

    // Process line-based formatting (headers, blockquotes, lists)
    QStringList lines = html.split(QStringLiteral("<br>"));
    if (lines.size() == 1) {
        lines = html.split(QStringLiteral("\n"));
    }

    for (int i = 0; i < lines.size(); ++i) {
        QString& line = lines[i];

        // H1: # Header
        static QRegularExpression h1Regex(QStringLiteral("^#{1}\\s+(.+)$"));
        line.replace(h1Regex, QStringLiteral("<span style=\"font-size: x-large; font-weight: bold; display: block; margin: 8px 0;\">\\1</span>"));

        // H2: ## Header
        static QRegularExpression h2Regex(QStringLiteral("^#{2}\\s+(.+)$"));
        line.replace(h2Regex, QStringLiteral("<span style=\"font-size: large; font-weight: bold; display: block; margin: 6px 0;\">\\1</span>"));

        // H3: ### Header
        static QRegularExpression h3Regex(QStringLiteral("^#{3}\\s+(.+)$"));
        line.replace(h3Regex, QStringLiteral("<span style=\"font-size: medium; font-weight: bold; display: block; margin: 4px 0;\">\\1</span>"));

        // H4+: #### Header
        static QRegularExpression h4Regex(QStringLiteral("^#{4,}\\s+(.+)$"));
        line.replace(h4Regex, QStringLiteral("<span style=\"font-weight: bold; display: block; margin: 2px 0;\">\\1</span>"));

        // Blockquotes: > text (escaped as &gt;)
        static QRegularExpression blockquoteRegex(QStringLiteral("^&gt;\\s+(.+)$"));
        line.replace(blockquoteRegex, QStringLiteral("<span style=\"border-left: 4px solid %1; padding-left: 12px; margin-left: 4px; display: block; opacity: 0.8;\">\\1</span>").arg(linkColorStr));

        // Unordered lists: - item or * item
        static QRegularExpression ulRegex(QStringLiteral("^[-*]\\s+(.+)$"));
        line.replace(ulRegex, QStringLiteral("<span style=\"display: block; margin-left: 16px;\">\u2022 \\1</span>"));

        // Ordered lists: 1. item
        static QRegularExpression olRegex(QStringLiteral("^(\\d+)\\.\\s+(.+)$"));
        line.replace(olRegex, QStringLiteral("<span style=\"display: block; margin-left: 16px;\">\\1. \\2</span>"));
    }

    html = lines.join(QStringLiteral("<br>"));

    // Spoilers (||text||)
    static QRegularExpression spoilerRegex(QStringLiteral("\\|\\|([^|]+)\\|\\|"));
    html.replace(spoilerRegex, QStringLiteral("<span style=\"background-color: %1; color: %1;\">\\1</span>").arg(textColorStr));

    // Underline (++text++)
    static QRegularExpression underlineRegex(QStringLiteral("\\+\\+([^+]+)\\+\\+"));
    html.replace(underlineRegex, QStringLiteral("<u>\\1</u>"));

    // Bold (**text** or __text__)
    static QRegularExpression boldStarRegex(QStringLiteral("\\*\\*([^*]+)\\*\\*"));
    html.replace(boldStarRegex, QStringLiteral("<b>\\1</b>"));
    static QRegularExpression boldUnderRegex(QStringLiteral("__([^_]+)__"));
    html.replace(boldUnderRegex, QStringLiteral("<b>\\1</b>"));

    // Italic (*text* or _text_)
    static QRegularExpression italicStarRegex(QStringLiteral("(^|[^*\\w])\\*([^*]+)\\*([^*\\w]|$)"));
    html.replace(italicStarRegex, QStringLiteral("\\1<i>\\2</i>\\3"));
    static QRegularExpression italicUnderRegex(QStringLiteral("(^|[^_\\w])_([^_]+)_([^_\\w]|$)"));
    html.replace(italicUnderRegex, QStringLiteral("\\1<i>\\2</i>\\3"));

    // Strikethrough (~~text~~)
    static QRegularExpression strikeRegex(QStringLiteral("~~([^~]+)~~"));
    html.replace(strikeRegex, QStringLiteral("<s>\\1</s>"));

    // @username mentions (plain text format)
    static QRegularExpression atMentionRegex(QStringLiteral("@([a-zA-Z0-9_]+)"));
    html.replace(atMentionRegex, QStringLiteral("<a href=\"user:\\1\" style=\"color: %1; font-weight: bold;\">@\\1</a>").arg(linkColorStr));

    // #channel references
    static QRegularExpression channelRegex(QStringLiteral("#([a-zA-Z0-9_-]+)"));
    html.replace(channelRegex, QStringLiteral("<a href=\"channel:\\1\" style=\"color: %1;\">#\\1</a>").arg(linkColorStr));

    // ========================================================================
    // Phase 4: Restore placeholders
    // ========================================================================

    // Restore URLs
    for (int i = 0; i < urlPlaceholders.size(); ++i) {
        html.replace(QStringLiteral("___URL_%1___").arg(i), urlPlaceholders[i]);
    }

    // Restore emojis
    for (int i = 0; i < emojiPlaceholders.size(); ++i) {
        html.replace(QStringLiteral("EMOJIPLACEHOLDER%1EMOJIPLACEHOLDER").arg(i), emojiPlaceholders[i]);
    }

    // Restore user mentions
    for (int i = 0; i < userMentionPlaceholders.size(); ++i) {
        html.replace(QStringLiteral("___USERMENTION_%1___").arg(i), userMentionPlaceholders[i]);
    }

    // Convert remaining newlines to <br>
    if (!html.contains(QStringLiteral("<br>"))) {
        html.replace(QStringLiteral("\n"), QStringLiteral("<br>"));
    }

    return html;
}
