## MODIFIED Requirements

### Requirement: 快速记账入口
系统 SHALL 在首页提供快速记账入口（FAB），触发后 SHALL 导航至记账流程。首页 SHALL 同时提供语音记账快捷入口，触发后 SHALL 导航至语音记账页（LISTENING 状态）。语音记账入口 SHALL 以大号麦克风图标展示，视觉层级高于手动记账入口。

#### Scenario: 触发快速记账
- **WHEN** 用户通过首页快速入口触发记账
- **THEN** 系统 SHALL 导航至记账流程，表单状态 SHALL 为初始状态（类型=支出、金额=0、日期=今天）

#### Scenario: 触发语音记账
- **WHEN** 用户通过首页语音记账入口触发
- **THEN** 系统 SHALL 导航至语音记账页，状态 SHALL 为 LISTENING（麦克风开启、VAD 启动）
