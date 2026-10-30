import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import 'comms_models.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String _route(String type) => switch (type) {
        'payment' => '/payments',
        'announcement' => '/announcements',
        _ => '/student',
      };

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return StreamBuilder<List<AppNotification>>(
      stream: Services.comms.watchNotifications(uid),
      builder: (context, snap) {
        final list = snap.data ?? const <AppNotification>[];
        final unread = list.where((n) => n.unread).map((n) => n.id).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('الإشعارات'),
            actions: [
              if (unread.isNotEmpty)
                TextButton(
                  onPressed: () => Services.comms.markAllRead(unread).catchError((Object e) {
                    if (context.mounted) showError(context, e);
                  }),
                  child: const Text('تعليم الكل كمقروء'),
                ),
            ],
          ),
          body: snap.hasError
              ? const Center(child: Text('تعذّر تحميل الإشعارات'))
              : !snap.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const Center(child: Text('لا توجد إشعارات'))
                      : Centered(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final n = list[i];
                              return Card(
                                child: ListTile(
                                  leading: Icon(n.unread ? Icons.circle : Icons.circle_outlined, size: 12),
                                  title: Text(n.title, style: TextStyle(fontWeight: n.unread ? FontWeight.bold : null)),
                                  subtitle: Text('${n.body}\n${fmtDate(n.createdAt)}'),
                                  isThreeLine: true,
                                  onTap: () {
                                    if (n.unread) Services.comms.markRead(n.id).catchError((Object _) {});
                                    context.push(_route(n.type));
                                  },
                                ),
                              );
                            },
                          ),
                        ),
        );
      },
    );
  }
}
