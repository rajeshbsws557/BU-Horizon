// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/home_cards.dart';
import '../data/local_store.dart';
import '../di/di.dart';

/// Owns the student's home-screen card layout: which quick cards are pinned
/// and in what order.
///
/// The home screen ships with only [HomeCardCatalog.defaultIds] (Class Notices
/// + Bus Schedule); everything else is opt-in. Choices are stored on-device via
/// [LocalStore] (like the theme), so they apply to guests as well as signed-in
/// students and survive restarts. When persistence isn't registered (UI-only
/// builds / widget tests) the cubit still works in memory and no-ops the save.
class HomeCardsCubit extends Cubit<List<HomeCard>> {
  HomeCardsCubit() : super(_initialCards());

  static List<HomeCard> _initialCards() {
    final saved = getIt.isRegistered<LocalStore>()
        ? getIt<LocalStore>().homeCards
        : null;
    // `null` means "never customised" → defaults. An empty saved list is a
    // deliberate "no cards" choice and is honoured as-is.
    if (saved == null) return HomeCardCatalog.resolve(HomeCardCatalog.defaultIds);
    return HomeCardCatalog.resolve(saved);
  }

  /// Ids currently pinned, in display order.
  List<String> get pinnedIds => [for (final c in state) c.id];

  /// Catalog entries not yet pinned — the "Add a card" list.
  List<HomeCard> get availableCards {
    final pinned = pinnedIds.toSet();
    return [
      for (final card in HomeCardCatalog.all)
        if (!pinned.contains(card.id)) card,
    ];
  }

  bool get isAtMax => state.length >= HomeCardCatalog.maxCards;

  bool isPinned(String id) => state.any((c) => c.id == id);

  /// Adds [id] to the end of the layout. No-ops when unknown, already pinned,
  /// or the [HomeCardCatalog.maxCards] ceiling is reached.
  void add(String id) {
    if (isPinned(id) || isAtMax) return;
    final card = HomeCardCatalog.byId(id);
    if (card == null) return;
    _commit([...state, card]);
  }

  void remove(String id) {
    if (!isPinned(id)) return;
    _commit([
      for (final card in state)
        if (card.id != id) card,
    ]);
  }

  void toggle(String id) => isPinned(id) ? remove(id) : add(id);

  /// Moves the card at [oldIndex] to [newIndex], using the index convention of
  /// [ReorderableListView] (where a downward move reports an index one past
  /// the intended slot).
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    final cards = [...state];
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, cards.length - 1);
    if (target == oldIndex) return;
    cards.insert(target, cards.removeAt(oldIndex));
    _commit(cards);
  }

  /// Restores the two default cards.
  void resetToDefaults() {
    emit(HomeCardCatalog.resolve(HomeCardCatalog.defaultIds));
    if (getIt.isRegistered<LocalStore>()) {
      getIt<LocalStore>().clearHomeCards();
    }
  }

  void _commit(List<HomeCard> cards) {
    emit(List.unmodifiable(cards));
    if (getIt.isRegistered<LocalStore>()) {
      getIt<LocalStore>().setHomeCards([for (final c in cards) c.id]);
    }
  }
}
