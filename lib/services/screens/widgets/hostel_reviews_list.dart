import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../../models/hostel_review.dart';
import 'hostel_review_dialog.dart';

class HostelReviewsList extends StatelessWidget {
  final String? hostelIdFilter;
  final int maxItems;

  const HostelReviewsList({super.key, this.hostelIdFilter, this.maxItems = 50});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        List<HostelReview> reviews = state.getAllHostelReviewsSorted();
        if (hostelIdFilter != null) {
          reviews = reviews.where((r) => r.hostelId == hostelIdFilter).toList();
        }
        if (maxItems > 0 && reviews.length > maxItems) {
          reviews = reviews.take(maxItems).toList();
        }

        if (reviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No hostel reviews yet.', style: TextStyle(color: Colors.grey))),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final r = reviews[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.hostelName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < r.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${r.studentName.isNotEmpty ? r.studentName : r.studentId}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (r.comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(r.comment),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class HostelReviewPromptCard extends StatelessWidget {
  const HostelReviewPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final user = state.currentUser;
        if (user == null || !state.shouldPromptHostelReview(user.studentId)) {
          return const SizedBox.shrink();
        }

        final hostelId = state.getAssignedHostelIdForStudent(user.studentId)!;
        final hostelName = state.getHostelNameById(hostelId) ?? 'Hostel';

        return Card(
          margin: const EdgeInsets.only(top: 16),
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rate_review, color: Color(0xFF6C63FF)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Share Your Hostel Experience',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You completed payment for $hostelName. Review is optional but helps other students.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => showHostelReviewPrompt(context, state),
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Write Review (Optional)'),
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
