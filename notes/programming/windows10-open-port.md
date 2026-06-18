# Windows 10 家庭版开放端口允许其他电脑访问

## 方法一：Windows Defender 防火墙（图形界面）

1. `Win + R` 输入 `wf.msc` 回车
2. 左侧点击 **入站规则** → 右侧点击 **新建规则**
3. 规则类型选 **端口** → 下一步
4. 选 **TCP**，特定本地端口填端口号（如 `9999`）→ 下一步
5. 选 **允许连接** → 下一步
6. 三个网络类型全选（域/专用/公用）→ 下一步
7. 填名称 → 完成

## 方法二：命令行（管理员 PowerShell）

```powershell
# 添加入站规则
netsh advfirewall firewall add rule name="Allow 9999 In" dir=in action=allow protocol=TCP localport=9999

# 验证规则
netsh advfirewall firewall show rule name="Allow 9999 In"
```

## 验证步骤

```powershell
# 1. 确认端口在监听
netstat -ano | findstr 9999

# 2. 本机 TCP 连通测试
Test-NetConnection -ComputerName 127.0.0.1 -Port 9999
Test-NetConnection -ComputerName <本机IP> -Port 9999

# 3. 本机 HTTP 响应测试
curl http://127.0.0.1:9999/
```

在另一台机器上测试：

```bash
# Linux/Mac
nc -zv <Windows机器IP> 9999

# Windows
Test-NetConnection -ComputerName <Windows机器IP> -Port 9999
```

## 排查思路

| 现象 | 原因 | 解决方法 |
|------|------|----------|
| TCP 不通 | 防火墙未放行 | 添加入站规则 |
| TCP 通但 HTTP 无响应 | 应用未 ready 或未处理该路径 | 查看应用日志 |
| 另一台机器 TCP 不通 | 不同子网，路由不通 | 检查两台机器是否在同一网段 |
| IP 填错 | 手误 | `ipconfig` 确认本机真实 IP |

## 注意事项

- 应用必须先监听该端口，防火墙放行才有意义
- 确认应用绑定的是 `0.0.0.0`（所有接口），而非 `127.0.0.1`（仅本机）
- 家庭版和专业版防火墙操作完全相同，无差异
- 如需外网访问，还需在路由器配置端口映射
