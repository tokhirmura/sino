import '../../../core/contracts/home_card.dart';
import '../../../core/data/health_goal.dart';

/// Card ids (from each feature's `HomeCardSpec.id`) that help with a goal,
/// most useful first. Unknown ids are ignored, so a feature renaming its
/// card only loses the boost.
const goalCardPriority = <HealthGoal, List<String>>{
  HealthGoal.loseWeight: ['nutrition', 'workouts', 'vitals'],
  HealthGoal.energy: ['workouts', 'breathing', 'nutrition', 'weather'],
  HealthGoal.pressureSugar: ['vitals', 'reminders', 'nutrition', 'doctors'],
  HealthGoal.family: ['family', 'reminders', 'doctors', 'pharmacy'],
};

/// Always on top whatever the goal: emergency help.
const pinnedCardIds = ['sos'];

/// [cards] (already sorted by `order`) reordered for [goal]: pinned cards,
/// then the goal's cards in priority order, then the rest as they were.
/// No goal → unchanged.
List<HomeCardSpec> orderCardsForGoal(
  List<HomeCardSpec> cards,
  HealthGoal? goal,
) {
  if (goal == null) return cards;
  final byId = {for (final c in cards) c.id: c};
  final lifted = [
    for (final id in [...pinnedCardIds, ...goalCardPriority[goal]!]) ?byId[id],
  ];
  return [
    ...lifted,
    for (final c in cards)
      if (!lifted.contains(c)) c,
  ];
}
