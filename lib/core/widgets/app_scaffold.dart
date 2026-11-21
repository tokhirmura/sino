import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import 'gradient_header.dart';

/// Base screen layout for every feature screen.
///
/// Design 2.0: the app bar is a turquoise → lapis gradient with the girih
/// ornament and rounded bottom corners, big white title. Actions are
/// recolored white automatically. `gradientHeader: false` — plain bar on
/// the page background (e.g. for camera or map screens).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.padding,
    this.subtitle,
    this.gradientHeader = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Body padding. Default: 16 on the sides (screens compute widths from
  /// it — keep it), 10 under the header.
  final EdgeInsetsGeometry? padding;

  /// Small second line under the title (date, place, count).
  final String? subtitle;
  final bool gradientHeader;

  static const _defaultPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    10,
    AppSpacing.md,
    0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientHeader ? _gradientBar(context) : _plainBar(context),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: Padding(padding: padding ?? _defaultPadding, child: body),
      ),
    );
  }

  Widget _title(BuildContext context, Color color) {
    final text = Theme.of(context).textTheme;
    final main = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.headlineSmall?.copyWith(color: color, fontSize: 22),
    );
    if (subtitle == null) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        const SizedBox(height: 2),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  PreferredSizeWidget _plainBar(BuildContext context) => AppBar(
    toolbarHeight: subtitle == null ? kToolbarHeight : 72,
    title: _title(context, Theme.of(context).colorScheme.onSurface),
    actions: actions,
  );

  PreferredSizeWidget _gradientBar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const white = Colors.white;
    // Actions were designed for a light bar: make icon / text buttons white.
    final onBar = theme.copyWith(
      colorScheme: scheme.copyWith(
        primary: white,
        onSurface: white,
        onSurfaceVariant: white.withValues(alpha: 0.8),
      ),
      iconTheme: const IconThemeData(color: white),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: white,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return AppBar(
      toolbarHeight: subtitle == null ? kToolbarHeight : 72,
      backgroundColor: Colors.transparent,
      foregroundColor: white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: white),
      actionsIconTheme: const IconThemeData(color: white),
      flexibleSpace: const GradientBackdrop(bottomRadius: 26),
      title: _title(context, white),
      actions: actions == null
          ? null
          : [
              for (final a in actions!) Theme(data: onBar, child: a),
              const SizedBox(width: 6),
            ],
    );
  }
}
