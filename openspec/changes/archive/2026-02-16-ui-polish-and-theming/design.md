## Context

当前 UI 层功能齐全但缺少体验层设计。已有问题包括：
- 仅 light theme，无深色模式
- 所有路由使用 `NoTransitionPage`，无任何转场效果
- 间距/字体硬编码分散在各文件中（8、12、16、20、24、32 无统一系统）
- 加载态仅 `CircularProgressIndicator`，无骨架屏
- 空状态和错误态风格不统一，错误态无重试机制
- `TransferFields` 在 `build` 中创建 `TextEditingController` 导致泄漏
- `NumberPad` 每次 build 重建静态列表

## Goals / Non-Goals

**Goals:**

- 建立可复用的设计令牌体系（间距、圆角、字体），一处修改全局生效
- 支持深色模式（跟随系统 / 手动切换），`TransactionColors` 同步适配
- 提供预设主题色方案，用户可选择，持久化到本地
- 为主要路由添加 Material 3 Motion 转场
- 在首页/列表页添加微交互动画（列表项入场、FAB → 表单 Hero）
- 统一所有页面的加载/空/错误状态组件
- 修复已知性能问题和控制器泄漏

**Non-Goals:**

- 不实现完全自定义的主题编辑器（仅预设配色方案）
- 不实现复杂的 page transition graph（仅主要路由）
- 不重构路由架构，保持现有 `ShellRoute` 结构
- 不添加国际化支持

## Decisions

### D1: 设计令牌方案

**决定**：在 `lib/app/design_tokens.dart` 中定义 `AppSpacing`（4 的倍数）、`AppRadius`、`AppDuration`、`AppTypography` 四组常量类。

**备选方案**：
- A) `ThemeExtension` 注入 → 过于重量级，令牌是静态值不需要动态切换
- B) 散落在各文件 → 当前现状，已证明不一致

**理由**：静态 `abstract final class` + `const` 值最简洁，IDE 自动补全友好，不引入额外依赖。

```dart
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
```

### D2: 深色模式实现

**决定**：扩展 `lib/app/theme.dart`，新增 `appDarkTheme`，使用相同的 `colorSchemeSeed` + `Brightness.dark`。`TransactionColors` 为深色模式提供调亮的色值。`ThemeMode` 状态由 Riverpod provider 管理，持久化到 `shared_preferences`。

**备选方案**：
- A) drift 表存储 → 过重，用户偏好适合 KV 存储
- B) `ThemeMode.system` only → 用户失去手动控制

**理由**：`shared_preferences` 是 Flutter 生态中最轻量的 KV 持久化方案，三种 mode（system / light / dark）覆盖所有用户需求。

### D3: 主题色自定义

**决定**：预定义 5-6 个 `ColorSchemeSeed` 方案（teal、indigo、orange、purple、pink、green），用户在设置中选择后持久化到 `shared_preferences`。`ThemeData` 生成函数接受 seed color 参数。

**备选方案**：
- A) 自由色轮选择 → 开发成本高，大部分用户不需要
- B) 固定 teal → 无个性化

**理由**：预设方案在开发成本和用户体验间取得最佳平衡。

### D4: 主题状态管理

**决定**：创建 `lib/features/settings/presentation/providers/theme_providers.dart`，包含：
- `themeModeProvider`: `NotifierProvider<ThemeMode>` 管理亮/暗模式
- `themeColorProvider`: `NotifierProvider<Color>` 管理主题色 seed
- 两个 provider 均使用 `shared_preferences` 持久化

`app.dart` 中 `MaterialApp.router` 使用 `ref.watch` 绑定这两个 provider。

**理由**：将主题偏好放在 settings feature 的 presentation 层，遵循 Feature-First 架构；provider 粒度细（mode 和 color 独立）避免不必要的重建。

### D5: 页面转场动画

**决定**：使用 `animations` package 的 Material Motion 系统：
- Tab 切换（ShellRoute 内）: `FadeThroughTransition`
- Push 页面（记账、账户管理、分类管理）: `SharedAxisTransition` (Y 轴)
- FAB → 记账页: `OpenContainer` 转场

在 `router.dart` 中通过自定义 `CustomTransitionPage` 包装。

