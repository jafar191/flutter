import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// هذا الاستيراد يبدو غير مستخدم بشكل مباشر هنا في DriverProfileScreen
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar و sendNotificationToAdmins في common/custom_snackbar.dart وملف آخر
import '../../common/custom_snackbar.dart';
// Future<void> sendNotificationToAdmins(...) // تأكد من توفر هذه الدالة


class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();
  DateTime? _dateOfBirth;

  bool _isLoading = true;
  bool _isSaving = false;

  double _averageRating = 0.0;
  int _totalDeliveries = 0;
  List<DocumentSnapshot> _recentRatings = [];

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchDriverProfileAndPerformance();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchDriverProfileAndPerformance() async {
    if (!mounted || _currentUser == null) return;

    setState(() { _isLoading = true; });

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _nameController.text = userDoc['name'] as String? ?? '';
          _phoneController.text = userDoc['phone'] as String? ?? '';
          _homeAddressController.text = userDoc['homeAddress'] as String? ?? '';
          if (userDoc['dateOfBirth'] != null) {
            _dateOfBirth = (userDoc['dateOfBirth'] as Timestamp).toDate();
          }
          _averageRating = userDoc['averageRating']?.toDouble() ?? 0.0;
          _totalDeliveries = userDoc['totalDeliveries'] ?? 0;
        });
      }

      QuerySnapshot ratingsSnapshot = await _firestore.collection('ratings')
          .where('driverId', isEqualTo: _currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _recentRatings = ratingsSnapshot.docs;
          _isLoading = false;
        });
      } else { // التحقق من mounted قبل استخدام setState هنا
        setState(() { _isLoading = false; });
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching driver profile/performance: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند جلب بيانات الملف الشخصي والأداء: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching driver profile/performance: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ عند جلب بيانات الملف الشخصي والأداء.', isError: true);
      }
    }
  }

  Future<void> _updateDriverProfile() async {
    if (!mounted || _currentUser == null) return;

    setState(() { _isSaving = true; });

    try {
      Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'homeAddress': _homeAddressController.text.trim(),
        'dateOfBirth': _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
      };

      await _firestore.collection('users').doc(_currentUser!.uid).update(updatedData);

      // افتراض أن دالة sendNotificationToAdmins مُعرّفة ومُتاحة
      await sendNotificationToAdmins(
        _firestore,
        'تحديث في الملف الشخصي لمندوب',
        // إزالة الأقواس غير الضرورية
        'المندوب ${_nameController.text} (ID: ${_currentUser!.uid}) قام بتعديل ملفه الشخصي.',
        type: 'profile_updated',
        senderId: _currentUser!.uid,
        senderName: _nameController.text,
      );

      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تم تحديث الملف الشخصي بنجاح!', isSuccess: true);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error updating profile: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isSaving = false; });
        showCustomSnackBar(context, 'حدث خطأ في Firebase: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error updating profile: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isSaving = false; });
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند تحديث الملف الشخصي.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final ThemeData theme = Theme.of(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            textTheme: theme.textTheme.copyWith(
              bodyMedium: theme.textTheme.bodyMedium,
              labelLarge: theme.textTheme.labelLarge,
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth && mounted) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    if (_currentUser == null || _isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("الملف الشخصي", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("الملف الشخصي", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileSectionHeader("معلومات عامة", isRtl), // تمرير isRtl
            _buildTextFormField(controller: _nameController, label: 'الاسم', readOnly: _isSaving, isRtl: isRtl), // تمرير isRtl
            _buildPhoneFormField(controller: _phoneController, label: 'رقم الهاتف (مطلوب)', isRequired: true, readOnly: _isSaving, isRtl: isRtl), // تمرير isRtl

            _buildProfileSectionHeader("عنوان المنزل", isRtl), // تمرير isRtl
            _buildTextFormField(controller: _homeAddressController, label: 'عنوان المنزل', readOnly: _isSaving, maxLines: 2, isRtl: isRtl), // تمرير isRtl

            _buildProfileSectionHeader("تاريخ الميلاد", isRtl), // تمرير isRtl
            GestureDetector(
              onTap: _isSaving ? null : () => _selectDateOfBirth(context),
              child: AbsorbPointer(
                child: _buildTextFormField(
                  controller: TextEditingController(text: _dateOfBirth == null ? '' : DateFormat('yyyy-MM-dd').format(_dateOfBirth!)),
                  label: 'تاريخ الميلاد',
                  readOnly: true,
                  isRtl: isRtl, // تمرير isRtl
                ),
              ),
            ),

            const SizedBox(height: 24.0),
            _isSaving
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : ElevatedButton(
                    onPressed: _updateDriverProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: Text('حفظ التعديلات', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
                  ),

            const SizedBox(height: 32.0),
            _buildProfileSectionHeader("الأداء والتقييم", isRtl), // تمرير isRtl
            if (_averageRating > 0 && _averageRating <= 2.5)
              Card(
                // تصحيح استخدام withAlpha بدلًا من withOpacity
                color: Colors.red.withAlpha((255 * 0.1).round()),
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: cardTheme.elevation,
                shape: cardTheme.shape,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: colorScheme.error, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "تحذير: متوسط تقييمك الحالي هو ${_averageRating.toStringAsFixed(1)}/5. استمرار انخفاض التقييم قد يؤثر على حسابك.",
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
                          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            _buildDetailRow(context, "متوسط التقييم:", '${_averageRating.toStringAsFixed(1)} / 5', isGreen: _averageRating > 3.0, isRtl: isRtl), // تمرير isRtl
            _buildDetailRow(context, "إجمالي التوصيلات:", _totalDeliveries.toString(), isRtl: isRtl), // تمرير isRtl

            const SizedBox(height: 16.0),
            Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
              child: Text(
                "آخر التقييمات:",
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              ),
            ),
            const SizedBox(height: 8.0),
            _recentRatings.isEmpty
                ? Center(
                  child: Column(
                    children: [
                      const Icon(Icons.star_half, size: 60, color: Color.fromRGBO(189, 189, 189, 1)),
                      const SizedBox(height: 8),
                      Text('لا توجد تقييمات حديثة حالياً.', style: textTheme.bodyMedium?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)), textAlign: TextAlign.center,),
                    ],
                  ),
                )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentRatings.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot rating = _recentRatings[index];
                      String comment = rating['comment'] ?? 'لا توجد ملاحظات';
                      int stars = rating['stars'] ?? 0;
                      return Card(
                        elevation: cardTheme.elevation,
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        shape: cardTheme.shape,
                        color: cardTheme.color,
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < stars ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              );
                            }),
                          ),
                          title: Text(
                            comment.isNotEmpty ? comment : 'لا توجد ملاحظات',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                          subtitle: Text(
                            'بتاريخ: ${DateFormat('yyyy-MM-dd').format((rating['createdAt'] as Timestamp).toDate())}',
                            style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildProfileSectionHeader(String title, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Align(
        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft, // استخدام isRtl
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    required bool isRtl, // إضافة isRtl كمعلمة مطلوبة
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: Theme.of(context).inputDecorationTheme.filled,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          border: Theme.of(context).inputDecorationTheme.border,
          enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
          focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
          labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
          hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
          contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
        ),
        validator: validator,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildPhoneFormField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    bool readOnly = false,
    required bool isRtl, // إضافة isRtl كمعلمة مطلوبة
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
          filled: Theme.of(context).inputDecorationTheme.filled,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          border: Theme.of(context).inputDecorationTheme.border,
          enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
          focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
          labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
          hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
          contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'الرجاء إدخال رقم الهاتف';
          }
          if (value != null && value.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(value)) {
            return 'الرجاء إدخال أرقام فقط';
          }
          return null;
        },
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isGreen = false, required bool isRtl}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isRtl ? MainAxisAlignment.end : MainAxisAlignment.start, // استخدام isRtl
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                color: isGreen ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isGreen ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
            ),
          ),
          const SizedBox(width: 8.0),
          Text(
            label,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: const Color.fromRGBO(117, 117, 117, 1)),
            textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
          ),
        ],
      ),
    );
  }
}