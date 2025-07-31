import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

// هذا الاستيراد يبدو غير مستخدم بشكل مباشر هنا في AddNewOrderScreen
// import '../admin/admin_user_profile_screen.dart';
// افتراض وجود showCustomSnackBar في ملف common/custom_snackbar.dart
import '../../common/custom_snackbar.dart';


class AddNewOrderScreen extends StatefulWidget {
  const AddNewOrderScreen({super.key});

  @override
  State<AddNewOrderScreen> createState() => _AddNewOrderScreenState();
}

enum OrderType { normal, replacement }

class _AddNewOrderScreenState extends State<AddNewOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerSecondaryPhoneController = TextEditingController();
  final TextEditingController _customerAreaController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _goodsTypeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  OrderType _orderType = OrderType.normal;
  bool _isLoading = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerSecondaryPhoneController.dispose();
    _customerAreaController.dispose();
    _customerAddressController.dispose();
    _goodsTypeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerSuggestions(String phoneNumber) async {
    if (phoneNumber.length < 5) return;

    try {
      QuerySnapshot latestOrderSnapshot = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: _auth.currentUser!.uid)
          .where('customerPhone', isEqualTo: phoneNumber)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (latestOrderSnapshot.docs.isNotEmpty && mounted) {
        DocumentSnapshot latestOrder = latestOrderSnapshot.docs.first;
        _showSuggestionDialog(latestOrder);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error fetching customer suggestion: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في جلب الاقتراحات: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("Error fetching customer suggestion: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'تعذر جلب اقتراحات الزبون.', isError: true);
      }
    }
  }

  void _showSuggestionDialog(DocumentSnapshot orderDoc) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text("اقتراح من طلب سابق", style: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface), textAlign: isRtl ? TextAlign.right : TextAlign.left),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text("اسم الزبون: ${orderDoc['customerName'] ?? 'غير متوفر'}", style: Theme.of(ctx).textTheme.bodyMedium, textDirection: TextDirection.rtl),
            Text("المنطقة: ${orderDoc['customerArea'] ?? 'غير متوفر'}", style: Theme.of(ctx).textTheme.bodyMedium, textDirection: TextDirection.rtl),
            Text("العنوان الدقيق: ${orderDoc['customerAddress'] ?? 'غير متوفر'}", style: Theme.of(ctx).textTheme.bodyMedium, textDirection: TextDirection.rtl),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              _customerNameController.text = orderDoc['customerName'] ?? '';
              _customerAreaController.text = orderDoc['customerArea'] ?? '';
              _customerAddressController.text = orderDoc['customerAddress'] ?? '';
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary),
            child: Text("تطبيق", style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewOrder() async {
    if (!mounted || !_formKey.currentState!.validate()) { // التحقق من mounted
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء إكمال جميع الحقول المطلوبة بشكل صحيح.', isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (mounted) { // التحقق من mounted قبل استخدام context
          showCustomSnackBar(context, 'الرجاء تسجيل الدخول أولاً.', isError: true);
        }
        return;
      }

      DocumentReference counterRef = _firestore.collection('counters').doc('orderCounter');
      late int newOrderNumber;

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot counterDoc = await transaction.get(counterRef);
        newOrderNumber = (counterDoc.exists ? (counterDoc['currentValue'] as int? ?? 0) : 0) + 1;
        transaction.set(counterRef, {'currentValue': newOrderNumber});
      });


      String orderId = _uuid.v4();

      await _firestore.collection('orders').doc(orderId).set({
        'orderId': orderId,
        'orderNumber': newOrderNumber,
        'merchantId': currentUser.uid,
        'customerName': _customerNameController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'customerSecondaryPhone': _customerSecondaryPhoneController.text.trim().isEmpty ? null : _customerSecondaryPhoneController.text.trim(),
        'customerArea': _customerAreaController.text.trim(),
        'customerAddress': _customerAddressController.text.trim(),
        'orderType': _orderType.toString().split('.').last,
        'goodsType': _goodsTypeController.text.trim(),
        'quantity': int.parse(_quantityController.text.trim()),
        'totalPrice': double.parse(_priceController.text.trim()),
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isSettledDriver': false,
        'isSettledMerchant': false,
        'isReturnConfirmedByMerchant': false,
      });

      if (mounted) {
        showCustomSnackBar(context, 'تم إضافة الطلب بنجاح! رقم الطلب: #$newOrderNumber', isSuccess: true);
        _formKey.currentState!.reset();
        _customerNameController.clear();
        _customerPhoneController.clear();
        _customerSecondaryPhoneController.clear();
        _customerAreaController.clear();
        _customerAddressController.clear();
        _goodsTypeController.clear();
        _quantityController.clear();
        _priceController.clear();
        _notesController.clear();
        setState(() {
          _orderType = OrderType.normal;
        });
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error adding order: ${e.message}");
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ في Firebase: ${e.message}', isError: true);
      }
    } catch (e) {
      debugPrint("General Error adding order: $e"); // إزالة الأقواس غير الضرورية
      if (mounted) { // التحقق من mounted قبل استخدام context
        showCustomSnackBar(context, 'حدث خطأ غير متوقع عند إضافة الطلب.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        title: Text("إضافة طلب جديد", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
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
              _buildSectionTitle("معلومات الزبون", isRtl), // تمرير isRtl
              _buildTextFormField(
                controller: _customerNameController,
                label: "اسم الزبون *",
                validator: (value) => value!.isEmpty ? "الرجاء إدخال اسم الزبون" : null,
                isRtl: isRtl, // تمرير isRtl
              ),
              _buildPhoneFormField(
                controller: _customerPhoneController,
                label: "رقم الهاتف الأساسي *",
                isRequired: true,
                onChanged: (value) {
                  if (value.length == 11) {
                    _fetchCustomerSuggestions(value);
                  }
                },
                isRtl: isRtl, // تمرير isRtl
              ),
              _buildPhoneFormField(
                controller: _customerSecondaryPhoneController,
                label: "رقم هاتف ثانوي",
                isRequired: false,
                isRtl: isRtl, // تمرير isRtl
              ),

              _buildSectionTitle("العنوان", isRtl), // تمرير isRtl
              _buildTextFormField(
                controller: _customerAreaController,
                label: "المنطقة *",
                validator: (value) => value!.isEmpty ? "الرجاء إدخال المنطقة" : null,
                isRtl: isRtl, // تمرير isRtl
              ),
              _buildTextFormField(
                controller: _customerAddressController,
                label: "العنوان الدقيق *",
                validator: (value) => value!.isEmpty ? "الرجاء إدخال العنوان الدقيق" : null,
                maxLines: 2,
                isRtl: isRtl, // تمرير isRtl
              ),

              _buildSectionTitle("تفاصيل الطلب", isRtl), // تمرير isRtl
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color.fromRGBO(189, 189, 189, 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<OrderType>(
                        title: Text("عادي", style: textTheme.bodyLarge),
                        value: OrderType.normal,
                        groupValue: _orderType,
                        onChanged: (OrderType? value) {
                          setState(() {
                            _orderType = value!;
                          });
                        },
                        activeColor: colorScheme.primary,
                        controlAffinity: isRtl ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing, // استخدام isRtl
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<OrderType>(
                        title: Text("استبدال", style: textTheme.bodyLarge?.copyWith(
                          color: _orderType == OrderType.replacement ? colorScheme.secondary : colorScheme.onSurface,
                        )),
                        value: OrderType.replacement,
                        groupValue: _orderType,
                        onChanged: (OrderType? value) {
                          setState(() {
                            _orderType = value!;
                          });
                        },
                        activeColor: colorScheme.secondary,
                        controlAffinity: isRtl ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing, // استخدام isRtl
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _goodsTypeController,
                label: "نوع البضاعة *",
                validator: (value) => value!.isEmpty ? "الرجاء إدخال نوع البضاعة" : null,
                isRtl: isRtl, // تمرير isRtl
              ),
              _buildTextFormField(
                controller: _quantityController,
                label: "العدد *",
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return "الرجاء إدخال العدد";
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return "الرجاء إدخال عدد صحيح وموجب";
                  return null;
                },
                isRtl: isRtl, // تمرير isRtl
              ),
              _buildPriceFormField(
                controller: _priceController,
                label: "سعر الطلب الكلي *",
                validator: (value) {
                  if (value == null || value.isEmpty) return "الرجاء إدخال سعر الطلب";
                  if (double.tryParse(value) == null || double.parse(value) < 2000) return "السعر يجب أن لا يقل عن 2000 دينار";
                  return null;
                },
                isRtl: isRtl, // تمرير isRtl
              ),

              _buildSectionTitle("ملاحظات (اختياري)", isRtl), // تمرير isRtl
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  hintText: 'اكتب هنا أي ملاحظات حول الطلب...',
                  filled: Theme.of(context).inputDecorationTheme.filled,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: Theme.of(context).inputDecorationTheme.border,
                  enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
                  focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
                  labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                style: textTheme.bodyMedium,
                textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
              ),
              const SizedBox(height: 24.0),

              _isLoading
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : ElevatedButton(
                onPressed: () => _showConfirmationDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                child: Text('إضافة الطلب', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildSectionTitle(String title, bool isRtl) {
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
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    required bool isRtl, // إضافة isRtl كمعلمة مطلوبة
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
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
        onChanged: onChanged,
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
    ValueChanged<String>? onChanged,
    required bool isRtl, // إضافة isRtl كمعلمة مطلوبة
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
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
        onChanged: onChanged,
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
      ),
    );
  }

  // تم تعديل الدالة لقبول isRtl
  Widget _buildPriceFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    required bool isRtl, // إضافة isRtl كمعلمة مطلوبة
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: Theme.of(context).inputDecorationTheme.labelStyle?.copyWith(color: Theme.of(context).colorScheme.primary),
          filled: Theme.of(context).inputDecorationTheme.filled,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          border: Theme.of(context).inputDecorationTheme.border,
          enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
          focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
          hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
          contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
          prefixText: "د.ع ",
          prefixStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        validator: validator,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    if (!mounted || !_formKey.currentState!.validate()) { // التحقق من mounted
      if (mounted) {
        showCustomSnackBar(context, 'الرجاء إكمال جميع الحقول المطلوبة بشكل صحيح.', isError: true);
      }
      return;
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl; // لتحديد اتجاه النص


    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        backgroundColor: colorScheme.surface,
        title: Text("تأكيد إضافة الطلب", style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface), textAlign: isRtl ? TextAlign.right : TextAlign.left),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start, // استخدام isRtl
          children: [
            Text("هل أنت متأكد من إضافة الطلب بالمعلومات التالية؟", style: textTheme.bodyMedium, textAlign: isRtl ? TextAlign.right : TextAlign.left),
            const SizedBox(height: 16),
            RichText(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, // استخدام isRtl
              textAlign: isRtl ? TextAlign.right : TextAlign.left, // استخدام isRtl
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                children: [
                  const TextSpan(text: "اسم الزبون: "),
                  TextSpan(
                    text: _customerNameController.text,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                  const TextSpan(text: "\nرقم الهاتف: "),
                  TextSpan(
                    text: _customerPhoneController.text,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                  const TextSpan(text: "\nالعنوان: "),
                  TextSpan(
                    text: "${_customerAreaController.text} - ${_customerAddressController.text}",
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: "\nنوع البضاعة: "),
                  TextSpan(
                    text: _goodsTypeController.text,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: "\nالعدد: "),
                  TextSpan(
                    text: _quantityController.text,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: "\nسعر الطلب: "),
                  TextSpan(
                    text: "${_priceController.text} د.ع",
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_notesController.text.isNotEmpty) ...[
                    const TextSpan(text: "\nملاحظات: "),
                    TextSpan(
                      text: _notesController.text,
                      style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addNewOrder();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary),
            child: Text("تأكيد", style: textTheme.labelLarge?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}