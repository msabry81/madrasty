import 'package:flutter/material.dart';

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import 'session_models.dart';

class MyAttendancePage extends StatelessWidget {
  const MyAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('حضوري')),
      body: StreamBuilder<List<AttendanceRecord>>(
        stream: Services.sessions.watchMyAttendance(uid),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('تعذّر تحميل الحضور'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد سجلات حضور بعد'));
          int n(String s) => list.where((r) => r.status == s).length;
          return Centered(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('حاضر: ${n('present')}   ·   متأخر: ${n('late')}   ·   غائب: ${n('absent')}'),
                ),
              ),
              for (final r in list)
                Card(
                  child: ListTile(
                    title: Text(r.sessionTitle),
                    subtitle: r.sessionStartsAt == null ? null : Text(CairoTime.format(r.sessionStartsAt!)),
                    trailing: Chip(label: Text(r.statusLabel)),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
