import 'dart:async';

import 'package:flutter/material.dart';

import '../core/brand_config.dart';
import '../core/cairo_time.dart';
import '../core/theme.dart';

bool isWide(BuildContext c, [double w = 900]) => MediaQuery.sizeOf(c).width >= w;

String money(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b ج.م';
}

String ago(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  return 'منذ ${diff.inDays} يوم';
}

/// "بعد X ساعة و Y دقيقة" / "جارية الآن"
String untilText(DateTime start) {
  final d = start.difference(DateTime.now());
  if (d.isNegative) return 'جارية الآن';
  if (d.inDays >= 1) return 'بعد ${d.inDays} يوم';
  if (d.inHours >= 1) return 'بعد ${d.inHours} ساعة و${d.inMinutes % 60} دقيقة';
  return 'بعد ${d.inMinutes} دقيقة';
}

(String, BadgeKind) gradeLabel(double pct) {
  if (pct >= 0.9) return ('ممتاز', BadgeKind.success);
  if (pct >= 0.75) return ('جيد جدًا', BadgeKind.info);
  if (pct >= 0.6) return ('جيد', BadgeKind.pending);
  return ('يحتاج مراجعة', BadgeKind.danger);
}

const kCardShadow = [
  BoxShadow(color: Color.fromRGBO(16, 38, 63, 0.04), blurRadius: 4, spreadRadius: -1, offset: Offset(0, 2)),
  BoxShadow(color: Color.fromRGBO(16, 38, 63, 0.06), blurRadius: 16, spreadRadius: -2, offset: Offset(0, 6)),
];

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap, this.color, this.radius = 20});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: r,
        border: Border.all(color: AppColors.border),
        boxShadow: kCardShadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

enum BadgeKind { pending, info, success, danger, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, this.kind, {super.key, this.icon});
  final String label;
  final BadgeKind kind;
  final IconData? icon;

  factory StatusBadge.payment(String status) => switch (status) {
        'pending_payment' => const StatusBadge('في انتظار الدفع', BadgeKind.pending, icon: Icons.hourglass_top),
        'proof_submitted' => const StatusBadge('تم إرسال الإيصال', BadgeKind.info, icon: Icons.attach_file),
        'approved' => const StatusBadge('مقبول', BadgeKind.success, icon: Icons.check_circle_outline),
        'rejected' => const StatusBadge('مرفوض', BadgeKind.danger, icon: Icons.cancel_outlined),
        'expired' => const StatusBadge('منتهي', BadgeKind.neutral, icon: Icons.timer_off_outlined),
        'refunded' => const StatusBadge('مسترد', BadgeKind.neutral, icon: Icons.undo),
        _ => StatusBadge(status, BadgeKind.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, bd) = switch (kind) {
      BadgeKind.pending => (AppColors.warnBg, AppColors.warnFg, AppColors.warnBorder),
      BadgeKind.info => (AppColors.infoBg, AppColors.infoFg, AppColors.infoBorder),
      BadgeKind.success => (AppColors.successBg, AppColors.successFg, AppColors.successBorder),
      BadgeKind.danger => (AppColors.errorBg, AppColors.errorFg, AppColors.errorBorder),
      BadgeKind.neutral => (AppColors.surfaceMid, AppColors.onVariant, AppColors.border),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: bd)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon, this.trailing});
  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (icon != null) ...[Icon(icon, color: AppColors.primary), const SizedBox(width: 8)],
        Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
        if (trailing != null) trailing!,
      ]);
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.footer,
    this.fg = AppColors.primary,
    this.bg = AppColors.primaryTint,
  });
  final IconData icon;
  final String label, value;
  final String? footer;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onVariant, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontFamily: kHeadFont, fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.3)),
            ]),
          ),
        ]),
        if (footer != null) ...[
          const SizedBox(height: 10),
          Text(footer!, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
        ],
      ]),
    );
  }
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar(this.value, {super.key, this.height = 12});
  final double value;
  final double height;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        borderRadius: BorderRadius.circular(999),
        backgroundColor: AppColors.surfaceMid,
        color: AppColors.primary,
      );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.subtitle, this.dark = false});
  final String? subtitle;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.school_outlined, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(BrandConfig.fullName,
            style: TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, fontSize: 18, color: dark ? Colors.white : AppColors.navy, height: 1.2)),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.outline, height: 1.2)),
      ]),
    ]);
  }
}

class CairoClock extends StatefulWidget {
  const CairoClock({super.key});
  @override
  State<CairoClock> createState() => _CairoClockState();
}

class _CairoClockState extends State<CairoClock> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.schedule, size: 16, color: AppColors.navy),
          const SizedBox(width: 6),
          Text('بتوقيت القاهرة: ${CairoTime.formatTime(DateTime.now())}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
        ]),
      );
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primaryTint,
        child: Text(
          name.trim().isEmpty ? '؟' : String.fromCharCode(name.trim().runes.first),
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: size * 0.42),
        ),
      );
}
