# 项目协作指南

本文件适用于整个仓库。开始工作前先确认任务涉及知识条目、站点配置还是运维脚本，并阅读相应文件；不要仅根据目录名推断行为。

## 项目定位与技术栈

- 项目包名为 `playloft`，用于将 AI 对话和技术实践整理为可复用的中文知识库。
- 站点由 VitePress 构建，内容根目录是 `notes/`，配置入口是 `notes/.vitepress/config.mts`。
- `package.json` 声明 VitePress `^1.6.4`、Mermaid `^11.16.0` 和 `vitepress-plugin-mermaid` `^2.0.17`；实际安装版本以 `package-lock.json` 为准。
- 使用 npm 管理依赖，GitHub Actions 使用 Node.js 20。修改依赖时同步维护 `package.json` 和 `package-lock.json`。
- `src/` 保存 Nginx 配置生成脚本、配置样例和 Ansible 文件，不是 VitePress 前端源码目录。

## 目录与依据

| 路径 | 用途与维护要求 |
| --- | --- |
| `inbox/` | 未整理记录和草稿，允许宽松格式 |
| `notes/` | 发布到站点的知识条目及首页 |
| `notes/ai/`、`notes/programming/`、`notes/security/` | 三个现有分类；各目录的 `index.md` 是分类入口 |
| `notes/.vitepress/config.mts` | 站点导航、手动维护的侧边栏、本地搜索和 Mermaid 配置 |
| `docs/` | 补充资料，不是当前站点内容根目录 |
| `src/test-nginx-conf/` | 多环境 Nginx 生成脚本及配置样例 |
| `src/pro-nginx-conf/` | 生产配置生成脚本及已纳入版本管理的 `output/` 配置 |
| `src/ansible-nginx-conf/` | 远程批量执行脚本的 inventory 与 playbook |
| `.specify/memory/constitution.md` | 知识库宪章，规定内容原则、中文要求、分类与治理流程 |
| `specs/` | 功能规格与检查清单；注意区分草稿要求和已实现能力 |
| `.specify/`、`.claude/skills/` | Spec Kit 模板、脚本和协作工具配置，按相关任务需要维护 |
| `.github/workflows/deploy.yml` | 构建并部署到 GitHub Pages 的流水线 |

贡献内容时遵循 `.specify/memory/constitution.md`。当前 `specs/001-knowledge-entry-workflow/spec.md` 的状态是 Draft，不要把其中提到的条目模板、校验机制等需求描述为已经实现。

## 语言与知识条目规范

- 文档、规格、计划、任务列表和助手回答使用中文。技术术语、代码、命令、路径、分支名及提交信息可以使用英文。
- 遵循五条核心原则：原子化知识、结论优先、结构化 Markdown、禁止重复、可检索设计。
- 新建条目前先用 `rg` 搜索 `notes/`，并按需要检查 `inbox/` 和 `docs/`。主题重叠时优先更新已有条目。
- 每条知识只解决一个问题或说明一个概念。优先呈现结论，省略无助于理解的对话过程。
- 文件名沿用描述性的英文小写短横线风格，如 `nginx-time-wait-diagnosis.md`。
- 正式条目包含 YAML frontmatter：`title`、`tags`、`date`、`source`。日期使用 `YYYY-MM-DD`，来源如实填写，不编造验证记录或引用。
- 至少使用一个现有分类标签：`AI`、`Security`、`Programming`。新增标签按宪章修订流程处理，不因历史条目出现其他标签就视为已获认可。
- 多标签条目只存放在主分类目录，通过标签与链接实现关联，不复制多份。
- 首页和分类索引是导航页面，不机械套用知识条目模板。

新条目可采用以下结构，填写真实内容后再归档：

```markdown
---
title: 描述性标题
tags: [Programming]
date: YYYY-MM-DD
source: 实际来源
---

# 描述性标题

## 结论

直接说明解决方案、适用条件或关键要点。

## 操作步骤

按需提供可复用的步骤、命令和预期结果。

## 相关链接

按需列出来源与关联条目。
```

`inbox/` 到 `notes/` 的归档流程是捕获、提炼、去重、补齐元数据、归入主分类。未验证的线索先留在草稿中，不写成确定结论。

## 站点维护

