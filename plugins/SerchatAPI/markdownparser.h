#ifndef MARKDOWNPARSER_H
#define MARKDOWNPARSER_H

#include <QObject>
#include <QString>
#include <QColor>

class EmojiCache;
class UserProfileCache;

/**
 * @brief Markdown parser for chat messages.
 *
 * Handles rendering of markdown-formatted text to HTML, including:
 * - Bold, italic, underline, strikethrough
 * - Code blocks and inline code
 * - Headers, blockquotes, lists
 * - Links (markdown and auto-detected URLs)
 * - Spoilers
 * - Custom emojis (<emoji:id>)
 * - User mentions (<userid:'id'>)
 * - Channel references (#channel)
 *
 * This class extracts text processing logic from QML for better performance
 * and maintainability.
 */
class MarkdownParser : public QObject {
    Q_OBJECT

public:
    explicit MarkdownParser(QObject *parent = nullptr);
    ~MarkdownParser() override = default;

    /**
     * @brief Set the emoji cache for custom emoji URL resolution.
     */
    void setEmojiCache(EmojiCache* cache);

    /**
     * @brief Set the user profile cache for mention display name resolution.
     */
    void setUserProfileCache(UserProfileCache* cache);

    /**
     * @brief Set the API base URL for constructing emoji/avatar URLs.
     */
    void setBaseUrl(const QString& baseUrl);

    // ========================================================================
    // QML-accessible methods
    // ========================================================================

    /**
     * @brief Render markdown text to HTML.
     * @param input The raw markdown text
     * @param textColor Color for regular text (used for spoilers)
     * @param linkColor Color for links
     * @param codeBackground Background color for code blocks
     * @param emojiSize Size for emoji images in pixels
     * @return HTML string ready for display in Text/Label
     */
    Q_INVOKABLE QString renderMarkdown(const QString& input,
                                        const QColor& textColor,
                                        const QColor& linkColor,
                                        const QColor& codeBackground,
                                        int emojiSize = 20) const;

    /**
     * @brief Check if text contains only emojis (Unicode or custom).
     * Used to determine if emojis should be displayed larger.
     * @param input The text to check
     * @return true if the text contains only emojis
     */
    Q_INVOKABLE bool isEmojiOnly(const QString& input) const;

    /**
     * @brief Format a timestamp for display.
     * @param timestamp ISO date string (e.g., "2024-01-15T10:30:00Z")
     * @return Human-readable string like "Today at 10:30" or "15/01/2024 10:30"
     */
    Q_INVOKABLE QString formatTimestamp(const QString& timestamp) const;

    /**
     * @brief Escape HTML special characters.
     * @param text Raw text
     * @return Text with &, <, >, " escaped
     */
    Q_INVOKABLE QString escapeHtml(const QString& text) const;

    /**
     * @brief Generate a consistent color from a string (for avatars, etc.).
     * @param text The string to hash (e.g., username)
     * @return A hex color string like "#7289da"
     */
    Q_INVOKABLE QString colorFromString(const QString& text) const;

    /**
     * @brief Get initials from a name (for avatars).
     * @param name The name to extract initials from
     * @return 1-2 character initials, uppercased
     */
    Q_INVOKABLE QString getInitials(const QString& name) const;

private:
    EmojiCache* m_emojiCache = nullptr;
    UserProfileCache* m_userProfileCache = nullptr;
    QString m_baseUrl;

    /**
     * @brief Process custom emoji tags and return HTML.
     */
    QString processCustomEmojis(const QString& text, int emojiSize) const;

    /**
     * @brief Process user mention tags and return HTML.
     */
    QString processUserMentions(const QString& text, const QColor& linkColor) const;

    /**
     * @brief Check if a Unicode codepoint is an emoji or emoji modifier.
     */
    static bool isEmojiCodepoint(uint codepoint);
};

#endif // MARKDOWNPARSER_H
