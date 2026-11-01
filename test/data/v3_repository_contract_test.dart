import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/data/db/database.dart';
import 'package:spending_tracker/data/drift_spending_repository.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';

import 'v3_repository_contract.dart';

void main() {
  runV3RepositoryContract('DriftSpendingRepository', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftSpendingRepository(db);
    await repo.createItem(nameAr: 'إندومي', categoryKey: 'Food');
    await repo.createItem(nameAr: 'شويبس', categoryKey: 'Drinks');
    return repo;
  });

  runV3RepositoryContract(
    'FixtureSpendingRepository',
    () async => FixtureSpendingRepository(),
    today: () => DateTime(2026, 9, 6),
  );
}
