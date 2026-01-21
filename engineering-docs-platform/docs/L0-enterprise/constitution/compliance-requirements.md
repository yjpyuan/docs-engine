# 合规性要求规范

> 企业级强制约束，下级知识库（L1/L2）不可覆盖
>
> 涵盖：个保法、GDPR、等保 2.0

## 一、用户授权规范 [MUST]

### 1.1 授权原则

```yaml
principles:
  - 前端引导授权
  - 后端强制校验
  - 授权状态持久化
  - 授权记录存证
```

### 1.2 授权校验

```java
// ✅ 正确：自定义授权校验注解
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequireAuth {
    String value();  // 授权项：location/phone 等
}

@Aspect
@Component
public class AuthCheckAspect {
    @Autowired
    private StringRedisTemplate redisTemplate;

    @Before("@annotation(requireAuth)")
    public void checkAuth(JoinPoint joinPoint, RequireAuth requireAuth) {
        Long userId = SecurityUtils.getCurrentUserId();
        String authJson = redisTemplate.opsForValue().get("user:auth:" + userId);

        if (StringUtils.isBlank(authJson)) {
            throw new BusinessException("请先完成授权");
        }

        JSONObject authObj = JSON.parseObject(authJson);
        Boolean hasAuth = authObj.getBoolean(requireAuth.value());
        if (hasAuth == null || !hasAuth) {
            throw new BusinessException("缺少" + requireAuth.value() + "授权");
        }
    }
}

// 使用示例
@GetMapping("/nearby")
@RequireAuth("location")
public Result<List<StoreDTO>> getNearbyStores(@RequestParam Double lat,
                                               @RequestParam Double lng) {
    return Result.success(storeService.getNearby(lat, lng));
}
```

---

## 二、数据留存与删除 [MUST]

### 2.1 留存期限

| 数据类型 | 留存期限 | 清理方式 |
|----------|----------|----------|
| 浏览日志/搜索记录 | ≤90 天 | 定时物理删除 |
| 订单/支付记录 | ≤3 年 | 归档后删除 |
| 用户基本信息 | 注销后 72 小时 | 全链路删除 |

### 2.2 MySQL 分区表清理

```sql
-- 创建分区表
CREATE TABLE user_browse_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    browse_time DATETIME NOT NULL
) PARTITION BY RANGE (TO_DAYS(browse_time)) (
    PARTITION p202401 VALUES LESS THAN (TO_DAYS('2024-02-01')),
    PARTITION p202402 VALUES LESS THAN (TO_DAYS('2024-03-01'))
);
```

```java
// ✅ 正确：定时删除过期分区
@Scheduled(cron = "0 0 2 1 * ?")
public void cleanExpiredPartition() {
    LocalDate threeMonthsAgo = LocalDate.now().minusMonths(3);
    String partitionName = "p" + threeMonthsAgo.format(DateTimeFormatter.ofPattern("yyyyMM"));
    jdbcTemplate.execute("ALTER TABLE user_browse_log DROP PARTITION " + partitionName);
}
```

### 2.3 用户注销全链路删除

```java
// ✅ 正确：分布式数据清理
@Async("cancelExecutor")
@Transactional(rollbackFor = Exception.class)
public void cancelUserAccount(Long userId) {
    try {
        // 1. MySQL 清理
        userMapper.deleteById(userId);
        orderMapper.deleteByUserId(userId);

        // 2. Redis 清理
        Set<String> keys = redisTemplate.keys("user:*:" + userId);
        if (!keys.isEmpty()) {
            redisTemplate.delete(keys);
        }

        // 3. ES 清理
        DeleteQuery deleteQuery = new DeleteQuery();
        deleteQuery.setQuery(QueryBuilders.termQuery("user_id", userId));
        esTemplate.delete(deleteQuery, IndexCoordinates.of("order_index"));

        // 4. MQ 清理
        rabbitTemplate.convertAndSend("user.cancel.exchange", "user.cancel.key", userId);

        // 5. OSS 清理
        ossClient.deleteObject("user-avatar-bucket", "avatar/" + userId + ".png");

        // 6. 审计日志（区块链存证）
        blockchainAuditService.record("user_cancel", "userId=" + userId);

    } catch (Exception e) {
        alertService.send("用户注销数据清理失败，userId=" + userId);
        throw e;
    }
}

// 清理后校验
@Scheduled(cron = "0 0 3 * * ?")
public void verifyCancelResult() {
    List<Long> pendingUserIds = cancelRecordMapper.queryPendingCancel(
        LocalDateTime.now().minusHours(72));

    for (Long userId : pendingUserIds) {
        boolean mysqlExist = userMapper.existsById(userId) > 0;
        boolean redisExist = redisTemplate.hasKey("user:info:" + userId);
        boolean esExist = esTemplate.exists(String.valueOf(userId),
                                            IndexCoordinates.of("order_index"));

        if (mysqlExist || redisExist || esExist) {
            alertService.send("用户注销数据残留，userId=" + userId);
        }
    }
}
```

---

## 三、数据导出规范 [MUST]

```java
// ✅ 正确：用户数据导出
public byte[] exportUserData(Long userId) {
    // 1. 身份验证（二次验证）
    if (!verifyService.verifyIdentity(userId)) {
        throw new BusinessException("身份验证失败");
    }

    // 2. 收集数据
    UserDataExportDTO data = new UserDataExportDTO();
    data.setUserInfo(userMapper.selectById(userId));
    data.setOrderList(orderMapper.selectByUserId(userId));

    // 3. 敏感数据脱敏
    data.getUserInfo().setIdCard(DesensitizeUtils.maskIdCard(data.getUserInfo().getIdCard()));
    data.getUserInfo().setPhone(DesensitizeUtils.maskPhone(data.getUserInfo().getPhone()));

    // 4. 生成加密 ZIP
    byte[] jsonBytes = JSON.toJSONBytes(data);
    byte[] encrypted = AesUtils.encrypt(jsonBytes, getExportKey());

    // 5. 审计日志
    auditService.recordExport(userId, "user_data_export");

    return encrypted;
}
```

