import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import 'models.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدورات')),
      body: StreamBuilder<List<Course>>(
        stream: Services.courses.watchPublished(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('تعذّر تحميل الدورات'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد دورات منشورة بعد'));
          return Centered(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = list[i];
                final meta = [c.gradeLabel, c.subjectLabel].where((e) => e.isNotEmpty).join(' · ');
                return Card(
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: meta.isEmpty ? null : Text(meta),
                    trailing: Text(c.priceText),
                    onTap: () => context.push('/courses/${c.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
