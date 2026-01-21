# Vue 3 编码规范（Ref-First · TypeScript 强约束版）

> 本规范基于 Vue 3.3+、TypeScript 5+ 及 Composition API，采用 **Ref 优先（Ref-First）策略**，并以 **类型系统作为第一约束**，旨在消除“过度灵活”带来的维护成本，构建**类型安全、逻辑自洽、性能可控**的前端工程。

---

## 规范级别

| 标识       | 含义                                               |
| ---------- | -------------------------------------------------- |
| `[MUST]`   | 强制要求，违反将导致逻辑错误、性能问题或 Lint 报错 |
| `[SHOULD]` | 推荐实践，除非有明确理由并注明，否则应遵循         |
| `[MAY]`    | 可选优化，视业务复杂度与性能需求而定               |

---

## 一、命名规范

### 1.1 文件命名 [MUST]

| 类型       | 规则                            | 示例                  |
| ---------- | ------------------------------- | --------------------- |
| 单文件组件 | `PascalCase.vue`                | `UserCard.vue`        |
| 组合式函数 | `camelCase.ts` 文件名 = Hook 名 | `useAuthStatus.ts`    |
| 子组件     | 同名目录管理，组件名语义明确    | `order-list/Item.vue` |

- **[MUST]** 非组件 `.ts` 文件禁止使用 `default export`，必须使用命名导出
  （增强 IDE 自动导入准确性，减少误引用）

---

### 1.2 标识符命名 [MUST]

| 类型       | 规则                           | 示例              |
| ---------- | ------------------------------ | ----------------- |
| 常量       | `UPPER_SNAKE_CASE`（模块顶层） | `MAX_RETRY_COUNT` |
| Props 接口 | `PascalCase + Props`           | `UserCardProps`   |
| 泛型       | `T` 或 `T + 描述`              | `TData`           |
| Boolean    | `is / has / can / should` 前缀 | `isLoading`       |

---

### 1.3 函数命名约定 [SHOULD]

| 类型         | 规则                         | 示例                |
| ------------ | ---------------------------- | ------------------- |
| 事件处理函数 | `handle + 动词`              | `handleSubmit`      |
| 副作用函数   | `fetch / sync / init` 前缀   | `fetchUser`         |
| Emit 事件    | `update:x / change / submit` | `update:modelValue` |

- **[MUST]** `handleXxx` 仅用于事件响应
- **[MUST]** 副作用函数禁止命名为 `handleXxx`

---

## 二、组件结构规范

### 2.1 代码组织顺序 [MUST]

`<script setup lang="ts">` 内**必须**遵循以下顺序（大型组件尤为关键）：

1. 类型定义（Props / Emits / 内部类型）
2. `defineOptions`
3. `defineProps` / `withDefaults`
4. `defineEmits`
5. State（**Ref 优先**）
6. Computed
7. 外部 Composables / Store
8. Watch
9. Methods / Handlers
10. 生命周期 Hooks
11. `defineExpose`

---

### 2.2 逻辑抽离 [MUST]

- **[MUST]** 模板中禁止复杂表达式
- **[MUST]** 超过 10 行逻辑必须抽离为函数
- **[MUST]** 超过 2 处复用逻辑必须抽离为 `useXxx`
- **[MUST]** 模板中禁止内联复杂函数调用

---

### 2.3 渲染纯度约束 [MUST]

- **[MUST]** 渲染阶段（模板 / setup 执行）禁止：

  - 发起请求
  - 修改外部变量
  - 使用非幂等 API（`Date.now()` / `Math.random()`）

- **[MUST]** 所有副作用只能存在于：

  - `watch`
  - 生命周期 Hooks
  - 事件处理函数

---

## 三、Composition API 深度规范（Ref-First）

### 3.1 响应式建模原则 [MUST]

- **[MUST]** 默认使用 `ref`（包括对象、数组）
- **[SHOULD]** 仅在以下场景允许 `reactive`：

  - 表单聚合对象
  - 高度内聚、无需解构的一组状态

- **[MUST]** 禁止因“对象是对象”而选择 `reactive`

> 选择依据是 **是否需要解构、是否需要替换引用**，而不是数据形态。

---

### 3.2 解构与响应性保持 [MUST]

