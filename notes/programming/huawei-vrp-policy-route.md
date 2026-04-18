---
title: 华为 VRP V300R022 路由器用 MQC 实现策略路由
tags: [Programming, Security]
date: 2026-04-15
source: Claude Code 对话
---

# 华为 VRP V300R022 路由器用 MQC 实现策略路由

## 结论

华为 AR6121EC-S（VRP V300R022）不支持 `ip policy-based-route` 命令，
也没有 Web 页面策略路由功能，必须通过 CLI 使用 **MQC（模块化 QoS）** 方式
实现指定 IP 走特定出口线路。

核心思路：ACL 匹配源 IP → traffic classifier 引用 ACL →
traffic behavior 设置 `redirect ip-nexthop` → traffic policy 组合 →
应用到内网接口 inbound。

## 关键踩坑

1. **Web 页面没有策略路由功能**，必须 SSH/Telnet CLI 配置
2. 该版本 VRP **不支持 `ip policy-based-route`**，只能用 MQC
3. MQC 中 ACL 的 **deny 规则会被忽略**，只有 permit 才能命中
4. 策略路由会影响访问路由器自身（192.168.0.1），需要用额外的
   classifier + 空 behavior 排除，且 precedence 必须更小（优先匹配）

## 设备信息

| 项目 | 值 |
| ---- | -- |
| 型号 | 华为 AR6121EC-S |
| 系统 | VRP V300R022C00SPC100 |
| 内网接口 | Vlanif1（192.168.0.1/24） |
| 线路1（主） | Dialer1（PPPoE 宽带，优先级 55） |
| 线路2（备） | GigabitEthernet0/0/10（223.87.216.98/24，下一跳 223.87.216.1） |

## 需求

让 192.168.0.88、192.168.0.132、192.168.0.240 固定走线路2
（GigabitEthernet0/0/10）出网，其他设备走默认路由不受影响。

## 完整配置

```
system-view

# ACL 3087：匹配访问路由器自身的流量（不重定向，正常转发）
acl number 3087
 rule 0 permit ip source 192.168.0.88 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 1 permit ip source 192.168.0.132 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 2 permit ip source 192.168.0.240 0.0.0.0 destination 192.168.0.1 0.0.0.0
 quit

# ACL 3088：匹配需要重定向的 IP
acl number 3088
 rule 0 permit ip source 192.168.0.88 0.0.0.0
 rule 1 permit ip source 192.168.0.132 0.0.0.0
 rule 2 permit ip source 192.168.0.240 0.0.0.0
 quit

# 内网流量分类和行为（空行为 = 正常转发）
traffic classifier TC_LOCAL
 if-match acl 3087
 quit

traffic behavior TB_LOCAL
 quit

# 外网流量分类和行为（重定向到线路2下一跳）
traffic classifier TC_88
 if-match acl 3088
 quit

traffic behavior TB_88
 redirect ip-nexthop 223.87.216.1
 quit

# 流策略（precedence 小的优先匹配）
traffic policy TP_88
 classifier TC_LOCAL behavior TB_LOCAL precedence 1
 classifier TC_88 behavior TB_88 precedence 10
 quit

# 应用到内网接口
interface Vlanif1
 traffic-policy TP_88 inbound
 quit

save
y
```

## 新增 IP

只需在 ACL 里加规则，流策略自动生效。以下是新增 192.168.0.240 的实际操作：

```
system-view
acl number 3088
 rule 2 permit ip source 192.168.0.240 0.0.0.0
 quit

acl number 3087
 rule 2 permit ip source 192.168.0.240 0.0.0.0 destination 192.168.0.1 0.0.0.0
 quit

save
y
```

如需继续新增其他 IP，按同样方式追加 rule（编号递增即可）：

```
system-view
acl number 3088
 rule 3 permit ip source 192.168.0.xxx 0.0.0.0
 quit
acl number 3087
 rule 3 permit ip source 192.168.0.xxx 0.0.0.0 destination 192.168.0.1 0.0.0.0
 quit
save
y
```

## 反向场景：默认走线路2，指定 IP 切到 PPPoE（Dialer1）

某些时候默认路由已经在线路2（223.87.216.98）上，需要让一部分
机器改走 PPPoE 线路1（Dialer1）。思路和前面相反：新增一条 ACL
匹配这些 IP，重定向到 `Dialer1` 接口即可。

**注意**：PPPoE 接口是 Dialer（虚拟拨号接口），不是物理 GE 口。
先确认接口名：

```
display interface brief | include Dialer
```

输出中 `Dialer1 up up(s)` 即表示可用，`(s)` 是 spoofing
（按需拨号的正常状态）。

**配置**（以 192.168.0.14、.15、.125、.126、.127、.128 为例）：

```
system-view

# ACL 3089：匹配需要走 Dialer1 的 IP
acl number 3089
 rule 0 permit ip source 192.168.0.125 0.0.0.0
 rule 1 permit ip source 192.168.0.126 0.0.0.0
 rule 2 permit ip source 192.168.0.127 0.0.0.0
 rule 3 permit ip source 192.168.0.128 0.0.0.0
 rule 4 permit ip source 192.168.0.14 0.0.0.0
 rule 5 permit ip source 192.168.0.15 0.0.0.0
 quit

# ACL 3087 放行这些 IP 访问路由器管理页面
acl number 3087
 rule 10 permit ip source 192.168.0.125 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 11 permit ip source 192.168.0.126 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 12 permit ip source 192.168.0.127 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 13 permit ip source 192.168.0.128 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 14 permit ip source 192.168.0.14 0.0.0.0 destination 192.168.0.1 0.0.0.0
 rule 15 permit ip source 192.168.0.15 0.0.0.0 destination 192.168.0.1 0.0.0.0
 quit

# 新分类器和行为
traffic classifier TC_DIALER
 if-match acl 3089
 quit

traffic behavior TB_DIALER
 redirect interface Dialer1
 quit

# 挂到已有策略上（precedence 5，优先于 TC_88 的 10）
traffic policy TP_88
 classifier TC_DIALER behavior TB_DIALER precedence 5
 quit

save
y
```

**新增 IP 走 Dialer1**（例如加入 192.168.0.130）：

```
system-view
acl number 3089
 rule 6 permit ip source 192.168.0.130 0.0.0.0
 quit
acl number 3087
 rule 16 permit ip source 192.168.0.130 0.0.0.0 destination 192.168.0.1 0.0.0.0
 quit
save
y
```

**验证**：在目标机器上 `curl ip.sb`，返回 PPPoE 线路公网 IP
即成功（不再是 223.87.216.98）。

**风险**：如果 PPPoE 断线，被重定向的机器会无法访问外网。

## 验证

```
display traffic-policy applied-record
display acl 3088
display acl 3087
```

## 回滚

```
system-view
interface Vlanif1
 undo traffic-policy TP_88 inbound
 quit
undo traffic policy TP_88
undo traffic behavior TB_88
undo traffic behavior TB_LOCAL
undo traffic classifier TC_88
undo traffic classifier TC_LOCAL
undo acl number 3088
undo acl number 3087
save
y
```

## SSH 登录

用户名 jason.chen，通过 Web 页面"管理账号配置"设置密码。
`ssh jason.chen 192.168.0.1`
如果 SSH 连不上可尝试 telnet。
