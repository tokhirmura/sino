import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_view.dart';
import 'loading_view.dart';

/// One-liner for `AsyncValue.when` with the app's unified loading and
/// error states:
///
/// ```dart
/// AsyncValueView(
///   value: ref.watch(medicinesProvider),
///   onRetry: () => ref.invalidate(medicinesProvider),
///   data: (list) => MedicinesList(list),
/// )
/// ```
///
/// [compact] — inline variants for a section inside a scrolling page.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.compact = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// Custom loading placeholder (e.g. `SkeletonList()`).
  final Widget Function()? loading;
  final bool compact;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => loading?.call() ?? LoadingView(compact: compact),
    error: (e, _) => ErrorView(error: e, onRetry: onRetry, compact: compact),
  );
}
