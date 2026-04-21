---
title: Ubuntu 使用 dnsmasq 搭建内网 DNS 服务器
tags: [Programming, Security]
date: 2026-04-15
source: Claude Code 对话
---

# Ubuntu 使用 dnsmasq 搭建内网 DNS 服务器

## 结论

在 Ubuntu 上用 dnsmasq 可以快速搭建内网 DNS，实现自定义域名解析和泛域名。
关键步骤：停用 systemd-resolved → 安装 dnsmasq → 配置 address 记录 → 路由器 DHCP 指向该 DNS。

泛域名不需要写 `*`，直接 `address=/example.net/IP` 即自动匹配所有子域名。

## 环境

| 角色 | 地址 | 说明 |
| ---- | ---- | ---- |
| DNS 服务器 | 192.168.0.127 | Ubuntu 24.10 |
| 内网网关 | 192.168.0.1 | 华为 AR6121EC-S |

> **注意**：Ubuntu 24.10 是非 LTS 版本，已停止支持，apt 源需改为 `old-releases.ubuntu.com`。

## 安装步骤

```bash
# 1. 停用 systemd-resolved（占用 53 端口）
sudo systemctl disable --now systemd-resolved

# 2. 安装 dnsmasq
sudo apt update && sudo apt install dnsmasq
```

## 核心配置 /etc/dnsmasq.d/local.conf

```ini
# 上游 DNS（用网关或公共 DNS）
server=192.168.0.1

# 监听所有网卡（让内网其他机器能查询）
listen-address=0.0.0.0

# 绑定接口
bind-interfaces

# 自定义域名解析
address=/crm.test129.net/192.168.0.129

# 泛域名（自动匹配所有子域名，无需写 *）
address=/spotec15.net/192.168.0.15
```

## 处理 resolv.conf

```bash
# 备份原文件
sudo mv /etc/resolv.conf /etc/resolv.conf.bak

# 写入本地 DNS
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf
```

## 防火墙放行

```bash
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

## 修改配置后重启生效

每次修改 `/etc/dnsmasq.d/local.conf` 后需要重启 dnsmasq：

```bash
sudo systemctl restart dnsmasq

# 确认服务正常运行
sudo systemctl status dnsmasq
```

## 用 nslookup 验证 DNS 解析

### 指定 DNS 服务器查询（最准确，不依赖本机 DNS 设置）

```bash
nslookup <域名> 192.168.0.127

# 例：
nslookup crm.test129.net 192.168.0.127
nslookup www.spotec14.net 192.168.0.127
nslookup ib.spotec14.net 192.168.0.127
```

正常输出示例：
```
Server:     192.168.0.127
Address:    192.168.0.127#53

Name:   www.spotec14.net
Address: 192.168.0.14
```

### 查看本机当前使用的 DNS

```bash
# macOS
scutil --dns | grep "nameserver\[0\]"

# Linux
cat /etc/resolv.conf
```

### 注意：nslookup 能通但 curl/ping 域名不通

如果 `nslookup 域名 192.168.0.127` 能解析，但 `curl http://域名` 报 `Could not resolve host`，
说明**本机系统 DNS 没有指向 192.168.0.127**，解析走的是默认 DNS。

**解决方法**：

- **macOS**：系统设置 → Wi-Fi → 详细信息 → DNS → 添加 `192.168.0.127`
- **Linux**：修改 `/etc/resolv.conf`，写入 `nameserver 192.168.0.127`
- **路由器 DHCP 方式**（推荐）：路由器 DHCP 设置 → DNS 服务器 → 填入 `192.168.0.127`，
  内网设备重新获取 IP 后自动生效（断开重连或等 DHCP 续租）

## 验证

```bash
dig @192.168.0.127 crm.test129.net      # 自定义域名
dig @192.168.0.127 anything.spotec15.net # 泛域名
dig @192.168.0.127 baidu.com             # 上游转发
```

## 让内网设备使用

路由器管理页面（192.168.0.1）→ DHCP 设置 → DNS 服务器改为 `192.168.0.127`，
内网设备续租后自动使用新 DNS。
