import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for bus routes and favorites.
abstract interface class BusRepository {
  List<BusRoute> get routes;
  List<BusRoute> get favoriteRoutes;
  List<BusRoute> get myRoutes;
  void toggleFavorite(String routeName);
}

@Injectable(as: BusRepository)
final class SampleBusRepository implements BusRepository {
  final List<BusRoute> _routes = SampleData.busRoutes();

  @override
  List<BusRoute> get routes => List.unmodifiable(_routes);

  @override
  List<BusRoute> get favoriteRoutes =>
      List.unmodifiable(_routes.where((r) => r.favorite));

  @override
  List<BusRoute> get myRoutes => List.unmodifiable(_routes.take(3));

  @override
  void toggleFavorite(String routeName) {
    final index = _routes.indexWhere((r) => r.name == routeName);
    if (index == -1) return;
    final route = _routes[index];
    _routes[index] = route.copyWith(favorite: !route.favorite);
  }
}
