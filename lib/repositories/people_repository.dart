import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for people search.
abstract interface class PeopleRepository {
  Future<List<Person>> search(String query);
}

@Injectable(as: PeopleRepository)
final class SamplePeopleRepository implements PeopleRepository {
  @override
  Future<List<Person>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(SampleData.people);
    return List.unmodifiable(
      SampleData.people.where(
        (p) =>
            p.name.toLowerCase().contains(q) ||
            p.department.toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q),
      ),
    );
  }
}
