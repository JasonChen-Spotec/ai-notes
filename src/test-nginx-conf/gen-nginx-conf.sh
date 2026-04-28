#!/usr/bin/env bash
set -euo pipefail

OUTDIR="/etc/nginx/conf.d"
SOURCE="14"

usage() {
    cat <<EOF
Usage: $0 <env_number>
  env_number   环境编号，如 14、129、88

生成文件：
  ${OUTDIR}/tmd-api.conf   API server 块
  ${OUTDIR}/tmd-site.conf  其余 server 块
EOF
    exit 1
}

[[ $# -ne 1 ]]         && usage
[[ "$1" =~ ^[0-9]+$ ]] || { echo "错误: env_number 必须是数字" >&2; exit 1; }

TARGET="$1"
echo "▶ 生成环境 ${TARGET} 的 nginx 配置..."

# ---------- 内嵌模板（单引号 heredoc，$ 不展开）----------
TMP=$(mktemp /tmp/nginx-gen.XXXXXX)
trap "rm -f $TMP" EXIT

cat > "$TMP" << 'NGINX_TEMPLATE'
# api 服务
server {
  listen 80;
  server_name api.spotecreadonly14.net api.spotec14.net.au api.spotec14.net api.spotec14v2.net;
  location ~ /api/(ib|app|client|h5|third|home|landingPage)/ {
    proxy_pass http://127.0.0.1:31000;
    proxy_set_header X-Client-IP $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    #proxy_set_header X-Forwarded-For $remote_addr;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;
    # 从当前nginx过的流量都携带B版本,流量仅在B路线消费
    proxy_set_header instanceVersion b;

    proxy_hide_header Access-Control-Allow-Origin;
    proxy_hide_header Access-Control-Allow-Headers;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers *;
    if ($request_method = 'OPTIONS') {
      return 204;
    }
  }


  location ^~ /mt4/ws/ {
    # 官网ws端口是31000
    proxy_pass http://127.0.0.1:31000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_connect_timeout 10s;
    proxy_send_timeout 60s;
    proxy_read_timeout 3600s;
  }

  location ^~ /mt4/ {
    proxy_pass http://127.0.0.1:31000;
    proxy_set_header X-Client-IP $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;
    # 从当前nginx过的流量都携带A版本,流量仅在A路线消费
    #proxy_set_header instanceVersion a;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
    if ($request_method = 'OPTIONS') {
      return 204;
    }
  }

  location ^~ /api/websocket/ {
    proxy_pass http://127.0.0.1:31000;
    proxy_set_header X-Client-IP $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;
    # 从当前nginx过的流量都携带A版本,流量仅在A路线消费
    #proxy_set_header instanceVersion a;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
    if ($request_method = 'OPTIONS') {
      return 204;
    }
  }

  location /mt4/trade.io/ {
    #proxy_pass http://127.0.0.1:31000;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_pass http://172.31.45.245:30012;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  location ^~ /ws/ {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    # 客户端ws端口是30000
    proxy_pass http://127.0.0.1:30013;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  access_log /var/log/nginx/client-api.log combined;
  error_log /var/log/nginx/client-api-error.log;
}

upstream client-site {
  server localhost:9030;
  server localhost:9080;
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

# crm 服务
server {
  server_name crm.spotecreadonly14.net crm.spotec14.net.au crm.spotec14v2.net crm.spotec14.net;
  listen 80;
  location / {
    proxy_intercept_errors on;
    proxy_pass http://client-site;

    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Client-IP $remote_addr;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_connect_timeout 5s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;
  }

  location = /robots.txt {
    default_type text/plain;

    if ($host ~* ^crm\.ecmarkets\.(sc|com|com\.au|co\.nz|mu)$) {
      return 200 "User-agent: *\nAllow: /\n";
    }

    return 200 "User-agent: *\nDisallow: /\n";
  }

  error_page 502 503 504 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }

  access_log /var/log/nginx/pc-web.log combined;
  error_log /var/log/nginx/pc-web-error.log;
}

# 代理服务
server {
  listen 80;
  server_name ib.spotecreadonly14.net ib.spotec14v2.net ib.spotec14.net ib.spotec14.net.au;
  index index.html index.htm default.php default.htm default.html;
  root /data/fee/application/tmd-IB-web/current;
  try_files $uri $uri/ /index.html;
}

# 官网
server {
  listen 80;
  server_name www.spotec14.net;

  location / {
    proxy_intercept_errors on;
    proxy_pass http://192.168.0.14:9010;

    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Client-IP $remote_addr;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_connect_timeout 5s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;
  }

  error_page 502 503 504 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }
}

# 文件服务
server {
  listen 80;
  server_name file.spotecreadonly14.net file.spotec14.net file.spotec14v2.net;
  location / {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host 192.168.0.129:9000;

    proxy_connect_timeout 300;
    # Default is HTTP/1, keepalive is only enabled in HTTP/1.1
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    chunked_transfer_encoding off;

    proxy_pass http://192.168.0.129:9000;
  }
}

# 落地页
server {
  listen 80;
  server_name r.spotec14.net;

  root /data/fee/application/tmd-landing-page/current;
  index index.html;

  try_files $uri $uri/ /index.html;

  # 清除潜在旧头
  add_header Content-Security-Policy "" always;
  add_header Content-Security-Policy-Report-Only "" always;
  add_header X-Frame-Options "" always;

  # 正确允许 iframe
  add_header Content-Security-Policy "frame-ancestors http: https:" always;
}

# webview
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
server {
  server_name m.spotec14.net;
  listen 80;
  location / {
    proxy_intercept_errors on;
    proxy_pass http://localhost:6060;

    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Client-IP $remote_addr;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_connect_timeout 5s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;
  }

  location = /robots.txt {
    default_type text/plain;

    if ($host ~* ^crm\.ecmarkets\.(sc|com|com\.au|co\.nz|mu)$) {
      return 200 "User-agent: *\nAllow: /\n";
    }

    return 200 "User-agent: *\nDisallow: /\n";
  }

  error_page 502 503 504 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }

  access_log /var/log/nginx/mobile-web.log combined;
  error_log /var/log/nginx/mobile-web-error.log;
}
NGINX_TEMPLATE

# ---------- 替换环境编号 ----------
# 替换域名中的编号（spotec14 / spotecreadonly14 等）
# 替换内网 IP 192.168.0.14（保留 192.168.0.129 文件服务不变）
TMP2=$(mktemp /tmp/nginx-gen.XXXXXX)
trap "rm -f $TMP $TMP2" EXIT
sed \
  -e "s/\(spotec[a-z]*\)${SOURCE}\([^0-9]\)/\1${TARGET}\2/g" \
  -e "s/192\.168\.0\.${SOURCE}\([^0-9]\)/192.168.0.${TARGET}\1/g" \
  "$TMP" > "$TMP2"

# ---------- 拆分 api.conf / site.conf，去重 map 块 ----------
python3 - "$TMP2" "$OUTDIR/tmd-api.conf" "$OUTDIR/tmd-site.conf" <<'PYEOF'
import sys

input_file, api_file, site_file = sys.argv[1], sys.argv[2], sys.argv[3]

with open(input_file) as f:
    lines = f.readlines()

api_lines, site_lines = [], []
map_seen = set()
depth = 0
first_server_done = False
in_first_server = False

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    if not first_server_done:
        if depth == 0 and 'server {' in line:
            in_first_server = True
        depth += line.count('{') - line.count('}')
        api_lines.append(line)
        if in_first_server and depth == 0:
            first_server_done = True
    else:
        # 去重：跳过重复的 map 块
        if depth == 0 and stripped.startswith('map '):
            sig = stripped
            if sig in map_seen:
                depth += line.count('{') - line.count('}')
                i += 1
                while i < len(lines) and depth > 0:
                    depth += lines[i].count('{') - lines[i].count('}')
                    i += 1
                while i < len(lines) and not lines[i].strip():
                    i += 1
                continue
            else:
                map_seen.add(sig)

        depth += line.count('{') - line.count('}')
        site_lines.append(line)

    i += 1

with open(api_file, 'w') as f:
    f.writelines(api_lines)

with open(site_file, 'w') as f:
    f.writelines(site_lines)

print(f"  → {api_file}")
print(f"  → {site_file}")
PYEOF

echo "▶ 验证配置..."
sudo nginx -t

echo "▶ 重载 nginx..."
sudo nginx -s reload

echo "✓ 完成，环境: ${TARGET}"
