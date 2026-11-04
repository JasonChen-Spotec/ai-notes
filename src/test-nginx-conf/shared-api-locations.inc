# 普通业务 API
location ~ /api/(be|ib|app|client|h5|third|home|landingPage|v3)/ {
  proxy_pass http://127.0.0.1:31000;
  proxy_set_header X-Client-IP $remote_addr;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header Host $http_host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_connect_timeout 60;
  proxy_read_timeout 600;
  # 普通业务 API 携带 B 版本请求头
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


# MT4 WebSocket
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

# MT4
location ^~ /mt4/ {
  proxy_pass http://127.0.0.1:31000;
  proxy_set_header X-Client-IP $remote_addr;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_connect_timeout 60;
  proxy_read_timeout 600;
  # 保留原配置：不启用 A 版本请求头
  #proxy_set_header instanceVersion a;

  add_header Access-Control-Allow-Origin *;
  add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
  add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
  if ($request_method = 'OPTIONS') {
    return 204;
  }
}

# API WebSocket
location ^~ /api/websocket/ {
  proxy_pass http://127.0.0.1:31000;
  proxy_set_header X-Client-IP $remote_addr;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_connect_timeout 60;
  proxy_read_timeout 600;
  # 保留原配置：不启用 A 版本请求头
  #proxy_set_header instanceVersion a;

  add_header Access-Control-Allow-Origin *;
  add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
  add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,lang,platform,token';
  if ($request_method = 'OPTIONS') {
    return 204;
  }
}

# MT4 trade.io
location /mt4/trade.io/ {
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header Host $http_host;
  proxy_pass http://172.31.45.245:30012;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
}

# 客户端 WebSocket
location ^~ /ws/ {
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header Host $http_host;
  proxy_pass http://127.0.0.1:30013;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
}
