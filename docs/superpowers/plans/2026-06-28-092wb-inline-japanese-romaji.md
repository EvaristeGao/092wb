# 092 五笔内嵌日语罗马字输入实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `092wb` 方案中增加 `zu` 前缀的日语罗马字查询，让用户可以在 092 五笔中穿插输入日语候选。

**架构：** `092wb.schema.yaml` 负责声明 `japanese` 依赖、注册 `affix_segmentor@japanese_lookup` 与 `script_translator@japanese_lookup`，并定义日语 lookup 的字典和前缀配置。`default.yaml` 与 `default.custom.yaml` 负责 recognizer pattern，让 `zu...` 进入日语 lookup，同时让原拼音反查排除 `zu...`。`lua/092wb_new_spelling.lua` 对日语 lookup 段跳过 092 拆分提示，避免日语汉字候选 comment 被改成 092 编码。日语词典来源仍是 `rime-japanese` submodule 生成的根目录 `japanese*.yaml` 文件。

**技术栈：** Rime YAML schema、Git submodule 管理的 `rime-japanese` 字典、人工 Rime 部署验证。

---

## 文件结构

- 修改 `092wb.schema.yaml`：增加 `japanese` dependency；在 segmentors 中加入 `affix_segmentor@japanese_lookup`；在 translators 中加入 `script_translator@japanese_lookup`；增加 `japanese_lookup` 配置。
- 修改 `default.yaml`：增加 `recognizer.patterns.japanese_lookup`，并把 `reverse_lookup` 改为排除 `zu...`。
- 修改 `default.custom.yaml`：同步 `default.yaml` 的 recognizer pattern，保持用户实际 patch 路径一致。
- 修改 `lua/092wb_new_spelling.lua`：日语 lookup 段跳过 092 拆分提示，空 comment 时用当前罗马字兜底。
- 不修改 `japanese*.yaml` 词典内容。
- 不新增 Lua translator。

### 任务 1：更新 092 schema 的日语 lookup 配置

**文件：**
- 修改：`092wb.schema.yaml`

- [ ] **步骤 1：确认实现前缺少 japanese lookup**

运行：

```bash
rg -n "japanese|japanese_lookup|reverse_lookup_translator" 092wb.schema.yaml
```

预期：只看到现有 `reverse_lookup_translator` 和其他既有内容，不包含 `japanese_lookup`，`schema.dependencies` 中不包含 `japanese`。

- [ ] **步骤 2：修改 `schema.dependencies`**

在 `092wb.schema.yaml` 的 dependency 列表中加入：

```yaml
    - japanese          # 日语罗马字穿插输入
```

修改后的片段应为：

```yaml
  dependencies:   # 依赖
    - 092wb_core        # 引入自定义过滤
    - 092wb_py          # 反查
    - 092wb_wb_spelling # 引入拆分
    - japanese          # 日语罗马字穿插输入
```

- [ ] **步骤 3：注册日语 lookup segmentor 与 translator**

在 `engine/segmentors` 中把现有片段：

```yaml
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - punct_segmentor
    - fallback_segmentor
```

改为：

```yaml
    - ascii_segmentor
    - matcher
    - abc_segmentor
    - affix_segmentor@japanese_lookup
    - punct_segmentor
    - fallback_segmentor
```

在 `engine/translators` 中把现有片段：

```yaml
    - punct_translator
    - reverse_lookup_translator             # 反查
    - table_translator
```

改为：

```yaml
    - punct_translator
    - reverse_lookup_translator             # 反查
    - script_translator@japanese_lookup     # 日语罗马字查询
    - table_translator
```

- [ ] **步骤 4：增加 `japanese_lookup` 配置**

在 `reverse_lookup` 配置块之后加入：

```yaml
japanese_lookup:
  tag: japanese_lookup
  dictionary: japanese
  spelling_hints: 5
  enable_completion: true
  prefix: "zu"
  tips: [日语]
  comment_format:
    - 'xlit|q|ー|'
  preedit_format:
    - 'xlit|q|ー|'
```

- [ ] **步骤 5：检查 diff**

运行：

```bash
git diff -- 092wb.schema.yaml
```

预期：diff 只包含 `japanese` dependency、`affix_segmentor@japanese_lookup`、`script_translator@japanese_lookup` 和 `japanese_lookup` 配置。

- [ ] **步骤 6：Commit**

运行：

```bash
git add 092wb.schema.yaml
git commit -m "feat: add japanese romaji lookup to 092wb"
```

预期：提交只包含 `092wb.schema.yaml`。

### 任务 2：更新 recognizer pattern

**文件：**
- 修改：`default.yaml`
- 修改：`default.custom.yaml`

- [ ] **步骤 1：确认当前 recognizer pattern**

运行：

```bash
rg -n "japanese_lookup|reverse_lookup|punct:" default.yaml default.custom.yaml
```

