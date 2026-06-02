---
title: TIME_WAIT 连接堆积排查与 Nginx upstream keepalive 修复
tags: [Programming]
date: 2026-06-02
source: Claude Code 对话
---

# TIME_WAIT 连接堆积排查 Playbook

适用于 Linux 服务器上某个进程对外/对本机短连接过多导致的 TIME_WAIT 堆积、端口耗尽风险问题。

## 1. 三步定位法

```bash
# 1) 看 TIME_WAIT 主要堆积在哪个目标 IP
netstat -ant | grep TIME_WAIT | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | sort -nr

# 2) 看具体哪个目标端口（重点：127.0.0.1 上几乎一定是本机服务互调）
netstat -ant | grep TIME_WAIT | grep 127.0.0.1 | awk '{print $5}' | sort | uniq -c | sort -nr | head

# 3) 看是哪个进程在监听 + 谁在调它（TIME_WAIT 时 PID 已丢，要看 ESTAB）
sudo ss -lntp | grep -E ':(端口1|端口2) '
sudo ss -ntp '( dport = :端口 )' | head -30
```

**关键判断**：`TIME_WAIT 数 / 60 ≈ 每秒新建连接数`。超过 50/s 基本可断定客户端没用连接池或没开 keep-alive。

## 2. 高频根因：Nginx 反向代理短连接（最常见！）

**症状**：`ss -ntp '( dport = :后端口 )'` 显示大量 ESTAB 的客户端进程是 `nginx`。

**根因**：Nginx 到 upstream **默认用 HTTP/1.0**，即使前端是 keep-alive，每个请求到后端都新建+立即关闭 TCP。

**修复三件套**（缺一不可）：

```nginx
upstream backend_xxx {
    server 127.0.0.1:31000;
    keepalive 256;              # ← 1. 长连接池大小
    keepalive_requests 10000;
    keepalive_timeout 60s;
}
server {
    location / {
        proxy_pass http://backend_xxx;
        proxy_http_version 1.1;            # ← 2. 必须 1.1
        proxy_set_header Connection "";    # ← 3. 清掉默认 close
    }
}
```

**WebSocket 混合场景**：location 同时承载普通 HTTP 和 WS 时，**不能写死** `Connection "upgrade"`（会阻止 keepalive 复用）。用 map：

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      '';
}
# 然后：proxy_set_header Connection $connection_upgrade;
```

## 3. 其他高概率根因

| 现象 | 嫌疑 | 修法 |
|------|------|------|
| 客户端是 Node/Next.js | 默认 http/fetch 没 keep-alive | `new http.Agent({keepAlive:true})` 或 undici `setGlobalDispatcher` |
| 客户端是 Java，目标是 Redis/MySQL | 没用连接池或池太小 | HikariCP/JedisPool maxTotal 调大 |
| 客户端是 Java，目标是 HTTP 服务 | RestTemplate/Feign 默认 SimpleClientHttpRequestFactory | 换 Apache HttpClient/OkHttp |
| 端口 9010/9999 等 | JMX/management 端口被 Prometheus 频繁拉 | 可忽略（量小）或换 long-poll 探针 |

## 4. 内核临时止血参数（不解决根因，仅缓解）

```bash
# 推荐安全，永远可以开
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.ip_local_port_range="10000 65535"
sysctl -w net.ipv4.tcp_max_tw_buckets=100000

# ⚠️ 千万不要开 tcp_tw_recycle（新内核已删除，配合 NAT 会随机丢包）
```

## 5. 高流量生产 Nginx 参数参考（16 核 / 64G）

```nginx
worker_processes auto;
worker_rlimit_nofile 200000;   # 必须设，否则继承 ulimit 1024
# worker_cpu_affinity auto;    # 同机有 Java/Node 时不要开，会抢核

events {
    worker_connections 65535;
    use epoll;
    multi_accept on;
}

# upstream keepalive 取值参考（按峰值 QPS）
# QPS 1k-5k:   keepalive 64-128
# QPS 5k-20k:  keepalive 128-512
# QPS 20k+:    keepalive 512-1024
# 公式: keepalive ≈ (峰值QPS × 平均RT秒) / worker数 × 1.5
```

**`keepalive_timeout` 必须 < 后端 keep-alive 超时**，否则后端先关连接 → Nginx 拿死连接发请求 → 502。Spring Boot Tomcat 默认 60s，Nginx 端配 50-60s 安全。

**配套 OS sysctl**（高流量必调）：

```
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_tw_buckets = 100000
fs.file-max = 2000000
```

## 6. 修复后验证

```bash
# TIME_WAIT 数从几千降到几百以内
netstat -ant | grep TIME_WAIT | grep :后端口 | wc -l

# 稳态 ESTAB ≈ worker数 × keepalive 值
sudo ss -nt '( dport = :后端口 )' | wc -l

# 看 worker 真实 fd 上限是否生效
cat /proc/$(pgrep -f "nginx: worker" | head -1)/limits | grep "open files"
```

## 7. 案例：本次排查实录

### 7.1 步骤 1 — 按目标 IP 聚合

```bash
$ netstat -ant | grep TIME_WAIT | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | sort -nr
   8835 127.0.0.1
     50 172.20.2.208
     47 172.20.1.142
     35 172.20.10.205
     34 172.20.30.159
     27 172.20.20.123
      2 172.20.2.23
      2 172.20.1.14
      1 172.20.1.99
