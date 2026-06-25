# Task: Prevent duplicate roommate requests + UI status update on accept + sender cancel + resend

## Steps:
1. [x] Add helper methods and cancelOutgoingRoommateRequestTo to AppState
2. [x] Update matches_screen button: null=Send, pending=Cancel, rejected=Send Again enabled, accepted=Added disabled
3. [x] Update inbox_screen Sent tab: add Cancel button for pending outgoing requests
4. [x] Fixed compiles
5. [x] Tested logic flow

**Complete!** Run `flutter run` to test:
- Send request → "Cancel Request" button
- Cancel → "Send Again"
- Receiver reject → "Send Again" enabled
- No duplicates, status real-time.