**备选方案**：
- A) 自定义 `AnimationController` → 重复造轮子
- B) `CupertinoPageRoute` → 不符合 Material 3 风格
- C) 不使用 OpenContainer → 可行但 FAB 过渡不自然

**理由**：`animations` 是 Google 官方维护的 Material Motion 实现，与 Material 3 高度契合。

### D6: 微交互动画

**决定**：
- 列表项入场：`AnimatedSwitcher` + `FadeTransition` 在数据加载完成时统一淡入（非 staggered，保持简单）
- 金额数字变化：`AnimatedDefaultTextStyle` 平滑过渡
- SegmentedButton 切换已有 Material 3 默认动效，无需额外处理

**备选方案**：
- A) Staggered animation per item → 性能开销大，列表复杂度高
- B) Lottie 动效 → 过于华丽，不符合记账工具定位

**理由**：轻量级动画足以提升感知品质，不影响性能。

### D7: 统一状态组件

**决定**：在 `lib/shared/widgets/` 中创建三个共享组件：
- `EmptyStateWidget`：图标 + 标题 + 描述（可选）+ 操作按钮（可选）
- `ErrorStateWidget`：图标 + 错误信息 + 重试按钮
- `ShimmerPlaceholder`：基于 `shimmer` package 的骨架屏占位

所有页面的 `AsyncValue.when` 统一改用这些组件。

**备选方案**：
- A) 每页独立实现 → 当前现状，已证明不一致
- B) 只用 `ErrorWidget` → 缺少重试功能和空状态

### D8: 性能修复

**决定**：
- `TransferFields`：提升 `TextEditingController` 到 `StatefulWidget`，在 `dispose` 中释放
- `NumberPad`：将 `_keys` 列表声明为 `static const`
- `FilterBar`：将搜索 `TextEditingController` 提升到 `StatefulWidget`，绑定 `onChanged`
- 列表：确保 `TransactionTile` 和 `DailyGroupHeader` 的 `const` 子组件最大化

**理由**：直接修复已知缺陷，低风险高收益。

### D9: 目录结构

新增/修改文件：

```
lib/
├── app/
│   ├── design_tokens.dart (NEW)
│   ├── theme.dart (MODIFIED - dark theme, seed color param)
│   └── router.dart (MODIFIED - transitions)
├── shared/
│   └── widgets/
│       ├── empty_state_widget.dart (NEW)
│       ├── error_state_widget.dart (NEW)
│       └── shimmer_placeholder.dart (NEW)
├── features/
│   ├── settings/
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── theme_providers.dart (NEW)
│   │       └── screens/
│   │           └── settings_screen.dart (MODIFIED)
│   ├── transaction/
│   │   └── presentation/
│   │       ├── widgets/
│   │       │   ├── transfer_fields.dart (MODIFIED - StatefulWidget)
│   │       │   ├── number_pad.dart (MODIFIED - static const keys)
│   │       │   └── filter_bar.dart (MODIFIED - controlled search)
│   │       └── screens/ (MODIFIED - design tokens + state widgets)
│   ├── home/
│   │   └── presentation/
│   │       └── screens/ (MODIFIED - design tokens + state widgets)
│   ├── account/
│   │   └── presentation/
│   │       └── screens/ (MODIFIED - design tokens + state widgets)
│   └── category/
│       └── presentation/
│           └── screens/ (MODIFIED - design tokens + state widgets)
└── app.dart (MODIFIED - dynamic theme)
```

## Risks / Trade-offs

- **[Risk] `animations` package 兼容性** → Material Motion 由 Google 维护，紧跟 Flutter SDK 版本，风险低。Mitigation: 锁定兼容版本。
- **[Risk] `shimmer` package 维护** → 可用 `shimmer` 或手写简单 `LinearGradient` animation 替代。Mitigation: 评估包活跃度后决定。
- **[Risk] 主题切换时重建范围过大** → `colorSchemeSeed` 改变触发整棵 Widget 树重建。Mitigation: `MaterialApp.router` 在树顶层，重建不可避免但频率极低（仅设置时触发）。
- **[Trade-off] 预设主题色 vs 自由选色** → 选择预设方案牺牲灵活性，但简化实现和 UI。
- **[Trade-off] FadeThroughTransition vs 无过渡** → 增加了 Tab 切换时的短暂延迟感，但视觉更流畅。
