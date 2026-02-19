## Why

数据层和领域层已就绪（账户、分类、交易记录的完整 CRUD + 查询能力），但 App 目前只有一个空白占位页面。用户无法实际使用任何记账功能。需要构建完整的 UI 层，将已有的数据能力转化为可交互的产品体验，实现"打开即可记账"的 P1 目标。

## What Changes

- 实现**首页**：展示本月收支汇总卡片 + 最近交易列表，提供快速记账入口（FAB）
- 实现**记账页面**：金额数字键盘输入、收支类型切换（支出/收入/转账）、分类选择网格（含最近使用快捷区 + 时段推荐高亮）、日期快捷选择（今天/昨天/前天 + 日期选择器）、可选描述输入、转账时显示方向选择和对方信息
- 实现**交易明细列表页**：按日分组展示、每日小计（收入/支出）、支持日期/分类/金额范围/关键词筛选
- 实现**设置页面**：多账户开关、账户管理（多账户模式下）、分类管理（排序/隐藏/新增）
- 配置 **go_router 路由**：首页 → 记账页、首页 → 明细列表、首页 → 设置
- 实现统一的 **Material 3 主题**和基础交互组件

## Capabilities

### New Capabilities

- `home-screen`：首页展示——本月收支汇总、最近交易列表、快速记账入口
- `transaction-form`：记账表单交互——金额输入、类型切换、分类选择（含智能排序 UI）、日期选择、描述输入、转账专属字段
- `transaction-list-screen`：交易明细列表——按日分组展示、日小计、多维度筛选 UI
- `settings-screen`：设置与管理——多账户开关、账户管理列表、分类管理（排序/隐藏/新增/编辑）

### Modified Capabilities

（无——本次不修改已有数据层/领域层 spec 的行为定义）

## Impact

- **代码**：新增 `lib/features/home/presentation/`、扩展 `lib/features/transaction/presentation/`、`lib/features/account/presentation/`、`lib/features/category/presentation/` 的 Widget 层
- **依赖**：无新增外部依赖，复用现有 flutter_riverpod、go_router、intl
- **路由**：替换 `app.dart` 中的占位路由为完整页面路由体系
- **测试**：新增 Widget 测试覆盖各页面核心交互
