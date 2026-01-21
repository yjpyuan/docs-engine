# 发布流程规范

> 企业级强制约束，确保发布安全与系统稳定

---

## 一、环境隔离规范 [MUST]

### 1.1 四级环境

| 环境 | 用途 | 资源配置 | 权限管控 |
|------|------|----------|----------|
| dev | 日常调试 | 单机/轻量集群 | 开发人员可读写 |
| test | 功能测试 | 小型集群(2-3 节点) | 测试可读写，开发只读 |
| staging | 回归/性能测试 | 与生产一致 | 仅 CI/CD 可部署 |
| prod | 生产 | 高可用集群(≥3 节点) | 仅 CI/CD 可部署，禁止手动 |

### 1.2 环境一致性

```yaml
rules:
  - Docker 镜像统一基础镜像
  - Terraform 管理基础设施
  - Flyway 管理数据库脚本
  - 配置中心管理环境配置
```

### 1.3 生产环境红线

```yaml
prohibited:
  - 手动登录服务器操作
  - 手动执行 SQL 脚本
  - 使用 latest 镜像标签
  - 明文存储敏感配置
```

---

## 二、发布流程 [MUST]

### 2.1 发布要求

```yaml
release_process:
  - "生产发布必须经过 staging/pre-production 环境验证"
  - "发布必须有可执行的回滚方案"
  - "业务高峰期禁止发布（由各业务线定义高峰时段）"
  - "发布后必须进行冒烟测试验证"
```

### 2.2 变更分类

| 类型 | 定义 | 审批级别 |
|------|------|----------|
| 微小变更 | 调整日志级别、新增监控指标 | 开发负责人 |
| 一般变更 | 新增接口、优化 SQL 索引 | 技术负责人 |
| 重大变更 | 分库分表、JVM 参数调整、框架升级 | 技术+产品+运维联合审批 |

### 2.3 变更流程

```yaml
before:
  - 登记 CMDB（变更内容、影响范围、执行时间）
  - 准备回滚方案
  - 非业务高峰期执行

during:
  - 灰度发布（先 1 个 Pod，观察 10 分钟）
  - 慢启动（preStop 延迟 10 秒）
  - 实时监控指标

after:
  - 开发验证
  - 测试验证
  - 观察 30 分钟
  - 无异常标记完成
```

---

## 三、CI/CD 流水线规范 [MUST]

### 3.1 流水线阶段

```yaml
stages:
  - code-check      # 代码检查（SonarQube）
  - test            # 单元测试 + 集成测试
  - build           # 构建 Docker 镜像
  - scan            # 镜像安全扫描
  - deploy          # K8s 部署
  - verify          # 部署验证
```

### 3.2 GitHub Actions 配置

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  IMAGE_REGISTRY: ghcr.io/${{ github.repository_owner }}
  APP_NAME: mall-order

jobs:
  code-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: SonarQube Scan
        uses: sonarsource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  test:
    runs-on: ubuntu-latest
    needs: code-check
    steps:
      - name: Run Tests with Coverage
        run: mvn clean test jacoco:report

  build:
    runs-on: ubuntu-latest
    needs: test
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.image_tag }}
          severity: 'HIGH,CRITICAL'
          exit-code: '1'

  deploy:
    runs-on: ubuntu-latest
    needs: [build, scan]
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Deploy to Kubernetes
        run: |
          helm upgrade --install ${{ env.APP_NAME }} ./charts/${{ env.APP_NAME }} \
            --namespace prod \
            --set image.tag=v1.0.0-${{ github.sha }} \
            --set replicas=3 \
            --wait --timeout=5m

  verify:
    runs-on: ubuntu-latest
    needs: deploy
    steps:
      - name: Run API Tests
        id: api-test
        continue-on-error: true
        run: |
          newman run test/api-test.json -e test/prod-environment.json

      - name: Rollback on Failure
        if: steps.api-test.outcome == 'failure'
        run: |
          helm rollback ${{ env.APP_NAME }} 0 --namespace prod
          curl -X POST -d '{"msg":"部署失败，已自动回滚"}' ${{ secrets.WEBHOOK_URL }}
          exit 1
```

### 3.3 质量门禁

```yaml
quality_gates:
  - sonarqube_no_critical_issues
  - unit_test_coverage >= 80%
  - security_scan_passed
  - all_tests_passed
```

---

## 四、灰度发布规范 [MUST]

### 4.1 K8s 滚动更新

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0    # 零停机
    maxSurge: 1          # 最多多启动 1 个 Pod
```

### 4.2 流量灰度（Istio）

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
spec:
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: mall-order
            subset: canary
    - route:
        - destination:
            host: mall-order
            subset: stable
