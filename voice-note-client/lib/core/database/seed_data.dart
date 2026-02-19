import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../constants/preset_accounts.dart';
import '../constants/preset_categories.dart';
import 'app_database.dart';

const _uuid = Uuid();

/// Insert all preset data into a freshly created database.
Future<void> seedDatabase(AppDatabase db) async {
  await _seedDefaultAccount(db);
  await _seedPresetCategories(db);
}

Future<void> _seedDefaultAccount(AppDatabase db) async {
  final now = DateTime.now();
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _uuid.v4(),
          name: defaultWalletAccount.name,
          type: defaultWalletAccount.type,
          icon: Value(defaultWalletAccount.icon),
          color: Value(defaultWalletAccount.color),
          isPreset: const Value(true),
          sortOrder: Value(defaultWalletAccount.sortOrder),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _seedPresetCategories(AppDatabase db) async {
  final now = DateTime.now();
  await db.batch((batch) {
    for (final cat in allPresetCategories) {
      batch.insert(
        db.categories,
        CategoriesCompanion.insert(
          id: _uuid.v4(),
          name: cat.name,
          type: cat.type,
          icon: Value(cat.icon),
          color: Value(cat.color),
          isPreset: const Value(true),
          isHidden: Value(cat.isHidden),
          sortOrder: Value(cat.sortOrder),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  });
}