- **[MUST]** 从 `reactive` 解构必须使用 `toRefs`
- **[MUST]** Pinia Store 解构 state / getter 必须使用 `storeToRefs`
- **[MUST]** 禁止直接解构导致响应性丢失

---

### 3.3 Watch 使用规范 [MUST]

- **[MUST]** `watch` 必须显式声明依赖
- **[MUST]** 禁止使用 `watchEffect` 承载业务逻辑
- **[MUST]** 禁止在 `watch` 中同步修改其监听源

---

### 3.4 副作用职责单一化 [MUST]

- **[MUST]** 一个 `watch` 只处理一种副作用
- **[MUST]** 不同语义的副作用必须拆分

---

## 四、状态与性能优化

### 4.1 状态建模规范 [MUST]

- **[MUST]** 状态中禁止存储：

  - 可计算值
  - Props 镜像

- 派生数据必须使用 `computed`
- **[MUST]** 禁止在 `reactive` 中嵌套 `ref`

---

### 4.2 引用稳定性 [MUST]

- **[MUST]** 作为 Props 传递的对象 / 数组必须稳定
- **[MUST]** 避免在模板中直接创建对象字面量

---

### 4.3 Key 稳定性 [MUST]

- **[MUST]** `v-for` 禁止使用 index 作为 key
- **[MUST]** key 必须来源于业务唯一标识

---

### 4.4 Provide / Inject 约束 [MUST]

- **[MUST]** 提供的值必须是稳定引用
- **[MUST]** 复杂场景拆分：

  - State
  - Mutations / Actions

---

## 五、异步与并发安全

### 5.1 异步逻辑约束 [MUST]

- **[MUST]** 禁止在 setup 顶层直接执行异步副作用
- **[MUST]** 异步请求必须：

  - 显式封装为函数
  - 由生命周期或事件触发

- **[MUST]** 必须考虑组件卸载后的异步终止（Abort / 忽略回调）

---

### 5.2 更新调度 [SHOULD]

- **[SHOULD]** `nextTick` 仅用于 DOM 同步
- **[MUST]** 禁止依赖 DOM 状态驱动业务逻辑

---

## 六、TypeScript 强约束（升级）

### 6.1 Props / Emits [MUST]

- **[MUST]** Props 必须使用 **TypeScript 泛型**
- **[MUST]** 禁止运行时 Props 声明
- **[MUST]** Emits 必须声明事件签名（元组）
- Props 默认只读，禁止修改

---

### 6.2 Ref 类型 [MUST]

- **[MUST]** DOM Ref 必须声明具体类型

```ts
const el = ref<HTMLDivElement | null>(null);
```

---

## 七、反模式（禁止清单）

| 编号 | 行为                          |
| ---- | ----------------------------- |
| 1    | 在模板或 setup 中发起请求     |
| 2    | 修改 Props                    |
| 3    | 使用 index 作为 key           |
| 4    | watch 中修改监听源            |
| 5    | 在模板中执行副作用函数        |
| 6    | setup 中使用非幂等 API        |
| 7    | 解构 reactive 导致失去响应性  |
| 8    | 使用 watchEffect 承载业务逻辑 |
| 9    | 解构 Pinia Store state        |
| 10   | 在 reactive 中嵌套 ref        |

---

## 八、工具链配置

### 8.1 ESLint 核心约束 [MUST]

```json
{
  "vue/no-mutating-props": "error",
  "vue/no-side-effects-in-computed-properties": "error",
  "vue/no-use-v-if-with-v-for": "error",
  "vue/require-explicit-emits": "error",
  "vue/this-in-template": "error"
}
```

---

### 8.2 ESLint 风格层 [SHOULD]

```json
{
  "vue/component-name-in-template-casing": "warn",
  "vue/attributes-order": "warn",
  "vue/html-self-closing": "warn"
}
```

---

### 8.3 TypeScript 编译约束 [MUST]

```json
{
  "strict": true,
  "noUnusedLocals": true,
  "noUnusedParameters": true,
  "noImplicitReturns": true,
  "noUncheckedIndexedAccess": true,
  "allowUnreachableCode": false
}
```

---

## 核心哲学（不可违背）

1. **组件是响应式状态的投影**
2. **副作用必须显式、可追踪**
3. **响应性不可被破坏**
4. **模板必须是纯表达式**
5. **类型系统是第一约束，不是装饰**