```

### 4.3 灰度策略

```yaml
canary_steps:
  1. 部署 canary 版本（1 个 Pod）
  2. 观察 10 分钟，检查错误率、RT
  3. 扩展到 30% 流量
  4. 观察 30 分钟
  5. 全量发布
  6. 清理 canary 资源
```

---

## 五、回滚方案 [MUST]

### 5.1 回滚步骤

```yaml
rollback_steps:
  1. 回滚代码（helm rollback）
  2. 回滚数据库（执行回滚脚本）
  3. 清理缓存（Redis 删除相关 key）
  4. 通知团队
```

### 5.2 自动回滚触发条件

```yaml
auto_rollback_triggers:
  - 错误率 > 5% 持续 2 分钟
  - P99 响应时间 > 2s 持续 5 分钟
  - 健康检查连续失败 3 次
  - 冒烟测试失败
```

---

## 六、监控告警规范 [MUST]

### 6.1 核心监控指标

```yaml
application:
  - http_requests_total          # 请求总数
  - http_request_duration_seconds  # 请求耗时
  - http_requests_errors_total   # 错误数

jvm:
  - jvm_memory_used_bytes        # 内存使用
  - jvm_gc_pause_seconds         # GC 暂停时间
  - jvm_threads_current          # 线程数

business:
  - order_create_total           # 订单创建数
  - payment_success_total        # 支付成功数
```

### 6.2 告警规则

```yaml
groups:
  - name: app-alerts
    rules:
      - alert: 接口错误率过高
        expr: rate(http_requests_errors_total[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "接口错误率超过 5%"

      - alert: P99 响应时间过高
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "P99 响应时间超过 1 秒"

      - alert: JVM 内存使用率过高
        expr: jvm_memory_used_bytes / jvm_memory_max_bytes > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "JVM 内存使用率超过 85%"
```

### 6.3 告警分级

| 级别 | 触发场景 | 通知方式 | 响应时效 |
|------|----------|----------|----------|
| Critical | 服务宕机、错误率 >5% | 钉钉@所有人+电话 | 5 分钟 |
| Warning | 内存 >85%、慢查询增多 | 钉钉群通知 | 30 分钟 |
| Info | 配置更新、服务重启 | 邮件通知 | 无需即时 |

---

## 七、灾备与恢复 [MUST]

### 7.1 备份策略

| 数据类型 | 备份频率 | 备份方式 | 保留时长 |
|----------|----------|----------|----------|
| 订单/支付（核心） | 全量每日+增量每小时 | MySQL 主从+定时备份 | 90 天 |
| 用户数据（重要） | 全量每日+增量每 2 小时 | 全量备份+Binlog | 180 天 |
| 日志/统计（非核心） | 全量每日 | 压缩存储 | 30 天 |

### 7.2 备份验证

```bash
#!/bin/bash
# 每周自动执行恢复测试

# 1. 下载最新备份
wget http://backup.mall.com/mysql/full-$(date +%Y%m%d).sql.gz

# 2. 恢复到测试库
gunzip full-$(date +%Y%m%d).sql.gz
mysql -h test-db -u test -p$TEST_PWD < full-$(date +%Y%m%d).sql

# 3. 校验数据完整性
prod_count=$(mysql -h prod-db -e "select count(*) from order_info" -N)
test_count=$(mysql -h test-db -e "select count(*) from order_info" -N)
if [ $prod_count -eq $test_count ]; then
    echo "备份恢复成功"
else
    curl -X POST -d '{"msg":"备份恢复失败"}' $DINGTALK_WEBHOOK
fi
```

---

## 八、事故响应 [MUST]

```yaml
incident_response:
  - "P0/P1 事故必须在 15 分钟内响应"
  - "事故处理必须记录时间线和处理过程"
  - "事故必须进行复盘并输出改进措施"
```

### 8.1 事故分级

| 级别 | 定义 | 响应时间 | 处理时间 |
|------|------|----------|----------|
| P0 | 核心业务不可用 | 5 分钟 | 1 小时 |
| P1 | 核心业务严重受损 | 15 分钟 | 4 小时 |
| P2 | 非核心功能不可用 | 30 分钟 | 8 小时 |
| P3 | 轻微问题 | 2 小时 | 24 小时 |

---

## 九、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | 镜像标签用 latest | 检查 Deployment 配置 |
| 2 | 容器无资源限制 | 检查 resources 配置 |
| 3 | 无滚动更新配置 | 检查 strategy 配置 |
| 4 | 备份未验证 | 检查恢复测试记录 |
| 5 | 监控仅覆盖指标 | 检查日志+链路配置 |
| 6 | 敏感配置明文存储 | 检查 ConfigMap/Secret |
| 7 | 生产环境手动部署 | 检查部署记录 |
| 8 | 无健康检查探针 | 检查 liveness/readiness |
| 9 | CI/CD 无质量门禁 | 检查流水线配置 |
| 10 | 业务高峰期发布 | 检查发布时间记录 |
