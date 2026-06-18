#!/usr/bin/env bash
set -euo pipefail

# ── 输出目录（可通过第一个参数覆盖）────────────────────
OUTDIR="${1:-/etc/nginx/conf.d}"

# ── 后端地址（在此处统一修改）──────────────────────────
BACKEND_JAVA="127.0.0.1:31000"      # Java 主服务（api / admin-api / 推广链接）
MT4_TRADE="172.31.45.245:30012"     # MT4 trade.io
WS_SVC="172.20.1.171:30013"         # WebSocket 行情服务
CRM_NODE1="127.0.0.1:9030"          # CRM 节点 1（weight=1）
CRM_NODE2="127.0.0.1:9080"          # CRM 节点 2（weight=2）
OFFICIAL="127.0.0.1:9010"           # 官网
WEBVIEW="127.0.0.1:6060"            # WebView H5

mkdir -p "$OUTDIR"
echo "生成目录: $OUTDIR"

# ─────────────────────────────────────────────────────────────────────────────
# 00 - 公共 map（整个 http 上下文只允许同名 map 出现一次）
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/00-common.conf" << 'CONF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      '';
}
CONF
echo "  ✓ 00-common.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 10 - API 服务（面向客户端的所有域名）
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-api.conf" << EOF
upstream backend_java {
  server ${BACKEND_JAVA};
  keepalive 256;
  keepalive_requests 10000;
  keepalive_timeout 60s;
}

server {
  listen 80;
  server_name api.lazard.cc api.lazard.net api.weal7h.com api.dailyprime.net api.justapple.uk api.ecmarket.cc api.ecmarket.work api.ecmarket.vip api.ecmarket.xyz api.ecmarket.club websocket.ecm-logo.com api.ecmarkets.mu api.ecmarkets.app api.eccapital.org api.eccapital.vip api.eccapital.club api.eccapital.uk api.eccapital.cc api.ecprime.xyz api.ecprime.cuz api.ecprime.work api.ecprime.uk api.ecprime.icu api.ecprime.cc api.def123.org api.dig123.org api.dec123.org api.ecintel.xyz api.ecintel.work api.ecintel.org api.ecintel.net api.ecintel.cc api.mtc123.org api.agc123.org api.abcapp123.com api.ecmprime.org api.acmprime.org api.ecmarket.space api.ecmarket.top api.ecmintl.me api.ecmintl.xyz api.ecmintl.work api.ecmintl.net api.ecmintl.club api.ecmglobal.icu api.ecmglobal.org api.ecmglobal.app api.ecmglobal.net api.acmprime.net api.ecmarket.org api.ecmprime.work api.ecmprime.xyz api.ecmprime.vip api.ecmarket.info api.ecmarket.fun api.ecmarket.site api.ecmarket.website api.ecmarket.life api.887765433.uk api.679544665.uk api.4733984.uk api.ecmprime.net api.rcapitalgroup.cc api.ecmcorp.org api.ec-markets.co api.ec-markets.ltd api.cprime.uk api.bprime.uk api.ecmarkets.com api.ecmarkets.com.au api.ecmarkets.co.nz api.ecmarkets.lol api.ecmarkets.shop api.ecmarkets.fun api.ecmarkets.link api.ecmintl.cc api.ecmarkets.pro api.ecmarkets.info api.ecmarkets.biz api.ecmglobal.cc api.ecmglobal.work api.ecmglobal.vip api.ecmglobal.club api.ecmglobal.xyz api.ecmarkets.xyz api.ecmprime.cc api.ecmarkets.ltd api.ecmarkets.live api.ecmarkets.co api.ecmarkets.net api.ecmarkets.sc api.ec-markets.net api.ecmarkets.asia api.ecmarkets.work api.ecmarkets.mobi api.ecmarkets.direct api.ecmarkets.tech api.ecmarkets.today;

  location ~ /api/(ib|app|client|h5|third|home|landingPage)/ {
    proxy_pass http://backend_java;
    proxy_http_version 1.1;
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
    if (\$request_method = 'OPTIONS') {
      return 204;
    }
  }

  location ^~ /mt4/ {
    proxy_pass http://backend_java;
    proxy_http_version 1.1;
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;
    #proxy_set_header instanceVersion a;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
    if (\$request_method = 'OPTIONS') {
      return 204;
    }
  }

  location ^~ /api/websocket/ {
    proxy_pass http://${BACKEND_JAVA};
    proxy_http_version 1.1;
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;
    #proxy_set_header instanceVersion a;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
    if (\$request_method = 'OPTIONS') {
      return 204;
    }
  }

  location /mt4/trade.io/ {
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_pass http://${MT4_TRADE};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
  }

  location ^~ /ws/ {
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_pass http://${WS_SVC};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
  }
}
EOF
echo "  ✓ tmd-api.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 20 - 管理端 API 服务
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-admin-api.conf" << EOF
server {
  listen 80;
  server_name common-api.pwcsolution.com admin-api.ecmarkets.net admin-api.ec-markets.net admin-api.ecmarkets.asia;

  location ~ (/api/be/payment|api/be/email|api/be/identity) {
    proxy_pass http://${BACKEND_JAVA};
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
    if (\$request_method = 'OPTIONS') {
      return 204;
    }
  }
}
EOF
echo "  ✓ tmd-admin-api.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 30 - 管理端前端（静态文件）
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-admin-ui.conf" << 'CONF'
server {
  listen 80;
  server_name 15030b8f-7868-4853-955b-26e277a08eeb.pwcsolution.com;
  index index.html index.htm;
  root /data/fee/application/tmd-admin/current;
  try_files $uri $uri/ /index.html;
}
CONF
echo "  ✓ tmd-admin-ui.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 40 - CRM 服务
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-crm.conf" << EOF
upstream ec_client_server {
  least_conn;
  server ${CRM_NODE1} weight=1;
  server ${CRM_NODE2} weight=2;
  keepalive 64;
  keepalive_timeout 60s;
  keepalive_requests 10000;
}

