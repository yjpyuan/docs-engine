# AI 编码策略规范

> 企业级 AI 辅助编码约束，确保 AI 生成代码符合企业标准

---

## 一、AI 编码优先级 [MUST]

### 1.1 优先级定义

| 级别 | 标识 | 含义 | AI 行为 |
|------|------|------|---------|
| 🔴 强制 | `[MUST]` | 违反将导致严重问题 | 必须遵守，不可妥协 |
| 🟡 推荐 | `[SHOULD]` | 最佳实践 | 默认遵守，特殊情况可调整 |
| 🟢 建议 | `[MAY]` | 可选优化 | 视情况采用 |

### 1.2 安全优先原则

```yaml
priorities:
  - SQL 注入防护 > 功能实现
  - 密码加密存储 > 快速开发
  - 敏感数据脱敏 > 日志完整性
  - 权限验证 > 业务逻辑
```

### 1.3 性能意识原则

```yaml
checks:
  - 索引是否合理设计
  - 是否存在 N+1 查询
  - 缓存策略是否正确
  - 线程池参数是否合理
  - 大数据量是否分页
```

---

## 二、AI 生成代码检查清单 [MUST]

### 2.1 生成前检查

```yaml
pre_generation:
  - 是否理解业务需求
  - 是否了解现有代码风格
  - 是否确认技术栈版本
  - 是否明确输入输出规范
  - 是否了解依赖约束
```

### 2.2 生成时检查

```yaml
during_generation:
  - 命名是否符合规范
  - 是否处理了异常情况
  - 是否考虑了线程安全
  - SQL 是否使用参数化查询
  - 敏感数据是否加密/脱敏
  - 是否有适当的日志记录
  - 资源是否正确释放
  - 是否使用统一请求/响应结构（CommonRequest/CommonResponse）
  - 错误码是否符合 13 位格式规范
  - 继承体系是否避免使用 @Accessors(chain=true)
```

### 2.3 生成后检查

```yaml
post_generation:
  - 是否需要添加单元测试
  - 是否需要更新 API 文档
  - 是否需要数据库脚本
  - 是否符合代码评审标准
  - 是否通过静态代码分析
  - 测试数据是否独立（避免固定 ID，使用 @BeforeEach/@AfterEach）
```

---

## 三、禁止行为清单 [MUST]

### 3.1 线程池相关

```java
// ❌ 禁止：使用 Executors 创建线程池
ExecutorService executor = Executors.newFixedThreadPool(10);

// ✅ 正确：手动创建线程池
new ThreadPoolExecutor(
    coreSize,
    maxSize,
    keepAlive,
    TimeUnit.SECONDS,
    new ArrayBlockingQueue<>(100),
    new ThreadFactoryBuilder().setNameFormat("biz-pool-%d").build(),
    new ThreadPoolExecutor.CallerRunsPolicy()
);
```

### 3.2 SQL 安全相关

```java
// ❌ 禁止：SQL 拼接
String sql = "SELECT * FROM user WHERE id = " + userId;

// ❌ 禁止：MyBatis 使用 ${}
@Select("SELECT * FROM user WHERE name = '${name}'")

// ✅ 正确：MyBatis 参数化查询
@Select("SELECT * FROM user WHERE id = #{userId}")
User selectById(@Param("userId") Long userId);
```

### 3.3 异常处理相关

```java
// ❌ 禁止：吞掉异常
try {
    // 业务逻辑
} catch (Exception e) {
    // 空处理
}

// ❌ 禁止：只打印异常
catch (Exception e) {
    e.printStackTrace();
}

// ✅ 正确：记录并处理异常
catch (Exception e) {
    log.error("操作失败, userId={}", userId, e);
    throw new BusinessException("操作失败");
}
```

### 3.4 安全相关

```java
// ❌ 禁止：明文存储密码
user.setPassword(rawPassword);

// ❌ 禁止：硬编码敏感信息
String apiKey = "sk-xxxx";

// ✅ 正确：密码 BCrypt 加密
user.setPassword(BCrypt.hashpw(rawPassword, BCrypt.gensalt()));

// ✅ 正确：从配置中心读取
@Value("${api.key}")
private String apiKey;
```

### 3.5 数据查询相关

```java
// ❌ 禁止：无限制查询
List<Order> orders = orderMapper.selectAll();

// ✅ 正确：分页查询
PageHelper.startPage(pageNum, pageSize);
List<Order> orders = orderMapper.selectByUserId(userId);
```

### 3.6 缓存相关

```java
// ❌ 禁止：缓存无过期时间
redisTemplate.opsForValue().set(key, value);

// ✅ 正确：设置缓存过期时间
redisTemplate.opsForValue().set(key, value, 30, TimeUnit.MINUTES);
```

### 3.7 链式调用相关

