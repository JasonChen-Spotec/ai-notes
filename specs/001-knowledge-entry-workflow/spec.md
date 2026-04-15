# Feature Specification: 知识条目结构与捕获归档流程

**Feature Branch**: `001-knowledge-entry-workflow`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "创建知识条目的基本结构和模板，支持从 inbox 捕获到 notes 归档的完整流程"

## User Scenarios & Testing

### User Story 1 - 快速捕获 AI 对话知识 (Priority: P1)

用户在与 AI 对话过程中发现了一个有价值的结论或解决方案，希望快速保存到知识库中，不需要立刻整理格式。

**Why this priority**: 捕获是整个知识管理流程的起点，如果捕获过程太繁琐，用户会放弃记录，知识就会丢失。

**Independent Test**: 用户可以通过创建一个 Markdown 文件到 `inbox/` 目录来验证，文件包含最基本的标题和内容即可。

**Acceptance Scenarios**:

1. **Given** 用户正在 AI 对话中获得了一个有用的结论, **When** 用户在 `inbox/` 目录下创建一个新的 Markdown 文件, **Then** 文件被成功保存，包含标题、日期和原始内容
2. **Given** 用户想快速记录, **When** 用户使用 inbox 模板创建条目, **Then** 模板自动包含必填字段（标题、日期、来源），用户只需填写内容
3. **Given** 用户记录了一条不符合记录标准的内容, **When** 内容既无通用价值也不可复用且无明确结论, **Then** 该内容应留在 `inbox/` 不被归档，或被删除

---

### User Story 2 - 提炼并结构化知识条目 (Priority: P2)

用户回顾 `inbox/` 中的原始记录，提炼出结论，去除对话噪音，将其转换为符合宪章标准的结构化知识条目。

**Why this priority**: 提炼是保证知识质量的关键步骤，确保归档到 `notes/` 的内容符合原子化、结论优先、结构化的要求。

**Independent Test**: 取一条 `inbox/` 中的原始记录，按照 notes 模板重写后，验证其符合五条核心原则。

**Acceptance Scenarios**:

1. **Given** `inbox/` 中有一条原始 AI 对话记录, **When** 用户按照 notes 模板提炼内容, **Then** 产出的条目包含：描述性标题、元数据（标签、日期、来源）、结论优先的正文
2. **Given** 用户提炼一条知识, **When** 该知识与已有 `notes/` 条目主题重叠, **Then** 用户更新已有条目而非创建新条目
3. **Given** 提炼后的条目缺少必需的标签或元数据, **When** 用户尝试将其移入 `notes/`, **Then** 条目不符合归档标准，需补充完整后再归档

---

### User Story 3 - 从 inbox 归档到 notes (Priority: P3)

用户将提炼完成的知识条目从 `inbox/` 移动到 `notes/` 的对应分类目录下，完成归档。

**Why this priority**: 归档是流程的最后一步，确保知识被正确分类存放，支持后续检索。

**Independent Test**: 将一条符合标准的条目从 `inbox/` 移动到 `notes/` 对应分类下，验证文件位置正确且内容完整。

**Acceptance Scenarios**:

1. **Given** 一条已提炼完成、符合所有宪章原则的知识条目, **When** 用户将其从 `inbox/` 移到 `notes/` 的分类目录, **Then** 文件出现在正确的分类目录下（如 `notes/ai/`、`notes/security/`、`notes/programming/`）
2. **Given** 用户归档一条条目, **When** 条目包含多个分类标签, **Then** 条目存放在主分类目录下，通过标签元数据支持跨分类检索
3. **Given** 归档完成后, **When** 用户通过标题关键词或标签搜索, **Then** 能够找到该条目

---

### Edge Cases

- 当 `inbox/` 中的记录完全无价值时怎么办？直接删除，不归档。
- 当一条 AI 对话包含多个不相关的知识点时怎么办？拆分为多条独立的 inbox 条目，每条对应一个知识点（原子化原则）。
- 当标签分类不确定时怎么办？先使用最接近的已有分类标签，后续可通过宪章修订新增分类。

## Requirements

### Functional Requirements

- **FR-001**: 系统必须提供 inbox 模板，包含字段：标题、日期、来源（AI 工具名称）、原始内容
- **FR-002**: 系统必须提供 notes 模板，包含字段：标题、日期、来源、标签（至少一个）、结论/摘要、详细说明（可选）、相关链接（可选）
- **FR-003**: `inbox/` 目录必须接受任意格式的 Markdown 文件，不强制结构化
- **FR-004**: `notes/` 目录必须按分类组织子目录：`notes/ai/`、`notes/security/`、`notes/programming/`
- **FR-005**: 每条 `notes/` 中的条目必须通过元数据中的标签支持检索
- **FR-006**: 系统必须提供目录结构的初始化方式，创建 `inbox/` 和 `notes/` 及其子目录
- **FR-007**: notes 模板中的标签字段必须限制为宪章中定义的分类（AI、Security、Programming），支持多标签

### Key Entities

- **Inbox Entry（草稿条目）**: 存放在 `inbox/` 中的原始记录，包含标题、日期、来源、原始内容。格式宽松，作为临时暂存。
- **Note Entry（知识条目）**: 存放在 `notes/<category>/` 中的最终知识，包含结构化元数据和结论优先的正文。是知识库的核心资产。
- **Category（分类）**: AI、Security、Programming 三个预定义分类，对应 `notes/` 下的子目录。

## Success Criteria

### Measurable Outcomes

- **SC-001**: 用户从产生记录意图到完成 inbox 捕获的时间不超过 2 分钟
- **SC-002**: 每条归档到 `notes/` 的知识条目都包含标题、日期、来源、至少一个分类标签
- **SC-003**: 通过文件名或标签关键词搜索，用户能在 10 秒内定位到目标知识条目
- **SC-004**: `notes/` 中不存在重复主题的条目（去重率 100%）

## Assumptions

- 用户使用本地文件系统和 Git 管理知识库，不依赖外部数据库或 Web 服务
- 用户熟悉 Markdown 语法，能够手动编辑文件
- 初期知识量较小（<500 条），文件系统目录结构足以支撑检索需求
- 搜索通过文件名、标签元数据和全文搜索工具（如 grep）实现，不需要专用搜索引擎
- 条目归档为手动操作（移动文件），暂不需要自动化脚本
