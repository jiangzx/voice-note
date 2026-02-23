# BatchConfirmationCard UX Spec

## 实际行为与差异说明（以当前实现为准）

- **卡片容器**：背景为 `AppColors.backgroundSecondary`，圆角为 `AppRadius.cardAll`（20px）。列表区域 4+ 笔时最大高度为 240dp（非屏幕 60%）。
- **Header**：仅展示「X 笔待确认」；全部处理完后仍为该格式，无「✓ 已完成」徽标。
- **Summary bar**：展示「待确认合计」与待确认金额合计，无「共N笔 · 支出¥X · 收入¥Y」分项。
- **Action bar**：始终为「取消」+「全部确认」；全部逐条处理完后按钮禁用，无单独「完成」按钮。
- **行内交互**：未实现「点击整行展开单笔详情」与「点击类型 Chip 切换类型」；仅支持滑动确认/取消。
- **滑动方向**：左滑取消（露出 errorContainer + 删除图标）、右滑确认（露出 primaryContainer + ✓），与下文章节一致。
- **无障碍**：行语义、liveRegion 已实现；小屏/大屏/横屏响应式与卡片内错误条以当前实现为准，部分未完全按本文实现。

---

## Design Principles

1. **单笔零退化**: `batch.size == 1` 时展示现有 `ConfirmationCard`，用户体验完全不变
2. **语音输入 + 视觉审核**: 语音是输入/纠正通道，UI 是审核/浏览通道
3. **渐进式复杂度**: 2-3 笔时列表紧凑；4+ 笔时可滚动；操作始终简单
4. **状态可见**: 每笔的 pending/confirmed/cancelled 状态通过颜色、图标、动画即时可见

## Layout Architecture

```
┌──────────────────────────────────────────────┐
│ [AI 识别 ●●○]                    [2笔待确认]  │  ← Header: source badge + pending count
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ 1  🔴支出  ¥60.00   餐饮   吃饭        │ │  ← Item row (swipeable)
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 2  🔴支出  ¥60.00   洗浴   洗脚        │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 3  🟢收入  ¥30.00   红包   红包        │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 4  🟢收入  ¥90.00   工资   工资        │ │
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ 待确认合计                          ¥XXX     │  ← Summary bar（当前实现）
├──────────────────────────────────────────────┤
│  [ 取消 ]          [ ✓ 全部确认 ]         │  ← Action bar
└──────────────────────────────────────────────┘
```

## Card Container

- **背景**: `AppColors.backgroundSecondary`（当前实现）
- **圆角**: `AppRadius.cardAll` (20px)
- **内边距**: `AppSpacing.lg` (16px)
- **列表最大高度**: 4+ 笔时为 240dp，内部可滚动（当前实现；非屏幕 60%）
- **入场动画**: slide-up 40px + fade-in，`AppDuration.normal` (300ms)，`Curves.easeOutCubic`

## Header

- **来源**: 含 LLM 解析时展示「AI 识别」，否则「本地识别」
- **Pending count badge**: 实时展示待确认笔数「X 笔待确认」，颜色 `primaryContainer`；全部处理完后仍为该格式（当前实现无「✓ 已完成」）

## Item Row

### 布局

```
┌─────────────────────────────────────────────────┐
│  [序号]  [类型Chip]  [金额]       [分类] [描述] │
│   48dp     auto       flex-end     auto   auto  │
└─────────────────────────────────────────────────┘
```

- **行高**: 56dp（满足 48dp 最小触控目标 + 上下 4dp padding）
- **序号**: 1-based，`bodySmall`，`outline` 颜色，宽 24dp 居中
- **类型 Chip**: 复用现有类型切换 badge（支出/收入/转账），点击可切换
- **金额**: `titleMedium`，`fontWeight: w600`，使用 `TransactionColors` 根据类型着色
- **分类**: `bodyMedium`，`onSurface` 颜色
- **描述**: `bodySmall`，`outline` 颜色（仅 description != category 时显示）

### 状态可视化

| 状态 | 背景色 | 左侧指示器 | 文字 | 可交互 |
|---|---|---|---|---|
| **pending** | 透明 | 无 | 正常 | 是 |
| **confirmed** | `primaryContainer` @ 0.3 alpha | ✓ 绿色圆点 | 正常 | 否（置灰） |
| **cancelled** | `errorContainer` @ 0.15 alpha | ✗ 灰色圆点 | 删除线 + 0.5 alpha | 否（置灰） |

### 状态变化动画

