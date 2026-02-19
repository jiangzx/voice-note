## 1. 基础设施：主题、路由、导航 Shell

- [x] 1.1 抽取主题配置到 `lib/app/theme.dart`：定义 light ThemeData（Material 3 + teal seed）、收入色/支出色/转账色语义色扩展
- [x] 1.2 创建路由配置 `lib/app/router.dart`：定义 ShellRoute（首页/明细/设置三 Tab）+ 记账全屏路由 `/record`、`/record/:id`、设置子路由
- [x] 1.3 创建导航 Shell `lib/shared/widgets/app_shell.dart`：BottomNavigationBar + Scaffold，FAB 在首页和明细列表 Tab 展示，设置 Tab 不展示
- [x] 1.4 重构 `lib/app.dart`：引用新的 `router.dart` 和 `theme.dart`，移除占位 `_PlaceholderHome`
- [x] 1.5 扩展 `TransactionForm` 新增 `loadFromEntity` 方法 `lib/features/transaction/presentation/providers/transaction_form_providers.dart`
- [x] 1.6 测试 `loadFromEntity` 方法 `test/features/transaction/presentation/providers/transaction_form_providers_test.dart`

## 2. 记账表单：共享组件

- [x] 2.1 创建金额显示组件 `lib/features/transaction/presentation/widgets/amount_display.dart`：大字体展示当前金额字符串
- [x] 2.2 创建自定义数字键盘 `lib/features/transaction/presentation/widgets/number_pad.dart`：4×3 网格（0-9/小数点/退格），输出字符回调
- [x] 2.3 创建金额输入控制器逻辑：字符串拼接、小数位限制（≤2）、前导零处理、最大值限制（99999999.99）
- [x] 2.4 测试金额输入控制器逻辑 `test/features/transaction/presentation/widgets/number_pad_test.dart`
- [x] 2.5 创建交易类型选择器 `lib/features/transaction/presentation/widgets/type_selector.dart`：SegmentedButton 切换支出/收入/转账
- [x] 2.6 创建日期快捷选择组件 `lib/features/transaction/presentation/widgets/date_quick_select.dart`：今天/昨天/前天 chips + 日期选择器入口
- [x] 2.7 创建分类网格组件 `lib/features/transaction/presentation/widgets/category_grid.dart`：网格布局展示分类（图标+名称），选中高亮，时段推荐标记
- [x] 2.8 创建分类 chip 组件 `lib/features/transaction/presentation/widgets/category_chip.dart`：最近使用分类的横向 chip 列表
- [x] 2.9 创建转账专属字段组件 `lib/features/transaction/presentation/widgets/transfer_fields.dart`：方向选择（转入/转出）+ 对方信息输入

## 3. 记账表单：页面组装

- [x] 3.1 创建记账页面 `lib/features/transaction/presentation/screens/transaction_form_screen.dart`：组装类型选择器 + 金额显示 + 分类区域/转账字段 + 日期选择 + 描述输入 + 数字键盘 + 保存操作
- [x] 3.2 实现新建模式：表单初始化（reset）、保存逻辑（校验 + repository.create + 导航回退）
- [x] 3.3 实现编辑模式：接收交易 ID 路由参数、loadFromEntity 回填、保存逻辑（repository.update + 导航回退）
- [x] 3.4 实现多账户模式下的账户选择：条件展示账户下拉、默认选中默认账户
- [x] 3.5 Widget 测试：记账页面核心交互 `test/features/transaction/presentation/screens/transaction_form_screen_test.dart`

## 4. 首页

- [x] 4.1 创建收支汇总卡片 `lib/features/home/presentation/widgets/summary_card.dart`：展示本月总收入/总支出，消费 summaryProvider
- [x] 4.2 创建最近交易条目组件 `lib/features/home/presentation/widgets/recent_transaction_tile.dart`：展示分类图标、描述/分类名、金额（颜色区分类型）、日期
- [x] 4.3 创建首页 `lib/features/home/presentation/screens/home_screen.dart`：汇总卡片 + 最近交易列表（消费 recentTransactionsProvider）+ 空状态处理
- [x] 4.4 Widget 测试：首页展示 `test/features/home/presentation/screens/home_screen_test.dart`

## 5. 交易明细列表

- [x] 5.1 创建交易条目组件 `lib/features/transaction/presentation/widgets/transaction_tile.dart`：分类图标、描述/分类名、金额（类型颜色区分）、支持点击编辑和滑动删除
- [x] 5.2 创建每日分组头 `lib/features/transaction/presentation/widgets/daily_group_header.dart`：日期标题 + 当日收入/支出小计
- [x] 5.3 创建筛选栏 `lib/features/transaction/presentation/widgets/filter_bar.dart`：日期范围快捷选项 chips + 类型筛选 chips + 搜索栏
- [x] 5.4 创建高级筛选面板（BottomSheet）：分类多选、金额范围输入、账户筛选（多账户模式下）
- [x] 5.5 创建明细列表页面 `lib/features/transaction/presentation/screens/transaction_list_screen.dart`：CustomScrollView + SliverList 按日分组展示、筛选栏、删除确认、空状态
- [x] 5.6 Widget 测试：明细列表页面 `test/features/transaction/presentation/screens/transaction_list_screen_test.dart`

## 6. 设置页面

- [x] 6.1 创建设置页面 `lib/features/settings/presentation/screens/settings_screen.dart`：多账户开关 SwitchListTile + 账户管理入口（条件展示）+ 分类管理入口
- [x] 6.2 创建账户管理页面 `lib/features/account/presentation/screens/account_manage_screen.dart`：活跃账户列表、创建/编辑/归档操作、预设账户保护
- [x] 6.3 创建分类管理页面 `lib/features/category/presentation/screens/category_manage_screen.dart`：支出/收入 Tab 切换、ReorderableListView 拖拽排序、隐藏/显示切换、创建/编辑/删除操作
- [x] 6.4 Widget 测试：设置页面 `test/features/settings/presentation/screens/settings_screen_test.dart`
- [x] 6.5 Widget 测试：账户管理页面 `test/features/account/presentation/screens/account_manage_screen_test.dart`
- [x] 6.6 Widget 测试：分类管理页面 `test/features/category/presentation/screens/category_manage_screen_test.dart`

## 7. 集成与验证

- [x] 7.1 运行 `dart format` 格式化所有新增文件
- [x] 7.2 运行 `flutter analyze` 确保无静态分析错误
- [x] 7.3 运行 `flutter test` 确保所有测试通过
- [x] 7.4 运行 `build_runner` 生成 Riverpod 代码（如有新增 provider）
