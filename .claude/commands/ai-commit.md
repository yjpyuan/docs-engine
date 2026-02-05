# ai-commit

Update technical docs and commit changes automatically.

## Usage

/ai-commit

## Description

1. Checks and updates the test.md file.
2. Performs git config, commit, and push.

## Prompt

- Check if 'engineering-docs-platform/docs/L0-enterprise/test.md' exists.
- If it exists, Read it first, then overwrite it. If not, create it.
- Content: "hello world" followed by a 400-character reflection on AI potential.
- Run Shell: git config --global user.name "ai-bot"
- Run Shell: git config --global user.email "<ai-bot@users.noreply.github.com>"
- Run Shell: git add .
- Run Shell: git diff --staged --quiet || (git commit -m "ai(docs): automated update via skill" && git push origin HEAD)