server {
  listen 80;
  server_name crm.ecmarket.cc;

  location / {
    proxy_http_version 1.1;
    proxy_intercept_errors on;
    proxy_pass http://ec_client_server;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
  }

  location = /robots.txt {
    default_type text/plain;
    if (\$host ~* ^crm\.ecmarkets\.(sc|com|com\.au|co\.nz|mu)\$) {
      return 200 "User-agent: *\nAllow: /";
    }
    return 200 "User-agent: *\nDisallow: /";
  }

  location = /.well-known/apple-developer-merchantid-domain-association.txt {
    default_type text/plain;
    root /etc/nginx;
    try_files /applepay/\$host/apple-developer-merchantid-domain-association.txt =404;
  }

  error_page 502 503 504 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }
}
EOF
echo "  ✓ tmd-crm.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 50 - 代理（IB）前端（静态文件）
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-sales.conf" << 'CONF'
server {
  listen 80;
  server_name sales.ecmarket.cc;
  index index.html index.htm;
  root /data/fee/application/tmd-IB-web/current;
  try_files $uri $uri/ /index.html;

  error_page 500 502 504 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }

  access_log /var/log/nginx/ib.log combined;
  error_log  /var/log/nginx/ib-error.log;
}
CONF
echo "  ✓ tmd-sales.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 60 - 官网
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-official.conf" << EOF
server {
  listen 80;
  server_name www.ecmarket.cc;

  location / {
    proxy_intercept_errors on;
    proxy_pass http://${OFFICIAL};
    proxy_set_header Host \$http_host;
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
  }

  location = /robots.txt {
    default_type text/plain;
    if (\$host ~* ^(www\.)?ecmarkets\.(mu|sc)\$) {
      return 200 "User-agent: *\nAllow: /";
    }
    return 200 "User-agent: *\nDisallow: /";
  }

  error_page 502 503 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }
}
EOF
echo "  ✓ tmd-official.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 70 - 文件服务（S3 代理）
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-file.conf" << 'CONF'
server {
  listen 80;
  server_name file.lazard.cc;
  resolver 8.8.8.8 valid=120s;
  resolver_timeout 10s;

  location / {
    set $bucket_name "";
    set $object_path "";
    if ($uri ~ ^/([^/]+)/(.+)$) {
      set $bucket_name $1;
      set $object_path $2;
    }
    if ($bucket_name ~* ^(country|icon|system|tmd)$) {
      set $bucket_name "ec-$bucket_name";
    }
    if ($bucket_name = "") {
      return 404;
    }
    proxy_set_header X-Real-IP        $remote_addr;
    proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host             s3.ap-east-1.amazonaws.com;
    proxy_connect_timeout 300;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    chunked_transfer_encoding off;
    proxy_pass https://s3.ap-east-1.amazonaws.com/$bucket_name/$object_path?$args;
  }
}
CONF
echo "  ✓ tmd-file.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 80 - 推广链接 / 私域信号分享
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/popularize-link.conf" << EOF
server {
  listen 80;
  server_name i.ecmarket.cc;

  location /api/client/pm/ {
    proxy_pass http://${BACKEND_JAVA};
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_connect_timeout 60;
    proxy_read_timeout 600;
  }
}
EOF
echo "  ✓ popularize-link.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 90 - 落地页（静态文件）
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-landing.conf" << 'CONF'
server {
  listen 80;
  server_name r.ecmarket.cc;
  index index.html index.htm;
  root /data/fee/application/tmd-landing-page/current;
  try_files $uri $uri/ /index.html;

  # 清除潜在旧头
  add_header Content-Security-Policy             "" always;
  add_header Content-Security-Policy-Report-Only "" always;
  add_header X-Frame-Options                     "" always;
  # 允许 iframe 嵌入
  add_header Content-Security-Policy "frame-ancestors http: https:" always;
}
CONF
echo "  ✓ tmd-landing.conf"

# ─────────────────────────────────────────────────────────────────────────────
# 95 - WebView
# ─────────────────────────────────────────────────────────────────────────────
cat > "$OUTDIR/tmd-webview.conf" << EOF
server {
  listen 80;
  server_name m.lazard.cc;

  location / {
    proxy_intercept_errors on;
    proxy_pass http://${WEBVIEW};
    proxy_set_header Host \$http_host;
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }

  error_page 502 503 /50x.html;
  location = /50x.html {
    root /etc/nginx/error_page;
  }
}
EOF
echo "  ✓ tmd-webview.conf"

echo ""
echo "完成！共生成 $(ls "$OUTDIR"/*.conf | wc -l) 个配置文件"
echo "验证配置: nginx -t"
