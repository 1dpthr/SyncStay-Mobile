import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/student.dart';
import '../../app_state.dart';

const String syncStayAppName = 'SyncStay';

String syncStaySiteLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin Site';
    case UserRole.owner:
      return 'Owner Site';
    case UserRole.warden:
      return 'Warden Site';
    case UserRole.student:
      return 'Student Site';
  }
}

/// AppBar title: SyncStay + site role (+ optional screen name).
class SyncStayAppBarTitle extends StatelessWidget {
  final String? screenTitle;
  final UserRole? role;

  const SyncStayAppBarTitle({
    super.key,
    this.screenTitle,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[];
    if (role != null) subtitleParts.add(syncStaySiteLabel(role!));
    if (screenTitle != null && screenTitle!.trim().isNotEmpty) {
      subtitleParts.add(screenTitle!.trim());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          syncStayAppName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: colorScheme.onSurface,
          ),
        ),
        if (subtitleParts.isNotEmpty)
          Text(
            subtitleParts.join(' · '),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

AppBar syncStayAppBar(
  BuildContext context, {
  String? screenTitle,
  UserRole? role,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  PreferredSizeWidget? bottom,
  Color? backgroundColor,
  double? elevation,
}) {
  final resolvedRole =
      role ?? Provider.of<AppState>(context, listen: false).currentUser?.role;

  return AppBar(
    title: SyncStayAppBarTitle(screenTitle: screenTitle, role: resolvedRole),
    actions: actions,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    bottom: bottom,
    backgroundColor: backgroundColor,
    elevation: elevation,
  );
}
