import 'package:flutter/material.dart';

import '../../../utils/payment_months.dart';

class PaymentMonthField extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  final List<String>? availableMonths;

  const PaymentMonthField({
    super.key,
    required this.value,
    required this.onChanged,
    this.availableMonths,
  });

  @override
  Widget build(BuildContext context) {
    final options = availableMonths ?? paymentMonthOptions();
    if (options.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Payment for month',
          prefixIcon: const Icon(Icons.date_range),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'All listed months are already paid',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final selected = options.contains(value) ? value : options.first;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Payment for month',
        hintText: 'Select month',
        prefixIcon: const Icon(Icons.date_range),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options
          .map((month) => DropdownMenuItem(value: month, child: Text(month)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Please select payment month' : null,
    );
  }
}
