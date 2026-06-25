enum PaymentStatus { pending, paid, failed, confirmed }

enum PaymentKind { studentRoom, wardenHostel }

extension PaymentStatusX on PaymentStatus {
  String get displayLabel {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.confirmed:
        return 'Confirmed';
    }
  }

  bool get isSettled => this == PaymentStatus.paid || this == PaymentStatus.confirmed;
}

extension PaymentKindX on PaymentKind {
  String get displayLabel {
    switch (this) {
      case PaymentKind.studentRoom:
        return 'Room Rent';
      case PaymentKind.wardenHostel:
        return 'Hostel Fee';
    }
  }
}

extension PaymentX on Payment {
  bool get isSettled => status.isSettled;

  String get statusLabel => status.displayLabel;

  String get kindLabel => kind.displayLabel;
}

class Payment {
  final String paymentId;
  final String userId;
  final String roomId;
  final double amount;
  final String paymentMethod;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? cardLast4Digits;
  final PaymentKind kind;
  final String? hostelId;
  final double? adminShare;
  final double? ownerShare;
  final String? ownerId;
  final String? paymentMonth;

  Payment({
    required this.paymentId,
    required this.userId,
    required this.roomId,
    required this.amount,
    required this.paymentMethod,
    this.status = PaymentStatus.pending,
    this.cardLast4Digits,
    DateTime? timestamp,
    this.kind = PaymentKind.studentRoom,
    this.hostelId,
    this.adminShare,
    this.ownerShare,
    this.ownerId,
    this.paymentMonth,
  }) : timestamp = timestamp ?? DateTime.now();

  Payment copyWith({
    PaymentStatus? status,
    String? paymentMonth,
  }) {
    return Payment(
      paymentId: paymentId,
      userId: userId,
      roomId: roomId,
      amount: amount,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      timestamp: timestamp,
      cardLast4Digits: cardLast4Digits,
      kind: kind,
      hostelId: hostelId,
      adminShare: adminShare,
      ownerShare: ownerShare,
      ownerId: ownerId,
      paymentMonth: paymentMonth ?? this.paymentMonth,
    );
  }
}
