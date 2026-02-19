import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../domain/export_service.dart';

part 'export_providers.g.dart';

@Riverpod(keepAlive: true)
ExportService exportService(Ref ref) {
  final txDao = ref.watch(transactionDaoProvider);
  final catDao = ref.watch(categoryDaoProvider);
  final accDao = ref.watch(accountDaoProvider);

  return ExportService(
    dao: txDao,
    resolveCategoryName: (id) async {
      final cat = await catDao.getById(id);
      return cat?.name ?? id;
    },
    resolveAccountName: (id) async {
      final acc = await accDao.getById(id);
      return acc?.name ?? id;
    },
  );
}
