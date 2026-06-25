import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'supabase_config.dart';
import 'services/app_state.dart';
import 'services/screens/login_screen.dart';
import 'services/screens/signup_screen.dart';
import 'services/screens/main_navigation_screen.dart';
import 'services/screens/profile_screen.dart';
import 'services/screens/matches_screen.dart';
import 'services/screens/inbox_screen.dart';
import 'services/screens/admin_dashboard.dart';
import 'services/screens/warden_dashboard.dart';
import 'services/screens/room_details_screen.dart';
import 'services/screens/user_details_screen.dart';
import 'services/screens/skill_peers_screen.dart';

import 'services/screens/payment_screen.dart';
import 'services/screens/warden_payment_screen.dart';
import 'services/screens/admin_users_screen.dart';
import 'services/screens/admin_rooms_screen.dart';
import 'services/screens/admin_payments_screen.dart';
import 'services/screens/admin_requests_screen.dart';
import 'services/screens/admin_analytics_screen.dart';
import 'services/screens/admin_misc_screens.dart';
import 'services/screens/owner_dashboard_screen.dart';
import 'services/screens/district_admin_dashboard.dart';
import 'services/screens/add_hostel_screen.dart';
import 'services/screens/hostel_request_form_screen.dart';
import 'services/screens/hostel_requests_screen.dart';
import 'services/screens/payment_history_screen.dart';
import 'services/screens/blocked_account_screen.dart';
import 'services/screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }
  final appState = AppState();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const MyApp(),
    ),
  );
  unawaited(appState.initialize());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        return MaterialApp(
          title: 'SyncStay',
          debugShowCheckedModeBanner: false,
          themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/dashboard': (context) => const MainNavigationScreen(),
            '/blocked-account': (context) => const BlockedAccountScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/matches': (context) => const MatchesScreen(),
            '/skill-peers': (context) => const SkillPeersScreen(),
            '/inbox': (context) => const InboxScreen(),
            '/admin': (context) => const AdminDashboard(),
            '/admin-dashboard': (context) => const AdminDashboard(),
            '/warden-dashboard': (context) => const WardenDashboard(),
            '/warden': (context) => const WardenDashboard(),
            '/owner-dashboard': (context) => const OwnerDashboardScreen(),
            '/district-admin-dashboard': (context) => const DistrictAdminDashboard(),
            '/add-hostel': (context) => const AddHostelScreen(),
            '/hostel-request-form': (context) => const HostelRequestFormScreen(),
            '/my-hostel-requests': (context) => const HostelRequestsScreen(),
            '/payment': (context) => const PaymentScreen(),
            '/payment-history': (context) => const PaymentHistoryScreen(),
            '/warden-payment': (context) => const WardenPaymentScreen(),
            '/room-details': (context) {
              final roomId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
              return RoomDetailsScreen(roomId: roomId);
            },
            '/user-details': (context) {
              final studentId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
              return UserDetailsScreen(studentId: studentId);
            },
            '/admin-users': (context) => const AdminUsersScreen(),
            '/admin-rooms': (context) {
              final filter = ModalRoute.of(context)?.settings.arguments as String?;
              return AdminRoomsScreen(initialFilter: filter);
            },
            '/admin-payments': (context) {
              final filter = ModalRoute.of(context)?.settings.arguments as String?;
              return AdminPaymentsScreen(initialFilter: filter);
            },
            '/admin-requests': (context) => const AdminRequestsScreen(),
            '/admin-analytics': (context) => const AdminAnalyticsScreen(),
            '/admin-notifications': (context) => const AdminNotificationsScreen(),
            '/admin-reports': (context) => const AdminReportsScreen(),
          },
        );
      },
    );
  }
}
