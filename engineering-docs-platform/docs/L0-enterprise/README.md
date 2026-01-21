# Enterprise Knowledge Standards (L0)

企业级知识标准库 - 多级知识空间体系的顶层规范

## 概述

本仓库是企业级知识空间三层架构体系中的 **L0 企业级** 知识库，包含全公司必须遵循的强制规范和跨项目统一标准。

```
┌─────────────────────────────────────────────────────┐
│              企业级 L0 (本仓库)                      │
│         ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│         │ 技术宪法  │ │ 编码规范  │ │ 技术雷达  │     │
│         └──────────┘ └──────────┘ └──────────┘     │
├─────────────────────────────────────────────────────┤
│              项目级 L1 (继承 L0)                     │
│         业务领域 · 服务目录 · 架构决策               │
├─────────────────────────────────────────────────────┤
│              仓库级 L2 (继承 L1)                     │
│         仓库上下文 · 代码衍生文档                    │
└─────────────────────────────────────────────────────┘
```

## 目录结构

```
enterprise-standards/
├── constitution/               # 技术宪法（不可覆盖）
│   ├── architecture-principles.md  # 架构底线
│   ├── security-baseline.md        # 安全红线
│   ├── compliance-requirements.md  # 合规要求
│   └── constitution-template.md    # 宪章模板
│
├── standards/                  # 编码规范（L0 基线，L1 可细化）
│   ├── coding-standards/
│   │   └── java.md
│   ├── api-design-guide.md
│   └── testing-standards.md
│
├── governance/                 # 治理流程（不可覆盖）
│   ├── review-process.md       # 代码评审流程
│   └── release-process.md      # 发布流程
│
├── ai-coding/                  # AI 编码策略（不可覆盖）
│   └── ai-coding-policy.md
│
└── technology-radar/           # 技术雷达
    ├── adopt.md                # 推荐采用
    ├── trial.md                # 试用阶段
    ├── assess.md               # 评估阶段
    └── hold.md                 # 暂缓使用
```

## 核心约束分类

### 不可覆盖 (L1/L2 必须遵循)

| 类别 | 说明 |
|------|------|
| 安全红线 | 密码存储、注入防护、数据加密 |
| 合规要求 | GDPR、审计日志、数据出境 |
| 架构底线 | 分层架构、数据一致性、可观测性 |
| 治理流程 | 代码审查、发布流程、事故响应 |
| AI 安全约束 | 访问控制、代码审查、测试要求 |
| 技术雷达 Hold | 禁止新项目采用 |

### 可细化 (L1 可扩展)

| 类别 | 说明 |
|------|------|
| 编码风格 | L0 定义基线，L1 细化规则 |
| 测试标准 | L0 定义底线，L1 定义覆盖率 |
| 技术雷达 Trial | 项目可选择采用 |

## 下级知识库引用

项目级 (L1) 和仓库级 (L2) 知识库通过 Git Subtree 引入本仓库：

```bash
# L1 项目级引入 L0
git remote add L0-knowledge git@github.com:org/enterprise-knowledge.git
git subtree add --prefix=upstream/L0-enterprise L0-knowledge main --squash

# 更新 L0
git subtree pull --prefix=upstream/L0-enterprise L0-knowledge main --squash
```

## 维护方式

由架构委员会统一维护，变更需经过审批流程。

## 相关文档

- [架构设计文档](architecture-design/)
- [知识空间设计](architecture-design/05-knowledge-spaces.md)
