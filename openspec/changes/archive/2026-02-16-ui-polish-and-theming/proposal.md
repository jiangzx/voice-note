## Why

当前 UI 层功能已完备但体验粗糙：页面无转场动画、无深色模式、间距/排版不统一、加载/空/错误状态简陋、列表存在潜在性能问题（TransferFields 控制器泄漏、NumberPad 每次 build 重建列表）。用户感知的品质差距需要在功能稳定后立即补齐。

## What Changes

- **设计令牌体系**：抽取统一的间距、圆角、字体样式常量，替代散落各处的硬编码值
- **深色模式**：新增 `darkTheme`，`TransactionColors` 同步适配；支持跟随系统或手动切换
- **主题色自定义**：提供若干预设配色方案（teal / indigo / orange 等），用户可在设置中选择，持久化到本地
- **页面转场动画**：为主要路由添加 Material 3 转场（SharedAxisTransition / FadeThroughTransition）；FAB → 记账页使用 Hero 动画
- **微交互动画**：列表项入场 staggered fade-in、SnackBar 滑入、SegmentedButton 切换动效
- **空状态 / 加载态 / 错误态统一**：提取共享组件 `EmptyState`、`ErrorState`（含重试）、`ShimmerPlaceholder`，在所有页面复用
- **性能修复**：修复 TransferFields 控制器泄漏、NumberPad 常量化静态列表、FilterBar 受控搜索输入
- **列表性能**：确保大数据量交易列表使用 `const` 子树与合理 Key 策略

## Capabilities

### New Capabilities

- `theming-and-appearance`：深色模式切换、主题色自定义、设计令牌体系
- `ui-transitions`：页面转场动画、微交互动画、共享元素过渡

### Modified Capabilities

- `home-screen`：统一使用新的加载/空/错误状态组件，应用设计令牌
- `transaction-form`：应用设计令牌和动画；修复 TransferFields 控制器泄漏
- `transaction-list-screen`：应用设计令牌和动画；列表性能优化
- `settings-screen`：新增深色模式切换和主题色选择入口

## Impact

- **新增依赖**：`animations`（Material motion）、`shimmer`（骨架屏）
- **修改文件范围**：`lib/app/theme.dart`（重构）、`lib/app/router.dart`（转场）、`lib/shared/widgets/`（新共享组件）、所有 `presentation/screens/` 和部分 `widgets/`
- **数据层**：新增用户偏好存储（主题色、深色模式选择），可使用 `shared_preferences`
- **测试影响**：需新增设计令牌单元测试、动画 widget 测试；现有 widget 测试需适配主题变更
