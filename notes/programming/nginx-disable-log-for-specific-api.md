---
title: Nginx 配置指定 API 路径不记录访问日志
tags: [Programming]
date: 2026-04-16
source: Claude Code 对话
---

# Nginx 配置指定 API 路径不记录访问日志

## 结论

用 `map` 变量 + `access_log` 的 `if=` 参数，可以让指定路径不写入访问日志。
这是 Nginx 官方支持的条件日志方式，不涉及 if 语句，无性能问题。

## 配置方法

在 `http {}` 块内、`server {}` 外面添加 `map`：

```nginx
# 精确匹配单个路径
map $uri $loggable {
    /heartbeat/recording/ping  0;
    default                    1;
}

server {
    access_log /var/log/nginx/access.log combined if=$loggable;

    # ... 其余配置
}
```

如果路径有前缀或需要模糊匹配，用正则：

```nginx
map $uri $loggable {
    ~*heartbeat/recording/ping  0;
    default                     1;
}
```

多个路径的写法：

```nginx
map $uri $loggable {
    /heartbeat/recording/ping  0;
    /health                    0;
    ~^/api/ping                0;
    default                    1;
}
```

## 生效

```bash
nginx -t && nginx -s reload
```

## `$uri` 与 `$request_uri` 的区别

| 变量 | 内容 | 示例（请求 `GET /heartbeat/recording/ping?token=abc`） |
| ---- | ---- | ---- |
| `$uri` | 解码后的路径，**不含查询参数**，经过 rewrite 后会变 | `/heartbeat/recording/ping` |
| `$request_uri` | 原始请求，**含查询参数**，rewrite 后不变 | `/heartbeat/recording/ping?token=abc` |

```nginx
# 客户端请求: GET /heartbeat/recording/ping?token=abc

map $uri $loggable {
    /heartbeat/recording/ping  0;    # ✅ 能匹配
}

map $request_uri $loggable {
    /heartbeat/recording/ping  0;    # ❌ 匹配不上，实际值带了 ?token=abc
    ~^/heartbeat/recording/ping  0;  # ✅ 用正则前缀匹配才行
}
```

只需匹配路径、不关心参数时，用 `$uri` 更简单。

## 要点

- `map` 必须放在 `http {}` 块内，不能放在 `server {}` 里
- `if=$loggable` 是 `access_log` 指令的内置参数，不是 if 语句
- `$loggable` 为 0 时不记录，非 0 时记录
