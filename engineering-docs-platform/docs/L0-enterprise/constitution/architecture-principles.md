# 架构底线规范

> 企业级强制约束，下级知识库（L1/L2）不可覆盖

## 一、分层架构 [MUST]

### 1.1 层级依赖规则

```yaml
rules:
  - "禁止 Controller/Handler 直接访问 Repository/DAO（必须经过 Service）"
  - "禁止循环依赖（A→B→C→A）"
  - "基础设施层不得依赖业务层"
  - "领域层不得依赖应用层"
```

```
┌─────────────────────────────────────┐
│         Controller / Handler        │  ← 接口层
├─────────────────────────────────────┤
│              Service                │  ← 业务逻辑层
├─────────────────────────────────────┤
│         Repository / DAO            │  ← 数据访问层
├─────────────────────────────────────┤
│           Infrastructure            │  ← 基础设施层
└─────────────────────────────────────┘
```

### 1.2 禁止模式

```java
// ❌ 禁止：Controller 直接访问 Mapper
@RestController
public class OrderController {
    @Autowired
    private OrderMapper orderMapper;  // 禁止！

    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable Long id) {
        return orderMapper.selectById(id);
    }
}

// ✅ 正确：通过 Service 层
@RestController
public class OrderController {
    @Autowired
    private OrderService orderService;

    @GetMapping("/orders/{id}")
    public Result<OrderVO> getOrder(@PathVariable Long id) {
        return Result.success(orderService.getOrderById(id));
    }
}
```

---

## 二、数据一致性 [MUST]

### 2.1 事务规范

```yaml
rules:
  - "跨服务数据修改必须使用分布式事务或最终一致性方案"
  - "禁止在数据库事务中调用外部 HTTP 服务"
  - "所有写接口必须支持幂等性（可安全重试）"
  - "并发修改必须有乐观锁或悲观锁保护"
```

### 2.2 事务边界

```java
// ❌ 禁止：事务内调用外部服务
@Transactional(rollbackFor = Exception.class)
public void createOrder(OrderRequest request) {
    orderMapper.insert(order);
    paymentService.pay(order);  // 外部 HTTP 调用，可能超时
    notificationService.send(order);  // 外部调用
}

// ✅ 正确：事务外调用外部服务
@Transactional(rollbackFor = Exception.class)
public Long createOrder(OrderRequest request) {
    orderMapper.insert(order);
    return order.getId();
}

public void processOrder(OrderRequest request) {
    Long orderId = createOrder(request);  // 事务内
    paymentService.pay(orderId);  // 事务外
    notificationService.send(orderId);  // 事务外
}
```

### 2.3 事务配置

```java
// ✅ 正确：必须指定 rollbackFor
@Transactional(rollbackFor = Exception.class)
public Long createOrder(OrderCreateRequest request) {
    // 业务逻辑
}

// ❌ 错误：未指定 rollbackFor
@Transactional
public Long createOrder(OrderCreateRequest request) {
    // 业务逻辑
}
```

### 2.4 乐观锁

```java
// ✅ 正确：版本号乐观锁
@Update("UPDATE order_info SET status = #{status}, version = version + 1 " +
        "WHERE id = #{id} AND version = #{version}")
int updateWithVersion(@Param("id") Long id,
                      @Param("status") Integer status,
                      @Param("version") Integer version);

public void updateOrderStatus(Long orderId, Integer newStatus) {
    Order order = orderMapper.selectById(orderId);
    int affected = orderMapper.updateWithVersion(orderId, newStatus, order.getVersion());
    if (affected == 0) {
        throw new ConcurrentModificationException("数据已被修改，请重试");
    }
}
```

---

## 三、可观测性 [MUST]

### 3.1 健康检查

```yaml
rules:
  - "所有服务必须暴露健康检查端点 /health 或 /actuator/health"
  - "所有服务必须接入统一监控体系（metrics/traces/logs）"
  - "关键业务流程必须有全链路追踪（TraceId 贯穿）"
  - "异常必须上报监控系统，禁止静默吞掉"
```

### 3.2 K8s 探针配置

```yaml
# 存活探针
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10
  failureThreshold: 3

# 就绪探针
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  failureThreshold: 3
```

### 3.3 链路追踪

```java
// ✅ 正确：Feign 拦截器传递链路 ID
@Component
public class FeignTraceInterceptor implements RequestInterceptor {
    @Override
    public void apply(RequestTemplate template) {
        String traceId = MDC.get("traceId");
        if (StringUtils.isNotBlank(traceId)) {
            template.header("X-Trace-Id", traceId);
        }
    }
}
```

### 3.4 日志格式规范

```yaml
rules:
  - "所有服务必须使用统一日志格式"
  - "日志必须包含 traceId、spanId"
  - "禁止日志明文打印敏感数据"
  - "日志级别：ERROR（异常）、WARN（警告）、INFO（关键流程）、DEBUG（调试）"
```

#### 3.4.1 Logback 配置

```xml
<!-- logback-spring.xml -->
<configuration>
    <property name="LOG_PATTERN"
              value="%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - [traceId:%X{traceId}] [spanId:%X{spanId}] - %msg%n"/>

    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>

    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_PATH}/app.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_PATH}/app.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <maxFileSize>100MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>10GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>${LOG_PATTERN}</pattern>
            <charset>UTF-8</charset>
        </encoder>
    </appender>
</configuration>
```

#### 3.4.2 日志字段规范

