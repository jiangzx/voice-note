## ADDED Requirements

### Requirement: 语音状态动画
系统 SHALL 根据当前语音状态展示对应的动画效果。LISTENING 状态 SHALL 展示中心圆点缓慢脉冲呼吸动画。RECOGNIZING 状态 SHALL 展示环形声波扩散动画。处理中（NLP 解析）SHALL 展示圆点快速跳动动画。保存成功 SHALL 展示打勾动画 + 短触感反馈。所有动画 SHALL 使用设计令牌中定义的时长和曲线。

#### Scenario: 监听态动画
- **WHEN** 语音状态为 LISTENING
- **THEN** 系统 SHALL 展示主题色圆点脉冲呼吸动画

#### Scenario: 识别态动画
- **WHEN** 语音状态为 RECOGNIZING
- **THEN** 系统 SHALL 展示声波扩散动画并高亮显示

#### Scenario: 保存成功反馈
- **WHEN** 交易保存成功
- **THEN** 系统 SHALL 展示打勾动画并触发设备触感反馈

### Requirement: 确认卡片
系统 SHALL 在 CONFIRMING 状态展示交易确认卡片。卡片 SHALL 展示已解析的所有字段：金额、分类、日期、描述、类型、账户。每个字段 SHALL 可点击进入编辑。金额修改时 SHALL 以动画过渡更新。

#### Scenario: 展示确认卡片
- **WHEN** NLP 解析完成且状态切换为 CONFIRMING
- **THEN** 系统 SHALL 以上浮动画展示确认卡片，包含所有已提取字段

#### Scenario: 编辑确认卡片字段
- **WHEN** 用户点击确认卡片上的"金额"字段
- **THEN** 系统 SHALL 展示金额编辑面板供用户手动修改

#### Scenario: null 字段提示
- **WHEN** 确认卡片中 amount=null
- **THEN** 系统 SHALL 在金额字段展示"请补充金额"提示，该字段 SHALL 高亮标记

### Requirement: 对话气泡
系统 SHALL 在语音记账页顶部展示对话气泡界面。助手（小记）消息 SHALL 展示在左侧，用户消息 SHALL 展示在右侧。气泡 SHALL 自动滚动到最新消息。

#### Scenario: 助手欢迎语
- **WHEN** 用户进入语音记账页
- **THEN** 系统 SHALL 在左侧展示助手气泡："你好，想记点什么？"

#### Scenario: 用户语音文本
- **WHEN** ASR 返回用户的识别文本"午饭花了35"
- **THEN** 系统 SHALL 在右侧展示用户气泡，内容为识别文本

#### Scenario: 助手确认询问
- **WHEN** NLP 解析完成
- **THEN** 系统 SHALL 在左侧展示助手气泡，描述已解析的交易信息并询问确认

### Requirement: 语音纠错
系统 SHALL 支持用户通过语音纠正已解析的交易信息。系统 SHALL 识别纠错意图关键词（"不对"、"改一下"、"金额改成XX"、"分类改成XX"）并定位修改字段。整条取消 SHALL 由"不要了"、"取消"、"删掉"等关键词触发。

#### Scenario: 语音修改金额
- **WHEN** 确认卡片展示 amount=35 且用户说"不对，是45"
- **THEN** 系统 SHALL 将金额更新为 45 并以动画反映变更

#### Scenario: 语音修改分类
- **WHEN** 用户说"分类改成购物"
- **THEN** 系统 SHALL 将分类更新为"购物"

#### Scenario: 语音取消当前记录
- **WHEN** 用户说"不要了"或"取消"
- **THEN** 系统 SHALL 丢弃当前记录，状态 SHALL 回到 LISTENING

### Requirement: 连续记账
系统 SHALL 支持用户在一次语音会话中连续记录多笔交易。每笔交易确认保存后，系统 SHALL 通过助手气泡提示"记好了，还有吗？"并回到 LISTENING 状态。退出时 SHALL 播报本次会话的汇总信息。

#### Scenario: 连续记两笔
- **WHEN** 用户说"午饭35" → 确认 → 系统提示"还有吗？" → 用户说"打车28" → 确认
- **THEN** 系统 SHALL 分别保存两笔交易，每笔确认后回到 LISTENING 状态

#### Scenario: 用户主动退出
- **WHEN** 用户说"没了"或"拜拜"，或通过返回键/手势退出
- **THEN** 若本次会话有已保存的交易，系统 SHALL 先显示汇总消息（"本次共记录 N 笔，合计 ¥XX.XX"），然后结束语音会话并返回上一页
- **NOTE**: TTS 语音播报汇总为 Phase 3 范畴，当前以系统消息文本形式展示

### Requirement: 消息类型系统
对话气泡 SHALL 支持四种消息类型：normal（普通对话）、system（系统提示）、error（错误提示）、success（成功提示）。不同类型 SHALL 有视觉差异化展示：normal 使用标准气泡；system 使用居中灰色小标签；error 使用错误色图标气泡；success 使用成功色图标气泡。

#### Scenario: 错误消息展示
- **WHEN** NLP 解析失败
- **THEN** 系统 SHALL 在聊天区域展示 error 类型消息（带错误图标和红色背景）

#### Scenario: 保存成功消息
- **WHEN** 交易保存成功
- **THEN** 系统 SHALL 在聊天区域展示 success 类型消息，同时 SHALL 弹出浮动 SnackBar 短暂提示

