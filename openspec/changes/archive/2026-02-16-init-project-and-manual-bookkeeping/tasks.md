## 1. 项目基础设施

- [x] 1.1 添加核心依赖到 `pubspec.yaml`：flutter_riverpod、riverpod_annotation、riverpod_generator、drift、sqlite3_flutter_libs、path_provider、path、uuid、shared_preferences、intl、go_router、build_runner、drift_dev（dev）
- [x] 1.2 创建 `analysis_options.yaml`，启用 strict-casts / strict-inference / strict-raw-types，配置推荐 lint 规则
- [x] 1.3 创建项目目录结构：`lib/core/{database,di,constants,utils,extensions}`、`lib/features/{account,category,transaction,home}/{data,domain,presentation}`
- [x] 1.4 创建应用入口 `lib/app.dart`（MaterialApp + ProviderScope + GoRouter + ThemeData with Material 3），更新 `lib/main.dart` 调用 app.dart

## 2. 数据层——drift 数据库与表定义

- [x] 2.1 创建 drift 数据库定义 `lib/core/database/app_database.dart`：定义 accounts、categories、transactions 三张表及字段（对齐 design.md D4 表结构），配置 schemaVersion=1
- [x] 2.2 创建 drift DAO 文件：`lib/features/account/data/account_dao.dart`、`lib/features/category/data/category_dao.dart`、`lib/features/transaction/data/transaction_dao.dart`
- [x] 2.3 运行 `dart run build_runner build` 生成 drift 代码
- [x] 2.4 创建数据库初始化与 Provider：`lib/core/di/database_provider.dart`（Riverpod keepAlive provider 提供 AppDatabase 单例）

## 3. 种子数据与常量

- [x] 3.1 创建常量文件 `lib/core/constants/preset_categories.dart`：定义 17 个预设分类（12 支出 + 5 收入），包含 name、type、icon（material: 格式）、color（ARGB hex）、is_hidden、sort_order。P1 阶段使用硬编码中文文案，后续国际化时替换为 i18n key
- [x] 3.2 创建常量文件 `lib/core/constants/preset_accounts.dart`：定义默认"钱包"账户（type=cash、icon=material:account_balance_wallet、is_preset=true）。P1 阶段使用硬编码中文文案
- [x] 3.3 创建常量文件 `lib/core/constants/time_period_recommendations.dart`：定义 5 个时段推荐映射（早/午/晚餐 + 早/晚通勤 → 分类）
- [x] 3.4 在 drift MigrationStrategy 的 `onCreate` 回调中实现种子数据插入（调用预设常量），路径 `lib/core/database/app_database.dart`
- [x] 3.5 编写种子数据单元测试 `test/core/database/seed_data_test.dart`：验证首次创建后存在 17 个预设分类 + 1 个默认账户

## 4. 账户模块（Account）——Data → Domain → Presentation

- [x] 4.1 创建领域实体 `lib/features/account/domain/entities/account_entity.dart`（不可变数据类，含 copyWith）
- [x] 4.2 创建 Repository 接口 `lib/features/account/domain/repositories/account_repository.dart`：getAll、getById、getDefault、create、update、archive、isMultiAccountEnabled、setMultiAccountEnabled
- [x] 4.3 创建 Repository 实现 `lib/features/account/data/repositories/account_repository_impl.dart`：基于 AccountDao 实现，multi_account_enabled 通过 shared_preferences 读写
- [x] 4.4 创建 Use Case `lib/features/account/domain/use_cases/calculate_balance_use_case.dart`：实现记账余额计算公式（initial_balance + income + transfer_in - expense - transfer_out，仅 is_draft=false）
- [x] 4.5 创建 Riverpod Providers `lib/features/account/presentation/providers/account_providers.dart`：accountRepositoryProvider（keepAlive）、accountListProvider、defaultAccountProvider、multiAccountEnabledProvider
- [x] 4.6 编写账户模块单元测试 `test/features/account/domain/use_cases/calculate_balance_test.dart`：验证余额计算（纯收入、纯支出、混合交易、有初始余额）
- [x] 4.7 编写账户 Repository 测试 `test/features/account/data/repositories/account_repository_impl_test.dart`：验证 CRUD、预设保护（不可删除/归档）、默认账户绑定
- [x] 4.8 编写账户 Provider 测试 `test/features/account/presentation/providers/account_providers_test.dart`：验证 accountListProvider、defaultAccountProvider、multiAccountEnabledProvider 的状态读取与切换

## 5. 分类模块（Category）——Data → Domain → Presentation

