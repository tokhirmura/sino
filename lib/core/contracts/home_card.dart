import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A card a feature contributes to the home screen.
/// `order` — smaller is higher (see root CLAUDE.md for ranges).
class HomeCardSpec {
  const HomeCardSpec({
    required this.id,
    required this.order,
    required this.builder,
  });

  final String id;
  final int order;
  final WidgetBuilder builder;
}

/// All home cards, sorted by order. Overridden in `lib/app/app.dart` with
/// the list from feature_registry, so the home feature never imports
/// other features.
final homeCardsProvider = Provider<List<HomeCardSpec>>((ref) => const []);