---

## 四、等保 2.0 规范 [MUST]

### 4.1 双因素认证

```java
// ✅ 正确：TOTP 双因素认证
@PostMapping("/login/2fa")
public Result<String> verify2FA(
        @RequestParam String username,
        @RequestParam String totpCode) {

    // 1. 获取用户密钥
    User user = userMapper.selectByUsername(username);
    String secret = user.getTotpSecret();

    // 2. 验证 TOTP
    GoogleAuthenticator gAuth = new GoogleAuthenticator();
    boolean isValid = gAuth.authorize(secret, Integer.parseInt(totpCode));

    if (!isValid) {
        // 记录失败次数，超过 5 次锁定
        int failCount = redisTemplate.opsForValue()
            .increment("2fa:fail:" + username).intValue();
        if (failCount >= 5) {
            userMapper.lockAccount(username);
            return Result.fail("验证失败次数过多，账户已锁定");
        }
        return Result.fail("验证码错误");
    }

    // 3. 生成 Token
    String token = jwtService.generateToken(user);
    return Result.success(token);
}
```

### 4.2 最小权限原则

```java
// ✅ 正确：细粒度权限控制
@PreAuthorize("hasPermission('order', 'read')")
@GetMapping("/api/v1/orders/{orderId}")
public Result<OrderVO> getOrder(@PathVariable Long orderId) {
    Order order = orderMapper.selectById(orderId);
    if (!SecurityUtils.hasDataPermission(order.getUserId())) {
        throw new AccessDeniedException("无权访问");
    }
    return Result.success(convertToVO(order));
}
```

### 4.3 审计日志存证

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface AuditLog {
    String operation();
    LogLevel level() default LogLevel.NORMAL;
}

public enum LogLevel {
    NORMAL,  // 普通日志
    CORE     // 核心日志（区块链存证）
}

// 使用示例
@AuditLog(operation = "用户注销账号", level = LogLevel.CORE)
public void cancelUserAccount(Long userId) {
    // 注销逻辑
}
```

### 4.4 生产环境安全配置

```yaml
spring:
  debug: false
  datasource:
    username: ENC(加密用户名)
    password: ENC(加密密码)

logging:
  level:
    com.baomidou.mybatisplus: WARN
    com.mall: INFO

server:
  port: 443
  ssl:
    enabled: true
```

---

## 五、GDPR 合规（出海） [MAY]

### 5.1 数据本地化

```java
// ✅ 正确：按地域路由数据源
@Component
public class RegionDataSourceRouter extends AbstractRoutingDataSource {
    @Override
    protected Object determineCurrentLookupKey() {
        String region = RegionContext.getCurrentRegion();
        return switch (region) {
            case "EU" -> "eu-datasource";
            case "US" -> "us-datasource";
            default -> "cn-datasource";
        };
    }
}
```

### 5.2 遗忘权实现

```yaml
gdpr_requirements:
  - 30 天内响应删除请求
  - 全链路数据清除
  - 提供删除确认证明
```

---

## 六、数据分级加密 [MUST]

| 敏感级别 | 加密算法 | 密钥管理 | 示例 |
|----------|----------|----------|------|
| 核心 | SM4+信封加密 | KMS | 身份证、银行卡 |
| 重要 | AES-256 | 配置中心加密 | 手机号、邮箱 |
| 一般 | 可逆脱敏 | 无 | 浏览记录 |

```java
// ✅ 正确：SM4 加密（国密）
public class Sm4Utils {
    public static String encrypt(String data, String key) {
        SM4Engine engine = new SM4Engine();
        KeyParameter keyParam = new KeyParameter(Hex.decode(key));
        engine.init(true, keyParam);
        byte[] encrypted = new byte[engine.getOutputSize(data.getBytes().length)];
        engine.processBytes(data.getBytes(), 0, data.length(), encrypted, 0);
        return Hex.toHexString(encrypted);
    }
}
```

---

## 七、合规自查清单

| 维度 | 检查项 | 检查方式 |
|------|--------|----------|
| 用户授权 | 敏感接口是否校验授权 | 接口测试 + Redis 查询 |
| 数据加密 | 敏感数据是否加密存储 | 数据库查询 |
| 审计日志 | 敏感操作是否记录日志 | 审计平台查询 |
| 数据删除 | 注销后是否全链路清理 | 分布式存储校验 |
| 等保加固 | 生产环境是否关闭调试 | 配置文件检查 |
| 出海合规 | 数据是否本地化存储 | 数据库地域查询 |

---

## 八、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | 授权仅前端校验 | 检查接口注解 |
| 2 | 敏感数据未加密 | 检查数据库存储 |
| 3 | 审计日志可篡改 | 检查存储方式 |
| 4 | 用户注销数据残留 | 检查分布式存储 |
| 5 | 生产环境开启调试 | 检查配置文件 |
| 6 | 密码弱校验 | 检查校验规则 |
| 7 | 无二次验证 | 检查敏感操作 |
| 8 | 日志明文打印敏感数据 | 检查日志输出 |
| 9 | 数据导出无脱敏 | 检查导出逻辑 |
| 10 | 无授权记录存证 | 检查审计日志 |
