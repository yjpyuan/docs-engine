# React 18+ 编码规范

> 本规范定义 React 18+ 的 **强约束开发标准**，面向函数组件、Hooks、并发安全、SSR/RSC 兼容、性能可控性与工具链（ESLint / TypeScript）的**可执行性**

---

## 规范级别

| 标识       | 含义                               |
| ---------- | ---------------------------------- |
| `[MUST]`   | 强制要求，违反会导致错误或工程风险 |
| `[SHOULD]` | 推荐实践，违反需有明确理由         |
| `[MAY]`    | 可选优化                           |

---

## 一、命名规范

### 1.1 文件命名 `[MUST]`

| 类型             | 规则                               | 示例                  |
| ---------------- | ---------------------------------- | --------------------- |
| 组件文件         | `PascalCase.tsx`                   | `UserCard.tsx`        |
| 自定义 Hook 文件 | `camelCase.ts`（文件名 = Hook 名） | `useAuthStatus.ts`    |
| 工具函数文件     | `kebab-case.ts`                    | `format-date.ts`      |
| 功能目录         | `kebab-case/`                      | `order-list/`         |
| 内部子组件       | 同目录下明确命名或 `index.tsx`     | `order-list/Item.tsx` |

---

### 1.2 标识符命名 `[MUST]`

| 类型         | 规则                           | 示例              |
| ------------ | ------------------------------ | ----------------- |
| 常量         | `UPPER_SNAKE_CASE`（模块顶层） | `MAX_RETRY_COUNT` |
| 组件         | `PascalCase`                   | `OrderDetail`     |
| Hook         | `camelCase` 且以 `use` 开头    | `useAuthStatus`   |
| 事件处理函数 | `handle + 动作`                | `handleSubmit`    |
| 类型 / 接口  | `PascalCase + 语义后缀`        | `UserCardProps`   |

---

### 1.3 函数命名约定 [SHOULD]

| 类型         | 规则                       | 示例           |
| ------------ | -------------------------- | -------------- |
| 事件处理函数 | `handle + 动词`            | `handleSubmit` |
| 副作用函数   | `fetch / sync / init` 前缀 | `fetchUser`    |
| 回调 Props   | `on + 动词`                | `onClose`      |

- **[MUST]** `handleXxx` 仅用于事件响应
- **[MUST]** 副作用函数禁止命名为 `handleXxx`

---

## 二、组件规范

### 2.1 组件形态 `[MUST]`

- **仅允许函数组件**
- 禁止 class component
- render 阶段必须是**纯逻辑**（无副作用）

---

### 2.2 Props 规范 `[MUST]`

- Props 必须确保 TypeScript 显式类型定义。
- 解构 Props 并提供合理默认值。
- 禁止 Props 透传至 DOM 元素（禁止 `{...props}`）。

---

## 三、组件导出规范（强制）

### 3.1 导出规则 `[MUST]`

- **禁止 `export default` 导出组件**
- **必须使用命名导出**

```ts
// ✅ 正确
export function UserCard(props: UserCardProps) {}

// ❌ 禁止
export default function UserCard() {}
```

---

### 3.2 原因（工程级）

- 支持 Tree Shaking
- 重构与重命名安全
- 避免隐式依赖与匿名导入

---

## 四、Hooks 使用规范

### 4.1 Hooks 调用基本规则 [MUST]

> 只能在函数组件或自定义 Hook 的顶层调用 Hooks。
> Hooks 不能在循环、条件、嵌套函数或 `try/catch/finally` 代码块中调用。
> Hooks 不能在普通 JavaScript 函数或类组件中调用。

**具体约束：**

- Hooks 只能在 React 函数组件（render body）顶层调用。
- Hooks 只能在自定义 Hook 顶层调用。
- Hook 调用顺序必须一致。
- 不能在循环、条件、嵌套函数、事件处理器、异步函数、try/catch 中调用。

```ts
// ✅ 正确
function MyComponent() {
  const count = useState(0);
  // ...
}

// ❌ 错误 —— 在条件中
if (cond) {
  useState(1);
}
```

---

### 4.2 状态更新不可变性 [MUST]

- 更新 state 时必须创建新引用。
- 禁止直接修改 state 引用后再 set。

```ts
setList((prev) => [...prev, item]);
```

---

### 4.3 useEffect 使用边界 [MUST]

useEffect 仅用于同步外部系统：

| 场景               | 允许 |
| ------------------ | ---- |
| API 请求           | ✅   |
| 注册/监听          | ✅   |
| props → state 同步 | ❌   |
| 派生状态计算       | ❌   |

