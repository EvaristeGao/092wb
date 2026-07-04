# rime-japanese submodule workflow 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 `rime-japanese` 作为父仓的 Git submodule 管理，并用同步脚本生成根目录日语 Rime YAML 文件，避免父仓跟踪根目录 symlink。

**架构：** `rime-japanese/` 是日语方案唯一上游来源，父仓只记录 submodule 指针和本地同步规则。根目录 `japanese*.yaml` 是部署产物，由 `scripts/sync-rime-japanese` 从 submodule 复制生成，并通过 `.gitignore` 排除出父仓。已有 `default.yaml` 和 `default.custom.yaml` 继续负责在 Rime `schema_list` 中启用 `japanese`。

**技术栈：** Git submodule、POSIX shell、Rime YAML 配置。

---

## 文件结构

- 创建 `.gitmodules`：记录 `rime-japanese` submodule 的路径和上游 URL。
- 修改 Git index：把 `rime-japanese/` 记录为 submodule gitlink，而不是普通未跟踪目录。
- 创建 `scripts/sync-rime-japanese`：复制 submodule 中的 5 个日语 YAML 文件到父仓根目录；先检查全部源文件，再删除目标文件或 symlink，然后复制。
- 修改 `.gitignore`：忽略根目录生成的 `japanese*.yaml`，保留其他用户数据忽略规则。
- 修改 `default.yaml`：确认 `schema_list` 包含 `japanese`。
- 修改 `default.custom.yaml`：确认 patch 中 `schema_list` 包含 `japanese`。
- 不跟踪 `japanese.schema.yaml`、`japanese.dict.yaml`、`japanese.jmdict.dict.yaml`、`japanese.kana.dict.yaml`、`japanese.mozc.dict.yaml`。

### 任务 1：记录 submodule

**文件：**
- 创建：`.gitmodules`
- 修改：Git index 中的 `rime-japanese` gitlink

- [ ] **步骤 1：确认当前子仓干净且远端正确**

运行：

```bash
git -C rime-japanese status --short
git -C rime-japanese remote -v
git -C rime-japanese rev-parse --short HEAD
```

预期：

```text
# status 无输出
origin	https://github.com/gkovacs/rime-japanese.git (fetch)
origin	https://github.com/gkovacs/rime-japanese.git (push)
4c1e651
```

- [ ] **步骤 2：把已有目录加入 submodule**

运行：

```bash
git submodule add --force https://github.com/gkovacs/rime-japanese.git rime-japanese
```

预期：生成 `.gitmodules`，并把 `rime-japanese` 作为 gitlink 加入暂存区。如果 Git 输出 `Adding existing repo at 'rime-japanese' to the index`，这是符合预期的。

- [ ] **步骤 3：检查 submodule 配置**

运行：

```bash
git config --file .gitmodules --get submodule.rime-japanese.path
git config --file .gitmodules --get submodule.rime-japanese.url
git diff --cached --name-status
```

预期：

```text
rime-japanese
https://github.com/gkovacs/rime-japanese.git
A	.gitmodules
A	rime-japanese
```

- [ ] **步骤 4：Commit**

运行：

```bash
git add .gitmodules rime-japanese
git commit -m "chore: add rime-japanese submodule"
```

预期：提交只包含 `.gitmodules` 和 `rime-japanese` gitlink。

### 任务 2：忽略根目录日语生成文件

**文件：**
- 修改：`.gitignore`

- [ ] **步骤 1：查看现有忽略规则**

运行：

```bash
sed -n '1,120p' .gitignore
```

预期：看到现有规则，包括 `.DS_Store`、`build/`、`installation.yaml`、`sync/`、`user.yaml`、`*.userdb/`。

- [ ] **步骤 2：在 `.gitignore` 增加根目录生成文件规则**

修改 `.gitignore`，加入以下内容：

```gitignore
/japanese.schema.yaml
/japanese.dict.yaml
/japanese.jmdict.dict.yaml
/japanese.kana.dict.yaml
/japanese.mozc.dict.yaml
```

- [ ] **步骤 3：确认根目录 symlink 变为 ignored**

运行：

```bash
git status --short --ignored japanese.schema.yaml japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml
```

预期：

```text
!! japanese.dict.yaml
!! japanese.jmdict.dict.yaml
!! japanese.kana.dict.yaml
!! japanese.mozc.dict.yaml
!! japanese.schema.yaml
```

- [ ] **步骤 4：Commit**

运行：

```bash
git add .gitignore
git commit -m "chore: ignore generated japanese rime files"
```

预期：提交只包含 `.gitignore`。

### 任务 3：添加同步脚本

**文件：**
- 创建：`scripts/sync-rime-japanese`

- [ ] **步骤 1：创建脚本**

创建 `scripts/sync-rime-japanese`，内容如下：

```sh
#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

SUBMODULE_DIR="rime-japanese"

FILES="
japanese.schema.yaml
japanese.dict.yaml
japanese.jmdict.dict.yaml
japanese.kana.dict.yaml
japanese.mozc.dict.yaml
"

if [ ! -d "$SUBMODULE_DIR" ]; then
  echo "error: $SUBMODULE_DIR is missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

if [ ! -f "$SUBMODULE_DIR/japanese.schema.yaml" ]; then
  echo "error: $SUBMODULE_DIR is not initialized. Run: git submodule update --init --recursive" >&2
  exit 1
fi

for file in $FILES; do
  if [ ! -f "$SUBMODULE_DIR/$file" ]; then
    echo "error: missing source file: $SUBMODULE_DIR/$file" >&2
    exit 1
  fi
done

for file in $FILES; do
  rm -f "$file"
  cp "$SUBMODULE_DIR/$file" "$file"
done

echo "Synced rime-japanese files."
```

