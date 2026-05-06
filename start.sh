#!/bin/bash

# 1. 设置环境变量（这些可以在 Railway 后台配置，也可以在这里写默认值）
PORT=${PORT:-8080}
SB_PORT=10086 # sing-box 内部监听端口
UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}

# 2. 修改 sing-box 配置文件中的 UUID
sed -i "s/YOUR_UUID/$UUID/g" /etc/sing-box/config.json

# 3. 启动 sing-box (后台运行)
/usr/local/bin/sing-box run -c /etc/sing-box/config.json &

# 4. 启动 Cloudflared Argo 隧道并获取域名
echo "正在启动 Argo 隧道，请稍等..."
/usr/local/bin/cloudflared tunnel --url http://localhost:$SB_PORT --no-autoupdate > /tmp/argo.log 2>&1 &

# 等待几秒让隧道建立并提取域名
sleep 10
ARGO_DOMAIN=$(grep -oE "[a-zA-Z0-9.-]+\.trycloudflare\.com" /tmp/argo.log | head -n 1)

# 5. 生成 VLESS 节点链接 (根据你的 sing-box 配置调整)
NODE_LINK="vless://$UUID@$ARGO_DOMAIN:443?encryption=none&security=tls&sni=$ARGO_DOMAIN&type=ws&host=$ARGO_DOMAIN&path=%2F#科技共享-Sing-Flare"

# 6. 生成展示页面 (存放在 /www 目录)
mkdir -p /www
cat > /www/index.html << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sing-Flare-Auto 部署成功</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; background-color: #f4f7f6; color: #333; line-height: 1.6; }
        .card { background: white; max-width: 650px; margin: 20px auto; padding: 30px; border-radius: 15px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); }
        h1 { color: #ff0000; font-size: 24px; margin-bottom: 10px; }
        .desc { font-size: 14px; color: #666; margin-bottom: 20px; }
        .info-item { background: #f9f9f9; padding: 10px; border-radius: 5px; margin-bottom: 10px; border-left: 4px solid #ff0000; }
        .node-title { color: #2c3e50; font-weight: bold; margin-top: 25px; margin-bottom: 10px; }
        .node-box { background: #2d3436; color: #00cec9; padding: 15px; border-radius: 8px; word-break: break-all; font-family: 'Courier New', Courier, monospace; cursor: pointer; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #999; }
        a { color: #0984e3; text-decoration: none; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Sing-Flare-Auto</h1>
        <p class="desc">基于 Docker 容器的轻量级、高隐匿性科学上网节点部署方案。通过集成 sing-box 和 cloudflared，你可以轻松地在各类云平台（如 Railway、Render 等）或个人 VPS 上一键构建安全隧道。</p>
        
        <div class="info-item"><b>YouTube:</b> <a href="https://www.youtube.com/@kejigongxiang" target="_blank">https://www.youtube.com/@kejigongxiang</a></div>
        <div class="info-item"><b>GitHub地址:</b> <a href="https://github.com/zzzhhh1/Sing-Flare-Auto" target="_blank">https://github.com/zzzhhh1/Sing-Flare-Auto</a></div>
        <div class="info-item"><b>油管频道:</b> 科技共享</div>
        
        <div class="node-title">+++++++++++++++++++++++<br>您的专属4K极速专线节点（点击/长按复制）*</div>
        <div class="node-box" onclick="copyNode()">$NODE_LINK</div>
    </div>
    <div class="footer">本页面由科技共享教程自动生成</div>

    <script>
        function copyNode() {
            const el = document.createElement('textarea');
            el.value = '$NODE_LINK';
            document.body.appendChild(el);
            el.select();
            document.execCommand('copy');
            document.body.removeChild(el);
            alert('节点已成功复制到剪贴板！');
        }
    </script>
</body>
</html>
EOF

# 7. 启动一个简单的 Web 服务来展示 index.html
echo "Web 展示页面已就绪，端口: $PORT"
# 使用 python3 启动简单的 HTTP 服务（Alpine 自带或安装 python3）
# 或者使用 busybox 自带的 httpd
busybox httpd -f -p $PORT -h /www
