import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../merchant/merchant_home_screen.dart';
import '../driver/driver_home_screen.dart';
import '../admin/admin_home_screen.dart';
// هذا الاستيراد غير مستخدم بشكل مباشر هنا في LoginScreen
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar في common/custom_snackbar.dart
import '../../common/custom_snackbar.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showCustomDialog(BuildContext context, String title, String message, IconData icon, Color color, Duration duration) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        Future.delayed(duration, () {
          if (dialogContext.mounted) { // التحقق من mounted
            Navigator.of(dialogContext).pop(true);
          }
        });
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colorScheme.surface,
          title: Column(
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 10),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
              ),
            ],
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
          ),
        );
      },
    );
  }

  Future<void> _login() async {
    if (!mounted) return; // التحقق من mounted في بداية الدالة
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) { // التحقق من mounted بعد أول await
          return;
        }

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!mounted) { // التحقق من mounted بعد ثاني await
          return;
        }

        if (userDoc.exists && userDoc['status'] == 'suspended') {
          await FirebaseAuth.instance.signOut();
          if (mounted) { // التحقق من mounted قبل استخدام context
            _showCustomDialog(
              context,
              "حسابك معلق",
              userDoc['suspension_reason'] ?? 'تم تعليق حسابك. يرجى التواصل مع الإدارة.',
              Icons.warning_amber,
              Theme.of(context).colorScheme.secondary,
              const Duration(seconds: 4),
            );
          }
          return;
        } else if (!userDoc.exists || userDoc['status'] == 'deleted') {
          await FirebaseAuth.instance.signOut();
          if (mounted) { // التحقق من mounted قبل استخدام context
            _showCustomDialog(
              context,
              "حسابك محذوف",
              "تم حذف حسابك نهائياً من النظام. لا يمكنك تسجيل الدخول.",
              Icons.error_outline,
              Theme.of(context).colorScheme.error,
              const Duration(seconds: 4),
            );
          }
          return;
        }

        if (mounted) { // التحقق من mounted قبل استخدام context و Navigator
          final userType = userDoc['userType'];
          Widget homeScreen;
          if (userType == 'merchant') {
            homeScreen = const MerchantHomeScreen();
          } else if (userType == 'driver') {
            homeScreen = const DriverHomeScreen();
          } else if (userType == 'admin') {
            homeScreen = const AdminHomeScreen();
          } else {
            homeScreen = const LoginScreen();
            await FirebaseAuth.instance.signOut();
            if (mounted) { // التحقق من mounted
              _showCustomDialog(
                context,
                "خطأ في نوع الحساب",
                "نوع حسابك غير معروف. يرجى التواصل مع الإدارة.",
                Icons.info_outline,
                Colors.grey,
                const Duration(seconds: 4),
              );
            }
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => homeScreen),
            (Route<dynamic> route) => false,
          );
        }

      } on FirebaseAuthException catch (e) {
        String message = 'حدث خطأ غير معروف.';
        Color color = Theme.of(context).colorScheme.error;

        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        } else if (e.code == 'invalid-email') {
          message = 'صيغة البريد الإلكتروني غير صحيحة.';
        } else if (e.code == 'user-disabled') {
          message = 'هذا الحساب معلق أو محذوف. يرجى التواصل مع الإدارة.';
        } else {
          message = 'خطأ في تسجيل الدخول: ${e.message}';
        }

        if (mounted) { // التحقق من mounted قبل استخدام context
          _showCustomDialog(context, "خطأ في تسجيل الدخول", message, Icons.error_outline, color, const Duration(seconds: 4));
        }
      } finally {
        if (mounted) { // التحقق من mounted
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _launchWhatsAppForAdmin() async {
    const String adminPhoneNumber = '9647855874575';
    const String message =
        "أود التواصل بخصوص حسابي في تطبيق جايك للتوصيل السريع.";
    final Uri whatsappUrl = Uri.parse(
        "whatsapp://send?phone=$adminPhoneNumber&text=${Uri.encodeComponent(message)}");

    if (!await launchUrl(whatsappUrl)) {
      if (mounted) { // التحقق من mounted
        showCustomSnackBar(context, "تعذر فتح تطبيق واتساب.", isError: true);
      }
    }
  }

  Future<void> _launchWhatsAppForRegistration() async {
    const String adminPhoneNumber = '9647855874575';
    const String message =
        "أود الانضمام لتطبيق جايك للتوصيل السريع. معلوماتي:\n\n"
        "نوع الحساب (تاجر/مندوب):\n"
        "الاسم الكامل:\n"
        "اسم المتجر (إن كنت تاجراً) أو عنوان المنزل (إن كنت مندوباً):\n"
        "رقم الواتساب الخاص بك:\n"
        "رقم هاتف شخصي (اختياري):\n"
        "تاريخ الميلاد (يوم/شهر/سنة):\n"
        "عنوان الاستلام الخاص بالمتجر (إن كنت تاجراً):\n";
    final Uri whatsappUrl = Uri.parse(
        "whatsapp://send?phone=$adminPhoneNumber&text=${Uri.encodeComponent(message)}");

    if (!await launchUrl(whatsappUrl)) {
      if (mounted) { // التحقق من mounted
        showCustomSnackBar(context, "تعذر فتح تطبيق واتساب.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص

    return Scaffold(
      appBar: AppBar(
        title: Text("تسجيل الدخول", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'lib/assets/images/jayk_logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 24),
                Text(
                  "تطبيق جايك للتوصيل السريع",
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني / اسم المستخدم',
                    prefixIcon: Icon(Icons.person, color: colorScheme.primary),
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
                    if (value == null || value.isEmpty) {
                      return 'البريد الإلكتروني / اسم المستخدم مطلوب';
                    }
                    return null;
                  },
                  style: textTheme.bodyMedium,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
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
                    if (value == null || value.isEmpty) {
                      return 'كلمة المرور مطلوبة';
                    }
                    if (value.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                  style: textTheme.bodyMedium,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                    : Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.primary.withAlpha(178)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withAlpha((255 * 0.3).round()), // withOpacity is deprecated
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _login,
                      borderRadius: BorderRadius.circular(12.0),
                      child: Center(
                        child: Text(
                          'تسجيل الدخول',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _launchWhatsAppForRegistration,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: Text(
                    'إنشاء حساب جديد؟ تواصل معنا عبر واتساب',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _launchWhatsAppForAdmin,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color.fromRGBO(117, 117, 117, 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: Text(
                    'هل تواجه مشكلة في تسجيل الدخول؟',
                    style: textTheme.bodySmall?.copyWith(color: const Color.fromRGBO(117, 117, 117, 1)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}