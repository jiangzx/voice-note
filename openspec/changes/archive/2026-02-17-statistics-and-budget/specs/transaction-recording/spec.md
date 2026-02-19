## ADDED Requirements

### Requirement: 保存后触发预算检查
系统 SHALL 在每次交易保存（创建或编辑）后异步检查该分类的预算状态。检查 SHALL 为非阻塞，SHALL NOT 影响保存操作本身的完成。仅支出类型交易 SHALL 触发检查。收入和转账 SHALL NOT 触发。

#### Scenario: 保存支出后检查预算
- **WHEN** 用户保存一笔"餐饮"支出
- **THEN** 系统 SHALL 异步查询"餐饮"当月总消费和预算金额，判断是否达到 80% 或 100% 阈值

#### Scenario: 保存收入不触发检查
- **WHEN** 用户保存一笔收入交易
- **THEN** 系统 SHALL NOT 触发预算检查

#### Scenario: 无预算的分类不触发
- **WHEN** 用户保存一笔"交通"支出，但"交通"未设置预算
- **THEN** 系统 SHALL NOT 发送任何通知

#### Scenario: 编辑交易触发重新检查
- **WHEN** 用户编辑一笔支出交易（修改金额或分类）
- **THEN** 系统 SHALL 对新分类重新检查预算状态
