import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'widgets/syncstay_app_bar.dart';
import '../matching_engine.dart';
import '../../models/roommate_request.dart';
import 'widgets/match_breakdown_chart.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Potential Matches'),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final matches = state.getSuggestedRoommatesForCurrentUser(topN: 10);
          final hasBookedHostel = state.getBookedHostelRequestForStudent(state.currentUser?.studentId ?? '') != null;

          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    hasBookedHostel ? 'No suggested users found.' : 'No matches yet.',
                    style: const TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasBookedHostel
                        ? 'Users appear when they share your approved hostel and 75%+ compatibility.'
                        : 'Get your hostel request approved by Admin first.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return _MatchCard(match: match, state: state);
            },
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatefulWidget {
  final StudentMatch match;
  final AppState state;

  const _MatchCard({required this.match, required this.state});

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String cleanUsername = widget.match.student.studentId.split('@')[0];
    String displayName = widget.match.student.name.isNotEmpty 
        ? widget.match.student.name 
        : cleanUsername;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: widget.match.compatibilityScore / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getScoreColor(widget.match.compatibilityScore),
                        ),
                      ),
                    ),
                    Text(
                      '${widget.match.compatibilityScore.toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _getScoreColor(widget.match.compatibilityScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/user-details',
                      arguments: widget.match.student.studentId,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: widget.match.student.isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary, size: 20),
                            ],
                          ),
                          Text(
                            'Username: $cleanUsername',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
            if (_isExpanded) ...[
              const Divider(height: 24),
              MatchBreakdownChart(match: widget.match),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Tap ▼ to see match chart & which fields align',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
            Consumer<AppState>(
              builder: (context, appState, child) {
                final status = appState.getOutgoingRoommateRequestStatusTo(widget.match.student);
                final score = widget.match.compatibilityScore;
                final alreadyMatched = appState.isAlreadyMatched(appState.currentUser?.studentId ?? '') || 
                                       appState.isAlreadyMatched(widget.match.student.studentId);
                
                if (score < 75.0) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Low Compatibility Match', 
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                String label;
                IconData icon = Icons.person_add;
                Color bgColor = const Color(0xFF03DAC6);
                Color fgColor = Colors.black;
                VoidCallback? onPressed;
                bool disabled = false;
                bool showMatchAnimation = false;

                if (alreadyMatched || status == RequestStatus.accepted) {
                  label = status == RequestStatus.accepted ? 'Roommate Confirmed ✓' : 'Already Matched';
                  icon = Icons.handshake;
                  bgColor = Colors.blue;
                  fgColor = Colors.white;
                  disabled = true;
                } else if (status == null) {
                  if (appState.canSendRoommateRequest(widget.match.student.studentId)) {
                    label = 'Send Request';
                    showMatchAnimation = true;
                    onPressed = () {
                      appState.sendRoommateRequest(widget.match.student.studentId, widget.match.compatibilityScore);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.match.compatibilityScore.toInt()}% Match – Great Compatibility! Request Sent.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    };
                  } else {
                    // This means they have a pending request FROM this student to the current user
                    // or other locking conditions
                    label = 'Check Inbox';
                    icon = Icons.mark_email_unread;
                    bgColor = Colors.orange;
                    fgColor = Colors.white;
                    disabled = true;
                  }
                } else if (status == RequestStatus.pending) {
                  label = 'Pending';
                  icon = Icons.access_time;
                  bgColor = Colors.orange;
                  fgColor = Colors.white;
                  onPressed = () {
                    appState.cancelOutgoingRoommateRequestTo(widget.match.student);
                  };
                } else {
                  label = 'Rejected - Send Again';
                  icon = Icons.refresh;
                  bgColor = Colors.red;
                  fgColor = Colors.white;
                  onPressed = () {
                    appState.sendRoommateRequest(widget.match.student.studentId, widget.match.compatibilityScore);
                  };
                }

                return Column(
                  children: [
                    if (status == null && score >= 75 && !alreadyMatched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '${score.toInt()}% Match – Great Compatibility!',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: disabled ? null : onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bgColor,
                          foregroundColor: fgColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(icon),
                        label: Text(label),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
