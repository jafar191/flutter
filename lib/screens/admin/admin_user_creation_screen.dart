import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// هذا الاستيراد غير مستخدم بشكل مباشر هنا في AdminUserCreationScreen
// import 'admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar في ملف common/custom_snackbar.dart
import '../../common/custom_snackbar.dart';


class AdminUserCreationScreen extends StatefulWidget {
  final String userTypeToCreate;

  const AdminUserCreationScreen({super.key, required this.userTypeToCreate});

  @override
  State<AdminUserCreationScreen> createState() => _AdminUserCreationScreenState();
}

class _AdminUserCreationScreenState extends State<AdminUserCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  DateTime? _dateOfBirth;

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _whatsappNumberController = TextEditingController();
  final TextEditingController _personalPhoneController = TextEditingController();
  final TextEditingController _pickupAddressController = TextEditingController();

  final TextEditingController _homeAddressController = TextEditingController();

  final TextEditingController _adminAddressController = TextEditingController();
  final TextEditingController _adminDetailsController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _storeNameController.dispose();
    _whatsappNumberController.dispose();
    _personalPhoneController.dispose();
    _pickupAddressController.dispose();
    _homeAddressController.dispose();
    _adminAddressController.dispose();
    _adminDetailsController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    // تم إضافة التحقق من mounted قبل استخدام context
    if (!mounted || !_formKey.currentState!.validate()) {
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء إكمال جميع الحقول المطلوبة بشكل صحيح.', isError: true);
      }
      return;
    }

    setState(() { _isLoading = true; });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'userType': widget.userTypeToCreate,
        'dateOfBirth': _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.userTypeToCreate == 'merchant') {
        userData['storeName'] = _storeNameController.text.trim();
        userData['whatsappNumber'] = _whatsappNumberController.text.trim();
        userData['personalPhone'] = _personalPhoneController.text.trim();
        userData['pickupAddress'] = _pickupAddressController.text.trim();
      } else if (widget.userTypeToCreate == 'driver') {
        userData['homeAddress'] = _homeAddressController.text.trim();
        userData['averageRating'] = 0.0;
        userData['totalDeliveries'] = 0;
      } else if (widget.userTypeToCreate == 'admin') {
        userData['address'] = _adminAddressController.text.trim();
        userData['details'] = _adminDetailsController.text.trim();
      }

      await _firestore.collection('users').doc(uid).set(userData);

      if (mounted) {
        showCustomSnackBar(
          context,
          'تم إنشاء حساب ${widget.userTypeToCreate == 'merchant' ? 'التاجر' : widget.userTypeToCreate == 'driver' ? 'المندوب' : 'المسؤول'} بنجاح!',
          isSuccess: true,
        );
        Navigator.pop(context, true);
      }

    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ في المصادقة.';
      if (e.code == 'email-already-in-use') {
        message = 'هذا البريد الإلكتروني مستخدم بالفعل.';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً. يجب أن تكون 6 أحرف على الأقل.';
      } else if (e.code == 'invalid-email') {
        message = 'صيغة البريد الإلكتروني غير صحيحة.';
      }
      if (mounted) { // تم إضافة الأقواس المتعرجة
        showCustomSnackBar(context, 'خطأ: $message', isError: true); // إزالة الأقواس
      }
    } catch (e) {
      debugPrint("General Error creating user: $e"); // إزالة الأقواس
      if (mounted) { // تم إضافة الأقواس المتعرجة
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند إنشاء الحساب.', isError: true);
      }
    } finally {
      if (mounted) { // تم إضافة الأقواس المتعرجة
        setState(() { _isLoading = false; });
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

    String appBarTitle = '';
    if (widget.userTypeToCreate == 'merchant') {
      appBarTitle = 'إنشاء تاجر جديد';
    } else if (widget.userTypeToCreate == 'driver') {
      appBarTitle = 'إنشاء مندوب جديد';
    } else if (widget.userTypeToCreate == 'admin') {
      appBarTitle = 'إنشاء مسؤول جديد';
    } else {
      appBarTitle = 'إنشاء مستخدم جديد';
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
          textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader("معلومات تسجيل الدخول", isRtl), // تمرير isRtl
              _buildTextFormField(
                controller: _emailController,
                label: 'البريد الإلكتروني *',
                validator: (value) {
                  if (value == null || value.isEmpty) return 'البريد الإلكتروني مطلوب';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'صيغة البريد الإلكتروني غير صحيحة';
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
                isRtl: isRtl, // تمرير isRtl
              ),
              _buildTextFormField(
                controller: _passwordController,
                label: 'كلمة المرور *',
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
                isRtl: isRtl, // تمرير isRtl
              ),

              _buildSectionHeader("معلومات عامة", isRtl), // تمرير isRtl
              _buildTextFormField(
                  controller: _nameController,
                  label: 'الاسم الكامل *',
                  validator: (value) => value!.isEmpty ? 'الاسم مطلوب' : null,
                  isRtl: isRtl // تمرير isRtl
              ),
              _buildPhoneFormField(controller: _phoneController, label: 'رقم الهاتف *', isRequired: true, isRtl: isRtl), // تمرير isRtl
              GestureDetector(
                onTap: () => _selectDateOfBirth(context),
                child: AbsorbPointer(
                  child: _buildTextFormField(
                    controller: TextEditingController(text: _dateOfBirth == null ? '' : DateFormat('yyyy-MM-dd').format(_dateOfBirth!)),
                    label: 'تاريخ الميلاد *',
                    readOnly: true,
                    isRtl: isRtl, // تمرير isRtl
                  ),
                ),
              ),

              if (widget.userTypeToCreate == 'merchant') ...[
                _buildSectionHeader("معلومات المتجر", isRtl), // تمرير isRtl
                _buildTextFormField(
                    controller: _storeNameController,
                    label: 'اسم المتجر *',
                    validator: (value) => value!.isEmpty ? 'اسم المتجر مطلوب' : null,
                    isRtl: isRtl // تمرير isRtl
                ),
                _buildPhoneFormField(controller: _whatsappNumberController, label: 'رقم الواتساب *', isRequired: true, isRtl: isRtl), // تمرير isRtl
                _buildPhoneFormField(controller: _personalPhoneController, label: 'رقم هاتف شخصي (اختياري)', isRtl: isRtl), // تمرير isRtl
                _buildTextFormField(
                    controller: _pickupAddressController,
                    label: 'عنوان الاستلام *',
                    validator: (value) => value!.isEmpty ? 'عنوان الاستلام مطلوب' : null,
                    isRtl: isRtl // تمرير isRtl
                ),
              ],
              if (widget.userTypeToCreate == 'driver') ...[
                _buildSectionHeader("معلومات المنزل", isRtl), // تمرير isRtl
                _buildTextFormField(
                    controller: _homeAddressController,
                    label: 'عنوان المنزل *',
                    validator: (value) => value!.isEmpty ? 'عنوان المنزل مطلوب' : null,
                    isRtl: isRtl // تمرير isRtl
                ),
              ],
              if (widget.userTypeToCreate == 'admin') ...[
                _buildSectionHeader("تفاصيل المسؤول", isRtl), // تمرير isRtl
                _buildTextFormField(
                    controller: _adminAddressController,
                    label: 'عنوان المسؤول *',
                    validator: (value) => value!.isEmpty ? 'عنوان المسؤول مطلوب' : null,
                    isRtl: isRtl // تمرير isRtl
                ),
                _buildTextFormField(controller: _adminDetailsController, label: 'تفاصيل المسؤول (اختياري)', isRtl: isRtl), // تمرير isRtl
              ],

              const SizedBox(height: 24.0),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : ElevatedButton(
                onPressed: _createUser,
                // The 'child' argument should be last in widget constructor invocations.
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                child: Text('إنشاء الحساب', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildSectionHeader(String title, bool isRtl) {
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
    bool obscureText = false,
    bool readOnly = false,
    int maxLines = 1,
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
        obscureText: obscureText,
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