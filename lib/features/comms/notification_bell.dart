import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: Services.comms.watchUnreadCount(uid),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return IconButton(
          tooltip: 'الإشعارات',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n >= 10 ? '9+' : '$n'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