| 字段 | 长度 | 格式 | 说明 |
|------|------|------|------|
| traceId | 32 位 | 小写十六进制 | 全链路唯一标识，跨服务传递 |
| spanId | 16 位 | 小写十六进制 | 单次调用标识 |
| timestamp | - | `yyyy-MM-dd HH:mm:ss.SSS` | 毫秒级时间戳 |
| level | - | `ERROR/WARN/INFO/DEBUG` | 日志级别 |
| thread | - | 线程名 | 当前线程 |
| logger | 36 位截断 | 类全限定名 | 日志来源 |

#### 3.4.3 TraceId 生成与传递

```java
// ✅ 正确：网关层生成 TraceId
@Component
public class TraceFilter implements GlobalFilter, Ordered {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String traceId = exchange.getRequest().getHeaders().getFirst("X-Trace-Id");
        if (StringUtils.isBlank(traceId)) {
            traceId = generateTraceId();  // 32 位小写十六进制
        }

        ServerHttpRequest request = exchange.getRequest().mutate()
            .header("X-Trace-Id", traceId)
            .build();

        return chain.filter(exchange.mutate().request(request).build());
    }

    private String generateTraceId() {
        return UUID.randomUUID().toString().replace("-", "");
    }
}

// ✅ 正确：服务层接收并放入 MDC
@Component
public class TraceInterceptor implements HandlerInterceptor {
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String traceId = request.getHeader("X-Trace-Id");
        String spanId = generateSpanId();  // 16 位小写十六进制

        MDC.put("traceId", traceId);
        MDC.put("spanId", spanId);
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                 Object handler, Exception ex) {
        MDC.clear();  // 必须清理
    }
}
```

#### 3.4.4 日志级别使用规范

```java
// ERROR：系统异常、业务异常、需要告警
log.error("创建订单失败, userId={}, request={}", userId, JSON.toJSONString(request), e);

// WARN：可恢复异常、降级、重试
log.warn("调用支付服务超时，触发重试, orderId={}, retryCount={}", orderId, retryCount);

// INFO：关键业务节点、入口出口
log.info("订单创建成功, orderId={}, userId={}, amount={}", orderId, userId, amount);

// DEBUG：调试信息（生产环境默认关闭）
log.debug("查询参数, query={}", JSON.toJSONString(query));
```

#### 3.4.5 敏感数据脱敏

```java
// ❌ 禁止：明文打印敏感数据
log.info("用户登录, phone={}, password={}", phone, password);

// ✅ 正确：脱敏后打印
log.info("用户登录, phone={}", DesensitizeUtils.maskPhone(phone));

// 脱敏规则
// 手机号：138****8000
// 身份证：310***********1234
// 银行卡：************1234
```

---

## 四、容错韧性 [MUST]

### 4.1 超时与熔断

```yaml
rules:
  - "外部依赖调用必须设置超时时间"
  - "核心链路必须有降级方案"
  - "禁止单点故障（数据库、缓存、MQ 等）"
```

### 4.2 Feign 超时配置

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connect-timeout: 3000
            read-timeout: 5000
          mall-order:
            read-timeout: 8000
```

### 4.3 熔断降级

```java
// ✅ 正确：FallbackFactory 获取异常信息
@Component
public class OrderFeignFallbackFactory implements FallbackFactory<OrderFeignApi> {
    @Override
    public OrderFeignApi create(Throwable cause) {
        return new OrderFeignApi() {
            @Override
            public Result<OrderDetailDTO> getOrderDetail(Long orderId) {
                log.error("熔断：调用订单服务失败，orderId:{}, cause:{}",
                         orderId, cause.getMessage());
                return Result.fail(503, "订单服务暂时不可用");
            }
        };
    }
}

// ❌ 错误：无降级处理
@FeignClient(name = "mall-order")
public interface OrderFeignApi { }
```

---

## 五、微服务通信 [MUST]

### 5.1 注册中心

```yaml
required: Nacos 集群（≥3节点）
rules:
  - 服务名格式：业务线-服务名（如 mall-order）
  - 命名空间：按环境隔离（dev/test/prod）
  - 分组：按业务线分组
  - 健康检查：心跳间隔 5 秒，超时 15 秒
```

### 5.2 Feign 规范

```yaml
rules:
  - 独立 API 模块（仅含 Feign 接口、DTO、枚举）
  - 必须配置 FallbackFactory
  - 禁止写操作开启重试
  - 链路 ID 必须传递
```

---

## 六、容器化部署 [MUST]

### 6.1 Dockerfile 规范

```dockerfile
# ✅ 正确：多阶段构建 + 非 root 用户
FROM maven:3.8.5-openjdk-17 AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S app && adduser -S app -G app
USER app
COPY --from=builder /build/target/*.jar /app/app.jar
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### 6.2 K8s 安全配置

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false

resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "2Gi"
```

### 6.3 镜像标签规范

```yaml
format: 版本号-CommitID
example: v1.0.0-7a3f2d9
prohibited:
  - latest
  - dev
  - test
```

---

## 七、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | Controller 直接访问 Mapper | 代码审查 |
| 2 | 事务内调用外部服务 | 检查 @Transactional 方法内的 HTTP 调用 |
| 3 | 未指定 rollbackFor | 检查 @Transactional 注解 |
| 4 | Nacos 单节点部署 | 检查 server-addr 配置 |
| 5 | Feign 写操作开启重试 | 检查重试策略配置 |
| 6 | 无 FallbackFactory | 检查 FeignClient 注解 |
| 7 | 容器 root 用户运行 | 检查 Dockerfile |
| 8 | 无健康检查探针 | 检查 K8s Deployment |
| 9 | 镜像标签用 latest | 检查 Deployment 配置 |
| 10 | 无资源限制 | 检查 resources 配置 |
