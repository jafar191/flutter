import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../common/custom_snackbar.dart';

class AdminAdsNotificationsScreen extends StatefulWidget {
  const AdminAdsNotificationsScreen({super.key});

  @override
  State<AdminAdsNotificationsScreen> createState() => _AdminAdsNotificationsScreenState();
}

class _AdminAdsNotificationsScreenState extends State<AdminAdsNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<DocumentSnapshot> _ads = [];
  XFile? _pickedImage;
  bool _isUploadingAd = false;

  final TextEditingController _notificationTitleController = TextEditingController();
  final TextEditingController _notificationBodyController = TextEditingController();
  String _notificationTarget = 'all';
  String? _specificUserId;
  List<DocumentSnapshot> _allUsers = [];
  bool _isSendingNotification = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAds();
    _fetchAllUsersForNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    super.dispose();
  }

  Future<void> _fetchAds() async {
    try {
      QuerySnapshot adsSnapshot = await _firestore.collection('ads')
          .orderBy('order', descending: false)
          .get();

      if (mounted) {
        setState(() => _ads = adsSnapshot.docs);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء جلب الإعلانات: ${e.message}', isError: true);
      }
      debugPrint("Firebase Error fetching ads: ${e.message}");
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'تعذر جلب الإعلانات', isError: true);
      }
      debugPrint("Error fetching ads: $e");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() => _pickedImage = image);
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ أثناء اختيار الصورة: $e', isError: true);
      }
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _uploadAd() async {
    if (_pickedImage == null) {
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء اختيار صورة للإعلان أولاً', isError: true);
      }
      return;
    }

    setState(() => _isUploadingAd = true);

    try {
      final String fileName = 'ads/${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.name}';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(File(_pickedImage!.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String imageUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('ads').add({
        'imageUrl': imageUrl,
        'isActive': true,
        'order': _ads.length + 1,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': _auth.currentUser?.uid,
      });

      if (mounted) {
        setState(() => _pickedImage = null);
        _fetchAds();
        showCustomSnackBar(context, 'تم رفع الإعلان بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء رفع الإعلان: ${e.message}', isError: true);
      }
      debugPrint("Firebase Error uploading ad: ${e.message}");
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ أثناء رفع الإعلان', isError: true);
      }
      debugPrint("Error uploading ad: $e");
    } finally {
      if (mounted) setState(() => _isUploadingAd = false);
    }
  }

  Future<void> _toggleAdStatus(DocumentSnapshot adDoc) async {
    try {
      await adDoc.reference.update({'isActive': !(adDoc['isActive'] ?? false)});
      _fetchAds();
      if (mounted) {
        showCustomSnackBar(context, 'تم تغيير حالة الإعلان بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء تغيير حالة الإعلان: ${e.message}', isError: true);
      }
      debugPrint("Firebase Error toggling ad status: ${e.message}");
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'تعذر تغيير حالة الإعلان', isError: true);
      }
      debugPrint("Error toggling ad status: $e");
    }
  }

  Future<void> _deleteAd(DocumentSnapshot adDoc) async {
    setState(() => _isUploadingAd = true);
    try {
      if (adDoc['imageUrl'] != null && (adDoc['imageUrl'] as String).isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(adDoc['imageUrl'] as String).delete();
      }
      await adDoc.reference.delete();
      _fetchAds();
      if (mounted) {
        showCustomSnackBar(context, 'تم حذف الإعلان بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء حذف الإعلان: ${e.message}', isError: true);
      }
      debugPrint("Firebase Error deleting ad: ${e.message}");
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'تعذر حذف الإعلان', isError: true);
      }
      debugPrint("Error deleting ad: $e");
    } finally {
      if (mounted) setState(() => _isUploadingAd = false);
    }
  }

  Future<void> _fetchAllUsersForNotifications() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      if (mounted) setState(() => _allUsers = usersSnapshot.docs);
    } catch (e) {
      debugPrint("Error fetching users for notifications: $e");
    }
  }

  Future<void> _sendNotification() async {
    if (_notificationTitleController.text.trim().isEmpty ||
        _notificationBodyController.text.trim().isEmpty) {
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء إدخال عنوان ومحتوى الإشعار', isError: true);
      }
      return;
    }
    if (_notificationTarget == 'specific_user' && _specificUserId == null) {
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء اختيار مستخدم محدد لإرسال الإشعار إليه.', isError: true);
      }
      return;
    }

    setState(() => _isSendingNotification = true);

    try {
      List<String> targetUids = [];

      if (_notificationTarget == 'specific_user' && _specificUserId != null) {
        targetUids.add(_specificUserId!);
      } else {
        Query query = _firestore.collection('users');
        if (_notificationTarget == 'merchant') {
          query = query.where('userType', isEqualTo: 'merchant');
        } else if (_notificationTarget == 'driver') {
          query = query.where('userType', isEqualTo: 'driver');
        }
        final snapshot = await query.get();
        targetUids = snapshot.docs.map((doc) => doc.id).toList();
      }

      final batch = _firestore.batch();
      for (String uid in targetUids) {
        batch.set(_firestore.collection('notifications').doc(), {
          'userId': uid,
          'userTypeTarget': _notificationTarget,
          'title': _notificationTitleController.text.trim(),
          'body': _notificationBodyController.text.trim(),
          'type': 'admin_message',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'sentByAdminId': _auth.currentUser?.uid,
        });
      }
      await batch.commit();

      if (mounted) {
        _notificationTitleController.clear();
        _notificationBodyController.clear();
        setState(() {
          _notificationTarget = 'all';
          _specificUserId = null;
        });
        showCustomSnackBar(context, 'تم إرسال الإشعار بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ في Firebase أثناء إرسال الإشعار: ${e.message}', isError: true);
      }
      debugPrint("Firebase Error sending notification: ${e.message}");
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'حدث خطأ أثناء إرسال الإشعار', isError: true);
      }
      debugPrint("Error sending notification: $e");
    } finally {
      if (mounted) setState(() => _isSendingNotification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "إدارة الإعلانات والإشعارات",
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: const Color.fromRGBO(117, 117, 117, 1),
          labelStyle: textTheme.labelLarge,
          unselectedLabelStyle: textTheme.labelMedium,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: "الإعلانات"),
            Tab(icon: Icon(Icons.send), text: "الإشعارات"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAdManagementTab(textTheme, colorScheme, isRtl),
          _buildSendNotificationTab(textTheme, colorScheme, isRtl),
        ],
      ),
    );
  }

  Widget _buildAdManagementTab(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) {
    final cardTheme = Theme.of(context).cardTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            'رفع إعلان جديد',
            style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 16),
          _pickedImage == null
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('اختيار صورة للإعلان', style: textTheme.labelLarge),
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : Card(
                  elevation: cardTheme.elevation,
                  shape: cardTheme.shape,
                  color: cardTheme.color,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Image.file(
                          File(_pickedImage!.path),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() => _pickedImage = null),
                                child: Text('إلغاء', style: textTheme.labelLarge?.copyWith(color: colorScheme.error)),
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _isUploadingAd
                                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                  : ElevatedButton(
                                      onPressed: _uploadAd,
                                      child: Text('رفع الإعلان', style: textTheme.labelLarge),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 30),
          Text(
            'الإعلانات الموجودة',
            style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 16),
          _ads.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      const Icon(Icons.image_not_supported_outlined, size: 60, color: Color.fromRGBO(189, 189, 189, 1)),
                      const SizedBox(height: 8),
                      Text('لا توجد إعلانات حالياً.', style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1))),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ads.length,
                  itemBuilder: (context, index) {
                    final ad = _ads[index];
                    return Card(
                      elevation: cardTheme.elevation,
                      shape: cardTheme.shape,
                      color: cardTheme.color,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                ad['imageUrl'] as String,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 150,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 50, color: Color.fromRGBO(189, 189, 189, 1)),
                                  ),
                                ),
                                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 150,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!.toDouble()
                                            : null,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            ListTile(
                              title: Text('الإعلان ${index + 1}',
                                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      ad['isActive'] ? Icons.visibility : Icons.visibility_off,
                                      color: ad['isActive'] ? colorScheme.primary : Colors.grey,
                                    ),
                                    onPressed: () => _toggleAdStatus(ad),
                                    tooltip: ad['isActive'] ? 'إخفاء الإعلان' : 'إظهار الإعلان',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: colorScheme.error),
                                    onPressed: () => _deleteAd(ad),
                                    tooltip: 'حذف الإعلان',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSendNotificationTab(TextTheme textTheme, ColorScheme colorScheme, bool isRtl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            'إرسال إشعار جديد',
            style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notificationTitleController,
            decoration: InputDecoration(
              labelText: 'عنوان الإشعار',
              hintText: 'مثال: تحديث هام، عروض جديدة',
              filled: true,
              fillColor: colorScheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: textTheme.bodyMedium,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notificationBodyController,
            decoration: InputDecoration(
              labelText: 'محتوى الإشعار',
              hintText: 'اكتب رسالتك هنا...',
              filled: true,
              fillColor: colorScheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 5,
            style: textTheme.bodyMedium,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
          const SizedBox(height: 20),
          Text(
            'إرسال إلى:',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: RadioListTile<String>(
                  title: Text('جميع المستخدمين', style: textTheme.bodyLarge),
                  value: 'all',
                  groupValue: _notificationTarget,
                  onChanged: (String? value) => setState(() {
                    _notificationTarget = value!;
                    _specificUserId = null;
                  }),
                  activeColor: colorScheme.primary,
                  controlAffinity: isRtl ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing,
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: RadioListTile<String>(
                  title: Text('التجار', style: textTheme.bodyLarge),
                  value: 'merchant',
                  groupValue: _notificationTarget,
                  onChanged: (String? value) => setState(() {
                    _notificationTarget = value!;
                    _specificUserId = null;
                  }),
                  activeColor: colorScheme.primary,
                  controlAffinity: isRtl ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing,
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: RadioListTile<String>(
                  title: Text('المندوبين', style: textTheme.bodyLarge),
                  value: 'driver',
                  groupValue: _notificationTarget,
                  onChanged: (String? value) => setState(() {
                    _notificationTarget = value!;
                    _specificUserId = null;
                  }),
                  activeColor: colorScheme.primary,
                  controlAffinity: isRtl ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing,
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: RadioListTile<String>(
                  title: Text('مستخدم محدد', style: textTheme.bodyLarge),
                  value: 'specific_user',
                  groupValue: _notificationTarget,
                  onChanged: (String? value) => setState(() {
                    _notificationTarget = value!;
                  }),
                  activeColor: colorScheme.primary,
                  controlAffinity: isRtl ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing,
                ),
              ),
            ],
          ),
          if (_notificationTarget == 'specific_user')
            Column(
              children: [
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _specificUserId,
                  items: _allUsers.map((user) {
                    final String userName = user['name'] ?? user['storeName'] ?? 'مستخدم غير معروف';
                    return DropdownMenuItem<String>(
                      value: user.id,
                      child: Text(userName, style: textTheme.bodyMedium, textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr),
                    );
                  }).toList(),
                  onChanged: (String? value) => setState(() => _specificUserId = value),
                  decoration: InputDecoration(
                    labelText: 'اختر مستخدم',
                    hintText: 'ابحث عن مستخدم...',
                    filled: true,
                    fillColor: colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: textTheme.bodyMedium,
                  isExpanded: true,
                  menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
              ],
            ),
          const SizedBox(height: 20),
          _isSendingNotification
              ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
              : ElevatedButton(
                  onPressed: _sendNotification,
                  child: Text('إرسال الإشعار', style: textTheme.labelLarge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ],
      ),
    );
  }
}