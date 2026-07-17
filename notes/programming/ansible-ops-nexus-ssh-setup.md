---
title: Ansible 批量运维 SSH 免密配置（ops_nexus 账号）
tags: [Programming, Ops]
date: 2026-07-16
source: Claude Code 对话
---

# Ansible 批量运维 SSH 免密配置（ops_nexus 账号）

## 结论

批量运维统一使用 `ops_nexus` 账号（非 root），执行 ansible-playbook 时指定 `-u ops_nexus`：

```bash
ansible-playbook -i /data/fee/ansible/nginx-conf/inventory.ini \
  /data/fee/ansible/nginx-conf/playbook.yml -u ops_nexus
```

## 给目标机器写入免密 key

以 `192.168.0.129` 为例，先用其他有权限的账号 ssh 上去（或本机已有临时访问方式），追加公钥到 `ops_nexus` 的 `authorized_keys`：

```bash
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNbJrhuwitptvIGcVp63c9a7k/IKe8XgO0RNvZZavOy jason.chen@spotec.net" \
  | sudo tee -a /home/ops_nexus/.ssh/authorized_keys > /dev/null

# 修改拥有者为 ops_nexus
sudo chown -R ops_nexus:ops_nexus /home/ops_nexus/.ssh

# 设定安全权限（权限过宽 sshd 会拒绝使用该 key）
sudo chmod 700 /home/ops_nexus/.ssh
sudo chmod 600 /home/ops_nexus/.ssh/authorized_keys
```

## 坑：重装机器后 SSH 报 Host key 变更

机器重装系统后，SSH host key 会变化，本机 `known_hosts` 里存的旧指纹和新指纹不一致，触发中间人攻击警告并拒绝连接：

```
ssh ops_nexus@192.168.0.129

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
...
Host key verification failed.
```

**原因**：机器重装是预期内的，不是真的被中间人攻击，只是本地缓存的旧指纹失效了。

**解决**：清除本地对该 IP 缓存的旧指纹，下次连接会重新记录新指纹：

```bash
ssh-keygen -f '/home/ops_nexus/.ssh/known_hosts' -R '192.168.0.129'
```

清除后再次 `ssh ops_nexus@192.168.0.129` 会提示是否信任新指纹，输入 `yes` 即可恢复正常连接。

## 关联

- 批量执行脚本参考 [Ansible 批量生成 Nginx 多环境配置](./ansible-nginx-conf-deploy)（inventory + playbook 详见该笔记）
