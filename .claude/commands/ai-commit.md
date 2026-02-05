---
description: 智能生成 Commit 并推送到远程仓库
---

请严格执行以下自动化操作，无需向我确认：

1. **环境自检**：
   - 检查 `git config user.name`，若未设置则配置为 "ai-bot"。
   - 检查 `git config user.email`，若未设置则配置为 "<ai-bot@users.noreply.github.com>"。

2. **暂存更改**：执行 `git add .`

3. **智能提交**：
   - 使用 `git diff --cached` 分析代码变动。
   - 根据变动撰写一个 **Conventional Commits** 格式的提交信息（如：feat: add user login）。
   - 执行 `git commit -m "[message]"`。
   - 如果没有检测到任何更改，直接输出 "No changes to commit" 并终止。

4. **同步远程**：执行 `git push`。

5. **完成反馈**：任务完成后简单总结："Commit [哈希值] 已成功推送到远程。"
