# API 设计规范

> 企业级 API 设计基线，适用于 RESTful API 设计、Controller 编写、接口文档场景

---

## 一、RESTful 语义规范 [MUST]

### 1.1 HTTP 方法映射

| 操作 | HTTP 方法 | 幂等性 | URL 示例 |
|------|----------|--------|---------|
| 查询单个 | GET | 是 | `GET /api/v1/orders/{orderId}` |
| 查询列表 | GET | 是 | `GET /api/v1/orders?status=1&pageNum=1` |
| 创建 | POST | 否 | `POST /api/v1/orders` |
| 全量更新 | PUT | 是 | `PUT /api/v1/orders/{orderId}` |
| 部分更新 | PATCH | 是 | `PATCH /api/v1/orders/{orderId}` |
| 删除 | DELETE | 是 | `DELETE /api/v1/orders/{orderId}` |

### 1.2 URL 设计规范

```yaml
rules:
  - 使用名词复数，禁止动词
  - 全小写，连字符分隔
  - 层级清晰，不超过 3 级
  - 版本号放在路径中
```

```java
// ✅ 正确 URL
GET    /api/v1/users                    // 用户列表
GET    /api/v1/users/{userId}           // 用户详情
POST   /api/v1/users                    // 创建用户
PUT    /api/v1/users/{userId}           // 更新用户
DELETE /api/v1/users/{userId}           // 删除用户
GET    /api/v1/users/{userId}/orders    // 用户的订单列表

// ❌ 错误 URL
GET    /api/v1/getUser                  // 动词
GET    /api/v1/user                     // 单数
GET    /api/v1/User                     // 大写
POST   /api/v1/createOrder              // 动词
GET    /api/v1/user_list                // 下划线
```

### 1.3 查询参数规范

```yaml
query_params:
  - pageNum: 页码（从 1 开始）
  - pageSize: 每页条数
  - sortBy: 排序字段
  - sortOrder: 排序方向（asc/desc）
  - 业务过滤字段使用小驼峰
```

```java
// ✅ 正确
GET /api/v1/orders?userId=1001&status=1&pageNum=1&pageSize=10&sortBy=createTime&sortOrder=desc

// ❌ 错误
GET /api/v1/orders?user_id=1001&page=1   // 命名不一致
```

---

## 二、请求规范 [MUST]

### 2.1 请求 DTO 设计

```java
@Data
@Schema(description = "订单创建请求")
public class OrderCreateRequest {

    @NotNull(message = "用户 ID 不能为空")
    @Schema(description = "用户 ID", example = "1001", required = true)
    private Long userId;

    @NotEmpty(message = "商品列表不能为空")
    @Size(min = 1, max = 100, message = "商品数量 1-100 件")
    @Schema(description = "商品列表", required = true)
    private List<OrderItemDTO> items;

    @NotNull(message = "订单金额不能为空")
    @DecimalMin(value = "0.01", message = "订单金额必须大于 0")
    @Schema(description = "订单金额", example = "299.00", required = true)
    private BigDecimal amount;

    @Schema(description = "收货地址 ID")
    private Long addressId;

    @Size(max = 200, message = "备注不超过 200 字")
    @Schema(description = "订单备注")
    private String remark;
}
```

### 2.2 Controller 参数校验

```java
@RestController
@RequestMapping("/api/v1/orders")
@Validated
public class OrderController {

    // 请求体校验
    @PostMapping
    public Result<Long> createOrder(@Valid @RequestBody OrderCreateRequest request) {
        return Result.success(orderService.createOrder(request));
    }

    // 路径参数校验
    @GetMapping("/{orderId}")
    public Result<OrderVO> getOrder(
            @PathVariable @Min(value = 1, message = "订单 ID 必须大于 0") Long orderId) {
        return Result.success(orderService.getOrderById(orderId));
    }

    // 查询参数校验
    @GetMapping
    public Result<PageInfo<OrderVO>> listOrders(
            @RequestParam @NotNull(message = "用户 ID 不能为空") Long userId,
            @RequestParam(defaultValue = "1") @Min(1) Integer pageNum,
            @RequestParam(defaultValue = "10") @Max(100) Integer pageSize) {
        return Result.success(orderService.listOrders(userId, pageNum, pageSize));
    }
}
```

---

## 三、响应规范 [MUST]

### 3.1 统一响应结构

