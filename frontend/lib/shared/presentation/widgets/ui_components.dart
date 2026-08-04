import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

// Section header with icon, title, subtitle, and accent border
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.csuMaroonLight : AppTheme.csuMaroon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.08),
            accent.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// Status badge with color-coded background
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.info,
  });

  factory StatusBadge.success(String label) =>
      StatusBadge(label: label, type: StatusBadgeType.success);

  factory StatusBadge.warning(String label) =>
      StatusBadge(label: label, type: StatusBadgeType.warning);

  factory StatusBadge.error(String label) =>
      StatusBadge(label: label, type: StatusBadgeType.error);

  factory StatusBadge.info(String label) =>
      StatusBadge(label: label, type: StatusBadgeType.info);

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.$2,
        ),
      ),
    );
  }

  (Color, Color) _getColors() {
    switch (type) {
      case StatusBadgeType.success:
        return (AppTheme.success, AppTheme.success);
      case StatusBadgeType.warning:
        return (AppTheme.warning, AppTheme.warning);
      case StatusBadgeType.error:
        return (AppTheme.error, AppTheme.error);
      case StatusBadgeType.info:
        return (AppTheme.info, AppTheme.info);
    }
  }
}

enum StatusBadgeType { success, warning, error, info }

// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// Error state widget
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Loading indicator
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              message!,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

// University letterhead widget
class UniversityLetterhead extends StatelessWidget {
  final bool showDivider;

  const UniversityLetterhead({super.key, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.csuMaroonLight : AppTheme.csuMaroon;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Icon(Icons.school, size: 40, color: accent),
          const SizedBox(height: 4),
          const Text('Republic of the Philippines',
              style: TextStyle(fontSize: 11)),
          const Text(
            'CAGAYAN STATE UNIVERSITY',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text(
            'CARIG CAMPUS',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Text('Carig Sur, Tuguegarao City, Cagayan',
              style: TextStyle(fontSize: 10)),
          const SizedBox(height: 4),
          const Text('Campus TVET Office',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
          if (showDivider) const Divider(height: 24),
        ],
      ),
    );
  }
}

// Success card shown after saving
class SuccessCard extends StatelessWidget {
  final String code;
  final VoidCallback onView;

  const SuccessCard({
    super.key,
    required this.code,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppTheme.success,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved: $code',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onView,
            icon: Icon(Icons.print, size: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.csuGoldLight
                    : AppTheme.success),
            label: Text(
              'Print / View',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.csuGoldLight
                    : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Responsive max-width wrapper
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
