import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import 'comms_models.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات')),
      body: StreamBuilder<List<Enrollment>>(
        stream: Services.courses.watchMyEnrollments(uid),
        builder: (context, es) {
          if (!es.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<List<Announcement>>(
            stream: Services.comms.watchAnnouncementsFor(es.data!.map((e) => e.courseId).toList()),
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('تعذّر تحميل الإعلانات'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!.where((a) => !a.isExpired).toList();
              if (list.isEmpty) return const Center(child: Text('لا توجد إعلانات'));
              return Centered(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = list[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(fmtDate(a.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Text(a.body),
                        ]),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