- [ ] **步骤 2：赋予执行权限**

运行：

```bash
chmod +x scripts/sync-rime-japanese
```

预期：脚本可执行。

- [ ] **步骤 3：运行脚本生成根目录文件**

运行：

```bash
scripts/sync-rime-japanese
```

预期：

```text
Synced rime-japanese files.
```

- [ ] **步骤 4：确认生成的是普通文件而不是 symlink**

运行：

```bash
ls -l japanese.schema.yaml japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml
```

预期：每一行都以 `-rw` 开头，不以 `l` 开头。

- [ ] **步骤 5：确认生成文件仍被忽略**

运行：

```bash
git status --short --ignored japanese.schema.yaml japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml
```

预期：

```text
!! japanese.dict.yaml
!! japanese.jmdict.dict.yaml
!! japanese.kana.dict.yaml
!! japanese.mozc.dict.yaml
!! japanese.schema.yaml
```

- [ ] **步骤 6：Commit**

运行：

```bash
git add scripts/sync-rime-japanese
git commit -m "chore: add rime-japanese sync script"
```

预期：提交只包含 `scripts/sync-rime-japanese`。

### 任务 4：确认方案列表启用 japanese

**文件：**
- 修改：`default.yaml`
- 修改：`default.custom.yaml`

- [ ] **步骤 1：查看两个配置的 schema_list**

运行：

```bash
rg -n "schema_list|schema: japanese|schema: 092wb" default.yaml default.custom.yaml
```

预期：两个文件都包含 `schema: 092wb` 和 `schema: japanese`。

- [ ] **步骤 2：如果缺少 japanese，补齐 `default.yaml`**

`default.yaml` 中应包含：

```yaml
schema_list:
  - schema: 092wb
  - schema: japanese
```

- [ ] **步骤 3：如果缺少 japanese，补齐 `default.custom.yaml`**

`default.custom.yaml` 的 `patch.schema_list` 中应包含：

```yaml
  schema_list:
    - schema: 092wb
    - schema: japanese
```

- [ ] **步骤 4：检查 diff 只包含 schema_list 相关改动**

运行：

```bash
git diff -- default.yaml default.custom.yaml
```

预期：如果文件此前已经包含 `japanese`，无 diff；如果有 diff，只应是 `schema_list` 增加 `- schema: japanese`。

- [ ] **步骤 5：如有配置改动则 Commit**

如果 `git diff --quiet -- default.yaml default.custom.yaml` 返回非 0，运行：

```bash
git add default.yaml default.custom.yaml
git commit -m "feat: enable japanese schema"
```

预期：提交只包含 `default.yaml` 和 `default.custom.yaml`。如果没有 diff，跳过此步骤并记录“配置已提前完成”。

### 任务 5：验证 submodule 和生成文件边界

**文件：**
- 检查：`.gitmodules`
- 检查：`rime-japanese`
- 检查：根目录 `japanese*.yaml`

- [ ] **步骤 1：确认 submodule 被父仓记录**

运行：

```bash
git submodule status
git ls-files --stage rime-japanese
```

预期：

```text
 4c1e651... rime-japanese ...
160000 ...
```

其中 `160000` 表示 `rime-japanese` 是 gitlink。

- [ ] **步骤 2：确认根目录日语 YAML 没有被跟踪**

运行：

```bash
git ls-files japanese.schema.yaml japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml
```

预期：无输出。

- [ ] **步骤 3：确认工作区没有意外暂存内容**

运行：

```bash
git diff --cached --name-status
```

预期：无输出。

- [ ] **步骤 4：确认剩余改动符合预期**

运行：

```bash
git status --short
```

预期：不再出现未跟踪的 `japanese*.yaml` 或普通未跟踪的 `rime-japanese/`。如果 `.codex/`、`AGENTS.md` 或其他用户现场改动仍然存在，不要修改它们。

### 任务 6：记录人工验证要求

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：添加 submodule 初始化和同步说明**

在 README 的安装说明附近加入简短说明：

````markdown
### 日语方案

日语方案来自 `rime-japanese` submodule。首次克隆后先初始化子模块：

```shell
git submodule update --init --recursive
```

如需在当前 Rime 配置目录根部生成日语方案文件，运行：

```shell
scripts/sync-rime-japanese
```

Rime 部署后的实际候选效果需要在本机输入法中验证。
````

- [ ] **步骤 2：检查 Markdown 代码围栏完整**

运行：

```bash
rg -n "日语方案|submodule|sync-rime-japanese|```" README.md
```

预期：新增小节可读，代码围栏成对出现。

- [ ] **步骤 3：Commit**

运行：

```bash
git add README.md
git commit -m "docs: document rime-japanese setup"
```

预期：提交只包含 `README.md`。

### 任务 7：最终验证

**文件：**
- 检查：全仓状态

- [ ] **步骤 1：运行最终 Git 检查**

运行：

```bash
git status --short
git submodule status
git ls-files japanese.schema.yaml japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml
```

预期：

```text
# git status --short 不包含 japanese*.yaml，也不包含 ?? rime-japanese/
# git submodule status 显示 rime-japanese
# git ls-files japanese*.yaml 无输出
```

- [ ] **步骤 2：运行同步脚本 smoke test**

运行：

```bash
scripts/sync-rime-japanese
ls -l japanese.schema.yaml japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml
```

预期：

```text
Synced rime-japanese files.
# ls 输出中 5 个 japanese*.yaml 都是普通文件
```

- [ ] **步骤 3：汇报人工验证项**

在最终回复中说明：自动检查已覆盖 submodule、生成文件和脚本；Rime 实际部署、方案切换和候选效果仍需用户在本机验证。