预期：两个文件都有 `reverse_lookup: "^z[a-z]*'?$"`，都没有 `japanese_lookup`。

- [ ] **步骤 2：修改 `default.yaml`**

把 `default.yaml` 中的 recognizer pattern：

```yaml
    punct: "^zi([0-9]0?|[A-Za-z]+)$"          # 特殊符号引导规则
    reverse_lookup: "^z[a-z]*'?$"             # 反查规则
```

改为：

```yaml
    punct: "^zi([0-9]0?|[A-Za-z]+)$"          # 特殊符号引导规则
    japanese_lookup: "^zu[a-z_-]*$"           # 日语罗马字查询规则
    reverse_lookup: "^z([a-tv-z][a-z]*)?'?$"  # 反查规则，排除 zu 日语前缀
```

- [ ] **步骤 3：修改 `default.custom.yaml`**

把 `default.custom.yaml` 中同样的 recognizer pattern 改为：

```yaml
      punct: "^zi([0-9]0?|[A-Za-z]+)$"          # 特殊符号引导规则
      japanese_lookup: "^zu[a-z_-]*$"           # 日语罗马字查询规则
      reverse_lookup: "^z([a-tv-z][a-z]*)?'?$"  # 反查规则，排除 zu 日语前缀
```

- [ ] **步骤 4：检查 diff**

运行：

```bash
git diff -- default.yaml default.custom.yaml
```

预期：diff 只包含两个 recognizer pattern 块的新增 `japanese_lookup` 和 `reverse_lookup` 正则更新。

- [ ] **步骤 5：Commit**

运行：

```bash
git add default.yaml default.custom.yaml
git commit -m "feat: route zu prefix to japanese lookup"
```

预期：提交只包含 `default.yaml` 和 `default.custom.yaml`。

### 任务 3：静态验证配置

**文件：**
- 检查：`092wb.schema.yaml`
- 检查：`default.yaml`
- 检查：`default.custom.yaml`

- [ ] **步骤 1：验证 schema 依赖与 translator**

运行：

```bash
rg -n "japanese|japanese_lookup|affix_segmentor@japanese_lookup|script_translator@japanese_lookup" 092wb.schema.yaml
```

预期输出包含：

```text
- japanese
- affix_segmentor@japanese_lookup
- script_translator@japanese_lookup
japanese_lookup:
  tag: japanese_lookup
  dictionary: japanese
  prefix: "zu"
```

- [ ] **步骤 2：验证 recognizer pattern**

运行：

```bash
rg -n "japanese_lookup|reverse_lookup" default.yaml default.custom.yaml
```

预期输出包含：

```text
japanese_lookup: "^zu[a-z_-]*$"
reverse_lookup: "^z([a-tv-z][a-z]*)?'?$"
```

- [ ] **步骤 3：确认没有改动日语词典**

运行：

```bash
git status --short japanese.dict.yaml japanese.jmdict.dict.yaml japanese.kana.dict.yaml japanese.mozc.dict.yaml japanese.schema.yaml
```

预期：无输出，或这些文件仅在 `--ignored` 下显示为 ignored 生成文件；不能出现 staged 或 modified 状态。

- [ ] **步骤 4：确认暂存区干净**

运行：

```bash
git diff --cached --name-status
```

预期：无输出。

### 任务 4：准备人工验证说明

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：补充 092 内嵌日语输入说明**

在 README 的日语方案说明段落后加入：

```markdown
在 092 五笔中可用 `zu` 前缀穿插输入日语罗马字。例如输入 `zunihon`、`zuarigatou` 查询日语候选。
```

- [ ] **步骤 2：检查 README diff**

运行：

```bash
git diff -- README.md
```

预期：diff 只新增一行或一个短段落，说明 `zu` 前缀的用法。

- [ ] **步骤 3：Commit**

运行：

```bash
git add README.md
git commit -m "docs: document inline japanese romaji input"
```

预期：提交只包含 `README.md`。

### 任务 5：最终验证与交接

**文件：**
- 检查：全仓状态

- [ ] **步骤 1：运行最终静态检查**

运行：

```bash
git status --short
git log --oneline -5
rg -n "japanese_lookup|reverse_lookup: \"\\^z\\(\\[a-tv-z\\]" 092wb.schema.yaml default.yaml default.custom.yaml
```

预期：

```text
# git status --short 不包含本次实现文件的未提交改动
# git log --oneline -5 显示本次实现的 3 个提交
# rg 输出显示 japanese_lookup 配置和两个 reverse_lookup 排除 zu 的规则
```

- [ ] **步骤 2：确认日语生成文件仍被忽略**

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

- [ ] **步骤 3：汇报人工 Rime 验证项**

最终回复中列出需要用户在本机 Rime 部署后验证的输入：

```text
zunihon      应出现日语候选
zuarigatou   应出现日语候选
zi1          仍进入特殊符号
z            仍重复上屏
其他 z 拼音反查仍可用，但 zu... 已保留给日语
```