```java
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {

    @Schema(description = "业务状态码", example = "200")
    private int code;

    @Schema(description = "提示消息", example = "成功")
    private String msg;

    @Schema(description = "响应数据")
    private T data;

    @Schema(description = "响应时间戳", example = "1704067200000")
    private long timestamp;

    public static <T> Result<T> success(T data) {
        return new Result<>(200, "成功", data, System.currentTimeMillis());
    }

    public static Result<Void> success() {
        return new Result<>(200, "成功", null, System.currentTimeMillis());
    }

    public static Result<Void> fail(int code, String msg) {
        return new Result<>(code, msg, null, System.currentTimeMillis());
    }
}
```

### 3.2 业务状态码规范

| 码段 | 含义 | 示例 |
|------|------|------|
| 200 | 成功 | 200 = 操作成功 |
| 400-499 | 客户端错误 | 400=参数错，401=未登录，403=无权限，404=资源不存在 |
| 500-599 | 服务端错误 | 500=系统错误，503=服务不可用 |
| 5001-5999 | 用户模块业务错误 | 5001=用户不存在，5002=密码错误 |
| 6001-6999 | 订单模块业务错误 | 6001=订单不存在，6002=订单已支付 |
| 7001-7999 | 支付模块业务错误 | 7001=余额不足，7002=支付超时 |

```java
public enum BizErrorCode {
    // 用户模块 5001-5999
    USER_NOT_FOUND(5001, "用户不存在"),
    PASSWORD_ERROR(5002, "密码错误"),
    USER_DISABLED(5003, "用户已禁用"),

    // 订单模块 6001-6999
    ORDER_NOT_FOUND(6001, "订单不存在"),
    ORDER_ALREADY_PAID(6002, "订单已支付"),
    ORDER_EXPIRED(6003, "订单已过期"),
    STOCK_NOT_ENOUGH(6004, "库存不足"),

    // 支付模块 7001-7999
    BALANCE_NOT_ENOUGH(7001, "余额不足"),
    PAYMENT_TIMEOUT(7002, "支付超时");

    private final int code;
    private final String msg;
}
```

### 3.3 分页响应结构

```java
@Data
@Schema(description = "分页响应")
public class PageInfo<T> {

    @Schema(description = "当前页", example = "1")
    private Integer pageNum;

    @Schema(description = "每页条数", example = "10")
    private Integer pageSize;

    @Schema(description = "总条数", example = "100")
    private Long total;

    @Schema(description = "总页数", example = "10")
    private Integer pages;

    @Schema(description = "数据列表")
    private List<T> list;

    @Schema(description = "是否有下一页", example = "true")
    private Boolean hasNextPage;
}
```

### 3.4 响应示例

```json
// 成功响应（单条数据）
{
    "code": 200,
    "msg": "成功",
    "data": {
        "orderId": 1001,
        "orderNo": "202401010001",
        "amount": 299.00,
        "status": 1,
        "createTime": "2024-01-01 12:00:00"
    },
    "timestamp": 1704067200000
}

// 成功响应（分页数据）
{
    "code": 200,
    "msg": "成功",
    "data": {
        "pageNum": 1,
        "pageSize": 10,
        "total": 100,
        "pages": 10,
        "list": [...],
        "hasNextPage": true
    },
    "timestamp": 1704067200000
}

// 失败响应
{
    "code": 6001,
    "msg": "订单不存在",
    "data": null,
    "timestamp": 1704067200000
}
```

---

## 四、全局异常处理 [MUST]

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 参数校验异常（@Valid）
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidException(MethodArgumentNotValidException e) {
        String errorMsg = e.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return Result.fail(400, "参数校验失败: " + errorMsg);
    }

    // 参数校验异常（@Validated）
    @ExceptionHandler(ConstraintViolationException.class)
    public Result<Void> handleConstraintException(ConstraintViolationException e) {
        String errorMsg = e.getConstraintViolations().stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .collect(Collectors.joining(", "));
        return Result.fail(400, "参数校验失败: " + errorMsg);
    }

    // 业务异常
    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusinessException(BusinessException e) {
        return Result.fail(e.getCode(), e.getMessage());
    }

    // 未知异常
    @ExceptionHandler(Exception.class)
    public Result<Void> handleException(Exception e) {
        log.error("系统异常", e);
        return Result.fail(500, "系统繁忙，请稍后重试");
    }
}
```

---

## 五、接口文档规范 [MUST]

### 5.1 SpringDoc 配置

```yaml
springdoc:
  api-docs:
    enabled: true
    path: /v3/api-docs
  swagger-ui:
    enabled: true
    path: /swagger-ui.html
  packages-to-scan: com.example.controller
