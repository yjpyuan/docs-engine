# 安全红线规范

> 企业级强制约束，下级知识库（L1/L2）不可覆盖
>
> AI Coding 场景下必须强制执行

## 一、认证授权 [MUST]

### 1.1 密码与凭证

```yaml
rules:
  - "禁止硬编码密码、API Key、Token、证书"
  - "禁止在日志中输出敏感信息（密码、身份证、手机号、银行卡）"
  - "所有外部接口必须进行身份认证"
  - "密码必须使用 bcrypt/argon2 加密存储，禁止 MD5/SHA1"
  - "Session/Token 必须设置合理过期时间"
```

```java
// ❌ 禁止：硬编码密钥
private static final String SECRET_KEY = "my-secret-key-123";

// ✅ 正确：从 KMS 获取密钥
private String getSecretKey() {
    return kmsService.getSecret("aes.encryption.key");
}

// ❌ 禁止：明文存储密码
user.setPassword(rawPassword);

// ❌ 禁止：MD5 加密密码（可破解）
user.setPassword(DigestUtils.md5Hex(rawPassword));

// ✅ 正确：BCrypt 加密
user.setPassword(BCrypt.hashpw(rawPassword, BCrypt.gensalt(12)));
```

### 1.2 密钥管理

```yaml
rules:
  - 禁止硬编码密钥
  - 使用 KMS 管理密钥
  - 定期轮换密钥
```

---

## 二、输入校验 [MUST]

### 2.1 SQL 注入防护

```yaml
rules:
  - "所有外部输入必须校验（长度、格式、范围、类型）"
  - "SQL 必须使用参数化查询，禁止字符串拼接"
  - "MyBatis 必须使用 #{}，禁止 ${}"
```

```java
// ✅ 正确：MyBatis #{}
@Select("SELECT * FROM user WHERE id = #{userId}")
User selectById(@Param("userId") Long userId);

// ❌ 错误：MyBatis ${}（SQL 注入风险）
@Select("SELECT * FROM user WHERE name = '${name}'")
User selectByName(@Param("name") String name);

// ❌ 错误：字符串拼接
String sql = "SELECT * FROM user WHERE id = " + userId;
```

### 2.2 ${} 仅允许场景

```java
// ✅ 允许：动态表名（需白名单校验）
private static final Set<String> ALLOWED_TABLES = Set.of("order_2024", "order_2025");

public List<Order> queryByTable(String tableName) {
    if (!ALLOWED_TABLES.contains(tableName)) {
        throw new IllegalArgumentException("非法表名");
    }
    return orderMapper.selectByTable(tableName);
}
```

### 2.3 XSS 防护

```yaml
rules:
  - "禁止直接输出用户输入到页面（XSS 防护）"
  - "输入过滤：网关层统一过滤危险字符"
  - "输出编码：响应数据 HTML 编码"
```

```java
// ✅ 正确：输出编码
public String sanitizeOutput(String input) {
    return StringEscapeUtils.escapeHtml4(input);
}

// ✅ 正确：网关 XSS 过滤
private boolean containsXss(String value) {
    String[] keywords = {"<script>", "javascript:", "onclick", "onerror"};
    return Arrays.stream(keywords).anyMatch(value.toLowerCase()::contains);
}
```

### 2.4 文件上传校验

```yaml
rules:
  - "文件上传必须校验类型、大小、内容（禁止仅校验扩展名）"
  - "反序列化必须使用白名单机制"
```

---

## 三、数据保护 [MUST]

### 3.1 敏感数据存储

```yaml
rules:
  - "PII（个人身份信息）数据必须加密存储"
  - "跨境数据传输需符合 GDPR/数据出境规定"
  - "数据删除敏感数据必须物理删除或脱敏，禁止仅逻辑删除"
  - "备份数据与生产数据同等安全级别"
```

| 数据类型 | 加密方式 | 密钥管理 |
|----------|----------|----------|
| 密码 | BCrypt（不可逆） | 无需密钥 |
| 手机号/身份证 | AES-256-GCM | KMS 管理 |
| 银行卡号 | RSA-2048 | HSM 存储私钥 |

```java
// ✅ 正确：手机号 AES 加密
public void saveUser(User user) {
    String aesKey = kmsService.getSecret("user.phone.aes.key");
    String encryptedPhone = AesUtils.encrypt(user.getPhone(), aesKey, "GCM");
    user.setPhone(encryptedPhone);
}
```

### 3.2 数据脱敏

| 数据类型 | 脱敏规则 | 示例 |
|----------|----------|------|
| 手机号 | 保留前 3 后 4 | 138****8000 |
| 身份证 | 保留前 6 后 4 | 310***********1234 |
| 银行卡 | 保留后 4 位 | ************1234 |
| 邮箱 | 保留首字母和域名 | z***@example.com |

```java
// ✅ 正确：响应脱敏
@Data
public class UserVO {
    private Long userId;
    private String userName;

    @JsonSerialize(using = PhoneDesensitizer.class)
    private String phone;  // 138****8000

    @JsonSerialize(using = IdCardDesensitizer.class)
    private String idCard;  // 310***********1234
}

// ✅ 正确：日志脱敏
log.info("用户登录，phone={}", DesensitizeUtils.maskPhone(phone));

// ❌ 错误：日志明文打印
log.info("用户登录，phone={}, password={}", phone, password);
```

