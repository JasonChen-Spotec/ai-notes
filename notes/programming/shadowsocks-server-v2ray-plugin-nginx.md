---
title: Shadowsocks 服务端搭建（v2ray-plugin + nginx 443 反代 + Cloudflare）
tags: [Programming, Security]
date: 2026-07-09
source: Claude Code 对话
---

# Shadowsocks 服务端搭建（v2ray-plugin + nginx 443 反代 + Cloudflare）

## 结论

把 Shadowsocks 藏在正常 HTTPS 网站的一个路径后面，实现流量伪装、复用 443 端口、
共用已有网站的证书。整条链路：

```
客户端 → Cloudflare(443/TLS) → nginx(443, /ray) → ws → 127.0.0.1:8388(ss + v2ray-plugin)
                                       └→ 其他路径 → 原网站（伪装）
```

**关键点**：
- SS 只监听 `127.0.0.1`，公网流量全走 nginx 443，SS 端口不对外暴露。
- TLS 由 nginx（或 Cloudflare）处理，SS 端跑**明文 ws**，不管证书。
- 服务端 `plugin_opts` **不写 tls**；客户端**必须写 tls**（它直连的是 https/443）。
- `path`、`host` 三处（服务端、nginx location、客户端）必须一致。

---

## 一、服务端（Ubuntu）

### 1. 安装 shadowsocks-libev

```bash
sudo apt update
sudo apt install -y shadowsocks-libev
```

### 2. 手动安装 v2ray-plugin

apt 源通常没有 `v2ray-plugin`（`E: Unable to locate package`），从 GitHub 下二进制：

```bash
uname -m          # x86_64 → amd64；aarch64 → arm64

cd /tmp
wget https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.2/v2ray-plugin-linux-amd64-v1.3.2.tar.gz
tar -xf v2ray-plugin-linux-amd64-v1.3.2.tar.gz
sudo mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin   # 必须改成标准名
sudo chmod +x /usr/local/bin/v2ray-plugin
v2ray-plugin -version
```

> 解压出来带架构后缀 `v2ray-plugin_linux_amd64`，一定要 `mv` 成 `v2ray-plugin`，否则 SS 找不到。
> 国内服务器连不上 GitHub 可用镜像前缀 `https://ghfast.top/` 或本地下载后 `scp` 上传。

### 3. SS 配置

`/etc/shadowsocks-libev/config.json`：

```json
{
    "server": "127.0.0.1",
    "server_port": 8388,
    "password": "用 openssl rand -base64 16 生成",
    "method": "chacha20-ietf-poly1305",
    "timeout": 300,
    "mode": "tcp_and_udp",
    "plugin": "/usr/local/bin/v2ray-plugin",
    "plugin_opts": "server;mode=websocket;path=/ray;host=sockts.ezpaynetwork.com"
}
```

### 4. nginx 配置（加到已有的 443 站点里）