```

### 5.2 Controller 文档注解

```java
@RestController
@RequestMapping("/api/v1/orders")
@Tag(name = "订单接口", description = "订单 CRUD 操作")
public class OrderController {

    @Operation(
        summary = "创建订单",
        description = "用户下单接口，需传入用户 ID、商品列表、金额"
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "创建成功"),
        @ApiResponse(responseCode = "400", description = "参数错误"),
        @ApiResponse(responseCode = "6004", description = "库存不足")
    })
    @PostMapping
    public Result<Long> createOrder(
            @RequestBody @Valid OrderCreateRequest request) {
        return Result.success(orderService.createOrder(request));
    }

    @Operation(summary = "查询订单详情")
    @Parameter(name = "orderId", description = "订单 ID", required = true, example = "1001")
    @GetMapping("/{orderId}")
    public Result<OrderVO> getOrder(@PathVariable Long orderId) {
        return Result.success(orderService.getOrderById(orderId));
    }
}
```

---

## 六、版本控制规范 [MUST]

### 6.1 版本策略

```yaml
format: /api/v{major}/resource
rules:
  - 主版本号递增表示不兼容变更
  - 新增字段必须设默认值
  - 禁止删除旧字段（标记废弃）
  - 禁止修改字段类型
```

### 6.2 接口废弃流程

```java
// 1. 标记废弃
@Deprecated
@Operation(summary = "【已废弃】查询订单", description = "请使用 /api/v2/orders 替代")
@GetMapping("/api/v1/orders/{orderId}")
public Result<OrderVO> getOrderV1(@PathVariable Long orderId) {
    // ...
}

// 2. 新版本接口
@Operation(summary = "查询订单详情")
@GetMapping("/api/v2/orders/{orderId}")
public Result<OrderDetailVO> getOrderV2(@PathVariable Long orderId) {
    // ...
}
```

---

## 七、安全规范 [MUST]

### 7.1 接口限流

```java
@SentinelResource(
    value = "createOrder",
    blockHandler = "createOrderBlockHandler"
)
@PostMapping
public Result<Long> createOrder(@RequestBody @Valid OrderCreateRequest request) {
    return Result.success(orderService.createOrder(request));
}

public Result<Long> createOrderBlockHandler(OrderCreateRequest request, BlockException e) {
    return Result.fail(429, "请求过于频繁，请稍后重试");
}
```

### 7.2 幂等性设计

```java
@PostMapping
public Result<Long> createOrder(
        @RequestHeader("X-Request-Id") String requestId,
        @RequestBody @Valid OrderCreateRequest request) {

    // 幂等检查
    String key = "idempotent:order:" + requestId;
    Boolean isNew = redisTemplate.opsForValue()
        .setIfAbsent(key, "1", 30, TimeUnit.MINUTES);
    if (Boolean.FALSE.equals(isNew)) {
        throw new BusinessException("请勿重复提交");
    }

    return Result.success(orderService.createOrder(request));
}
```

### 7.3 敏感数据脱敏

```java
@Data
public class UserVO {
    private Long userId;
    private String userName;

    @JsonSerialize(using = PhoneDesensitizer.class)
    private String phone;  // 138****8000

    @JsonSerialize(using = IdCardDesensitizer.class)
    private String idCard;  // 310***********1234
}
```

---

## 八、反模式检查清单

| 序号 | 反模式 | 检测方式 |
|------|--------|----------|
| 1 | URL 包含动词 | 检查 RequestMapping 路径 |
| 2 | GET 请求带 RequestBody | 检查 GET 方法参数 |
| 3 | 无统一响应格式 | 检查返回类型是否为 Result |
| 4 | 无参数校验注解 | 检查 @Valid/@Validated |
| 5 | 无全局异常处理 | 检查 @RestControllerAdvice |
| 6 | 无接口文档注解 | 检查 @Operation/@Tag |
| 7 | 无版本号 | 检查 URL 是否包含 /v1/ |
| 8 | 响应包含敏感数据 | 检查 password/secret 等字段 |
| 9 | POST 接口无幂等设计 | 检查创建类接口 |
| 10 | 无分页参数 | 检查列表查询接口 |
