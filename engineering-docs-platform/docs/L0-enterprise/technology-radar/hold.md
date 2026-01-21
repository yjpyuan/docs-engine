# 技术雷达 - 暂缓（Hold）

> 不推荐使用的技术，新项目禁止采用，存量项目逐步迁移

---

## 一、语言与框架

### 1.1 过时版本

| 技术 | 暂缓原因 | 迁移目标 | 迁移期限 |
|------|----------|----------|----------|
| Java 8 | 安全漏洞、缺少新特性 | Java 17 | 2025-06 |
| Java 11 | 即将 EOL | Java 17 | 2025-12 |
| Spring Boot 2.x | 安全支持即将结束 | Spring Boot 3.x | 2025-06 |
| Spring Cloud Netflix | 已停止维护 | Spring Cloud Alibaba | 已过期 |

### 1.2 不推荐框架

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| Struts | 安全漏洞频发 | Spring MVC |
| Hibernate (单独使用) | 复杂度高、性能问题 | MyBatis-Plus |
| JSP | 前后端耦合 | Vue/React + REST API |

---

## 二、数据存储

### 2.1 数据库

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| MySQL 5.x | 安全支持结束 | MySQL 8.0+ |
| Oracle | 高昂成本、供应商锁定 | PostgreSQL/MySQL |
| Redis 4.x | 缺少 Stream、安全更新 | Redis 7.x |

### 2.2 缓存方案

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| Ehcache | 功能落后、社区不活跃 | Caffeine |
| Memcached | 功能单一、不支持持久化 | Redis |
| Guava Cache | 已不再更新 | Caffeine |

---

## 三、微服务组件

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| Eureka | Netflix 已停止维护 | Nacos |
| Zuul 1.x | 同步阻塞、性能差 | Spring Cloud Gateway |
| Hystrix | 已停止维护 | Sentinel |
| Ribbon | 已停止维护 | Spring Cloud LoadBalancer |
| Feign (Netflix) | 已停止维护 | OpenFeign |
| Dubbo 2.x | 版本过旧 | Dubbo 3.x 或 OpenFeign |

---

## 四、消息队列

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| ActiveMQ Classic | 性能不足、功能落后 | RocketMQ/Kafka |
| RabbitMQ (高吞吐场景) | 吞吐量限制 | Kafka |

---

## 五、DevOps 工具

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| Jenkins (手动配置) | 配置复杂、难以版本控制 | GitHub Actions/GitLab CI |
| Docker Swarm | 功能有限、社区萎缩 | Kubernetes |
| Ansible (大规模部署) | 无状态管理、大规模慢 | Terraform + K8s |

---

## 六、前端技术

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| jQuery | 现代框架更优 | Vue/React |
| AngularJS (1.x) | 已停止维护 | Angular 17+ 或 Vue |
| Vue 2.x | 即将 EOL | Vue 3.x |
| Webpack 4.x | 性能和功能落后 | Vite/Webpack 5 |

---

## 七、安全相关

| 技术 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| MD5 加密 | 已被破解 | BCrypt/Argon2 |
| SHA-1 | 已被破解 | SHA-256+ |
| HTTP (生产环境) | 数据明文传输 | HTTPS |
| Basic Auth (敏感系统) | 安全性不足 | OAuth2/JWT |
| 自研加密算法 | 安全性无法保证 | 标准加密库 |

---

## 八、编程实践

| 实践 | 暂缓原因 | 替代方案 |
|------|----------|----------|
| Executors 创建线程池 | OOM 风险 | ThreadPoolExecutor |
| synchronized 重度使用 | 性能瓶颈 | ReentrantLock/CAS |
| XML 配置 Spring | 繁琐、难维护 | Java Config/注解 |
| 手写 SQL 拼接 | SQL 注入风险 | MyBatis #{} |
| 单体应用日志文件 | 难以聚合分析 | ELK/Loki |

---

## 九、迁移管理

### 9.1 迁移优先级

```yaml
migration_priority:
  P0: 有安全漏洞、已停止支持
  P1: 即将停止支持（6个月内）
  P2: 有更好替代方案
  P3: 技术债务、长期优化
```

### 9.2 迁移流程

```yaml
migration_process:
  1. 评估影响范围和迁移成本
  2. 制定迁移计划和时间表
  3. 准备回滚方案
  4. 分批迁移（先测试后生产）
  5. 验证功能和性能
  6. 下线旧技术
  7. 更新文档和培训
```

### 9.3 例外申请

```yaml
exception_request:
  - 提交技术例外申请
  - 说明无法迁移的原因
  - 制定风险缓解措施
  - 设定最终迁移期限
  - 需架构委员会审批
```

---

## 十、监控与告警

```yaml
hold_monitoring:
  - 定期扫描 Hold 技术使用情况
  - 新项目使用 Hold 技术自动告警
  - 季度 Hold 技术使用报告
  - 迁移进度跟踪看板
```
