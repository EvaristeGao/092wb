# rime-japanese 子仓管理设计

## 背景

本仓库是个人 Rime 配置，根目录作为 Rime 配置目录使用。`092wb` 相关文件属于 092 五笔方案，`rime-japanese` 来自独立上游仓库 `https://github.com/gkovacs/rime-japanese.git`。当前工作区中 `rime-japanese/` 已经是一个独立 Git 仓库，但父仓只把它视为未跟踪目录；根目录的 `japanese*.yaml` 文件目前是指向 `rime-japanese/` 内文件的符号链接。

目标是让父仓清楚记录日语方案的上游来源和版本，同时避免在父仓中维护根目录符号链接。

## 方案

采用 `rime-japanese` Git submodule 作为日语方案的唯一上游来源。父仓记录 submodule URL 和固定 commit，不直接吸收上游仓库的文件内容。

根目录的 `japanese.schema.yaml`、`japanese.dict.yaml`、`japanese.jmdict.dict.yaml`、`japanese.kana.dict.yaml`、`japanese.mozc.dict.yaml` 不作为父仓跟踪文件，也不作为符号链接提交。它们是本地部署产物，由同步脚本从 `rime-japanese/` 复制到父仓根目录。

## 文件边界

父仓应跟踪：

- `.gitmodules`
- `rime-japanese` submodule gitlink
- 同步脚本 `scripts/sync-rime-japanese`
- `.gitignore` 中对根目录日语生成文件的忽略规则
- `default.yaml` 和 `default.custom.yaml` 中启用 `japanese` 方案的配置

父仓不应跟踪：

- 根目录的 `japanese*.yaml` 实体文件
- 根目录的 `japanese*.yaml` 符号链接
- `rime-japanese/` 内部文件内容

## 同步流程

同步脚本负责把以下文件从 submodule 复制到父仓根目录：

- `rime-japanese/japanese.schema.yaml` -> `japanese.schema.yaml`
- `rime-japanese/japanese.dict.yaml` -> `japanese.dict.yaml`
- `rime-japanese/japanese.jmdict.dict.yaml` -> `japanese.jmdict.dict.yaml`
- `rime-japanese/japanese.kana.dict.yaml` -> `japanese.kana.dict.yaml`
- `rime-japanese/japanese.mozc.dict.yaml` -> `japanese.mozc.dict.yaml`

脚本应在 `rime-japanese/` 不存在或 submodule 尚未初始化时报错，并提示运行 `git submodule update --init --recursive`。脚本应先检查全部 5 个源文件都存在，再执行任何复制。脚本可以覆盖根目录中已有的日语生成文件或符号链接，因为这些文件不属于父仓跟踪内容。

## 更新流程

更新日语上游时，在 `rime-japanese/` 中切换或拉取目标 commit，然后回到父仓提交 submodule 指针变化。需要刷新本地 Rime 配置时，再运行同步脚本复制最新文件到根目录。

## 错误处理

如果 submodule 未初始化，同步脚本应停止并给出明确提示。如果上游缺少某个预期文件，脚本应在复制前停止，不生成部分结果。这样可以避免 Rime 根目录处于半更新状态。

## 验证

自动验证范围包括：

- `git status` 中 `rime-japanese` 表现为 submodule，而不是普通未跟踪目录
- 根目录 `japanese*.yaml` 不被父仓跟踪
- 同步脚本在 submodule 已初始化时能生成 5 个根目录日语 YAML 文件
- 同步脚本在 submodule 未初始化或缺文件时失败并提示原因

Rime 实际部署和候选效果需要用户在本机完成验证。
