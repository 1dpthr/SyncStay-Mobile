class HostelReview {
  final String id;
  final String studentId;
  final String studentName;
  final String hostelId;
  final String hostelName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  HostelReview({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.hostelId,
    required this.hostelName,
    required this.rating,
    this.comment = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
