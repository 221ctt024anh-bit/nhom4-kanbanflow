import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_preferences.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/direct_message.dart';
import '../../domain/entities/friend_user.dart';
import '../../injection_container.dart';

class ChatScreen extends StatefulWidget {
  final FriendUser friend;

  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _chatRepository = sl<ChatRepository>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;
  bool _isFriendTyping = false;
  Timer? _readTimer;
  Timer? _friendTypingTimer;
  Timer? _typingBroadcastTimer;
  RealtimeChannel? _chatChannel;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _subscribeToChat();
    _markRead();
    _readTimer = Timer.periodic(const Duration(seconds: 5), (_) => _markRead());
  }

  void _subscribeToChat() {
    final userId = _currentUserId;
    if (userId == null) return;

    final conversationId = ChatRepository.buildConversationId(
      userId,
      widget.friend.id,
    );

    _chatChannel = Supabase.instance.client.channel('chat:$conversationId');

    _chatChannel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['sender_id'] as String?;
            if (senderId == widget.friend.id) {
              setState(
                () => _isFriendTyping = (payload['is_typing'] as bool?) ?? false,
              );
              _friendTypingTimer?.cancel();
              if (_isFriendTyping) {
                _friendTypingTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _isFriendTyping = false);
                });
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _friendTypingTimer?.cancel();
    _typingBroadcastTimer?.cancel();
    _broadcastTyping(false);
    if (_chatChannel != null) {
      Supabase.instance.client.removeChannel(_chatChannel!);
    }
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _chatRepository.markConversationRead(widget.friend.id);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _chatRepository.sendMessage(
        friendId: widget.friend.id,
        content: text,
      );
      _messageController.clear();
      _broadcastTyping(false);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppPreferences.tr('Gui tin nhan that bai', 'Failed to send message')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showSnack(
          AppPreferences.tr(
            'Khong doc duoc du lieu anh',
            'Could not read image data',
          ),
        );
        return;
      }

      setState(() => _sending = true);
      final publicUrl = await _chatRepository.uploadChatImage(
        friendId: widget.friend.id,
        bytes: bytes,
        fileName: file.name,
      );
      await _chatRepository.sendImageMessage(
        friendId: widget.friend.id,
        imageUrl: publicUrl,
      );
      _broadcastTyping(false);
      _scrollToBottom();
    } catch (e) {
      _showSnack(
        '${AppPreferences.tr('Gui anh that bai', 'Failed to send image')}: $e',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.friend.displayName ?? widget.friend.email;
    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  backgroundImage: widget.friend.avatarUrl != null
                      ? NetworkImage(widget.friend.avatarUrl!)
                      : null,
                  child: widget.friend.avatarUrl == null
                      ? Text(
                          title.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (widget.friend.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.friend.isOnline
                        ? AppPreferences.tr('Dang hoat dong', 'Active')
                        : AppPreferences.tr('Ngoai tuyen', 'Offline'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.friend.isOnline
                          ? Colors.green
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [const SizedBox(width: 4)],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DirectMessage>>(
              stream: _chatRepository.streamConversation(widget.friend.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? <DirectMessage>[];
                if (messages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom(),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppPreferences.tr(
                              'Chua co tin nhan nao.\nHay bat dau cuoc tro chuyen voi ${widget.friend.displayName ?? 'nguoi nay'}.',
                              'No messages yet.\nStart a conversation with ${widget.friend.displayName ?? 'this person'}.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == _currentUserId;

                    var isFirstInGroup = true;
                    var isLastInGroup = true;

                    if (index > 0) {
                      isFirstInGroup =
                          messages[index - 1].senderId != message.senderId;
                    }
                    if (index < messages.length - 1) {
                      isLastInGroup =
                          messages[index + 1].senderId != message.senderId;
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        top: isFirstInGroup ? 12 : 2,
                        bottom: isLastInGroup ? 2 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: isMine
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMine) ...[
                            if (isLastInGroup)
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: widget.friend.avatarUrl != null
                                    ? NetworkImage(widget.friend.avatarUrl!)
                                    : null,
                                child: widget.friend.avatarUrl == null
                                    ? Text(
                                        title.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontSize: 10),
                                      )
                                    : null,
                              )
                            else
                              const SizedBox(width: 28),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: message.messageType == 'image'
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                              clipBehavior: message.messageType == 'image'
                                  ? Clip.antiAlias
                                  : Clip.none,
                              decoration: BoxDecoration(
                                gradient:
                                    isMine && message.messageType == 'text'
                                    ? const LinearGradient(
                                        colors: [
                                          Colors.blueAccent,
                                          Color(0xFF6366F1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isMine
                                    ? null
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(
                                    isMine ? 20 : (isLastInGroup ? 6 : 20),
                                  ),
                                  bottomRight: Radius.circular(
                                    isMine ? (isLastInGroup ? 6 : 20) : 20,
                                  ),
                                ),
                              ),
                              child: message.messageType == 'image'
                                  ? GestureDetector(
                                      onTap: () =>
                                          _showFullImage(message.content),
                                      child: Hero(
                                        tag: message.id,
                                        child: Image.network(
                                          message.content,
                                          width: 240,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Container(
                                              width: 240,
                                              height: 180,
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : Text(
                                      message.content,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isMine
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                            ),
                          ),
                          if (isMine && isLastInGroup && message.isRead)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: CircleAvatar(
                                radius: 6,
                                backgroundImage: widget.friend.avatarUrl != null
                                    ? NetworkImage(widget.friend.avatarUrl!)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isFriendTyping)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text(
                        '${widget.friend.displayName ?? widget.friend.email} ${AppPreferences.tr('dang soan tin...', 'is typing...')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _sending ? null : _pickAndSendImage,
                        icon: const Icon(
                          Icons.image_outlined,
                          color: Colors.blueAccent,
                        ),
                        tooltip: AppPreferences.tr('Gui anh', 'Send image'),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            onChanged: _onTextChanged,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: AppPreferences.tr(
                                'Nhap tin nhan...',
                                'Type a message...',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sending ? null : _sendMessage,
                        child: _sending
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.blueAccent,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.blueAccent,
                                size: 28,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTextChanged(String value) {
    if (_chatChannel == null || _currentUserId == null) return;

    if (value.trim().isEmpty) {
      _broadcastTyping(false);
      return;
    }

    _broadcastTyping(true);
    _typingBroadcastTimer?.cancel();
    _typingBroadcastTimer = Timer(
      const Duration(milliseconds: 1200),
      () => _broadcastTyping(false),
    );
  }

  void _broadcastTyping(bool isTyping) {
    if (_chatChannel == null || _currentUserId == null) return;
    _chatChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'sender_id': _currentUserId, 'is_typing': isTyping},
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showFullImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }
}