- 新增、移动或重命名条目时，同步维护对应分类的 `index.md` 与 `notes/.vitepress/config.mts` 中的侧边栏，并检查其他条目的引用。
- 导航和侧边栏不是自动生成的；现有入口可能不完全一致，按本次任务涉及的范围修正。
- 当前站点 `base` 为 `/ai-notes/`。内部链接沿用相邻页面的相对路径或站点路径写法，不把本机绝对路径写入发布页面。
- Mermaid 使用带 `mermaid` 语言标记的代码块，继续使用现有插件集成。
- 不编辑或提交 `node_modules/`、`notes/.vitepress/cache/` 和 `notes/.vitepress/dist/`；这些目录已被忽略。
- 普通知识条目维护不需要改动 Spec Kit 模板或执行完整规格流程；涉及规格工作时再读取相关宪章、规格和工具说明。

## 常用命令与验证

以下命令从仓库根目录运行：

| 命令 | 用途 |
| --- | --- |
| `npm ci` | 按锁文件安装依赖；需要初始化环境时执行 |
| `npm run dev` | 启动本地 VitePress 开发服务器 |
| `npm run build` | 构建站点，产物位于 `notes/.vitepress/dist/` |
| `npm run preview` | 预览已构建的站点 |
| `git diff --check` | 检查已跟踪文件的差异中是否存在空白问题；新文件需另行检查 |

- 修改 `notes/`、VitePress 配置或前端依赖后，运行 `npm run build`；涉及导航、排版或 Mermaid 的改动，还应检查相关页面的实际渲染。
- 当前没有配置 `test`、`lint` 或 `typecheck` npm 脚本，不要声称运行了不存在的检查。
- 仅修改协作指南或未参与站点构建的文档时，检查内容、路径、格式和差异即可，无需为此新增测试框架。
- 修改 Bash 脚本后，先对相关文件执行 `bash -n <脚本路径>`。语法检查不能替代生成内容或运行行为验证。
- 修改 Ansible 文件后，可在已安装 Ansible 的环境中执行 `ansible-playbook -i src/ansible-nginx-conf/inventory.ini src/ansible-nginx-conf/playbook.yml --syntax-check`；此检查不代表远程部署成功。
- 工具或运行环境不可用时，明确说明未完成的验证，不把静态阅读描述为执行成功。

## 运维脚本维护边界

- `src/test-nginx-conf/gen-nginx-conf.sh` 接收环境编号，固定写入 `/etc/nginx/conf.d`，使用 `python3` 拆分配置，并执行 `sudo nginx -t` 和 `sudo nginx -s reload`。不要为阅读文档或验证语法直接运行该脚本。
- `src/pro-nginx-conf/gen-pro-nginx-conf.sh` 的第一个参数是输出目录，默认也为 `/etc/nginx/conf.d`。当前脚本只生成文件并提示验证命令，不自动执行 Nginx 校验或重载。
- 验证生产生成器时显式传入新建的临时目录，检查生成结果后再决定是否更新仓库中的 `output/`；不要默认覆盖系统配置。
- 模板内的 Nginx 变量（如 `$host`、`$remote_addr`）必须保留正确的 heredoc 引号或转义，避免被 Shell 提前展开。维护环境编号替换逻辑时兼顾 macOS 与 Linux 的 `sed` 行为。
- 修改生成器时核对相应配置样例和使用文档，避免只修改生成结果而遗漏实际模板；不要假定现有样例与脚本始终一致。
- `src/ansible-nginx-conf/playbook.yml` 会以提权方式在 inventory 指定的主机下载并执行远程脚本；本地脚本修改不会自动更新远程下载源。
- 写入系统配置、连接目标主机及重载服务应属于用户已授权的运维范围；普通文档编辑不包含这些操作。
- 运维记录涉及内部地址和环境信息，新增示例使用必要的占位符，不新增真实密码、令牌或私钥。

## Git 与交付

- 开始前查看 `git status --short`，保留用户已有修改和未跟踪文件，不自动清理临时脚本或其他无关内容。
- 控制改动范围，不顺带批量重排历史笔记或修复与任务无关的格式问题。
- `npm run deploy` 实际执行 `git add -A`、提交及推送到 `origin main`，会包含所有可暂存变更。它不是本地预览或验证命令，仅在用户授权相应提交和发布范围时使用。
- 推送 `main` 会触发 GitHub Pages 构建与部署；流水线也支持手动触发。普通编辑任务不自动提交或推送。
- 最终交付说明修改了什么、做了哪些验证以及哪些验证未执行，不把站点构建成功等同于运维配置已上线。
