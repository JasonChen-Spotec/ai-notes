---
title: Nginx 多环境配置自动生成脚本
tags: [Programming]
date: 2026-04-21
source: Claude Code 对话
---

# Nginx 多环境配置自动生成脚本

## 结论

一条命令快速生成多个环境的 nginx 配置（API + 站点），无需手工编辑。
脚本内嵌完整模板，支持 Linux 和 macOS，自动验证和重载 nginx。

用法：`sudo ./gen-nginx-conf.sh <env_number>`

## 核心功能

- ✅ 内嵌 nginx 配置模板，无依赖
- ✅ 自动替换域名和内网 IP
- ✅ 拆分 tmd-api.conf（API 服务）+ tmd-site.conf（其余服务）
- ✅ 去重 map 块，避免重复声明
- ✅ 自动验证配置 + nginx -s reload
- ✅ Linux / macOS 兼容（sed 跨平台支持）

## 快速开始

### 方式一：从 192.168.0.132 下载

**在 192.168.0.132 上启动 HTTP 服务**（只需一次）：
```bash
cd /path/to/gen-nginx-conf.sh
python3 -m http.server 6666
```

**在目标机器上执行**：
```bash
# 下载脚本
curl -O http://192.168.0.132:6666/gen-nginx-conf.sh

# 授权执行
chmod +x gen-nginx-conf.sh

# 生成环境 125 的配置
sudo ./gen-nginx-conf.sh 125
```

### 方式二：直接运行（脚本已在 PATH）

```bash
sudo gen-nginx-conf.sh 129
```

## 执行结果

```
$ sudo ./gen-nginx-conf.sh 125
▶ 生成环境 125 的 nginx 配置...
  → /etc/nginx/conf.d/tmd-api.conf
  → /etc/nginx/conf.d/tmd-site.conf
▶ 验证配置...
nginx: the configuration file /etc/nginx/conf.d/tmd-api.conf syntax is ok
nginx: configuration test is successful
▶ 重载 nginx...
✓ 完成，环境: 125
```

## 配置替换规则

**源环境**（模板中硬编码）：`14`

**替换模式**（传入 125 为例）：

| 类别 | 替换前 | 替换后 |
| ---- | ---- | ---- |
| API 域名 | `api.spotec14.net` | `api.spotec125.net` |
| 反向代理 | `api.spotecreadonly14.net` | `api.spotecreadonly125.net` |
| v2 版本 | `api.spotec14v2.net` | `api.spotec125v2.net` |
| .au 域名 | `api.spotec14.net.au` | `api.spotec125.net.au` |
| CRM | `crm.spotec14.net` | `crm.spotec125.net` |
| IB 代理 | `ib.spotec14.net` | `ib.spotec125.net` |
| 官网 | `www.spotec14.net` | `www.spotec125.net` |
| 文件服务 | `file.spotec14.net` | `file.spotec125.net` |
| 落地页 | `r.spotec14.net` | `r.spotec125.net` |
| WebView | `m.spotec14.net` | `m.spotec125.net` |
| 内网 IP | `192.168.0.14` | `192.168.0.125` |

**保持不变**：

- 文件服务后端：`192.168.0.129:9000`（跨环境共用）
- 本地代理端口：`127.0.0.1:31000`、`127.0.0.1:30013` 等（本机端口不替换）

## 生成的两个文件

### tmd-api.conf

API 服务器块，处理：
- `/api/ib/*`, `/api/app/*`, `/api/client/*` 等路由
- WebSocket 升级：`/mt4/ws/`, `/api/websocket/`
- CORS 预检响应（OPTIONS）
- 代理到 `127.0.0.1:31000`

### tmd-site.conf

其余所有服务：

| 服务 | 说明 |
| ---- | ---- |
| CRM | 后台系统，代理到 backend 上游（9030、9080） |
| IB | 交易平台前端，根路径静态站点 |
| 官网 | 代理到 `192.168.0.<env>:9010` |
| 文件服务 | 代理到 `192.168.0.129:9000`（不变） |
| 落地页 | 静态站点，允许 iframe 嵌入 |
| WebView | 移动端应用，代理到 `localhost:6060` |

## 技术细节

### 跨平台 sed 兼容性

使用 `[^0-9]` 代替 `\b` 单词边界：

```bash
# ❌ macOS BSD sed 不支持
sed 's/spotec14\b/spotec125/g'

# ✅ 两个平台都支持
sed 's/\(spotec[a-z]*\)14\([^0-9]\)/\1125\2/g'
```

### Python 去重逻辑

配置中 `map $http_upgrade $connection_upgrade` 出现多次，脚本会：
1. 第一个 server 块（API）→ tmd-api.conf
2. 后续服务中遇到重复 map → 跳过
3. 确保 nginx 加载时无重复声明错误

### 自动重载

生成配置后立即执行：
```bash
nginx -t  # 验证语法
nginx -s reload  # 重载（无中断）
```

## 故障排除

| 错误 | 原因 | 解决 |
| ---- | ---- | ---- |
| `permission denied` | 需要 root 权限 | 用 `sudo` 运行 |
| `syntax error` | sed 替换有问题 | 检查生成的文件，确认域名和 IP 正确 |
| `curl: command not found` | 网络下载工具缺失 | 手动复制脚本或使用 wget |
| `nginx: command not found` | nginx 未安装 | 确认目标机器已安装 nginx |

## 脚本源码位置

- **脚本**：`src/test-ngxin-conf/gen-nginx-conf.sh`
- **文档**：`src/test-ngxin-conf/README.md`
- **模板**：脚本内嵌（无外部依赖）

## 使用场景

- **新环境部署**：快速搭建新测试环境（125、126、127 等）
- **配置备份**：生成后可保存为配置库版本
- **灾难恢复**：服务器故障重装后快速恢复完整配置
- **CI/CD 集成**：自动化部署流程的一部分
