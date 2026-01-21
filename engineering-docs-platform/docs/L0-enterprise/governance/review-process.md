# 代码评审流程规范

> 企业级强制约束，确保代码质量与团队协作效率

---

## 一、分支管理规范 [MUST]

### 1.1 分支类型

| 分支类型 | 格式 | 用途 | 生命周期 |
|----------|------|------|----------|
| main | main | 生产环境基准 | 永久 |
| develop | develop | 开发集成基准 | 永久 |
| feature | feature/REQ-ID-描述 | 新功能开发 | 临时（合并后删除） |
| hotfix | hotfix/BUG-ID-描述 | 生产紧急修复 | 临时（合并后删除） |

### 1.2 分支命名

```yaml
format: {type}/REQ-{需求ID}-{简要描述}
examples:
  - feature/REQ-2025001-order-batch-create
  - hotfix/BUG-2025100-payment-timeout-fix
prohibited:
  - feature/test
  - feature/new-function
  - hotfix/fix
```

### 1.3 操作流程

```bash
# 1. 拉取 feature 分支
git checkout develop
git pull origin develop
git checkout -b feature/REQ-2025001-order-batch-create

# 2. 提交代码（必须包含配套文件）
git add src/main/java/com/mall/order/service/OrderBatchService.java
git add src/main/resources/db/migration/V1_20250105_REQ2025001_add_order_batch.sql
git add src/test/java/com/mall/order/service/OrderBatchServiceTest.java

# 3. 提交信息规范
git commit -m "feat(order): 新增订单批量创建接口 [REQ-2025001]"

# 4. 推送并创建 MR
git push origin feature/REQ-2025001-order-batch-create
```

### 1.4 提交信息格式

```yaml
format: "{type}({scope}): {description} [REQ-ID]"
types:
  - feat: 新功能
  - fix: Bug 修复
  - refactor: 重构
  - perf: 性能优化
  - test: 测试
  - docs: 文档
  - chore: 构建/工具
examples:
  - "feat(order): 新增订单批量创建接口 [REQ-2025001]"
  - "fix(payment): 修复支付超时问题 [BUG-2025100]"
```

### 1.5 Flyway 脚本规范

```yaml
format: V{version}_{date}_{REQ-ID}_{description}.sql
examples:
  - V1_20250105_REQ2025001_add_order_batch_column.sql
  - V2_20250110_REQ2025002_create_product_index.sql
rules:
  - 必须与代码一起提交
  - 禁止修改已执行的脚本
  - 生产变更需 DBA 评审
```

---

## 二、代码评审规范 [MUST]

### 2.1 自动化前置检查

```yaml
name: PR Quality Check

on:
  pull_request:
    branches: [main, develop]

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      # 代码规范检查（CheckStyle）
      - name: CheckStyle
        run: mvn checkstyle:check

      # 单元测试 + 覆盖率
      - name: Test with Coverage
        run: mvn test jacoco:report

      - name: Check Coverage Threshold
        run: |
          COVERAGE=$(grep -oP 'Total.*?([0-9]+)%' target/site/jacoco/index.html | grep -oP '[0-9]+' | head -1)
          if [ "$COVERAGE" -lt 80 ]; then
            echo "❌ Coverage $COVERAGE% < 80%"
            exit 1
          fi
          echo "✅ Coverage $COVERAGE% >= 80%"

      # SonarQube 扫描
      - name: SonarQube Scan
        uses: sonarsource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      # 安全扫描（硬编码密钥检测）
      - name: Secret Scanning
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}

      # MyBatis SQL 注入检查
      - name: Check MyBatis SQL Injection
        run: |
          if grep -rn '\$\{' --include="*.xml" src/main/resources/mapper/; then
            echo "❌ Found \${} in MyBatis XML, use #{} instead"
            exit 1
          fi
          echo "✅ MyBatis SQL injection check passed"
```

### 2.2 自动化检查清单

```yaml
automated_checks:
  - 代码规范（CheckStyle + SonarQube）
  - 单元测试覆盖率 ≥80%（JaCoCo）
  - 无 Critical/Blocker 问题
  - MyBatis 使用 #{}
  - 无硬编码密钥
```

### 2.3 PR 模板

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->
## PR 基本信息
- 关联 Issue：#123 或 REQ-2025001（订单批量创建功能）
- 核心修改：OrderBatchService.java（180 行）、Flyway 脚本
- 测试情况：单元测试覆盖率 85%；接口测试通过
- 依赖变更：无新增依赖

## Java 核心评审点（必查）
- [ ] 事务边界：@Transactional 是否加在正确位置？rollbackFor 是否指定？
- [ ] 线程池：线程池参数是否合理？是否会引发 OOM？
- [ ] SQL 性能：是否有索引？是否有全表扫描？
- [ ] 缓存一致性：缓存更新策略是否正确？

## 风险说明
- 无破坏性变更
- 数据库影响：仅新增字段和索引
- 并发测试：压测 1000QPS 无超时

