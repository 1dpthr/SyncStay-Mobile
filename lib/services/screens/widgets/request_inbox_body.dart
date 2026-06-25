import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/roommate_request.dart';
import '../../../models/student.dart';
import '../../app_state.dart';

enum _InboxSection { incoming, sent, history }

enum _InboxFilter { all, roommate, skill }

/// Shared inbox UI for roommate + skill learn/teach requests.
class RequestInboxBody extends StatefulWidget {
  final bool showInfoBanner;

  const RequestInboxBody({super.key, this.showInfoBanner = true});

  @override
  State<RequestInboxBody> createState() => _RequestInboxBodyState();
}

class _RequestInboxBodyState extends State<RequestInboxBody> {
  _InboxSection _section = _InboxSection.incoming;
  _InboxFilter _filter = _InboxFilter.all;

  List<RoommateRequest> _filtered(AppState state) {
    final userId = state.currentUser!.studentId;
    List<RoommateRequest> base;

    switch (_section) {
      case _InboxSection.incoming:
        base = state.getIncomingRequests();
        break;
      case _InboxSection.sent:
        base = state.getOutgoingRequests().where((r) => r.status == RequestStatus.pending).toList();
        break;
      case _InboxSection.history:
        base = state.allRequests.where((r) {
          final involved = r.senderId == userId || r.receiverId == userId;
          return involved && r.status != RequestStatus.pending;
        }).toList()
          ..sort((a, b) => (b.respondedAt ?? b.createdAt).compareTo(a.respondedAt ?? a.createdAt));
        break;
    }

    switch (_filter) {
      case _InboxFilter.all:
        return base;
      case _InboxFilter.roommate:
        return base.where((r) => r.type == RequestType.roommate).toList();
      case _InboxFilter.skill:
        return base.where((r) => r.type == RequestType.skillShare).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final requests = _filtered(state);
        final pendingCount = state.pendingIncomingRequestCount;
        final roommatePending = state.getIncomingRoommateRequests().length;
        final skillPending = state.getIncomingSkillRequests().length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showInfoBanner) ...[
              _InfoBanner(
                pendingCount: pendingCount,
                roommatePending: roommatePending,
                skillPending: skillPending,
              ),
              const SizedBox(height: 12),
            ],
            _SectionTabs(
              section: _section,
              pendingCount: pendingCount,
              onChanged: (s) => setState(() => _section = s),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FilterChips(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: requests.isEmpty
                  ? _EmptyInboxState(section: _section, filter: _filter)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final isOutgoing = req.senderId == state.currentUser!.studentId;
                        return _RequestCard(
                          request: req,
                          isOutgoing: isOutgoing,
                          state: state,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final int pendingCount;
  final int roommatePending;
  final int skillPending;

  const _InfoBanner({
    required this.pendingCount,
    required this.roommatePending,
    required this.skillPending,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inbox, color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Requests Inbox',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Yahan aapko roommate aur skill (learn / teach) ki tamam requests milti hain. '
            'Incoming tab mein Accept ya Reject karein.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CountChip(label: '$pendingCount pending', color: Colors.orange),
                if (roommatePending > 0) _CountChip(label: '$roommatePending roommate', color: scheme.primary),
                if (skillPending > 0) _CountChip(label: '$skillPending skill', color: const Color(0xFF03DAC6)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  final _InboxSection section;
  final int pendingCount;
  final ValueChanged<_InboxSection> onChanged;

  const _SectionTabs({
    required this.section,
    required this.pendingCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SectionTab(
            label: 'Incoming',
            icon: Icons.call_received,
            selected: section == _InboxSection.incoming,
            badge: pendingCount > 0 ? pendingCount : null,
            onTap: () => onChanged(_InboxSection.incoming),
          ),
          const SizedBox(width: 8),
          _SectionTab(
            label: 'Sent',
            icon: Icons.call_made,
            selected: section == _InboxSection.sent,
            onTap: () => onChanged(_InboxSection.sent),
          ),
          const SizedBox(width: 8),
          _SectionTab(
            label: 'History',
            icon: Icons.history,
            selected: section == _InboxSection.history,
            onTap: () => onChanged(_InboxSection.history),
          ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 20, color: selected ? scheme.primary : Colors.grey),
                    if (badge != null)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text(
                            '$badge',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? scheme.primary : Colors.grey,
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

class _FilterChips extends StatelessWidget {
  final _InboxFilter filter;
  final ValueChanged<_InboxFilter> onChanged;

  const _FilterChips({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All', _InboxFilter.all, Icons.all_inbox),
          const SizedBox(width: 8),
          _filterChip('Roommate', _InboxFilter.roommate, Icons.people),
          const SizedBox(width: 8),
          _filterChip('Skill', _InboxFilter.skill, Icons.school),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _InboxFilter value, IconData icon) {
    final selected = filter == value;
    return FilterChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (_) => onChanged(value),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  final _InboxSection section;
  final _InboxFilter filter;

  const _EmptyInboxState({required this.section, required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    switch (section) {
      case _InboxSection.incoming:
        message = filter == _InboxFilter.skill
            ? 'Koi skill learn/teach request nahi aayi.\nSkills tab se partners ko request bhejein.'
            : filter == _InboxFilter.roommate
                ? 'Koi roommate request nahi aayi.\nRoommates tab se request bhejein.'
                : 'Koi incoming request nahi.\nRoommate ya skill requests yahan dikhengi.';
      case _InboxSection.sent:
        message = 'Aap ne abhi koi pending request nahi bheji.';
      case _InboxSection.history:
        message = 'Abhi koi accepted ya rejected request nahi.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RoommateRequest request;
  final bool isOutgoing;
  final AppState state;

  const _RequestCard({
    required this.request,
    required this.isOutgoing,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isSkill = request.type == RequestType.skillShare;
    final profileId = isOutgoing ? request.receiverId : request.senderId;
    final displayName = isOutgoing
        ? (request.receiverName.isNotEmpty ? request.receiverName : request.receiverId.split('@')[0])
        : (request.senderName.isNotEmpty ? request.senderName : request.senderId.split('@')[0]);

    final typeColor = isSkill ? const Color(0xFF03DAC6) : Theme.of(context).colorScheme.primary;
    final typeLabel = isSkill ? 'Skill Exchange' : 'Roommate';
    final isPending = request.status == RequestStatus.pending;

    Student? otherStudent;
    try {
      otherStudent = state.allStudents.firstWhere((s) => s.studentId == profileId);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: isPending ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: typeColor.withValues(alpha: 0.2),
                  child: Icon(isSkill ? Icons.school : Icons.people, color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isOutgoing ? 'To: $displayName' : 'From: $displayName',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          _TypeBadge(label: typeLabel, color: typeColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSkill
                            ? 'Skill: "${request.skillName ?? '—'}"'
                            : 'Compatibility: ${request.compatibilityScore.toInt()}%',
                        style: TextStyle(fontWeight: FontWeight.w600, color: typeColor, fontSize: 13),
                      ),
                      if (!isSkill && otherStudent != null)
                        Text(
                          'Gender: ${otherStudent.gender} • Pref: ${otherStudent.preferredSharing}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (!isPending) ...[
                        const SizedBox(height: 6),
                        _StatusBadge(status: request.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (isPending && !isOutgoing) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        state.approveRoommateRequest(request.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${isSkill ? 'Skill' : 'Roommate'} request accepted!')),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.rejectRoommateRequest(request.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request rejected.')),
                        );
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
            if (isPending && isOutgoing) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    state.rejectRoommateRequest(request.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request cancelled.')),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Request'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/user-details', arguments: profileId),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('View Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == RequestStatus.accepted ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
