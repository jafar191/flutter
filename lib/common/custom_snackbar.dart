import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // محتاجينها عشان FirebaseAuth في sendNotificationToAdmins

// دي دالة showCustomSnackBar
void showCustomSnackBar(BuildContext context, String message, {bool isError = false, bool isSuccess = false}) {
  Color backgroundColor = const Color.fromRGBO(85, 85, 85, 1);
  IconData icon = Icons.info_outline;

  // تأكد إن الـ context لسه موجود (mounted) قبل ما تستخدمه لـ Theme.of(context)
  if (!context.mounted) return;

  if (isError) {
    backgroundColor = Theme.of(context).colorScheme.error;
    icon = Icons.error_outline;
  } else if (isSuccess) {
    backgroundColor = Theme.of(context).colorScheme.primary;
    icon = Icons.check_circle_outline;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              // استخدم Directionality عشان تحدد اتجاه النص للـ Snackbar لو محتاج
              textDirection: Directionality.of(context),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}

// دي دالة sendNotificationToAdmins
Future<void> sendNotificationToAdmins(
    FirebaseFirestore firestore,
    String title,
    String body, {
    String type = 'general_info',
    String? relatedOrderId,
    String? relatedSettlementId,
    String? senderId,
    String? senderName,
}) async {
  try {
    QuerySnapshot adminUsersSnapshot = await firestore
        .collection('users')
        .where('userType', isEqualTo: 'admin')
        .get();

    WriteBatch batch = firestore.batch();
    for (var doc in adminUsersSnapshot.docs) {
      batch.set(firestore.collection('notifications').doc(), {
        'userId': doc.id,
        'userTypeTarget': 'admin',
        'title': title,
        'body': body,
        'type': type,
        'relatedOrderId': relatedOrderId,
        'relatedSettlementId': relatedSettlementId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': senderId,
        'senderName': senderName,
      });
    }
    await batch.commit();
    debugPrint("Notification sent to all admins: $title");
  } on FirebaseException catch (e) {
    debugPrint("Firebase Error sending notification to admins: ${e.message}");
  } catch (e) {
    debugPrint("General Error sending notification to admins: $e");
  }
}