## 自检清单
- [ ] 代码已自测通过
- [ ] 单元测试覆盖率 ≥80%
- [ ] Flyway 脚本已包含（如有 DB 变更）
- [ ] 提交信息符合规范
```

### 2.4 评审检查清单

#### 业务逻辑

| 检查项 | 反例 | 正例 |
|--------|------|------|
| 事务边界 | @Transactional 加在子方法 | 加在入口方法 + rollbackFor |
| 循环依赖 | Controller 注入 Service，Service 又注入 Controller | 用 @Lazy 或拆分服务 |
| 异常处理 | catch 后只打印日志 | catch 后抛出业务异常 |
| 线程池 | new Thread() 执行任务 | 注入全局线程池 |

#### 性能与安全

| 检查项 | 反例 | 正例 |
|--------|------|------|
| SQL 性能 | SELECT *；无索引 | 只查必要字段；有索引 |
| 缓存使用 | 无过期时间；先删后更 | 设过期时间；先更后删 |
| 并发安全 | static int 计数 | AtomicInteger |
| JVM 资源 | 一次加载 1000 条到内存 | 分页查询每次 100 条 |

#### 兼容性

| 检查项 | 反例 | 正例 |
|--------|------|------|
| 接口兼容 | 修改 v1 接口参数类型 | 新增 v2 接口 |
| 代码复用 | 3 个 Service 都写日期格式化 | 抽为 DateUtils 工具类 |
| 配置管理 | 硬编码 Redis 地址 | @Value 读取配置 |

---

## 三、评审规则 [MUST]

### 3.1 评审要求

```yaml
code_review:
  - "所有代码必须至少 1 人 Review 后方可合并"
  - "安全相关变更必须安全团队成员 Review"
  - "架构变更（新增服务、中间件、重大重构）必须架构委员会审批"
  - "数据库 Schema 变更必须 DBA Review"
```

### 3.2 评审时效

| PR 类型 | 评审时效 | 说明 |
|---------|----------|------|
| 普通 PR | 24 小时内 | 工作日内 |
| 紧急修复 | 2 小时内 | 需标注 urgent |
| 架构变更 | 3 个工作日 | 需多人评审 |

---

## 四、文档规范 [SHOULD]

### 4.1 接口文档

```yaml
rules:
  - 使用 Swagger/OpenAPI 自动生成
  - 禁止手动编写接口文档
  - 代码修改自动更新文档
```

```java
// ✅ 正确：Swagger 注解
@Operation(summary = "创建订单", description = "用户下单接口")
@ApiResponses({
    @ApiResponse(responseCode = "200", description = "创建成功"),
    @ApiResponse(responseCode = "400", description = "参数错误")
})
@PostMapping("/api/v1/orders")
public Result<Long> createOrder(@RequestBody @Valid OrderCreateRequest request) {
    return Result.success(orderService.createOrder(request));
}
```

### 4.2 技术文档

```yaml
required_docs:
  - 架构设计文档
  - 数据库设计文档
  - 部署文档
  - 运维手册
location: 统一文档平台（Confluence/语雀）
```

---

## 五、故障复盘规范 [MUST]

### 5.1 复盘流程

```yaml
steps:
  1. 故障时间线梳理
  2. 根因分析（5 Why）
  3. 影响评估
  4. 改进措施
  5. 责任认定（非追责）
  6. 经验沉淀
```

### 5.2 复盘报告模板

```markdown
## 故障概述
- 故障时间：2025-01-05 10:00 - 10:30
- 影响范围：订单服务，影响用户 1000 人
- 故障级别：P1

## 时间线
- 10:00 监控告警：订单服务错误率 >5%
- 10:05 值班人员响应，查看日志
- 10:15 定位原因：数据库连接池耗尽
- 10:20 扩容数据库连接池
- 10:30 服务恢复正常

## 根因分析
直接原因：数据库连接池配置过小（maxPoolSize=10）
根本原因：新增批量查询接口未评估连接池压力

## 改进措施
- 短期：连接池配置调整为 maxPoolSize=50
- 长期：新增接口必须进行压测评审

## 责任认定
- 主责：开发人员（未评估连接池压力）
- 次责：评审人员（未发现问题）
```

---

## 六、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | feature 分支未提交 Flyway 脚本 | 检查 PR 文件列表 |
| 2 | PR 代码量超 500 行 | GitHub PR 统计 |
| 3 | 事务加在子方法 | 代码评审检查 |
| 4 | 接口文档手动编写 | 检查 Swagger 配置 |
| 5 | 故障后无复盘 | 复盘记录查询 |
| 6 | 提交信息不规范 | Git log 检查 |
| 7 | 合并未关联 Issue | PR 描述检查 |
| 8 | 评审只关注代码风格 | 评审记录检查 |
| 9 | 安全变更无安全人员评审 | 检查评审人列表 |
| 10 | 架构变更无架构审批 | 检查审批记录 |
