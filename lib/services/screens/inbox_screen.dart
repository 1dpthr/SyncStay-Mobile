import 'package:flutter/material.dart';

import 'widgets/request_inbox_body.dart';
import 'widgets/syncstay_app_bar.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Requests Inbox'),
      body: const RequestInboxBody(),
    );
  }
}
