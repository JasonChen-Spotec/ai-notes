---
title: Ansible 批量生成 Nginx 多环境配置（安装 + 执行）
tags: [Programming, Ops]
date: 2026-07-16
source: Claude Code 对话
---

# Ansible 批量生成 Nginx 多环境配置（安装 + 执行）

## 结论

用 Ansible 批量对多台服务器执行 `gen-nginx-conf.sh`，每台机器参数不同（IP 最后一段），
配置文件在 [src/ansible-nginx-conf/](../../src/ansible-nginx-conf/)。

免密账号配置见 [Ansible 批量运维 SSH 免密配置（ops_nexus 账号）](./ansible-ops-nexus-ssh-setup)。

## 安装 Ansible

Ubuntu / Debian：

```bash
sudo apt update
sudo apt install -y ansible
```

macOS（控制端）：

```bash
brew install ansible
```

验证安装：

```bash
ansible --version
```

## 配置文件

**inventory.ini** — 每台主机对应参数（IP 最后一段）：

```ini
[nginx_gen]
192.168.0.125 param=125
192.168.0.126 param=126
192.168.0.127 param=127
192.168.0.128 param=128
192.168.0.129 param=129
192.168.0.14  param=14
192.168.0.15  param=15
```

**playbook.yml** — 下载脚本、赋权、执行、打印结果：

```yaml
---
- hosts: nginx_gen
  become: true
  tasks:
    - name: 下载 gen-nginx-conf.sh
      get_url:
        url: http://tool.cdspotec.net/gen-nginx-conf.sh
        dest: /tmp/gen-nginx-conf.sh
        mode: "0755"
        force: true

    - name: 执行 gen-nginx-conf.sh
      command: /tmp/gen-nginx-conf.sh {{ param }}
      register: result

    - name: 输出执行结果
      debug:
        var: result.stdout_lines
```

## 执行

```bash
ansible-playbook -i /data/fee/ansible/nginx-conf/inventory.ini \
  /data/fee/ansible/nginx-conf/playbook.yml -u ops_nexus
```

前提：
- 已用 `ops_nexus` 账号对 7 台目标机器配置好 SSH 免密（见上面链接的笔记）。
- `become: true` 对应脚本里原本的 `sudo`，如目标机 sudo 需要密码，加 `-K` 参数交互输入。
