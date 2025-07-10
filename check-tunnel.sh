#!/bin/bash

# Quick tunnel status check
echo "🔍 Checking Orca Tunnel Status..."
echo "================================"

cloudflared tunnel info orca-tunnel

echo ""
echo "🌐 Testing orca.best..."
curl -I https://orca.best 2>/dev/null | head -n 5

echo ""
echo "📡 Local services:"
echo -n "Port 3008 (Backend): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3008 && echo " ✓" || echo " ✗"
echo -n "Port 3009 (Frontend): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3009 && echo " ✓" || echo " ✗"