import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';

/// Semantic type of a chat message.
enum ChatMessageType {
  /// Normal assistant or user message.
  normal,

  /// System notification (mode change, network status).
  system,

  /// Error message.
  error,

  /// Success notification (transaction saved).
  success,
}

/// A single message in the voice chat history.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageType type;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.type = ChatMessageType.normal,
  });
}

/// A chat bubble widget (left = assistant, right = user).
///
/// Renders differently based on [ChatMessageType]:
/// - [normal]: standard chat bubble
/// - [system]: centered chip with muted style
/// - [error]: red-tinted bubble with error icon
/// - [success]: green-tinted bubble with check icon
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return _SystemChip(message: message);
    }
    if (message.type == ChatMessageType.error) {
      return _StatusBubble(message: message, isError: true);
    }
    if (message.type == ChatMessageType.success) {
      return _StatusBubble(message: message, isError: false);
    }
    return _NormalBubble(message: message);
  }
}

/// Standard user/assistant chat bubble.
class _NormalBubble extends StatelessWidget {
  final ChatMessage message;

  const _NormalBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final role = isUser ? '你' : '助手';

    return Semantics(
      label: '$role说：${message.text}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.smart_toy_rounded,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.xl),
                    topRight: const Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(isUser ? AppRadius.xl : 4),
                    bottomRight: Radius.circular(isUser ? 4 : AppRadius.xl),
                  ),
                ),
                child: Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isUser
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: AppSpacing.sm),
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered system notification chip (e.g. "网络已恢复").
class _SystemChip extends StatelessWidget {
  final ChatMessage message;

  const _SystemChip({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '系统提示：${message.text}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xs,
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              borderRadius: AppRadius.xlAll,
            ),
            child: Text(
              message.text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Error or success status bubble with leading icon.
class _StatusBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isError;

  const _StatusBubble({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final fgColor = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;
    final icon = isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded;

    final prefix = isError ? '错误' : '成功';
    return Semantics(
      label: '$prefix：${message.text}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: bgColor,
              child: Icon(icon, size: 16, color: fgColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fgColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable chat history with auto-scroll to bottom on new messages.
class ChatHistory extends StatefulWidget {
  final List<ChatMessage> messages;

  const ChatHistory({super.key, required this.messages});

  @override
  State<ChatHistory> createState() => _ChatHistoryState();
}

class _ChatHistoryState extends State<ChatHistory> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(ChatHistory old) {
    super.didUpdateWidget(old);
    if (widget.messages.length > old.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDuration.normal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return Center(
        child: Text(
          '说点什么或输入来记一笔吧',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final msg = widget.messages[index];
        return ChatBubble(key: ValueKey('msg_$index'), message: msg);
      },
    );
  }
}
