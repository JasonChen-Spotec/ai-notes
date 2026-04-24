---
title: Docker 安装的 Jenkins 配置代理（yarn install 走代理）
tags: [Programming]
date: 2026-04-24
source: Claude Code 对话
---

# Docker 安装的 Jenkins 配置代理

## 结论

Jenkins Pipeline 中 `yarn install` 超时，根本原因是 **yarn v1 不支持 socks5h:// 格式的代理**，
必须提供 HTTP 代理。解决方案：在代理机器上安装 privoxy 把 SOCKS5 转为 HTTP 代理，
再配置到 Jenkins 全局环境变量。

## 环境

| 角色 | 地址 |
| ---- | ---- |
| Jenkins（Docker） | 192.168.0.14 |
| 代理服务器（Shadowsocks） | 192.168.0.132:1087（SOCKS5） |
| privoxy（HTTP 转换层） | 192.168.0.132:8118（HTTP） |

## 问题排查过程

### 1. Jenkins 全局环境变量设置 socks5h 不生效

在 Jenkins → 系统配置 → 全局属性 → 环境变量 中设置：

```
https_proxy = socks5h://192.168.0.132:1087
http_proxy  = socks5h://192.168.0.132:1087
```

Pipeline 内验证变量已传入，但 yarn 仍然超时：

```bash
sh 'env | grep -i proxy'
# 输出：https_proxy=socks5h://192.168.0.132:1087 ✅

sh 'yarn config list'
# 输出：无 proxy 配置，yarn 忽略了 socks5h ❌
```

### 2. 根本原因

yarn v1 只支持 `http://` 格式的代理，不识别 `socks5://` 或 `socks5h://`，会静默忽略。

## 解决方案：privoxy 转换 SOCKS5 → HTTP

### 在 192.168.0.132 上安装配置 privoxy

```bash
sudo apt install privoxy

# 追加 SOCKS5 转发规则
echo 'forward-socks5 / 127.0.0.1:1087 .' | sudo tee -a /etc/privoxy/config

# 改为监听所有网卡（默认只监听 127.0.0.1，Docker 容器无法访问）
sudo sed -i 's/listen-address  127.0.0.1:8118/listen-address  0.0.0.0:8118/' /etc/privoxy/config

# 重启
sudo systemctl restart privoxy

# 防火墙放行
sudo ufw allow 8118/tcp
```

### 验证 privoxy 可用

```bash
# 在 192.168.0.132 本机测试
curl --proxy http://127.0.0.1:8118 https://www.google.com

# 从 Jenkins Docker 容器内测试
docker exec -it jenkins curl --proxy http://192.168.0.132:8118 https://www.google.com
```

能返回 HTML 即成功。

### 配置 Jenkins 全局环境变量

Jenkins → 系统配置 → 全局属性 → 环境变量，添加以下 4 条：

| Name | Value |
| ---- | ---- |
| `http_proxy` | `http://192.168.0.132:8118` |
| `https_proxy` | `http://192.168.0.132:8118` |
| `HTTP_PROXY` | `http://192.168.0.132:8118` |
| `HTTPS_PROXY` | `http://192.168.0.132:8118` |

> 大小写两套都加，部分工具只认大写，部分只认小写。

保存后重新执行 Pipeline，`yarn install` 即可走代理。

## 关键踩坑

| 坑 | 原因 | 解决 |
| ---- | ---- | ---- |
| `socks5h://` 设了没效果 | yarn v1 不支持 SOCKS5 代理 | 改用 HTTP 代理（privoxy 转换） |
| Docker 内连不上 192.168.0.132:8118 | privoxy 默认只监听 127.0.0.1 | 改为 `listen-address 0.0.0.0:8118` |
| 只加小写 `http_proxy` 不够 | 不同工具读不同大小写的变量 | 大小写各加一组共 4 条 |
