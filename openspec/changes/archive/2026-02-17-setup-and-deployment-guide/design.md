## Design Decisions

### D1: 文档放置位置
- 选项 A: 根目录 `docs/`（与现有 PRD 同级）
- 选项 B: 各模块内部 README
- **选择 A**: 集中管理，方便查阅。现有 PRD 和技术设计已在 `docs/` 目录

### D2: OpenSpec 追踪方式
- 创建 `openspec/specs/deployment/spec.md` 作为主 spec，定义部署配置的系统行为
- 文档本身放在 `docs/`，spec 定义"系统的配置需求"
- 未来新增配置项时，先更新 spec，再同步到文档

### D3: 文档结构
```
docs/
  SETUP_GUIDE.md          # 端到端上手指南
  DEPLOYMENT_GUIDE.md     # 生产部署教程
  Phase2_语音记账_技术设计.md  # (existing)
  PRD_随口记_v1.1.md         # (existing)
```

## Directory Impact
- `docs/SETUP_GUIDE.md` — 新增
- `docs/DEPLOYMENT_GUIDE.md` — 新增
- `openspec/specs/deployment/spec.md` — 新增
