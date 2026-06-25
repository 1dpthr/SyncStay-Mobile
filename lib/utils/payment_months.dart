const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String paymentMonthLabel(DateTime date) => '${_monthNames[date.month - 1]} ${date.year}';

String currentPaymentMonthLabel() => paymentMonthLabel(DateTime.now());

List<String> paymentMonthOptions({int monthsBack = 2, int monthsAhead = 10}) {
  final now = DateTime.now();
  final options = <String>[];
  for (var i = -monthsBack; i <= monthsAhead; i++) {
    final d = DateTime(now.year, now.month + i);
    options.add(paymentMonthLabel(d));
  }
  return options;
}
