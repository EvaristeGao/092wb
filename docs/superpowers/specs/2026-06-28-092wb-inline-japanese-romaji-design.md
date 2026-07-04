# 092 五笔内嵌日语罗马字输入设计

## 背景

`092wb` 是主力五笔方案，`z` 不属于 092 五笔字根，当前已用于若干辅助功能：

- 单独 `z`：重复上一次上屏
- `z[a-z]*'?`：拼音反查 092 编码
- `zi...`：特殊符号
- 候选菜单中 `z`：第 10 候选快捷键

项目已经通过 `rime-japanese` submodule 提供日语词典，并通过同步脚本在 Rime 配置根目录生成 `japanese*.yaml`。现在希望在不切换输入方案的情况下，在 092 五笔中穿插少量日语输入。

## 目标

在 `092wb` 方案中新增 `zu` 前缀的日语罗马字查询。用户输入 `zu` 加日语罗马字编码时，候选来自 `japanese` 字典。例如：

- `zunihon` 查询日语词典中的 `nihon`
- `zuarigatou` 查询日语词典中的 `arigatou`

`zu` 前缀只用于日语主词典查询，不实现 `japanese.schema.yaml` 中的笔画、汉喃、汉字反查等附加 lookup。

## 方案

在 `092wb.schema.yaml` 中新增一个日语专用 `affix_segmentor@japanese_lookup` 与 `script_translator@japanese_lookup`，复用 `rime-japanese` 主词典的罗马字查询能力，而不是用 Lua 读取词库。

选择 `script_translator` 的原因是它会按 `japanese` 词典自身的编码产生候选 comment；`reverse_lookup_translator` 虽然能查出候选，但日语汉字候选会被后续 092 拆分提示补成五笔编码。`lua/092wb_new_spelling.lua` 因此对 `japanese_lookup` 段原样放行，并在候选 comment 为空时用 `zu` 后的罗马字兜底。

## 输入规则

新增 recognizer pattern：

```yaml
japanese_lookup: "^zu[a-z_-]*$"
```

该规则匹配 `zu` 后接小写罗马字、下划线或连字符。下划线用于日语词典中的小假名编码，例如 `_tsu`；连字符用于长音相关编码，例如 `ra-men` 一类词条。

原有拼音反查 pattern 应排除 `zu...`：

```yaml
reverse_lookup: "^z([a-tv-z][a-z]*)?'?$"
```

这样 `zunihon` 不会同时进入拼音反查，也不依赖正则负向前瞻。`zi...` 特殊符号、单独 `z` 重复上屏和候选菜单中的 `z` 选第 10 候选保持不变。

## Translator 配置

在 `engine/segmentors` 中加入：

```yaml
- affix_segmentor@japanese_lookup
```

建议放在 `abc_segmentor` 之后、`punct_segmentor` 之前，让 `zu...` 先被识别为日语 lookup 段。

在 `engine/translators` 中加入：

```yaml
- script_translator@japanese_lookup
```

建议放在现有 `reverse_lookup_translator` 之后、`table_translator` 之前。这样辅助查询类 translator 聚在一起，主 092 五笔候选仍由 `table_translator` 提供。

新增配置：

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

`tag: japanese_lookup` 明确让该 translator 接收 recognizer 产生的 `japanese_lookup` segment；没有这个 tag 时，`zu...` 会被识别为日语查询段，但 translator 不会接管它。`dictionary: japanese` 使用 `rime-japanese` 提供的聚合词典。`spelling_hints`、`comment_format` 和 `preedit_format` 复用日语方案的候选注释与 `q` 到长音 `ー` 的显示转换。

## 依赖

`092wb.schema.yaml` 需要在 `schema.dependencies` 中增加 `japanese`，确保 Rime 编译 092 方案时可以访问日语词典。

项目仍然要求先初始化 `rime-japanese` submodule，并运行 `scripts/sync-rime-japanese` 生成根目录日语词典文件。

## 不做的事情

- 不把日语候选混入普通 092 编码输入；必须显式输入 `zu` 前缀。
- 不改 `z` 重复上屏。
- 不改 `zi...` 特殊符号。
- 不实现日语方案里的笔画、汉喃、汉字反查等附加功能。
- 不新增 Lua 词库查询逻辑。
- 不调整日语词库内容。

## 验证

自动检查范围：

- `092wb.schema.yaml` 中包含 `japanese` dependency。
- `engine/segmentors` 中包含 `affix_segmentor@japanese_lookup`。
- `engine/translators` 中包含 `script_translator@japanese_lookup`。
- `recognizer.patterns.japanese_lookup` 匹配 `zu...`。
- `recognizer.patterns.reverse_lookup` 排除 `zu...`。

人工 Rime 验证范围：

- 部署后在 092 五笔中输入 `zunihon` 能出现日语候选。
- 输入 `zuarigatou` 能出现日语候选。
- 输入 `zi1` 仍进入特殊符号。
- 单独输入 `z` 仍可重复上屏。
- 拼音反查除 `zu...` 以外仍可用。
