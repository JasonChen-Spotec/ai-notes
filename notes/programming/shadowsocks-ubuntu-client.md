---
title: Ubuntu 安装配置 Shadowsocks 客户端
tags: [Programming, Security]
date: 2026-04-22
source: Claude Code 对话
---

# Ubuntu 安装配置 Shadowsocks 客户端

## 结论

Ubuntu 上用 `shadowsocks-libev` 的 `ss-local` 启动本地 SOCKS5 代理，
终端通过设置环境变量走代理。

**关键**：环境变量必须用 `socks5h://` 而不是 `socks5://`，否则 DNS 走本地
会被污染，导致连接超时。

## 安装

```bash
sudo apt update
sudo apt install shadowsocks-libev
```

## 配置文件

```bash
sudo nano /etc/shadowsocks-libev/config.json
```

```json
{
    "server": "服务器IP",
    "server_port": 8388,
    "local_address": "127.0.0.1",
    "local_port": 1087,
    "password": "密码",
    "method": "chacha20-ietf-poly1305"
}
```

## 启动

```bash
# 前台运行（测试用）
ss-local -c /etc/shadowsocks-libev/config.json

# 后台服务
sudo systemctl start shadowsocks-libev-local@config
```

正常输出：
```
INFO: initializing ciphers... chacha20-ietf-poly1305
INFO: listening at 127.0.0.1:1087
```

## 终端走代理

```bash
# 临时设置（当前终端会话）
export http_proxy=socks5h://127.0.0.1:1087
export https_proxy=socks5h://127.0.0.1:1087

# 测试
curl https://www.google.com
```

永久生效写入 `~/.bashrc`：

```bash
echo 'export http_proxy=socks5h://127.0.0.1:1087' >> ~/.bashrc
echo 'export https_proxy=socks5h://127.0.0.1:1087' >> ~/.bashrc
source ~/.bashrc
```

## 关键坑：socks5 vs socks5h

| 协议 | DNS 解析位置 | 结果 |
| ---- | ---- | ---- |
| `socks5://` | 本地解析后发 IP 给代理 | ❌ 本地 DNS 污染，Google 被解析到错误 IP |
| `socks5h://` | 发域名给代理服务端解析 | ✅ 绕过本地 DNS 污染 |

**症状**：`curl -v` 显示 `locally resolved`，IP 解析到 Twitter 等无关服务器，TLS 握手超时。

**解决**：将 `socks5://` 改为 `socks5h://`。

## 转成 HTTP/HTTPS 代理（给不支持 SOCKS5 的程序用）

部分工具（如某些 GUI 程序、旧版 wget/apt）只认 HTTP/HTTPS 代理，不认 SOCKS5，需要用 `privoxy` 做一层转发。

```bash
sudo apt install privoxy
```

追加转发规则（快速写入，等价于手动编辑 `/etc/privoxy/config` 末尾加一行）：

```bash
echo "forward-socks5t / 127.0.0.1:1087 ." | sudo tee -a /etc/privoxy/config
```

重启服务：

```bash
sudo systemctl restart privoxy
```

默认监听 `127.0.0.1:8118`，即为 HTTP/HTTPS 代理地址：

```bash
export http_proxy=http://127.0.0.1:8118
export https_proxy=http://127.0.0.1:8118
```

**注意**：规则用 `forward-socks5t`（末尾带 `t`），表示域名解析交给 SOCKS5 代理端处理，效果等同于 `socks5h://`，避免 DNS 污染。不要写成不带 `t` 的 `forward-socks5`。
