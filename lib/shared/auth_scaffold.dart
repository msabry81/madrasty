import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/brand_config.dart';
import '../core/theme.dart';
import '../features/legal/legal_pages.dart';
import 'design.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go('/'),
                  child: const Padding(padding: EdgeInsets.all(8), child: BrandMark(subtitle: BrandConfig.tagline)),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 18),
                    child,
                  ]),
                ),
                const SizedBox(height: 8),
                const LegalFooter(),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