- **pending → confirmed**: 背景色渐变（0 → primaryContainer），左侧 ✓ 图标 scale-in 150ms
- **pending → cancelled**: 背景色渐变（0 → errorContainer），高度收缩至 40dp（250ms），文字加删除线
- **纠正更新**: 变化字段高亮闪烁（黄色背景 200ms → 消退 300ms），`HapticFeedback.selectionClick()`

### 点击交互

- **滑动**: 左滑取消、右滑确认（见下节）；当前实现未提供「点击整行展开详情」与「点击类型 Chip 切换类型」
- **触控反馈**: 滑动触发 `HapticFeedback.selectionClick()`；按钮点击使用 selectionClick / lightImpact

## Swipe Gestures

### 左滑取消（单笔）

- **方向**: 左滑（endToStart）露出右侧 `secondaryBackground`
- **背景**: `theme.colorScheme.errorContainer`，显示删除图标（当前实现无「取消」文字）
- **行为**: 松手后调用 `onCancelItem`，行状态变为 cancelled；`confirmDismiss` 返回 false 故行不滑出
- **反馈**: `HapticFeedback.selectionClick()`（当前实现）

### 右滑确认（单笔）

- **方向**: 右滑（startToEnd）露出左侧 `background`
- **背景**: `theme.colorScheme.primaryContainer`，显示 ✓ 图标
- **行为**: 松手后调用 `onConfirmItem`，行状态变为 confirmed
- **反馈**: 同上

### Swipe 约束

- 已确认/已取消的行 SHALL NOT 响应滑动手势
- 滑动进行中 SHALL 禁用列表滚动（避免手势冲突）
- 单笔模式 (size == 1) 不显示 swipe 提示（保持现有 UI）

## Summary Bar

- 与列表、Action bar 一同展示（当前实现始终显示）
- 展示「待确认合计」与待确认项的金额合计（已取消/已确认不计入）
- 金额随纠正与逐条确认实时更新

## Action Bar

### 多笔模式 (size > 1)

- **「取消」与「全部确认」按钮**: 始终展示；无 pending 或 isLoading 时 disabled
- 当前实现无「完成」单按钮：全部逐条处理完后仍为两按钮禁用态

### 单笔模式 (size == 1)

保持现有 `_ActionRow` 不变：`[ 取消 ]  [ ✓ 确认记账 ]`

## Scrolling Behavior

- **≤ 3 笔**: Column 布局，无列表滚动
- **4+ 笔**: 列表区域固定最大高度 240dp（当前实现），可纵向滚动；header 与 action bar 固定
- 列表项圆角 `AppRadius.mdAll`

## Transitions & Animations

### 1. 新笔追加（append）
- 新行从底部 slide-in (250ms, easeOutCubic): translateY 56→0, opacity 0→1
- 同时 summary bar 数字 AnimatedSwitcher 更新

### 2. 笔取消（cancelItem）
- 行背景渐变至 errorContainer @ 0.3，文字删除线 + opacity 0.5，AnimatedContainer 250ms
- 状态图标切换为 cancelled 图标（250ms scale transition）

### 3. 纠正更新（updateItem）
- 当前实现：通过 `onDraftBatchUpdated` 刷新整卡；pending 行在 LLM 请求期间显示 shimmer，无字段级高亮闪烁

### 4. 全部确认（confirmAll）
- 由上层保存后关闭确认卡片；卡片内无 stagger 或 slide-down 动画（当前实现）

### 5. 展开详情（点击行）
- 当前未实现：无点击行展开单笔详情的交互

## Voice + Touch Hybrid

### 语音纠正进行中
- LLM 请求发起时：被修改的行显示 shimmer loading 效果
- LLM 返回后：shimmer 停止，字段更新动画触发

### 混合操作冲突处理
- 当前实现：滑动、纠正由编排器与状态驱动；无行内编辑弹窗与展开详情，故无上述冲突分支实现

## Accessibility

- **Semantics**: 每行提供完整语义标签「第{N}笔，{type}{amount}元，{category}，{status}」
- **Swipe hint**: VoiceOver/TalkBack 用户通过自定义操作「确认此笔」「取消此笔」替代滑动
- **Focus order**: Header → 列表行（按序号）→ Summary → Action buttons
- **Live region**: pending count 变化时触发 accessibility announcement

## Responsive Sizing

- 当前实现未对卡片做 360dp/600dp 或横屏的专门布局；以实际 UI 为准

## Error States

- 保存失败与网络错误由上层（语音页/编排器）处理并 TTS 提示；卡片内无独立错误条或「重试保存」按钮（当前实现）
