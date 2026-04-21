# Nginx 配置自动生成脚本

多环境 nginx 配置快速部署工具，一条命令生成指定环境的 API 和站点配置。

## 功能

- ✅ 内嵌模板，无需依赖外部文件
- ✅ 自动替换域名和内网 IP：`spotec14` → `spotec125`，`192.168.0.14` → `192.168.0.125`
- ✅ 拆分 API 配置和站点配置：`tmd-api.conf` + `tmd-site.conf`
- ✅ 去重 map 块，避免重复声明
- ✅ 自动验证配置和重载 nginx：`nginx -t && nginx -s reload`
- ✅ Linux / macOS 兼容

## 使用

### 方式一：从 192.168.0.132 下载

**192.168.0.132 上启动 HTTP 服务**（只需一次）：
```bash
cd /path/to/gen-nginx-conf.sh/dir
python3 -m http.server 6666
```

**在目标机器上执行**：
```bash
# 下载脚本
curl -O http://192.168.0.132:6666/gen-nginx-conf.sh

# 授权执行
chmod +x gen-nginx-conf.sh

# 生成环境配置（以 125 为例）
sudo ./gen-nginx-conf.sh 125
```

### 方式二：直接运行（已在 PATH 中）

```bash
sudo gen-nginx-conf.sh 129
```

## 示例

**生成环境 125 的配置**：
```bash
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

## 配置变更

**源环境**：`14`（模板内硬编码）

**替换规则**：

| 项目 | 替换前 | 替换后（例：env=125） |
| ---- | ---- | ---- |
| API 域名 | `api.spotec14.net` | `api.spotec125.net` |
| 反向域名 | `api.spotecreadonly14.net` | `api.spotecreadonly125.net` |
| v2 域名 | `api.spotec14v2.net` | `api.spotec125v2.net` |
| .au 域名 | `api.spotec14.net.au` | `api.spotec125.net.au` |
| CRM | `crm.spotec14.net` → `crm.spotec125.net` | ✅ |
| IB | `ib.spotec14.net` → `ib.spotec125.net` | ✅ |
| 官网 | `www.spotec14.net` → `www.spotec125.net` | ✅ |
| 文件服务 | `file.spotec14.net` → `file.spotec125.net` | ✅ |
| 落地页 | `r.spotec14.net` → `r.spotec125.net` | ✅ |
| WebView | `m.spotec14.net` → `m.spotec125.net` | ✅ |
| 内网 IP | `192.168.0.14` → `192.168.0.125` | ✅ |

**不动的配置**：

- 文件服务代理后端：`192.168.0.129:9000`（保持不变）
- 上游 API 本地端口：`127.0.0.1:31000` / `127.0.0.1:30013` 等（不替换本地地址）

## 生成文件

脚本生成两个配置文件到 `/etc/nginx/conf.d/`：

**tmd-api.conf** — API 服务器块
- 路径：`/api/ib/*`, `/api/app/*` 等
- 代理：`127.0.0.1:31000`
- 特点：支持 WebSocket，处理 CORS

**tmd-site.conf** — 其余服务
- CRM 服务
- IB（代理）
- 官网
- 文件服务
- 落地页
- WebView（移动端）

## 故障排除

### 权限错误
```
错误: open(/etc/nginx/conf.d/...) permission denied
```
→ 需要 sudo：`sudo ./gen-nginx-conf.sh 125`

### nginx 验证失败
```
nginx: [emerg] ... syntax error
```
→ 检查生成的配置文件，确认 sed 替换是否正确

### 找不到脚本
→ 确认脚本路径正确，或从 192.168.0.132 下载最新版本

## 技术细节

- **模板方式**：脚本内嵌完整 nginx 配置模板，不依赖外部文件
- **跨平台 sed**：用 `[^0-9]` 代替 `\b` 单词边界，兼容 macOS BSD sed 和 Linux GNU sed
- **Python 去重**：拆分 server 块时，自动跳过重复的 `map $http_upgrade` 声明
- **自动重载**：生成后立即 `nginx -t && nginx -s reload`，无需手工操作
