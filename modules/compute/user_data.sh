#!/bin/bash
set -euo pipefail

# Install and start Nginx (Amazon Linux 2023 uses dnf).
dnf install -y nginx
systemctl enable --now nginx

# Fetch instance metadata via IMDSv2 so the welcome page shows which
# instance served the request -- handy for proving the load balancer
# is actually distributing traffic across the ASG.
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /usr/share/nginx/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Flat Rock Demo</title>
<style>
  body{font-family:system-ui,sans-serif;background:#0f1115;color:#e6e6e6;
       display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}
  .card{text-align:center;padding:2rem 3rem;border:1px solid #2a2f3a;border-radius:12px}
  h1{margin:0 0 .5rem} code{color:#7dd3fc}
</style></head>
<body><div class="card">
  <h1>Scalable Web App</h1>
  <p>Served by instance <code>${INSTANCE_ID}</code></p>
  <p>Availability Zone: <code>${AZ}</code></p>
  <p>Refresh to see the load balancer rotate instances.</p>
</div></body></html>
HTML
