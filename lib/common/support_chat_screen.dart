import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../common/custom_snackbar.dart';

class SupportChatScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const SupportChatScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _currentUserType;
  String? _currentUserName;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, String> _userNames = {};
  final Map<String, DocumentSnapshot> _latestMessagesPerUser = {};

  bool _isLoading = true;
  String? _selectedChatUserId;
  String? _selectedChatUserName;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchCurrentUserAndNames();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserAndNames() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserType = userDoc['userType'] as String?;
          _currentUserName = userDoc['name'] ?? userDoc['storeName'] ?? 'أنت';
        });

        if (_currentUserType == 'admin' && widget.targetUserId == null) {
          _isLoading = false;
        } else if (widget.targetUserId != null) {
          setState(() {
            _selectedChatUserId = widget.targetUserId;
            _selectedChatUserName = widget.targetUserName;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }

      final QuerySnapshot allUsersSnapshot = await _firestore.collection('users').get();
      final Map<String, String> names = {};
      for (final doc in allUsersSnapshot.docs) {
        names[doc.id] = doc['name'] ?? doc['storeName'] ?? 'مستخدم غير معروف';
      }
      if (mounted) {
        setState(() {
          _userNames = names;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint("Error fetching current user or all names: ${e.message}");
      if (mounted) {
        setState(() => _isLoading = false);
        showCustomSnackBar(context, 'حدث خطأ في جلب بيانات المستخدمين: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching current user or all names: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        showCustomSnackBar(context, 'تعذر جلب بيانات المستخدمين.', isError: true);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_currentUser == null) {
      if (mounted) {
        showCustomSnackBar(context, 'يجب تسجيل الدخول لإرسال الرسائل.', isError: true);
      }
      return;
    }
    if (_currentUserType == 'admin' && _selectedChatUserId == null) {
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء اختيار محادثة أولاً.', isError: true);
      }
      return;
    }

    String senderId = _currentUser!.uid;
    String receiverId = '';
    String receiverUserType = '';

    if (_currentUserType == 'admin') {
      receiverId = _selectedChatUserId!;
      receiverUserType = 'unknown';
    } else {
      QuerySnapshot adminSnapshot = await _firestore.collection('users').where('userType', isEqualTo: 'admin').limit(1).get();
      if (adminSnapshot.docs.isNotEmpty) {
        receiverId = adminSnapshot.docs.first.id;
        receiverUserType = 'admin';
      } else {
        if (mounted) {
          showCustomSnackBar(context, 'لا يوجد مسؤول دعم فني متاح.', isError: true);
        }
        return;
      }
    }

    try {
      await _firestore.collection('chats').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'senderType': _currentUserType,
        'receiverType': receiverUserType,
        'isRead': false,
        'chatUsers': [senderId, receiverId],
      });

      _messageController.clear();
      _scrollToBottom();
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error sending message: ${e.message}");
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في إرسال الرسالة: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند إرسال الرسالة.', isError: true);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    String appBarTitle = 'الدعم الفني';
    if (_currentUserType == 'admin') {
      if (_selectedChatUserName != null && _selectedChatUserName!.isNotEmpty) {
        appBarTitle = _selectedChatUserName!;
      } else {
        appBarTitle = 'المحادثات';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
          textAlign: TextAlign.center,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading || _currentUserType == null
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _currentUserType == 'admin' && _selectedChatUserId == null
              ? _buildAdminChatList(textTheme, colorScheme, isRtl)
              : _buildChatView(textTheme, colorScheme, isRtl),
    );
  }

  Widget _buildChatView(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) {
    String chatWithId = '';
    if (_currentUserType == 'admin') {
      chatWithId = _selectedChatUserId!;
    } else {
      chatWithId = _userNames.keys.firstWhere(
            (id) => _userNames[id] == 'مسؤول الدعم الفني' || id == 'AdminUID',
            orElse: () => '',
          );
      if (chatWithId.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent_outlined, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
              const SizedBox(height: 16),
              Text(
                'لا يوجد مسؤول دعم فني متاح حالياً.',
                style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
          ),
        );
      }
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chats')
                .where('chatUsers', arrayContains: _currentUser!.uid)
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              }
              if (snapshot.hasError) {
                debugPrint("Chat Stream Error: ${snapshot.error}");
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'حدث خطأ في جلب الرسائل: ${snapshot.error}',
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ),
                );
              }
              if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                      const SizedBox(height: 16),
                      Text(
                        'ابدأ محادثة الدعم الفني.',
                        style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ],
                  ),
                );
              }

              List<DocumentSnapshot> messages = snapshot.data!.docs.where((msg) {
                return (msg['senderId'] == _currentUser!.uid && msg['receiverId'] == chatWithId) ||
                       (msg['senderId'] == chatWithId && msg['receiverId'] == _currentUser!.uid);
              }).toList();

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد محادثات سابقة مع هذا المستخدم.',
                        style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ],
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12.0),
                reverse: false,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot messageDoc = messages[index];
                  bool isMe = messageDoc['senderId'] == _currentUser!.uid;
                  DateTime messageTime = (messageDoc['timestamp'] as Timestamp).toDate();

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: isMe ? colorScheme.primary.withAlpha(230) : colorScheme.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16.0),
                          topRight: const Radius.circular(16.0),
                          bottomLeft: isMe ? const Radius.circular(0.0) : const Radius.circular(16.0),
                          bottomRight: isMe ? const Radius.circular(16.0) : const Radius.circular(0.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          Text(
                            messageDoc['message'] ?? '',
                            style: textTheme.bodyMedium?.copyWith(
                              color: isMe ? Colors.white : colorScheme.onSurface,
                            ),
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(messageTime),
                            style: textTheme.bodySmall?.copyWith(
                              color: isMe ? Colors.white.withAlpha(178) : const Color.fromRGBO(117, 117, 117, 1),
                            ),
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildMessageInput(textTheme, colorScheme, isRtl),
      ],
    );
  }

  Widget _buildAdminChatList(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('chatUsers', arrayContains: _currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }
        if (snapshot.hasError) {
          debugPrint("Admin Chat List Stream Error: ${snapshot.error}");
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'حدث خطأ في جلب المحادثات: ${snapshot.error}',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
          );
        }
        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_outlined, size: 80, color: Color.fromRGBO(189, 189, 189, 1)),
                const SizedBox(height: 16),
                Text(
                  'لا توجد محادثات حالياً.',
                  style: textTheme.titleMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                ),
              ],
            ),
          );
        }

        final Map<String, DocumentSnapshot> latestMessagesPerUser = {};
        for (var doc in snapshot.data!.docs) {
          List<dynamic> chatUsers = doc['chatUsers'] ?? [];
          String otherUserId = chatUsers.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');
          if (otherUserId.isNotEmpty) {
            if (!latestMessagesPerUser.containsKey(otherUserId) ||
                (_latestMessagesPerUser[otherUserId]!['timestamp'] as Timestamp)
                    .compareTo(doc['timestamp'] as Timestamp) < 0) {
              latestMessagesPerUser[otherUserId] = doc;
            }
          }
        }

        final List<DocumentSnapshot> chatListDocs = latestMessagesPerUser.values.toList();
        chatListDocs.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: chatListDocs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot latestMessage = chatListDocs[index];
            List<dynamic> chatUsers = latestMessage['chatUsers'] ?? [];
            String otherUserId = chatUsers.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');
            String otherUserName = _userNames[otherUserId] ?? 'مستخدم غير معروف';
            String lastMessageContent = latestMessage['message'] ?? '...';
            DateTime lastMessageTime = (latestMessage['timestamp'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withAlpha(51),
                  child: Icon(Icons.person, color: colorScheme.primary),
                ),
                title: Text(
                  otherUserName,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                ),
                subtitle: Text(
                  lastMessageContent,
                  style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  DateFormat('HH:mm').format(lastMessageTime),
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                ),
                onTap: () {
                  setState(() {
                    _selectedChatUserId = otherUserId;
                    _selectedChatUserName = otherUserName;
                    _isLoading = true;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) {
    bool canSendMessage = _currentUserType != 'admin' || _selectedChatUserId != null;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'اكتب رسالتك هنا...',
                hintText: canSendMessage ? '' : 'اختر محادثة للبدء',
                filled: true,
                fillColor: colorScheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              ),
              maxLines: 5,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              style: textTheme.bodyMedium,
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              enabled: canSendMessage,
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: canSendMessage ? _sendMessage : null,
            backgroundColor: canSendMessage ? colorScheme.primary : const Color.fromRGBO(189, 189, 189, 1),
            mini: true,
            child: Icon(Icons.send, color: colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }
}