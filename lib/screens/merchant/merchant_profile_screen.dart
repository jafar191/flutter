import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// هذا الاستيراد غير مستخدم بشكل مباشر هنا في MerchantProfileScreen
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar و sendNotificationToAdmins في common/custom_snackbar.dart وملف آخر
import '../../common/custom_snackbar.dart';
// Future<void> sendNotificationToAdmins(...) // تأكد من توفر هذه الدالة


class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();
  final TextEditingController _personalPhoneController = TextEditingController();
  final TextEditingController _pickupAddressController = TextEditingController();
  DateTime? _dateOfBirth;

  bool _isLoading = true;
  bool _isSaving = false;


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchMerchantProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _whatsappNumberController.dispose();
    _personalPhoneController.dispose();
    _pickupAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchMerchantProfile() async {
    if (!mounted || _currentUser == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _nameController.text = userDoc['name'] as String? ?? '';
          _storeNameController.text = userDoc['storeName'] as String? ?? '';
          _whatsappNumberController.text = userDoc['whatsappNumber'] as String? ?? '';
          _personalPhoneController.text = userDoc['personalPhone'] as String? ?? '';
          _pickupAddressController.text = userDoc['pickupAddress'] as String? ?? '';
          if (userDoc['dateOfBirth'] != null) {
            _dateOfBirth = (userDoc['dateOfBirth'] as Timestamp).toDate();
          }
          _isLoading = false;
        });
      } else if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'لم يتم العثور على بيانات ملفك الشخصي.', isError: true);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching merchant profile: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ في Firebase عند جلب بيانات الملف الشخصي: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching merchant profile: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        setState(() { _isLoading = false; });
        showCustomSnackBar(context, 'حدث خطأ عند جلب بيانات الملف الشخصي.', isError: true);
      }
    }
  }

  Future<void> _updateMerchantProfile() async {
    if (!mounted || _currentUser == null) return;

    setState(() { _isSaving = true; });

    try {
      Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'storeName': _storeNameController.text.trim(),
        'whatsappNumber': _whatsappNumberController.text.trim(),
        'personalPhone': _personalPhoneController.text.trim(),
        'pickupAddress': _pickupAddressController.text.trim(),
        'dateOfBirth': _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
      };

      await _firestore.collection('users').doc(_currentUser!.uid).update(updatedData);

      // افتراض أن دالة sendNotificationToAdmins مُعرّفة ومُتاحة
      await sendNotificationToAdmins(
        _firestore,
        'تحديث في الملف الشخصي لتاجر',
        // إزالة الأقواس غير الضرورية
        'التاجر ${_nameController.text} (ID: ${_currentUser!.uid}) قام بتعديل ملفه الشخصي.',
        type: 'profile_updated',
        senderId: _currentUser!.uid,
        senderName: _nameController.text,
      );

      if (mounted) {
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
            _buildTextFormField(controller: _storeNameController, label: 'اسم المتجر', readOnly: _isSaving, isRtl: isRtl), // تمرير isRtl
            _buildPhoneFormField(controller: _whatsappNumberController, label: 'رقم الواتساب (مطلوب)', isRequired: true, readOnly: _isSaving, isRtl: isRtl), // تمرير isRtl
            _buildPhoneFormField(controller: _personalPhoneController, label: 'رقم هاتف شخصي (اختياري)', isRequired: false, readOnly: _isSaving, isRtl: isRtl), // تمرير isRtl

            _buildProfileSectionHeader("عنوان الاستلام", isRtl), // تمرير isRtl
            _buildTextFormField(controller: _pickupAddressController, label: 'عنوان الاستلام', readOnly: _isSaving, maxLines: 2, isRtl: isRtl), // تمرير isRtl

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
                    onPressed: _updateMerchantProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: Text('حفظ التعديلات', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
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
}