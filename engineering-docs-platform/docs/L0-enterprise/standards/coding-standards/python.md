## Python 开发规范

**核心要求:** 始终使用 uv | pytest 测试 | ruff 代码质量 | 自文档化代码

### 包管理 - 仅限 UV

**强制要求: 所有 Python 包操作必须使用 `uv`，禁止直接使用 `pip`。**

```bash
# 包操作
uv pip install package-name
uv pip install -r requirements.txt
uv pip list
uv pip show package-name

# 运行 Python
uv run python script.py
uv run pytest
uv run mypy src
```

**为什么用 uv:** 项目标准、更快的依赖解析、更好的锁文件、团队一致性。

**如果你输入了 `pip`:** 停下！改用 `uv pip`。

### 测试与质量

```bash
# 测试
uv run pytest                                       # 全部测试
uv run pytest -m unit                               # 仅单元测试
uv run pytest -m integration                        # 仅集成测试
uv run pytest --cov=src --cov-fail-under=80        # 带覆盖率（最低80%）

# 代码质量
ruff format .                                       # 格式化代码
ruff check . --fix                                  # 修复 lint 问题
mypy src --strict                                   # 类型检查
basedpyright src                                    # 备选类型检查器
```

### 代码风格要点

**文档字符串:** 大多数函数使用单行。仅复杂逻辑使用多行。
```python
def calculate_total(items: list[Item]) -> float:
    """计算所有商品的总价。"""
    return sum(item.price for item in items)
```

**类型提示:** 所有公共函数签名必须包含类型提示。
```python
def process_order(order_id: str, user_id: int) -> Order:
    pass
```

**导入顺序:** 标准库 → 第三方库 → 本地模块。使用 `ruff check . --fix` 自动排序。

**注释:** 编写自文档化代码。仅在复杂算法、非显而易见的业务逻辑或变通方案时使用注释。

### 项目配置

**Python 版本:** 3.12+（pyproject.toml 中设置 requires-python = ">=3.12"）

**项目结构:**
- 依赖项放在 `pyproject.toml`（不用 requirements.txt）
- 测试放在 `src/*/tests/` 目录
- 使用 `@pytest.mark.unit` 和 `@pytest.mark.integration` 标记

### 完成检查清单

完成 Python 工作前：
- [ ] 所有包操作都使用了 `uv`
- [ ] 测试通过: `uv run pytest`
- [ ] 代码已格式化: `ruff format .`
- [ ] Lint 检查通过: `ruff check .`
- [ ] 类型检查通过: `mypy src --strict` 或 `basedpyright src`
- [ ] 覆盖率 ≥ 80%
- [ ] 无未使用的导入（用 `getDiagnostics` 检查）

### 快速参考

| 任务         | 命令                          |
| ------------ | ----------------------------- |
| 安装包       | `uv pip install package-name` |
| 运行测试     | `uv run pytest`               |
| 覆盖率       | `uv run pytest --cov=src`     |
| 格式化       | `ruff format .`               |
| Lint 检查    | `ruff check . --fix`          |
| 类型检查     | `mypy src --strict`           |
| 运行脚本     | `uv run python script.py`     |