### 3.3 传输加密

```yaml
rules:
  - 强制 HTTPS
  - 核心服务 mTLS 双向认证
  - 禁止明文传输敏感数据
```

---

## 四、审计追溯 [MUST]

### 4.1 审计日志

```yaml
rules:
  - "关键操作必须记录审计日志（who/when/what/where/result）"
  - "审计日志禁止删除或篡改，保留期限 ≥6 个月"
  - "登录失败、权限变更、数据导出必须记录"
```

```java
// ✅ 正确：敏感操作审计
@Aspect
@Component
public class AuditLogAspect {
    @AfterReturning(pointcut = "@annotation(auditLog)", returning = "result")
    public void recordLog(JoinPoint joinPoint, AuditLog auditLog, Object result) {
        AuditLogEntity log = new AuditLogEntity()
            .setUserId(SecurityUtils.getCurrentUserId())
            .setOperation(auditLog.operation())
            .setIp(ServletUtils.getClientIp())
            .setParams(JSON.toJSONString(joinPoint.getArgs()))
            .setResult(JSON.toJSONString(result))
            .setOperateTime(LocalDateTime.now());
        auditLogMapper.insert(log);

        // 核心日志同步区块链
        if (auditLog.level() == LogLevel.CORE) {
            blockchainAuditService.record(auditLog.operation(), log);
        }
    }
}
```

---

## 五、权限控制 [MUST]

### 5.1 RBAC 模型

```yaml
model: RBAC3.0（用户-角色-权限-数据）
rules:
  - 功能权限：控制接口访问
  - 数据权限：控制数据范围
  - 最小权限原则
```

### 5.2 分层校验

```yaml
layers:
  - 前端：隐藏无权限按钮（仅辅助）
  - 网关：统一 Token 校验
  - 接口：@PreAuthorize 注解校验
  - 业务：数据权限校验
```

```java
// ✅ 正确：接口层权限校验
@PreAuthorize("hasPermission('order', 'update')")
@PutMapping("/api/v1/orders/{orderId}")
public Result<Void> updateOrder(@PathVariable Long orderId,
                                 @RequestBody OrderUpdateRequest request) {
    return Result.success(orderService.updateOrder(orderId, request));
}

// ✅ 正确：业务层数据权限校验
public OrderVO getOrder(Long orderId) {
    Order order = orderMapper.selectById(orderId);
    Long currentUserId = SecurityUtils.getCurrentUserId();

    if (!order.getUserId().equals(currentUserId) && !SecurityUtils.isAdmin()) {
        throw new AccessDeniedException("无权访问该订单");
    }
    return convertToVO(order);
}
```

---

## 六、禁止的代码模式 [MUST]

```yaml
forbidden_patterns:
  - "禁止 eval()、exec() 执行动态代码"
  - "禁止反序列化不可信数据源"
  - "禁止使用已知漏洞的依赖版本（CVE 高危）"
  - "禁止禁用 SSL/TLS 证书校验"
  - "禁止在生产代码中使用 TODO/FIXME 绕过安全逻辑"
```

```java
// ❌ 禁止：命令注入
Runtime.getRuntime().exec("ls " + userInput);

// ❌ 禁止：反序列化漏洞
ObjectInputStream ois = new ObjectInputStream(inputStream);
Object obj = ois.readObject();  // 不安全

// ❌ 禁止：路径遍历
new File("/data/" + userInput);  // 用户输入可能是 ../etc/passwd

// ✅ 正确：路径校验
public File getFile(String filename) {
    Path path = Paths.get("/data", filename).normalize();
    if (!path.startsWith("/data")) {
        throw new SecurityException("非法路径");
    }
    return path.toFile();
}
```

---

## 七、容器安全 [MUST]

```yaml
rules:
  - 禁止 root 用户运行容器
  - 使用只读文件系统
  - 限制资源配额
  - 定期扫描镜像漏洞
```

```dockerfile
# ✅ 正确：非 root 用户
FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S app && adduser -S app -G app
USER app
COPY target/app.jar /app/app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

# ❌ 错误：root 用户运行
FROM eclipse-temurin:17-jre
COPY target/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

## 八、依赖安全 [MUST]

```xml
<!-- Maven 依赖检查插件 -->
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>8.2.1</version>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
    </configuration>
</plugin>
```

---

## 九、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | MyBatis 使用 ${} | 检查 Mapper XML 和注解 |
| 2 | 密码明文/MD5 存储 | 检查加密方式 |
| 3 | 权限仅前端校验 | 检查接口注解 |
| 4 | 密钥硬编码 | 检查代码中的常量 |
| 5 | 容器 root 运行 | 检查 Dockerfile |
| 6 | 日志明文打印敏感数据 | 检查 log 语句 |
| 7 | 依赖有高危漏洞 | 运行 OWASP 扫描 |
| 8 | 微服务通信无认证 | 检查 mTLS 配置 |
| 9 | 无审计日志 | 检查敏感操作 |
| 10 | 敏感配置明文 | 检查配置文件 |
