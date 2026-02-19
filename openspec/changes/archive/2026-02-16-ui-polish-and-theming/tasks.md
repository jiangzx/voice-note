## 1. 依赖与基础设施

- [x] 1.1 添加 `animations`、`shimmer`、`shared_preferences` 依赖到 `pubspec.yaml`，运行 `flutter pub get`
- [x] 1.2 创建设计令牌文件 `lib/app/design_tokens.dart`，定义 `AppSpacing`、`AppRadius`、`AppDuration`、`AppTypography`
- [x] 1.3 编写设计令牌单元测试 `test/app/design_tokens_test.dart`，验证常量值正确性

## 2. 主题系统重构

- [x] 2.1 重构 `lib/app/theme.dart`：抽取 `buildTheme(Color seedColor, Brightness brightness)` 工厂函数，生成对应的 `ThemeData`；`TransactionColors` 区分 light/dark 变体
- [x] 2.2 创建主题偏好 providers `lib/features/settings/presentation/providers/theme_providers.dart`：`themeModeProvider`（system/light/dark）和 `themeColorProvider`（seed Color），使用 `shared_preferences` 持久化
- [x] 2.3 修改 `lib/app.dart`：`MaterialApp.router` 绑定 `theme`/`darkTheme`/`themeMode` 到 providers
- [x] 2.4 编写主题 provider 单元测试 `test/features/settings/presentation/providers/theme_providers_test.dart`
- [x] 2.5 编写主题工厂函数单元测试 `test/app/theme_test.dart`，验证 light/dark 主题和 TransactionColors 适配

## 3. 共享状态组件

- [x] 3.1 创建 `lib/shared/widgets/empty_state_widget.dart`：统一空状态组件（图标 + 标题 + 可选描述 + 可选操作按钮），使用设计令牌
- [x] 3.2 创建 `lib/shared/widgets/error_state_widget.dart`：统一错误状态组件（图标 + 错误信息 + 重试按钮），使用设计令牌
- [x] 3.3 创建 `lib/shared/widgets/shimmer_placeholder.dart`：骨架屏占位组件，提供列表型和卡片型两种预设
- [x] 3.4 编写共享组件 widget 测试 `test/shared/widgets/empty_state_widget_test.dart`
- [x] 3.5 编写共享组件 widget 测试 `test/shared/widgets/error_state_widget_test.dart`
- [x] 3.6 编写共享组件 widget 测试 `test/shared/widgets/shimmer_placeholder_test.dart`

## 4. 路由转场动画

- [x] 4.1 修改 `lib/app/router.dart`：ShellRoute 内 Tab 页使用 `FadeThroughTransition`，push 页面使用 `SharedAxisTransition` (Y 轴)
- [x] 4.2 修改 `lib/shared/widgets/app_shell.dart`：将 FAB 替换为 `OpenContainer`，展开为 `TransactionFormScreen`
- [x] 4.3 编写路由转场 widget 测试 `test/app/router_test.dart`，验证页面可正常导航

## 5. 性能修复

- [x] 5.1 重构 `lib/features/transaction/presentation/widgets/transfer_fields.dart`：改为 `StatefulWidget`，在 `initState` 创建 `TextEditingController`，在 `dispose` 释放
- [x] 5.2 修改 `lib/features/transaction/presentation/widgets/number_pad.dart`：将 `_keys` 列表声明为 `static const`（已是 static const，无需修改）
- [x] 5.3 重构 `lib/features/transaction/presentation/widgets/filter_bar.dart`：改为 `StatefulWidget`，搜索 `TextEditingController` 受控管理，与外部状态同步
- [x] 5.4 编写 transfer_fields 控制器生命周期测试 `test/features/transaction/presentation/widgets/transfer_fields_test.dart`
- [x] 5.5 编写 filter_bar 受控搜索测试 `test/features/transaction/presentation/widgets/filter_bar_test.dart`

## 6. 首页优化

- [x] 6.1 修改 `lib/features/home/presentation/screens/home_screen.dart`：替换 loading/empty/error 为共享组件，应用设计令牌，添加列表入场淡入动画
- [x] 6.2 修改 `lib/features/home/presentation/widgets/summary_card.dart`：应用设计令牌
- [x] 6.3 修改 `lib/features/home/presentation/widgets/recent_transaction_tile.dart`：应用设计令牌
- [x] 6.4 更新首页 widget 测试 `test/features/home/presentation/screens/home_screen_test.dart`

## 7. 记账页优化

- [x] 7.1 修改 `lib/features/transaction/presentation/screens/transaction_form_screen.dart`：应用设计令牌，金额显示添加 `AnimatedDefaultTextStyle`
- [x] 7.2 修改 `lib/features/transaction/presentation/widgets/amount_display.dart`：添加数值变化动画
- [x] 7.3 修改 `lib/features/transaction/presentation/widgets/category_grid.dart`：应用设计令牌
- [x] 7.4 修改 `lib/features/transaction/presentation/widgets/date_quick_select.dart`：应用设计令牌
- [x] 7.5 修改 `lib/features/transaction/presentation/widgets/type_selector.dart`：应用设计令牌
- [x] 7.6 更新记账页 widget 测试 `test/features/transaction/presentation/screens/transaction_form_screen_test.dart`

## 8. 明细列表页优化

- [x] 8.1 修改 `lib/features/transaction/presentation/screens/transaction_list_screen.dart`：替换 loading/empty/error 为共享组件，应用设计令牌，添加列表入场淡入动画
- [x] 8.2 修改 `lib/features/transaction/presentation/widgets/daily_group_header.dart`：应用设计令牌
- [x] 8.3 修改 `lib/features/transaction/presentation/widgets/transaction_tile.dart`：应用设计令牌，确保 `const` 最大化
- [x] 8.4 更新明细列表 widget 测试 `test/features/transaction/presentation/screens/transaction_list_screen_test.dart`

## 9. 设置页优化

- [x] 9.1 修改 `lib/features/settings/presentation/screens/settings_screen.dart`：新增深色模式切换入口（三选一：跟随系统/浅色/深色），新增主题色选择入口，应用设计令牌，替换错误状态为统一组件
- [x] 9.2 更新设置页 widget 测试 `test/features/settings/presentation/screens/settings_screen_test.dart`

## 10. 账户/分类管理页优化

- [x] 10.1 修改 `lib/features/account/presentation/screens/account_manage_screen.dart`：替换 loading/empty/error 为共享组件，应用设计令牌
- [x] 10.2 修改 `lib/features/category/presentation/screens/category_manage_screen.dart`：替换 loading/empty/error 为共享组件，应用设计令牌
- [x] 10.3 更新账户管理 widget 测试 `test/features/account/presentation/screens/account_manage_screen_test.dart`
- [x] 10.4 更新分类管理 widget 测试 `test/features/category/presentation/screens/category_manage_screen_test.dart`

## 11. 集成验证

- [x] 11.1 运行 `dart format .` 确保格式统一
- [x] 11.2 运行 `flutter analyze` 确保无 lint 错误（仅剩预存 info/warning）
- [x] 11.3 运行 `flutter test` 确保所有测试通过（170 tests passed）
- [x] 11.4 运行 `dart run build_runner build --delete-conflicting-outputs` 确保代码生成更新
