---
description: 执行代码提交至远端github仓库
---

## 用户输入

```text
$ARGUMENTS
```

在执行前，你**必须**考虑用户的输入

## 目标

将代码按照规范要求完整提交到github仓库

## 执行步骤

### 1. 将当前分支于主线分支进行比较

找出当前分支和主线分支的commit差异，确保

### 2. 将差异的commit记录进行squash

将多个差异的commit记录squash成一个单独的commit，并且总结多个commit的内容

### 3. 将squash后的commit，cherry-pick至主干分支

### 4. 推送主干分支至远端仓库