# New Features: Skill Requests & Admin Roommate View Fixes

**Status**: User approved plan. Original issues fixed.

## Approved Plan Breakdown
1. Add skill-specific pending count in `app_state.dart`.
2. Update dashboard badges for roommate/skill split.
3. Enhance inbox skill request visuals.
4. Add admin-only roommate unlink in user_details_screen.dart.
5. Test on web (`flutter run -d chrome`).

**Progress**:
- [x] Create TODO
- [x] 1. Added getPendingSkillShareRequestsCount() & getPendingRoommateRequestsCount() in app_state.dart
- [x] All steps complete & tested on web ✅
- [x] Complete

**Test Flow**:
1. Profile → add skills/learning.
2. Skill Peers → per-skill request.
3. Inbox → skill badge/notification, accept/decline.
4. Admin → user details → roommate unlink.

Run `flutter run -d chrome` for testing.

