import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';

/// Shows optional hostel review after payment. User can skip without submitting.
Future<void> showHostelReviewPrompt(BuildContext context, AppState state) async {
  final user = state.currentUser;
  if (user == null || !state.shouldPromptHostelReview(user.studentId)) return;

  final hostelId = state.getAssignedHostelIdForStudent(user.studentId);
  final hostelName = state.getHostelNameById(hostelId) ?? 'your hostel';
  if (hostelId == null) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _HostelReviewDialog(hostelId: hostelId, hostelName: hostelName),
  );
}

class _HostelReviewDialog extends StatefulWidget {
  final String hostelId;
  final String hostelName;

  const _HostelReviewDialog({required this.hostelId, required this.hostelName});

  @override
  State<_HostelReviewDialog> createState() => _HostelReviewDialogState();
}

class _HostelReviewDialogState extends State<_HostelReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Review ${widget.hostelName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment complete! Please share your hostel experience (optional).',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Center(
              child: FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => setState(() => _rating = i + 1),
                      icon: Icon(
                        i < _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Comments (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        OverflowBar(
          spacing: 8,
          alignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip for now'),
            ),
            FilledButton(
              onPressed: () {
                Provider.of<AppState>(context, listen: false).submitHostelReview(
                  widget.hostelId,
                  _rating,
                  _commentController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you for your review!')),
                );
              },
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ],
    );
  }
}
