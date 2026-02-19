## MODIFIED Requirements

### Requirement: 输入模式切换
系统 SHALL 支持三种输入模式：自动模式（VAD 自动检测）、按住说话（PTT）、键盘输入。默认 SHALL 为自动模式。用户 SHALL 可在语音记账页底部随时切换。模式切换控件 SHALL 在所有三种输入模式下始终可见。用户的默认模式偏好 SHALL 可在设置中配置并持久化。

#### Scenario: 自动模式工作
- **WHEN** 输入模式为"自动"且 VAD 检测到人声
- **THEN** 系统 SHALL 自动启动 ASR 识别

#### Scenario: 按住说话模式工作
- **WHEN** 输入模式为"按住说话"且用户按下录音按钮
- **THEN** 系统 SHALL 在按住期间录音并发送到 ASR；松开时结束本次输入

#### Scenario: 切换到键盘输入
- **WHEN** 用户在语音记账页切换到键盘输入模式
- **THEN** 系统 SHALL 关闭麦克风和 VAD，展示文字输入框

#### Scenario: 从键盘切回语音模式
- **WHEN** 用户从键盘模式切换到自动或按住说话模式
- **THEN** 系统 SHALL 重新启动麦克风和 VAD

#### Scenario: 键盘模式下模式切换控件可见
- **WHEN** 用户处于键盘输入模式
- **THEN** 模式切换控件 SHALL 保持可见，用户 SHALL 可切换到自动或按住说话模式