- 必须完整声明依赖数组。
- 若存在订阅/监听，必须在清理函数中注销。

---

## 五、React 18 Strict Mode 约束

### 5.1 双重挂载语义 `[MUST]`

> Strict Mode 下：`mount → unmount → mount`

- 所有 `useEffect` **必须返回清理函数**
- 副作用必须是 **幂等的**
- 禁止依赖“只执行一次”的假设

```ts
useEffect(() => {
  const id = subscribe();
  return () => unsubscribe(id);
}, []);
```

---

## 六、状态管理规范

### 6.1 状态类型区分 `[SHOULD]`

| 状态类型   | 推荐方式          |
| ---------- | ----------------- |
| UI 状态    | `useState`        |
| 派生状态   | `useMemo`         |
| 业务状态   | 上提 / 原子状态   |
| 服务端状态 | React Query / SWR |

- 禁止将可计算状态存入 `useState` `[MUST]`

---

### 6.2 性能优化 `[SHOULD]`

| 工具          | 使用条件           |
| ------------- | ------------------ |
| `useMemo`     | 昂贵计算           |
| `useCallback` | 传递给 memo 子组件 |
| `React.memo`  | 纯展示组件         |

---

## 七、Context 使用与性能边界

### 7.1 Context 使用规则 `[MUST]`

- Provider 的 `value` **必须是稳定引用**
- 必须使用 `useMemo` / `useCallback`
- 禁止在 Context 中放高频变更状态

```ts
const value = useMemo(() => ({ user, setUser }), [user]);
```

---

### 7.2 架构建议 `[SHOULD]`

- 优先使用 Zustand / Jotai / Redux Toolkit
- Context 仅用于低频、跨层级数据
- 禁止“大一统 Context”

---

## 八、并发特性规范

### 8.1 useTransition `[SHOULD]`

- 仅用于非关键 UI 更新
- 禁止用于表单提交等核心路径

---

### 8.2 Suspense `[SHOULD]`

- 必须有 fallback
- loading 边界清晰
- 禁止无意义嵌套

---

## 九、SSR / RSC（Server Components）

### 9.1 客户端组件 `[MUST]`

- 使用 Hooks / 浏览器 API 的组件
  **必须以 `use client` 开头**

```tsx
"use client";
```

---

### 9.2 服务端组件 `[MUST]`

- 禁止使用 `useState/useEffect`
- 禁止访问 `window / document`
- 仅包含纯渲染与数据读取逻辑

---

## 十、Ref 与 DOM 操作

### 10.1 Ref 使用边界 `[MUST]`

- 禁止使用 ref 操作 UI 状态
- 禁止通过 ref 替代 props / 事件流
- 禁止业务组件使用 `useImperativeHandle`

---

### 10.2 允许场景 `[SHOULD]`

- **仅限通用 UI 组件库**
- 必须有文档与测试

---

## 十一、错误处理 `[MUST]`

| 层级     | 方式            |
| -------- | --------------- |
| 路由层   | ErrorBoundary   |
| 核心模块 | ErrorBoundary   |
| 异步逻辑 | 显式 error 状态 |

---

## 十二、反模式（禁止） `[MUST]`

| 编号 | 行为                           |
| ---- | ------------------------------ |
| 1    | 条件 / 循环中调用 Hooks        |
| 2    | 使用 array index 作为 key      |
| 3    | useEffect 中同步 state         |
| 4    | 超大组件（>300 行）            |
| 5    | default export 组件            |
| 6    | 滥用 Context                   |
| 7    | 滥用 ref / useImperativeHandle |

---

## 十三、ESLint / TypeScript 对齐

### 13.1 ESLint（最小强约束）

```json
{
  "plugins": ["react", "react-hooks", "@typescript-eslint", "import"],
  "rules": {
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "error",
    "react/no-array-index-key": "error",
    "react/jsx-props-no-spreading": "error",
    "import/no-default-export": "error",
    "@typescript-eslint/no-explicit-any": "error"
  }
}
```

---

### 13.2 TypeScript

```json
{
  "strict": true,
  "exactOptionalPropertyTypes": true,
  "noUncheckedIndexedAccess": true
}
```

---

## 核心工程原则（不可违背）

- 渲染必须是纯函数
- Hooks 是“公式外的逻辑挂钩”
- Context ≠ 状态管理方案
- 默认导出是工程债务
- React 18 以 **并发 + 可重构** 为第一优先级

> **UI = f(state, props)**
> 一切副作用都必须被显式标记、可清理、可重复执行。