### Requirement: NLP 处理指示器
系统 SHALL 在 NLP 解析期间展示加载动画。解析期间输入区域 SHALL 禁用（防止重复提交）。状态 SHALL 通过 isProcessing 字段管理。

#### Scenario: 解析中状态
- **WHEN** 用户提交文本且 NLP 正在处理
- **THEN** 系统 SHALL 展示加载指示器，文字输入框和发送按钮 SHALL 禁用

#### Scenario: 解析完成
- **WHEN** NLP 解析完成（成功或失败）
- **THEN** isProcessing SHALL 变为 false，输入区域 SHALL 恢复可用

### Requirement: 确认卡片增强
确认卡片 SHALL 以 slide-up + fade-in 动画入场。卡片 SHALL 展示识别来源徽标（Local/AI + 置信度指示器）。缺失字段（null 值）SHALL 以红色斜体高亮提示"请补充XX"。

#### Scenario: 来源徽标展示
- **WHEN** NLP 解析完成且结果来自本地引擎
- **THEN** 确认卡片 SHALL 展示"本地"徽标，置信度 SHALL 以 1-3 个圆点表示（<0.5 低/0.5-0.8 中/≥0.8 高）

#### Scenario: 缺失字段提示
- **WHEN** 确认卡片中 category=null
- **THEN** 分类字段 SHALL 以红色斜体展示"请补充分类"，SHALL 可点击进入分类选择

### Requirement: 收入/支出/转账类型切换
确认卡片金额行 SHALL 内联类型切换控件。用户 SHALL 可通过点击在 EXPENSE → INCOME → TRANSFER 循环切换。类型切换 SHALL 以颜色动画反映变化（支出红/收入绿/转账蓝）。

#### Scenario: 类型切换
- **WHEN** 用户在确认卡片上点击当前类型标签
- **THEN** 系统 SHALL 循环切换到下一个类型，金额颜色 SHALL 同步变化

### Requirement: 统一字段编辑器
系统 SHALL 提供统一的 bottom sheet 编辑体验。金额 SHALL 使用数字键盘；分类 SHALL 从数据库列表中选择；日期 SHALL 使用 Material DatePicker；账户 SHALL 从数据库列表中选择；描述 SHALL 使用多行文本输入。编辑后 SHALL 通过 ParseResult.copyWith 更新对应字段。

#### Scenario: 编辑金额
- **WHEN** 用户点击确认卡片上的金额字段
- **THEN** 系统 SHALL 展示带数字键盘的 bottom sheet，提交后 SHALL 更新金额

#### Scenario: 编辑分类
- **WHEN** 用户点击确认卡片上的分类字段
- **THEN** 系统 SHALL 展示分类列表 bottom sheet（从数据库查询），选择后 SHALL 更新分类

### Requirement: 触觉反馈
系统 SHALL 在关键交互节点提供分级触觉反馈。SHALL 使用以下强度映射：语音检测到 → lightImpact；识别完成 → mediumImpact；保存成功 → heavyImpact；错误 → vibrate。

#### Scenario: 保存成功反馈
- **WHEN** 交易保存成功
- **THEN** 系统 SHALL 触发 heavyImpact 触觉反馈 + 浮动 SnackBar + success 消息

### Requirement: 历史数据动态快捷词
键盘输入模式 SHALL 展示基于历史记账数据动态生成的快捷输入词。系统 SHALL 查询最近 200 笔交易，按分类名和描述词频率排序，生成最多 16 个快捷词。不足时 SHALL 以默认词补充。快捷词列表 SHALL 在每次保存交易后刷新。

#### Scenario: 动态快捷词展示
- **WHEN** 用户在键盘模式下且有历史交易数据
- **THEN** 系统 SHALL 展示按使用频率排序的快捷词 Chip 列表

#### Scenario: 快捷词点击
- **WHEN** 用户点击快捷词"午饭"
- **THEN** 系统 SHALL 将"午饭"追加到输入框光标位置

### Requirement: 首次使用引导
系统 SHALL 在用户首次进入语音记账页时展示教程对话框。教程 SHALL 为 3 页 PageView，分别介绍语音模式、键盘输入和确认操作。已读状态 SHALL 通过 SharedPreferences 持久化，每台设备仅展示一次。

#### Scenario: 首次进入展示引导
- **WHEN** 用户首次进入语音记账页（SharedPreferences 无已读标记）
- **THEN** 系统 SHALL 展示教程对话框

#### Scenario: 再次进入不展示
- **WHEN** 用户再次进入语音记账页（SharedPreferences 已有已读标记）
- **THEN** 系统 SHALL NOT 展示教程对话框

### Requirement: 无障碍支持
语音记账 UI SHALL 为所有交互组件提供 Semantics 语义标签。确认卡片、聊天气泡、录音控件、快捷词 Chip 等 SHALL 包含描述性 label。状态动画 SHALL 使用 liveRegion 向屏幕阅读器实时通报状态变化。

#### Scenario: 确认卡片无障碍
- **WHEN** 屏幕阅读器聚焦到确认卡片
- **THEN** 系统 SHALL 朗读交易摘要（如"确认交易：支出35元，分类餐饮"）

#### Scenario: 录音按钮无障碍
- **WHEN** 屏幕阅读器聚焦到按住说话按钮
- **THEN** 系统 SHALL 根据状态朗读"长按说话"或"正在录音，松开停止"

#### Scenario: 离线横幅无障碍
- **WHEN** 设备离线且屏幕阅读器活动
- **THEN** 离线横幅 SHALL 以 liveRegion 自动通报"当前离线，仅使用本地解析"
