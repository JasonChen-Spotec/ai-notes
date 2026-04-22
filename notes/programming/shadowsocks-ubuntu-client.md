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
