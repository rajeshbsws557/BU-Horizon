// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';

import '../navigation/app_router.dart';
import '../theme/app_theme.dart';

/// One entry in the home-screen "quick card" catalog.
///
/// [id] is the stable key persisted in [LocalStore.homeCards]; renaming a
/// title is therefore safe, changing an id is not.
///
/// [color] holds an [AppColorToken] sentinel (const data has no BuildContext),
/// so renderers must resolve it against the live theme via
/// `context.colors.resolve(...)`.
@immutable
class HomeCard {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  /// Needs a signed-in account. Guests still see the tile; tapping it opens
  /// the "sign in required" sheet (mirrors [AppRoutes.membersOnly]).
  final bool membersOnly;

  const HomeCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.membersOnly = false,
  });
}

/// The full set of cards a student can pin to their home screen.
///
/// The home screen ships intentionally minimal: only [defaultIds] are shown
/// out of the box (Class Notices + Bus Schedule). Everything else lives here
/// and is opt-in through the "Customize cards" sheet, so the first screen stays
/// calm and each student builds the dashboard they actually use.
abstract class HomeCardCatalog {
  HomeCardCatalog._();

  static const HomeCard classNotices = HomeCard(
    id: 'notices',
    title: 'Class Notices',
    subtitle: 'Stay updated',
    icon: Icons.campaign_rounded,
    color: AppColorToken.accentCyan,
    route: AppRoutes.notices,
    membersOnly: true,
  );

  static const HomeCard busSchedule = HomeCard(
    id: 'bus',
    title: 'Bus Schedule',
    subtitle: 'View bus timing & set alarm',
    icon: Icons.directions_bus_rounded,
    color: AppColorToken.primary,
    route: AppRoutes.bus,
  );

  /// Every available card, in the order they appear in the "Add a card" list.
  static const List<HomeCard> all = [
    classNotices,
    busSchedule,
    HomeCard(
      id: 'exams',
      title: 'Exam Schedule',
      subtitle: 'Quizzes, midterms & finals',
      icon: Icons.edit_calendar_rounded,
      color: AppColorToken.danger,
      route: AppRoutes.exams,
      membersOnly: true,
    ),
    HomeCard(
      id: 'attendance',
      title: 'Attendance',
      subtitle: 'Mark & track attendance',
      icon: Icons.check_circle_rounded,
      color: AppColorToken.success,
      route: AppRoutes.attendance,
      membersOnly: true,
    ),
    HomeCard(
      id: 'resources',
      title: 'Class Archive',
      subtitle: 'Past classes & materials',
      icon: Icons.folder_rounded,
      color: AppColorToken.primary,
      route: AppRoutes.resources,
      membersOnly: true,
    ),
    // TODO(bug-fix): re-enable People Search once the bug is fixed.
    // HomeCard(
    //   id: 'people',
    //   title: 'People Search',
    //   subtitle: 'Find anyone in campus',
    //   icon: Icons.group_rounded,
    //   color: AppColorToken.purple,
    //   route: AppRoutes.search,
    //   membersOnly: true,
    // ),
    HomeCard(
      id: 'blood',
      title: 'Blood Help',
      subtitle: 'Request or offer blood',
      icon: Icons.water_drop_rounded,
      color: AppColorToken.danger,
      route: AppRoutes.blood,
    ),
    HomeCard(
      id: 'lost-found',
      title: 'Lost & Found',
      subtitle: 'Report or find items',
      icon: Icons.inventory_2_rounded,
      color: AppColorToken.warning,
      route: AppRoutes.lostFound,
    ),
    HomeCard(
      id: 'club',
      title: 'Clubs',
      subtitle: 'Campus clubs & activities',
      icon: Icons.groups_rounded,
      color: AppColorToken.purple,
      route: AppRoutes.club,
    ),
    // TODO: re-enable Legal Help once the feature goes public.
    // HomeCard(
    //   id: 'legal-help',
    //   title: 'Legal Help',
    //   subtitle: 'Report harassment safely',
    //   icon: Icons.shield_rounded,
    //   color: AppColorToken.danger,
    //   route: AppRoutes.legalHelp,
    // ),
    HomeCard(
      id: 'alerts',
      title: 'Alerts',
      subtitle: 'Campus-wide announcements',
      icon: Icons.notifications_active_rounded,
      color: AppColorToken.warning,
      route: AppRoutes.alerts,
    ),
    HomeCard(
      id: 'about',
      title: 'About',
      subtitle: 'About BU Horizon',
      icon: Icons.info_rounded,
      color: AppColorToken.gold,
      route: AppRoutes.about,
    ),
  ];

  /// The two cards every student starts with.
  static const List<String> defaultIds = ['notices', 'bus'];

  /// Hard ceiling on how many cards can be pinned, so the home screen can
  /// never degrade back into an endless wall of tiles.
  static const int maxCards = 8;

  static HomeCard? byId(String id) {
    for (final card in all) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// Resolves persisted ids to cards, dropping any that no longer exist (e.g.
  /// a card removed in a later release) and de-duplicating.
  static List<HomeCard> resolve(Iterable<String> ids) {
    final seen = <String>{};
    final cards = <HomeCard>[];
    for (final id in ids) {
      if (!seen.add(id)) continue;
      final card = byId(id);
      if (card != null) cards.add(card);
    }
    return cards;
  }
}
