import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/direct_message.dart';
import '../models/profile.dart';
import '../services/firestore_dm_service.dart';
import '../state/profile_controller.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.otherProfile,
  });

  final String conversationId;
  final Profile? otherProfile;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreDmService _dmService = FirestoreDmService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<List<DirectMessage>>? _subscription;
  List<DirectMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  File? _selectedImage;

  String get _currentUserId => context.read<ProfileController>().profile.id;

  @override
  void initState() {
    super.initState();
    _startListening();
    _markAsRead();
  }

  void _startListening() {
    _subscription = _dmService.watchMessages(widget.conversationId).listen(
      (messages) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      },
    );
  }

  void _markAsRead() {
    _dmService.markAsRead(
      conversationId: widget.conversationId,
      userId: _currentUserId,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    if (_isSending) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Optimize size
      );
      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.imageSelectFailed ?? '画像の選択に失敗しました')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final imageFile = _selectedImage;

    if ((text.isEmpty && imageFile == null) || _isSending) return;

    final otherUserId = widget.otherProfile?.id;
    if (otherUserId == null) return;

    setState(() => _isSending = true);

    // Clear input immediately to prevent double sends
    _messageController.clear();
    setState(() {
      _selectedImage = null;
    });

    try {
      await _dmService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId,
        recipientId: otherUserId,
        text: imageFile == null ? text : null,
        imageFile: imageFile,
      );
    } catch (error) {
      debugPrint('Send message error: $error');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.sendFailed ?? '送信に失敗しました'),
            backgroundColor: Colors.redAccent,
          ),
        );
        // Restore input on failure
        if (imageFile == null) _messageController.text = text;
        if (imageFile != null) {
          setState(() {
            _selectedImage = imageFile;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayName =
        widget.otherProfile?.displayName ?? l10n?.chat ?? 'チャット';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.black87,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.otherProfile != null) ...[
              ProfileAvatar(profile: widget.otherProfile!, radius: 16),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildMessageList(theme),
            ),
            _buildInputArea(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.startConversation ?? '会話を始めましょう',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUserId;

        // Show date if day changed
        bool showDate = false;
        if (index == 0) {
          showDate = true;
        } else {
          final prev = _messages[index - 1].createdAt;
          final curr = message.createdAt;
          if (prev.day != curr.day ||
              prev.month != curr.month ||
              prev.year != curr.year) {
            showDate = true;
          }
        }

        return Column(
          children: [
            if (showDate) _buildDateLabel(message.createdAt),
            _MessageBubble(
              message: message,
              isMe: isMe,
              theme: theme,
              showAvatar: !isMe,
              profile: widget.otherProfile,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateLabel(DateTime date) {
    final now = DateTime.now();
    final isSameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final l10n = AppLocalizations.of(context);
    final text =
        isSameDay ? (l10n?.today ?? '今日') : '${date.month}/${date.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 48),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _isSending ? null : _pickImage,
                icon: Icon(
                  Icons.image_rounded,
                  color: theme
                      .colorScheme.primary, // Use theme color for image icon
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.of(context)?.messageInputHint ??
                              'メッセージを入力...',
                      hintStyle:
                          const TextStyle(color: Colors.black38, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isSending ? null : () => _sendMessage(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isSending
                        ? Colors.grey[300]
                        : theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded,
                          color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.theme,
    required this.showAvatar,
    required this.profile,
  });

  final DirectMessage message;
  final bool isMe;
  final ThemeData theme;
  final bool showAvatar;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final isImage = message.type == 'image';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (profile != null)
              ProfileAvatar(profile: profile!, radius: 16)
            else
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            const SizedBox(width: 8),
          ],
          if (isMe) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: isImage
                  ? const EdgeInsets.all(4) // Minimal padding for images
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? theme.colorScheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isImage
                  ? GestureDetector(
                      onTap: () {
                        if (message.imageUrl != null) {
                          FullScreenImageViewer.show(
                            context,
                            imageUrl: message.imageUrl,
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: message.imageUrl != null
                            ? Image.network(
                                message.imageUrl!,
                                fit: BoxFit.cover,
                                width: 200, // Constrain width
                                height: 200, // Constrain height (optional)
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 200,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 200,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  );
                                },
                              )
                            : const SizedBox(
                                width: 200,
                                height: 200,
                                child: Icon(Icons.error),
                              ),
                      ),
                    )
                  : Text(
                      message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isMe ? Colors.black : Colors.black87,
                        height: 1.4,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
