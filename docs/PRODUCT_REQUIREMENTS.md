# WeAreFamily 产品需求基线（长期产品化 / 二期MVP）

更新时间：2026-03-20  
状态：当前有效（后续需求和开发默认以本文为单一事实来源）

## 1. 项目初衷（不可偏离）
WeAreFamily 是面向经纪人（B 端）与家庭用户（C 端）的家庭保险管理平台，核心目标是把“看得懂、管得住、可运营”做成长期能力，而不是一次性功能堆叠。

新增并确认的关键初衷：
1. 家庭必须清楚知道自己每年的保险支出是多少，并能与全国平均收入基准对比，判断负担是否合理。
2. 家庭购买的保单要能做“性价比评估”，至少从保额、保障责任、免责/等待期、豁免条款、续保稳定性等维度体现，并结合 AI 给出可解释建议。
3. 上述能力 C 端和 B 端都可用：
- C 端用于家庭自我管理与决策。
- B 端用于家庭池优先级管理、续保推进与服务运营。

## 2. 二期MVP目标（B/C 双端）
### 2.1 成功标准
- C 端可见：年总保费、月均保费、收入占比、性价比报告、改进建议。
- B 端可见：按负担压力 + 性价比 + 到期风险管理家庭池，并可推进任务处理。
- 外部收入基准异常时：系统自动降级到最近快照，核心页面可用。

### 2.2 已确认的产品决策
- 首期深度：运营增强版。
- 性价比方法：规则打分 + AI 解释。
- 收入基准：外部数据源自动更新。
- 基准接入：定时拉取 + 本地快照兜底。

## 3. 需求范围（本期必须落地）
## 3.1 数据与领域模型
- `income_benchmark_snapshots`
  - 字段：source, period, publishedAt, effectiveDate, annualIncome, currency, region, fetchedAt, payload。
- `policy_value_analyses`
  - 字段：valueScore, valueConfidence, dimensions, reasons, recommendations, summary, scoringVersion。
- `ops_tasks`
  - 类型：`renewal_due` / `document_review` / `value_low_confidence` / `missing_data`。
  - 状态：`open` / `in_progress` / `done` / `cancelled`。

现有实体扩展：
- `Policy`：`renewalStatus`、`assigneeUserId`、`lifecycleNote`、`valueScore`、`valueDimensions[]`、`valueSummary`、`valueConfidence`。
- `FamilyInsight`：`annualPremiumTotal`、`monthlyPremiumAvg`、`premiumIncomeRatio`、`benchmarkIncome`、`benchmarkAsOf`。
- `FamilyDocument`：`reviewStatus`、`reviewNotes`、`reviewedByUserId`、`reviewedAt`。

## 3.2 评分与 AI 流水线
固定 100 分模型（首版权重锁定）：
- `coverageAdequacy` 30%
- `affordability` 25%
- `termsQuality` 20%
- `waiverCompleteness` 15%
- `renewalStability` 10%

规则：
- AI 不参与打分，只负责解释与建议文案。
- AI 失败时回退模板解释。
- 低置信度触发：`valueConfidence < 0.65` 或关键字段缺失，自动生成运营任务。

## 3.3 API 范围（保持 `/api/v1`）
- `GET /api/v1/benchmarks/income/current`
- `GET /api/v1/broker/families`（支持按 `risk`、`premiumIncomeRatio`、`valueScore`、`renewalDueDays` 排序/筛选）
- `GET /api/v1/policies/:policyId/value-analysis`
- `POST /api/v1/policies/:policyId/value-analysis/refresh`（broker/admin）
- `PATCH /api/v1/policies/:policyId/lifecycle`
- `GET /api/v1/tasks`
- `PATCH /api/v1/tasks/:taskId`

权限策略：
- `consumer`：仅自己的家庭。
- `broker/admin`：本租户范围。
- 所有新增接口：强制租户隔离。

## 3.4 前端交付范围
C 端：
- 家庭中心新增“年度保费负担卡”：年总保费、月均、收入占比、基准快照时间。
- 保单详情新增“性价比报告卡”：总分、维度、建议、置信度、是否待复核。

B 端：
- 家庭中心新增“家庭运营台”：按压力/风险/性价比查看家庭池。
- 家庭中心新增“任务面板”：续保、低置信度复核、资料补齐任务处理。

统一交互：
- 基准数据过期/失败时，显示“最近快照时间 + 可能过期提示”，不阻断页面主流程。

## 3.5 运维与审计
- 每周定时拉取收入基准（Asia/Shanghai），失败回退最近快照。
- 监控指标：
  - benchmark 拉取成功率/延迟/最近成功时间
  - value-analysis 耗时与失败率
  - 低置信度任务生成率与处理时长
- 审计事件：
  - 续保状态变更
  - 任务状态变更
  - 人工复核提交

## 4. 测试与质量门禁
API 与安全：
- 同租户可访问。
- 跨租户拒绝。
- 角色越权拒绝。
- 新接口契约稳定（benchmarks / broker families / value-analysis / tasks）。

评分与基准：
- 5 个维度边界值。
- 权重计算正确。
- 缺失字段降级与低置信度任务触发正确。
- 外部源成功/超时/异常/快照回退覆盖。

端到端：
- C 端：导入保单 -> 生成报告 -> 查看年支出占比 -> 低置信度提示。
- B 端：家庭池筛选 -> 打开低分家庭 -> 分配续保处理 -> 关闭任务。

## 5. 非目标（本期不做）
- 跨产品实时比价引擎。
- 私有化深度定制优先级提升（本期以 SaaS 为第一优先）。
- 高耦合外部生态集成（先保障可运营、可审计、可回归）。

## 6. 建议扩展（待审批）
以下为建议项，默认“待你批准后排期”：
1. 家庭预算护栏（Budget Guardrail）
- 按家庭目标（保守/平衡/进取）给出“建议保费占比区间”，超出自动预警。

2. 任务 SLA 分层
- 为 `renewal_due` / `document_review` 等任务设置默认时限和超时升级策略（提醒 -> 升级 -> 指派）。

3. 价值分可解释页（Explainability Trace）
- 每个维度支持“字段来源 -> 规则命中 -> 扣分原因 -> 修正入口”一键追踪。

4. 运营周报自动化
- 自动生成租户维度周报：风险家庭变化、低置信度处理效率、续保闭环率。

5. 评分版本灰度
- 支持 `scoringVersion` 灰度发布与回滚，避免规则升级导致业务波动不可控。

## 7. 执行规则
- 新功能必须标注“对应本文哪个章节”。
- 与本文冲突时，先更新本文，再实施代码变更。
- 本文是项目初衷与二期MVP边界的唯一基线。
