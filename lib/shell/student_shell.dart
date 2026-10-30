import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/brand_config.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../features/comms/notification_bell.dart';
import '../shared/design.dart';

class _NavItem {
  const _NavItem(this.label, this.path, this.icon);
  final String label, path;
  final IconData icon;
}

const _items = [
  _NavItem('الرئيسية', '/student', Icons.home_outlined),
  _NavItem('الدورات', '/courses', Icons.menu_book_outlined),
  _NavItem('الحصص المباشرة', '/sessions', Icons.sensors),
  _NavItem('الامتحانات', '/exams', Icons.quiz_outlined),
  _NavItem('طلباتي', '/payments', Icons.receipt_long_outlined),
];

bool _active(String loc, String path) =>
    path == '/student' ? loc == '/student' : (loc == path || loc.startsWith('$path/'));

/// إطار الطالب/الزائر: شريط علوي بروابط التنقل (يتحوّل لقائمة جانبية على الهاتف).
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      drawer: wide ? null : _NavDrawer(location: location),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const BrandMark(),
              actions: const [NotificationBellIfStudent(), _UserMenu(compact: true)],
            ),
      body: Column(children: [
        if (wide) _TopBar(location: location),
        Expanded(child: child),
      ]),
    );
  }
}

class NotificationBellIfStudent extends StatelessWidget {
  const NotificationBellIfStudent({super.key});
  @override
  Widget build(BuildContext context) =>
      Services.session.user != null && !Services.session.isAdmin ? const NotificationBell() : const SizedBox.shrink();
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final loggedIn = Services.session.user != null;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color.fromRGBO(16, 38, 63, 0.04), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        InkWell(onTap: () => context.go('/'), child: const BrandMark()),
        const SizedBox(width: 28),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final i in _items)
                if (loggedIn || i.path == '/courses') _Pill(item: i, active: _active(location, i.path)),
              if (!loggedIn) _Pill(item: const _NavItem('الرئيسية', '/', Icons.home_outlined), active: false),
            ]),
          ),
        ),
        if (loggedIn) ...[
          const CairoClock(),
          const SizedBox(width: 8),
          const NotificationBellIfStudent(),
          const _UserMenu(),
        ] else ...[
          OutlinedButton(onPressed: () => context.go('/login'), child: const Text('تسجيل الدخول')),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => context.go('/register'), child: const Text('إنشاء حساب')),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.item, required this.active});
  final _NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(item.path),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(item.label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.navy)),
            ),
          ),
        ),
      );
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = Services.session;
    final u = s.user;
    if (u == null) {
      return IconButton(onPressed: () => context.go('/login'), icon: const Icon(Icons.login));
    }
    final name = u.displayName ?? u.email ?? '';
    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      onSelected: (v) {
        switch (v) {
          case 'attendance':
            context.go('/attendance');
          case 'announcements':
            context.go('/announcements');
          case 'admin':
            context.go('/admin');
          case 'logout':
            Services.auth.signOut();
        }
      },
      itemBuilder: (_) => [
        if (s.isAdmin) const PopupMenuItem(value: 'admin', child: Text('لوحة الإدارة')),
        const PopupMenuItem(value: 'attendance', child: Text('حضوري')),
        const PopupMenuItem(value: 'announcements', child: Text('الإعلانات')),
        const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InitialAvatar(name, size: 36),
          if (!compact) ...[
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
              Text(s.isAdmin ? 'المدير' : 'طالب', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _NavDrawer extends StatelessWidget {
  const _NavDrawer({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final loggedIn = Services.session.user != null;
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          const Padding(padding: EdgeInsets.all(8), child: BrandMark(subtitle: BrandConfig.tagline)),
          const Divider(),
          for (final i in _items)
            if (loggedIn || i.path == '/courses')
              ListTile(
                leading: Icon(i.icon),
                title: Text(i.label),
                selected: _active(location, i.path),
                selectedTileColor: AppColors.primaryTint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  context.go(i.path);
                },
              ),
          if (!loggedIn) ...[
            ListTile(leading: const Icon(Icons.login), title: const Text('تسجيل الدخول'), onTap: () => context.go('/login')),
            ListTile(leading: const Icon(Icons.person_add_alt), title: const Text('إنشاء حساب'), onTap: () => context.go('/register')),
          ],
        ]),
      ),
    );
  }
}