在原有网站的 `server { listen 443 ssl; ... }` 块里加 `location /ray`，
并把 server 层的 `try_files` 移进 `location /`（否则会拦截 `/ray`）：

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name  sockts.ezpaynetwork.com;
    root /data/fee/application/tmd-IB-web/current;

    ssl_certificate     /etc/nginx/conf.d/ssl/_.ezpaynetwork.com.crt;   # 泛域名证书即可
    ssl_certificate_key /etc/nginx/conf.d/ssl/_.ezpaynetwork.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    # Shadowsocks (v2ray-plugin websocket) 入口
    location /ray {
        proxy_pass http://127.0.0.1:8388;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # 原网站（伪装）
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 5. 启动

```bash
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl restart shadowsocks-libev
sudo systemctl enable shadowsocks-libev          # 开机自启
sudo ss -lntp | grep 8388                         # 确认本地在监听
```

---

## 二、客户端（macOS / ShadowsocksX-NG）

### 1. 放插件二进制

点客户端「打开插件目录…」，把 **macOS 版** v2ray-plugin 放进去：

- Apple Silicon（M 系列）→ `v2ray-plugin-darwin-arm64`
- Intel → `v2ray-plugin-darwin-amd64`

解压后**改名成 `v2ray-plugin`**，放进插件目录，加权限并放行 quarantine：

```bash
DIR=~/Library/Application\ Support/ShadowsocksX-NG/v2ray-plugin
chmod +x "$DIR/v2ray-plugin"
xattr -d com.apple.quarantine "$DIR/v2ray-plugin" 2>/dev/null
"$DIR/v2ray-plugin" -version    # 能打印 V2Ray x.x.x darwin/arm64 即 OK
```

### 2. 填配置

| 栏位 | 值 |
|------|-----|
| 地址 | `sockts.ezpaynetwork.com` |
| Port | `443` |
| 加密方法 | `chacha20-ietf-poly1305` |
| 密码 | 与服务端一致 |
| **插件** | **`v2ray-plugin`** ←（易漏！空着会当纯 SS 直连，必然连不上） |
| 插件选项 | `tls;host=sockts.ezpaynetwork.com;path=/ray` |

三个参数含义：`tls`=开 TLS（因为连的是 https/443）、`host`=域名、`path`=与服务端一致。
参数之间用分号，无空格。

其它客户端（Clash Meta）写法：

```yaml
- name: ss-ezpay
  type: ss
  server: sockts.ezpaynetwork.com
  port: 443
  cipher: chacha20-ietf-poly1305
  password: "你的密码"
  plugin: v2ray-plugin
  plugin-opts:
    mode: websocket
    tls: true
    host: sockts.ezpaynetwork.com
    path: /ray
```

---

## 二·B、客户端（Ubuntu / ss-local）

Linux 客户端同样要装 v2ray-plugin 并走 tls/ws。

### 1. 装 v2ray-plugin（客户端也是 linux）

同服务端装法。注意此时代理还没起来，**下载要绕开代理**（见下方坑）：

```bash
uname -m
http_proxy= https_proxy= all_proxy= wget \
  https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.2/v2ray-plugin-linux-amd64-v1.3.2.tar.gz
tar -xf v2ray-plugin-linux-amd64-v1.3.2.tar.gz
sudo mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
sudo chmod +x /usr/local/bin/v2ray-plugin
```

### 2. 客户端 config.json

由旧的裸 SS 客户端配置改造而来 —— 新增 `plugin` / `plugin_opts`，端口改 443：

```json
{
    "server": "sockts.ezpaynetwork.com",
    "server_port": 443,
    "local_address": "127.0.0.1",
    "local_port": 1087,
    "password": "与服务端一致的密码",
    "timeout": 300,
    "method": "chacha20-ietf-poly1305",
    "plugin": "/usr/local/bin/v2ray-plugin",
    "plugin_opts": "tls;host=sockts.ezpaynetwork.com;path=/ray"
}
```

| 字段 | 裸 SS 旧值 | 新值 | 说明 |
|------|-----------|------|------|
| `server_port` | 8388/143 等 | `443` | 走 nginx https |
| `local_address` | `0.0.0.0` | `127.0.0.1` | 只本机用；要给局域网别的机器用才留 `0.0.0.0` |
| `plugin` | 无 | `/usr/local/bin/v2ray-plugin` | 新增 |
| `plugin_opts` | 无 | `tls;host=...;path=/ray` | 新增，客户端**必须**开 `tls` |

### 3. 启动

```bash
ss-local -c /path/to/config.json     # 监听 127.0.0.1:1087，会自动拉起 v2ray-plugin
```

> ⚠️ **下载 / apt 时的代理坑**：若 `~/.bashrc` 里设过 `export http_proxy=socks5h://...`，
> wget 会报 `Error parsing proxy URL socks5h://...: Unsupported scheme`（wget 不支持 socks5h）。
> 在代理尚未跑起来时，所有下载/安装都要先绕开代理：命令前加 `http_proxy= https_proxy= all_proxy=`，
> 或 `unset http_proxy https_proxy all_proxy`，curl 用 `--noproxy '*'`。

---

## 三、如何测试是否联通

### 测试 A：验证服务端链路（不依赖客户端软件）

用 curl 模拟 WebSocket 握手。**必须 `--http1.1`**（ws 升级在 HTTP/2 下不成立，会返回
`HTTP/2 400 Bad Request`，这是测试方法问题，不是后端坏了），并绕开本地代理：

```bash
curl -i -N --http1.1 --noproxy '*' \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  https://sockts.ezpaynetwork.com/ray
```

**成功标志**：`HTTP/1.1 101 Switching Protocols` + `Sec-WebSocket-Accept: ...`。
拿到 101 即代表 `客户端 → CF → nginx → v2ray-plugin` 整条链路通。

在服务器本机排除 Cloudflare 干扰，直接打本地 nginx：

```bash
curl -i -N --http1.1 -k \
  --resolve sockts.ezpaynetwork.com:443:127.0.0.1 \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Sec-WebSocket-Version: 13" \
  https://sockts.ezpaynetwork.com/ray
# 101 → nginx→SS 正常，问题在 CF；400/502 → 查本机 SS/nginx
```

### 测试 B：验证客户端代理生效（客户端连上后）

端口用客户端实际的本地 SOCKS 端口（ShadowsocksX-NG「高级」里看，本例为 `1086`）：

```bash
curl --proxy socks5h://127.0.0.1:1086 https://ip.sb   # 应返回服务器公网 IP
curl https://ip.sb                                     # 对比：本地真实 IP
```

两个 IP 不同、且第一个是服务器 IP → 全通。

---

## 三·B、查看服务端日志

代理日志分三层，联调时按需要看哪一层。

### 1. Shadowsocks 本体（journald，最常看）

```bash
sudo journalctl -u shadowsocks-libev -n 50 --no-pager   # 最近 50 行
sudo journalctl -u shadowsocks-libev -f                 # 实时跟踪
sudo systemctl status shadowsocks-libev                 # 服务状态
```

### 2. nginx（看 /ray 有没有被访问到）

```bash
sudo tail -f /var/log/nginx/ib-https.log         # 访问日志
sudo tail -f /var/log/nginx/ib-https-error.log   # 错误日志（502/504 看这）
```

客户端连接时，访问日志里应出现 `"GET /ray HTTP/1.1" 101` —— 有 101 表示流量到了 nginx
并成功升级 ws。

### 3. v2ray-plugin（默认很安静，需手动开）

在 `plugin_opts` 末尾加 `loglevel=debug`，日志会混进 SS 的 journal，排查完记得去掉：

```json
"plugin_opts": "server;mode=websocket;path=/ray;host=sockts.ezpaynetwork.com;loglevel=debug"
```

### 联调姿势：两个终端同时跟踪，再发起连接

```bash
# 终端 A
sudo journalctl -u shadowsocks-libev -f
# 终端 B
sudo tail -f /var/log/nginx/ib-https.log /var/log/nginx/ib-https-error.log
```

| nginx 访问日志 | SS journal | 结论 |
|---|---|---|
| 有 `/ray` 101 | 有新连接 | 全通 |
| 有 `/ray` 101 | 无反应/报错 | SS/插件问题，开 `loglevel=debug` |
| 有 `/ray` 但 502/400 | — | nginx→SS 反代问题（SS 没监听 8388？） |
| 完全没有 `/ray` | — | 流量没到服务器：查 DNS/CF/安全组/客户端 |

---

## 四、排错速查

| 现象 | 原因 | 处理 |
|------|------|------|
| `HTTP/2 400 Bad Request` | curl 走了 HTTP/2，ws 升级不成立 | 加 `--http1.1` |
| 响应里出现 `Connection established` | curl 走了本地代理，测试无意义 | `--noproxy '*'` 或 `unset http_proxy https_proxy` |
| `server: cloudflare` | 域名挂在 CF 橙云后面 | 支持 ws，但可先切灰云(DNS only)直连排查 |
| 服务端 101、客户端连不上 | 客户端「插件」栏空，当成纯 SS | 插件栏填 `v2ray-plugin` + 放插件二进制 |
| 插件启动失败 | 架构选错 / quarantine 拦截 | 选对 arm64/amd64，`chmod +x` + `xattr -d` |
| SS 启动失败 | 插件路径 / 配置错 | `journalctl -u shadowsocks-libev -n 30` |

---

## 关联

- 客户端侧（Ubuntu 终端走代理）见 [Shadowsocks 客户端（Ubuntu）](./shadowsocks-ubuntu-client)，
  注意 `socks5h://` vs `socks5://` 的 DNS 污染坑。