```java
// ❌ 禁止：继承体系中使用 @Accessors(chain = true)
@Data
@Accessors(chain = true)
public class BaseRequest { private String traceId; }

@Data
@Accessors(chain = true)
public class OrderRequest extends BaseRequest { private Long orderId; }

// 问题：setTraceId() 返回 BaseRequest，无法继续调用子类方法

// ✅ 正确：使用 @Builder 替代
@Builder
public class OrderRequest {
    private String traceId;
    private Long orderId;
}
```

### 3.8 错误码相关

```java
// ❌ 禁止：错误码格式不规范
throw new BusinessException("001", "用户不存在");

// ✅ 正确：使用 13 位标准格式 [系统编码4位][类型1位][序列号8位]
// 类型：B=业务错误, C=客户端错误, T=系统错误
public enum ErrorCodeEnum {
    SUCCESS("0", "success"),
    USER_NOT_FOUND("1001B00000001", "用户不存在"),
    PARAM_ERROR("1001C00000001", "参数校验失败"),
    SYSTEM_ERROR("1001T00000001", "系统内部错误");
}
```

---

## 四、AI 代码质量标准 [MUST]

### 4.1 可维护性要求

```yaml
requirements:
  - 命名见名知意
  - 关键逻辑有注释
  - 代码结构清晰
  - 异常处理完善
  - 单一职责原则
```

### 4.2 代码风格一致性

```yaml
style_checks:
  - 与现有代码风格保持一致
  - 遵循项目命名规范
  - 使用项目统一的日志框架
  - 使用项目统一的异常体系
  - 使用项目统一的工具类
```

### 4.3 测试要求

```yaml
testing:
  - 核心逻辑必须有单元测试
  - 边界条件必须覆盖
  - 异常场景必须测试
  - 测试覆盖率 >= 80%
```

---

## 五、AI 生成代码规范索引 [SHOULD]

### 5.1 阶段一：项目启动

| 规范 | 核心关注点 |
|------|------------|
| 基础编码规范 | 命名、注释、语法、参数校验 |
| 接口设计规范 | RESTful、请求响应、文档、版本控制 |

### 5.2 阶段二：架构设计

| 规范 | 核心关注点 |
|------|------------|
| 数据库交互规范 | 连接池、SQL 安全、索引、事务、MyBatis |
| 缓存规范 | 选型、穿透/击穿/雪崩、一致性、Redis |
| 微服务治理规范 | 注册发现、远程调用、流量治理、配置管理 |

### 5.3 阶段三：编码实现

| 规范 | 核心关注点 |
|------|------------|
| 并发编程规范 | 线程池、锁、线程安全、并发工具 |
| 安全规范 | 输入输出安全、权限控制、数据加密 |

### 5.4 阶段四：质量校验

| 规范 | 核心关注点 |
|------|------------|
| 测试规范 | 单元测试、集成测试、性能测试、CI/CD |

### 5.5 阶段五：部署上线

| 规范 | 核心关注点 |
|------|------------|
| 部署运维规范 | 环境隔离、容器化、CI/CD、监控告警 |

### 5.6 阶段六：持续治理

| 规范 | 核心关注点 |
|------|------------|
| 数据治理规范 | 数据标准、质量、分库分表、生命周期 |
| 合规性规范 | 数据隐私、等保 2.0、GDPR |
| 团队协作规范 | 分支管理、代码评审、变更管理 |

---

## 六、AI 交互规范 [SHOULD]

### 6.1 上下文理解

```yaml
context_requirements:
  - 理解项目技术栈版本
  - 了解现有代码结构
  - 掌握业务领域知识
  - 遵循项目编码风格
```

### 6.2 输出规范

```yaml
output_requirements:
  - 代码必须完整可运行
  - 包含必要的 import 语句
  - 包含必要的注释说明
  - 标注可能的风险点
  - 提供测试建议
```

### 6.3 反馈机制

```yaml
feedback:
  - 主动询问不明确的需求
  - 提供多种实现方案对比
  - 说明技术选型理由
  - 指出潜在的性能/安全问题
```

---

## 七、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | SQL 字符串拼接 | 检查 SQL 语句构造方式 |
| 2 | 使用 Executors 创建线程池 | 检查线程池创建方式 |
| 3 | 空 catch 块 | 检查异常处理逻辑 |
| 4 | 明文密码存储 | 检查密码处理方式 |
| 5 | 缓存无过期时间 | 检查 Redis 操作 |
| 6 | 无限制查询 | 检查是否有分页/条数限制 |
| 7 | 硬编码敏感信息 | 检查配置管理方式 |
| 8 | 日志打印敏感数据 | 检查日志输出内容 |
| 9 | 未验证输入参数 | 检查参数校验注解 |
| 10 | 资源未关闭 | 检查 try-with-resources |
| 11 | 继承体系使用 @Accessors(chain=true) | 检查 extends + 链式注解 |
| 12 | 测试使用固定 ID 数据 | 检查测试数据生成方式 |
| 13 | 错误码格式不符合规范 | 检查是否为 13 位标准格式 |
