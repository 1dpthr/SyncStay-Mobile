import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../app_state.dart';
import 'widgets/hostel_review_dialog.dart';
import 'widgets/payment_month_field.dart';
import 'widgets/syncstay_app_bar.dart';
import '../../utils/payment_months.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isProcessing = false;
  late String _selectedPaymentMonth;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMonth = currentPaymentMonthLabel();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      final state = Provider.of<AppState>(context, listen: false);
      final screenContext = context;
      String last4 = _cardNumberController.text.substring(_cardNumberController.text.length - 4);
      final error = state.makePayment(
        'Credit Card',
        cardLast4Digits: last4,
        paymentMonth: _selectedPaymentMonth,
      );
      
      setState(() => _isProcessing = false);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Success',
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (dialogContext, anim1, anim2) {
          return Center(
            child: FadeInScale(
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Column(
                  children: [
                    BounceInDown(child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80)),
                    const SizedBox(height: 16),
                    const Text('Payment Successful', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text(
                  'Your payment for $_selectedPaymentMonth has been processed successfully.\nRoom assignment is now confirmed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await showHostelReviewPrompt(screenContext, state);
                        if (screenContext.mounted) Navigator.pop(screenContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Go to Dashboard'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) return 'Please enter card number';
    if (value.length != 16 || int.tryParse(value) == null) {
      return 'Card number must be exactly 16 digits';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) return 'Please enter expiry date';
    final parts = value.split('/');
    if (parts.length != 2) return 'Format MM/YY';
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    
    if (month == null || year == null || month < 1 || month > 12) {
      return 'Invalid date format';
    }
    
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return 'Card has expired';
    }
    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) return 'Please enter CVV';
    if (value.length != 3 || int.tryParse(value) == null) {
      return 'CVV must be exactly 3 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final user = state.currentUser!;
        if (user.assignedRoomId == null) {
          return Scaffold(
            appBar: syncStayAppBar(context, screenTitle: 'Complete Payment', elevation: 0),
            body: const Center(child: Text('No room assigned for payment.')),
          );
        }
        final room = state.allRooms.firstWhere((r) => r.roomId == user.assignedRoomId);
        final amount = room.calculateTotalPrice();
        final availableMonths = state.getAvailablePaymentMonthsForStudent(user.studentId);
        if (!availableMonths.contains(_selectedPaymentMonth) && availableMonths.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedPaymentMonth = availableMonths.first);
          });
        }

    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Complete Payment', elevation: 0),
      body: _isProcessing 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(strokeWidth: 6),
                const SizedBox(height: 24),
                FadeIn(
                  duration: const Duration(seconds: 1),
                  child: const Text('Processing your payment...', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: const Text('Payment Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _summaryRow('Room ID', room.roomId),
                          _summaryRow('Category', room.roomType.toUpperCase()),
                          _summaryRow('Location', room.location),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(),
                          ),
                          _summaryRow('Total Amount', 'Rs. ${amount.toInt()}', isBold: true),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInDown(
                  delay: const Duration(milliseconds: 400),
                  child: const Text('Payment Period', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PaymentMonthField(
                          value: _selectedPaymentMonth,
                          availableMonths: availableMonths,
                          onChanged: (month) {
                            if (month != null) setState(() => _selectedPaymentMonth = month);
                          },
                        ),
                        const SizedBox(height: 32),
                        const Text('Card Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cardNumberController,
                          keyboardType: TextInputType.number,
                          maxLength: 16,
                          decoration: InputDecoration(
                            labelText: 'Card Number',
                            hintText: '1234567890123456',
                            prefixIcon: const Icon(Icons.credit_card),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: _validateCardNumber,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _expiryDateController,
                                keyboardType: TextInputType.datetime,
                                maxLength: 5,
                                decoration: InputDecoration(
                                  labelText: 'Expiry Date',
                                  hintText: 'MM/YY',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: _validateExpiry,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _cvvController,
                                keyboardType: TextInputType.number,
                                maxLength: 3,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'CVV',
                                  hintText: '123',
                                  prefixIcon: const Icon(Icons.security),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: _validateCVV,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: availableMonths.isEmpty ? null : _handlePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
                      ),
                      child: Text('Confirm Payment', 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
      },
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: isBold ? 20 : 14,
                color: isBold ? const Color(0xFF6C63FF) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FadeInScale extends StatefulWidget {
  final Widget child;
  const FadeInScale({super.key, required this.child});

  @override
  State<FadeInScale> createState() => _FadeInScaleState();
}

class _FadeInScaleState extends State<FadeInScale> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: Transform.scale(scale: _scale.value, child: widget.child)),
    );
  }
}