- [x] 5.1 创建领域实体 `lib/features/category/domain/entities/category_entity.dart`
- [x] 5.2 创建 Repository 接口 `lib/features/category/domain/repositories/category_repository.dart`：getVisible(type)、getAll(type)、create、update、delete（条件策略）、reorder、getRecentlyUsed(limit)
- [x] 5.3 创建 Repository 实现 `lib/features/category/data/repositories/category_repository_impl.dart`：硬删除/软删除条件逻辑、最近使用查询（SELECT DISTINCT category_id FROM transactions ORDER BY created_at DESC LIMIT N）
- [x] 5.4 创建时段推荐服务 `lib/features/category/domain/services/time_period_recommendation_service.dart`：基于当前时间返回推荐分类 ID 列表
- [x] 5.5 创建 Riverpod Providers `lib/features/category/presentation/providers/category_providers.dart`：categoryRepositoryProvider（keepAlive）、visibleCategoriesProvider(type)、recentCategoriesProvider、recommendedCategoryIdsProvider
- [x] 5.6 编写分类模块单元测试 `test/features/category/data/repositories/category_repository_impl_test.dart`：验证 CRUD、条件删除（有引用软删除 vs 无引用硬删除）、预设保护、排序
- [x] 5.7 编写时段推荐测试 `test/features/category/domain/services/time_period_recommendation_test.dart`：验证各时段返回正确分类
- [x] 5.8 编写分类 Provider 测试 `test/features/category/presentation/providers/category_providers_test.dart`：验证 visibleCategoriesProvider、recentCategoriesProvider、recommendedCategoryIdsProvider

## 6. 交易记录模块（Transaction Recording）——Data → Domain → Presentation

- [x] 6.1 创建领域实体 `lib/features/transaction/domain/entities/transaction_entity.dart`：含 TransactionType 枚举（expense/income/transfer）和 TransferDirection 枚举（in/out）
- [x] 6.2 创建 Repository 接口 `lib/features/transaction/domain/repositories/transaction_repository.dart`：create、update、delete（含配对解除）、getById
- [x] 6.3 创建 Repository 实现 `lib/features/transaction/data/repositories/transaction_repository_impl.dart`：实现必填字段校验（amount>0、category_id 非转账时必填）、日期默认今天、currency 默认 CNY、默认账户绑定、删除时清理 linked_transaction_id
- [x] 6.4 创建 Riverpod Providers `lib/features/transaction/presentation/providers/transaction_form_providers.dart`：用于记账表单的 StateNotifier（selectedType、amount、categoryId、date、description、accountId、transferDirection、counterparty）
- [x] 6.5 编写交易记录单元测试 `test/features/transaction/data/repositories/transaction_repository_impl_test.dart`：验证三种类型创建、必填字段校验（拒绝零/负金额、拒绝无分类支出）、currency 默认 CNY、编辑、删除、配对解除
- [x] 6.6 编写交易表单 Provider 测试 `test/features/transaction/presentation/providers/transaction_form_providers_test.dart`：验证表单状态管理（类型切换、字段设置、重置）

## 7. 交易查询模块（Transaction Query）——Data → Domain → Presentation

- [x] 7.1 创建筛选条件值对象 `lib/features/transaction/domain/entities/transaction_filter.dart`：dateRange、categoryIds、accountId、amountRange、keyword、type
- [x] 7.2 扩展 Repository 接口，添加查询方法到 `lib/features/transaction/domain/repositories/transaction_repository.dart`：getFiltered(filter, offset, limit)、getSummary(dateRange)、getRecent(limit)、getDailyGrouped(dateRange)
- [x] 7.3 扩展 Repository 实现 `lib/features/transaction/data/repositories/transaction_repository_impl.dart`：实现组合筛选（AND 逻辑）、收支汇总（转账不计入）、按日分组、最近交易
- [x] 7.4 创建 Riverpod Providers `lib/features/transaction/presentation/providers/transaction_query_providers.dart`：transactionListProvider(filter)、summaryProvider(dateRange)、recentTransactionsProvider、dailyGroupedProvider
- [x] 7.5 编写交易查询单元测试 `test/features/transaction/data/repositories/transaction_query_test.dart`：验证排序（date DESC + created_at DESC）、日期/分类/账户/金额/关键词筛选、组合筛选、收支汇总（转账排除）、按日分组、最近 N 条
- [x] 7.6 编写交易查询 Provider 测试 `test/features/transaction/presentation/providers/transaction_query_providers_test.dart`：验证 transactionListProvider、summaryProvider、recentTransactionsProvider

## 8. 工具类与扩展

- [x] 8.1 创建 UUID 生成工具 `lib/core/utils/id_generator.dart`：封装 uuid 包，提供 generateId() 方法
- [x] 8.2 创建颜色解析工具 `lib/core/utils/color_utils.dart`：ARGB hex 字符串 ↔ Flutter Color 互转
- [x] 8.3 创建图标解析工具 `lib/core/utils/icon_utils.dart`：解析 `material:<name>` 和 `emoji:<char>` 格式为 Widget
- [x] 8.4 创建日期扩展 `lib/core/extensions/date_extensions.dart`：isSameDay、isSameMonth、toDateOnly、yesterday、dayBeforeYesterday、常用日期范围快捷方法（today、thisWeek、thisMonth、thisYear）
- [x] 8.5 编写工具类单元测试 `test/core/utils/color_utils_test.dart`、`test/core/utils/icon_utils_test.dart`、`test/core/extensions/date_extensions_test.dart`
