# C++ Models Architecture

This document explains the C++ model architecture implemented to optimize the Serchat application's performance and fix scroll-related bugs.

## Why C++ Models?

### Problems with JavaScript Arrays in QML

When using `property var messages: []` in QML:

1. **Full Model Reset**: Every array assignment (`messages = newArray`) triggers a full model reset in ListView, which:
   - Resets scroll position to the beginning
   - Destroys and recreates all delegates
   - Causes visible UI jumps

2. **Performance**: JavaScript array operations are interpreted at runtime:
   - O(n) lookups to find messages by ID
   - Slow array manipulation (splice, concat, etc.)
   - High memory overhead from QVariant boxing

3. **No Incremental Updates**: There's no way to tell QML "just update this one item"

### C++ Model Advantages

1. **Proper Qt Model Signals**:
   - `beginInsertRows/endInsertRows` - adds items without scroll reset
   - `dataChanged` - updates items without scroll reset
   - `beginRemoveRows/endRemoveRows` - removes items without scroll reset

2. **Performance**:
   - Compiled machine code (~10-100x faster than JS)
   - O(1) lookups using `QHash<QString, int>` for ID→index mapping
   - Efficient memory layout

3. **Thread Safety**: Can be safely updated from network threads

## Available Models

### MessageModel

Specialized model for chat messages with built-in:
- Scroll position preservation during edits/deletes/reactions
- O(1) message lookup by ID
- Automatic sender name/avatar resolution from profile cache
- Temp message replacement (optimistic updates)

**QML Access:**
```qml
ListView {
    model: SerchatAPI.messageModel
    delegate: MessageBubble {
        messageId: model.id
        text: model.text
        senderId: model.senderId
        senderName: model.senderName  // Auto-resolved from profile cache
        reactions: model.reactions
    }
}
```

**API Methods:**
```cpp
// Channel context
void setChannel(serverId, channelId)
void setDMRecipient(recipientId)

// Message operations (these use proper Qt signals!)
void prependMessage(message)        // New message at top (index 0)
void appendMessages(messages)       // Older messages (pagination)
void updateMessage(id, newMessage)  // Edit - uses dataChanged
void updateReactions(id, reactions) // Reaction update - uses dataChanged
bool deleteMessage(id)              // Delete - uses beginRemoveRows
void replaceTempMessage(tempId, realMessage) // Optimistic update

// Fast lookups
bool hasMessage(id)                 // O(1)
QVariantMap getMessage(id)          // O(1)
int indexOfMessage(id)              // O(1)
```

### GenericListModel

Flexible model for servers, channels, members, friends, etc.

**QML Access:**
```qml
// Servers list
ListView {
    model: SerchatAPI.serversModel
    delegate: ServerItem {
        name: model.name
        icon: model.icon
    }
}

// Channels list
ListView {
    model: SerchatAPI.channelsModel
    delegate: ChannelItem {
        name: model.name
        type: model.type
    }
}
```

**API Methods:**
```cpp
// Bulk operations
void setItems(items)        // Replace all items
void clear()

// Individual operations
void append(item)
void prepend(item)
void insert(index, item)
bool updateItem(id, item)
bool updateItemProperty(id, property, value)  // Single property update
bool removeItem(id)

// Queries
bool contains(id)
QVariantMap get(id)
int indexOf(id)
```

## Migration Guide

### Before (JavaScript arrays):
```qml
// HomePage.qml
property var messages: []

// Adding a message (causes scroll reset!)
homePage.messages = [newMessage].concat(homePage.messages)

// Updating a message (causes scroll reset!)
var newMessages = []
for (var i = 0; i < messages.length; i++) {
    if (messages[i]._id === messageId) {
        newMessages.push(updatedMessage)
    } else {
        newMessages.push(messages[i])
    }
}
homePage.messages = newMessages

// Deleting a message (causes scroll reset!)
var filtered = messages.filter(m => m._id !== messageId)
homePage.messages = filtered
```

### After (C++ model):
```qml
// MessageView.qml
ListView {
    model: SerchatAPI.messageModel
    // No more scroll resets!
}

// Adding a message (preserves scroll!)
SerchatAPI.messageModel.prependMessage(newMessage)

// Updating a message (preserves scroll!)
SerchatAPI.messageModel.updateMessage(messageId, updatedMessage)

// Deleting a message (preserves scroll!)
SerchatAPI.messageModel.deleteMessage(messageId)
```

### Connecting to Real-time Events

```qml
Connections {
    target: SerchatAPI
    
    onServerMessageReceived: {
        // Use model directly - no JavaScript array manipulation needed
        SerchatAPI.messageModel.prependMessage(message)
    }
    
    onServerMessageEdited: {
        SerchatAPI.messageModel.updateMessage(message._id, message)
    }
    
    onServerMessageDeleted: {
        SerchatAPI.messageModel.deleteMessage(messageId)
    }
    
    onReactionAdded: {
        SerchatAPI.messageModel.updateReactions(messageId, reactions)
    }
}
```

## Performance Comparison

| Operation | JavaScript Array | C++ Model |
|-----------|-----------------|-----------|
| Find by ID | O(n) loop | O(1) hash lookup |
| Add message | O(n) array copy | O(1) prepend |
| Update message | O(n) filter + copy | O(1) direct access |
| Delete message | O(n) filter + copy | O(1) lookup + O(n) shift |
| Scroll preserved | ❌ No | ✅ Yes |

## Implementation Notes

### Role Names

The MessageModel exposes these roles for delegate binding:
- `id` - Message ID (_id or id)
- `text` - Message content
- `senderId` - Sender's user ID
- `senderName` - Sender's display name (auto-resolved)
- `senderAvatar` - Sender's avatar URL (auto-resolved)
- `timestamp` - createdAt timestamp
- `isEdited` - Edit flag
- `replyToId` - Reply-to message ID
- `repliedMessage` - Full replied message object
- `reactions` - Reactions array
- `attachments` - Attachments array
- `isTempMessage` - True if optimistic (temp_xxx ID)

### User Profile Cache

The MessageModel maintains a reference to user profiles for automatic sender name/avatar resolution:

```cpp
// In C++ (called by SerchatAPI when profiles are fetched)
messageModel->updateUserProfile(userId, profileData);

// Automatically updates senderName/senderAvatar for all messages from this user
```

### Thread Safety

All model operations emit Qt signals which are queued to the main thread, making it safe to call model methods from network callbacks.
