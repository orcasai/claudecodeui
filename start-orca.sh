#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Orca.best Stack${NC}"
echo "================================"

# Check if tunnel is already running
CONNECTIONS=$(cloudflared tunnel info orca-tunnel 2>/dev/null | grep -o 'Connections:.*' | awk '{print $2}')

if [ "$CONNECTIONS" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ Tunnel already running with $CONNECTIONS connections${NC}"
else
    echo -e "${BLUE}Starting Cloudflare tunnel...${NC}"
    # Start tunnel in background
    cloudflared tunnel run orca-tunnel &
    TUNNEL_PID=$!
    echo "Tunnel PID: $TUNNEL_PID"
    
    # Wait for tunnel to establish connections
    echo "Waiting for tunnel to connect..."
    sleep 5
    
    # Check if tunnel is running
    if ps -p $TUNNEL_PID > /dev/null; then
        echo -e "${GREEN}✓ Tunnel started successfully${NC}"
    else
        echo -e "${RED}✗ Tunnel failed to start${NC}"
        exit 1
    fi
fi

# Start the development server
echo -e "${BLUE}Starting Claude Code UI...${NC}"
cd /Users/robin/Code/claudecodeui
npm run dev

# When npm exits, optionally kill the tunnel
if [ ! -z "$TUNNEL_PID" ]; then
    echo -e "${BLUE}Stopping tunnel...${NC}"
    kill $TUNNEL_PID 2>/dev/null
fi