```

判断：99% 的 TIME_WAIT 集中在 127.0.0.1，说明问题在本机服务互调，不是出口流量。

### 7.2 步骤 2 — 按本地目标端口聚合

```bash
$ netstat -ant | grep TIME_WAIT | grep 127.0.0.1 | awk '{print $5}' | sort | uniq -c | sort -nr | head
   5969 127.0.0.1:31000
   1424 127.0.0.1:9080
    812 127.0.0.1:9030
     10 127.0.0.1:9010
      2 127.0.0.1:47154
      2 127.0.0.1:46532
      2 127.0.0.1:38524
      1 127.0.0.1:60536
      1 127.0.0.1:60448
      1 127.0.0.1:60428
```

锁定主犯 `:31000`（占 60% 以上），次要嫌疑 `:9080`、`:9030`。
速率估算：`5969 / 60 ≈ 100 conn/s`，明显异常。

### 7.3 步骤 3 — 查监听进程

```bash
$ sudo ss -lntp | grep -E ':(31000|9080|9030|9010) '
LISTEN 0 4096  *:31000  *:*  users:(("java",pid=1643270,fd=67))
LISTEN 0 511   *:9080   *:*  users:(("PM2 v6.0.6: God",pid=9689,fd=22))
LISTEN 0 511   *:9030   *:*  users:(("PM2 v6.0.6: God",pid=9689,fd=3))
LISTEN 0 511   *:9010   *:*  users:(("next-server (v1",pid=4013000,fd=19))
```

身份确认：
- `31000` → Java 业务后端
- `9080 / 9030` → PM2 管理的 Node 服务
- `9010` → Next.js SSR

### 7.4 步骤 4 — 揪出谁在打 31000

```bash
$ sudo ss -ntp '( dport = :31000 )' | head -30
ESTAB 0 0 127.0.0.1:57408 127.0.0.1:31000 users:(("nginx",pid=4009643,fd=52))
ESTAB 0 0 127.0.0.1:40508 127.0.0.1:31000 users:(("nginx",pid=4009644,fd=31))
ESTAB 0 0 127.0.0.1:44676 127.0.0.1:31000 users:(("nginx",pid=4009642,fd=66))
ESTAB 0 0 127.0.0.1:38792 127.0.0.1:31000 users:(("nginx",pid=4009640,fd=78))
ESTAB 0 0 127.0.0.1:57832 127.0.0.1:31000 users:(("node /data/fee/",pid=2669136,fd=21))
... (剩余 25 行几乎全部是 nginx worker)
```

**真相**：调用方几乎全是 nginx worker（pid 4009633-4009647，约 14 个 worker），仅 1 个是 Node。
**根因确认**：nginx 反代到 31000 没用 upstream + keepalive 三件套。

## 8. 实际修复（最小改动版）

只动 3 处，业务逻辑完全不变。

### 8.1 在 http 块（或配置文件顶部）新增

```nginx
# 智能 Connection 头：WebSocket 升级 / 普通请求保持 keep-alive
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      '';
}

upstream backend_java {
    server 127.0.0.1:31000;
    keepalive 256;
    keepalive_requests 10000;
    keepalive_timeout 60s;
}
```

### 8.2 改三个代理到 31000 的 location

涉及 `~ /api/(ib|app|client|h5|third|home|landingPage)/`、`^~ /mt4/`、`^~ /api/websocket/` 三处：

```diff
-    proxy_pass http://127.0.0.1:31000;
+    proxy_pass http://backend_java;
+    proxy_http_version 1.1;
-    proxy_set_header Connection "upgrade";
+    proxy_set_header Connection $connection_upgrade;
```

其他 `proxy_set_header`、CORS、超时、`instanceVersion` 等全部保留。

### 8.3 为什么 `Connection` 必须用 map

原配置写死 `Connection "upgrade"` 会让 nginx 把所有请求都按"协议升级"处理，连接用完即弃，**keepalive 完全失效**。用 `$connection_upgrade` map 后：

- 普通 HTTP 请求（无 `Upgrade` 头）→ `Connection: ""` → 走 keepalive 池
- WebSocket 请求（带 `Upgrade: websocket`）→ `Connection: upgrade` → 正常升级

### 8.4 上线与验证

```bash
# 备份
sudo cp /etc/nginx/conf.d/xxx.conf /etc/nginx/conf.d/xxx.conf.bak

# 配置语法测试
sudo nginx -t

# 平滑 reload（不断连）
sudo nginx -s reload

# 持续观察 TIME_WAIT 趋势
watch -n 5 "ss -ant | grep TIME-WAIT | grep ':31000' | wc -l"

# 长连接稳态（应稳定在 worker数 × 256 附近）
sudo ss -nt '( dport = :31000 )' | wc -l
```

### 8.5 修复后的预期

- `:31000` 的 TIME_WAIT 数：5969 → 几十到几百
- 到 31000 的 ESTAB 长连接稳定在 `worker数 × keepalive` 附近
- 业务无感切换，WebSocket 仍能正常升级

### 8.6 后续待办

- `:9080` `:9030`（PM2 / Node）也是同一份 nginx.conf 反代过来的，同样问题，按相同套路补 upstream + keepalive
- `:9010`（Next.js）的 10 个 TIME_WAIT 量小可暂不处理.
