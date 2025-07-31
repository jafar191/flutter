import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String _userRole = '';
  List<DocumentSnapshot> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchUserRole().then((_) {
        _fetchNotifications();
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc['role'] ?? '';
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _fetchNotifications() async {
    if (_currentUser == null || _userRole.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    Query query = _firestore.collection('notifications');

    if (_userRole == 'merchant') {
      query = query.where('recipientId', isEqualTo: _currentUser!.uid)
                   .where('recipientType', isEqualTo: 'merchant');
    } else if (_userRole == 'driver') {
      query = query.where('recipientId', isEqualTo: _currentUser!.uid)
                   .where('recipientType', isEqualTo: 'driver');
    } else if (_userRole == 'admin') {
      query = query.where('recipientType', isEqualTo: 'admin');
    }

    query = query.orderBy('timestamp', descending: true);

    try {
      QuerySnapshot snapshot = await query.get();
      setState(() {
        _notifications = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'read': true});
      setState(() {
        _notifications = _notifications.map((doc) {
          if (doc.id == notificationId) {
            return _createUpdatedDoc(doc, {'read': true});
          }
          return doc;
        }).toList();
      });
    } catch (e) {
      // Handle error
    }
  }

  DocumentSnapshot _createUpdatedDoc(DocumentSnapshot doc, Map<String, dynamic> newData) {
    final Map<String, dynamic> currentData = doc.data() as Map<String, dynamic>;
    return _firestore.doc(doc.reference.path).snapshots().first as DocumentSnapshot;
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد إشعارات حالياً.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    var notification = _notifications[index];
                    var data = notification.data() as Map<String, dynamic>;
                    String title = data['title'] ?? 'إشعار جديد';
                    String message = data['message'] ?? 'لا يوجد محتوى.';
                    Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
                    bool isRead = data['read'] ?? false;

                    String formattedDate = DateFormat('dd MMM yyyy - hh:mm a').format(timestamp.toDate());

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: isRead ? Colors.white : Colors.blue.shade50,
                      child: ListTile(
                        onTap: () {
                          if (!isRead) {
                            _markNotificationAsRead(notification.id);
                          }
                        },
                        leading: Icon(
                          isRead ? Icons.notifications_none : Icons.notifications_active,
                          color: isRead ? Colors.grey : Theme.of(context).primaryColor,
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRead ? Colors.grey[700] : Colors.black,
                          ),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: TextStyle(
                                color: isRead ? Colors.grey[600] : Colors.black87,
                              ),
                              textAlign: isRtl ? TextAlign.right : TextAlign.left,
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: isRtl ? Alignment.bottomLeft : Alignment.bottomRight,
                              child: Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}