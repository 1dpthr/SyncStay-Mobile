import 'package:flutter/material.dart';

class SyncStayLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;

  const SyncStayLogo({
    super.key,
    this.size = 96,
    this.borderRadius = 24,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: size * 0.24,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/syncstay_app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
