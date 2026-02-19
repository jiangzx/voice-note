import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/database_provider.dart';
import '../../data/repositories/account_repository_impl.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/account_repository.dart';

part 'account_providers.g.dart';

@Riverpod(keepAlive: true)
Future<AccountRepository> accountRepository(Ref ref) async {
  final dao = ref.watch(accountDaoProvider);
  final prefs = await SharedPreferences.getInstance();
  return AccountRepositoryImpl(dao, prefs);
}

@riverpod
Future<List<AccountEntity>> accountList(Ref ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  return repo.getActive();
}

@riverpod
Future<AccountEntity?> defaultAccount(Ref ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  return repo.getDefault();
}

@riverpod
Future<bool> multiAccountEnabled(Ref ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  return repo.isMultiAccountEnabled();
}
