#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Parse command line arguments
DRY_RUN=false
UPDATE=false
LOCALHOST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --update|--clean)
            UPDATE=true
            shift
            ;;
        --localhost-only|--local-only|--localhost)
            LOCALHOST_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --update, --clean     Clean install dependencies before starting"
            echo "  --localhost-only      Start only localhost server without Cloudflare tunnel"
            echo "  --dry-run            Simulate the process without executing commands"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$LOCALHOST_ONLY" = true ]; then
    echo -e "${BLUE}🏠 Starting Localhost-Only Stack${NC}"
else
    echo -e "${BLUE}🚀 Starting Orca.best Stack${NC}"
fi
echo "================================"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - Commands will be shown but not executed${NC}"
    echo ""
fi

# Handle update/clean option
if [ "$UPDATE" = true ]; then
    echo -e "${BLUE}🧹 Cleaning up for fresh install...${NC}"
    cd /Users/robin/Code/claudecodeui
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would execute: rm -rf node_modules package-lock.json"
    else
        rm -rf node_modules package-lock.json
        echo -e "${GREEN}✓ Removed node_modules and package-lock.json${NC}"
    fi
    
    echo -e "${BLUE}📦 Installing dependencies...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo "Would execute: npm install"
    else
        npm install
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install dependencies${NC}"
            exit 1
        fi
    fi
    echo ""
fi

# Function to check and display process information
check_port_process() {
    local port=$1
    local port_name=$2
    
    EXISTING_PROCESS=$(lsof -ti:$port)
    if [ ! -z "$EXISTING_PROCESS" ]; then
        echo -e "${YELLOW}⚠ Found existing process on port $port ($port_name):${NC}"
        
        # Get detailed process information
        PROCESS_INFO=$(ps -p $EXISTING_PROCESS -o pid,ppid,command --no-headers 2>/dev/null)
        if [ ! -z "$PROCESS_INFO" ]; then
            echo -e "${YELLOW}   PID: $EXISTING_PROCESS${NC}"
            echo -e "${YELLOW}   Command: $(echo "$PROCESS_INFO" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}'| sed 's/[[:space:]]*$//')${NC}"
            
            # Check if it's one of our expected processes
            if echo "$PROCESS_INFO" | grep -q "node server/index.js\|vite\|npm run"; then
                echo -e "${GREEN}   → This appears to be from a previous run of this script${NC}"
                SAFE_TO_KILL=true
            else
                echo -e "${RED}   → This is a different application, proceed with caution${NC}"
                SAFE_TO_KILL=false
            fi
        else
            echo -e "${RED}   → Could not get process details (process may have ended)${NC}"
            SAFE_TO_KILL=true
        fi
        
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}   Would execute: kill $EXISTING_PROCESS${NC}"
        else
            if [ "$SAFE_TO_KILL" = true ]; then
                kill $EXISTING_PROCESS
                echo -e "${GREEN}   ✓ Killed process $EXISTING_PROCESS${NC}"
            else
                echo -e "${YELLOW}   ⚠ Killing potentially unrelated process $EXISTING_PROCESS${NC}"
                kill $EXISTING_PROCESS
                echo -e "${GREEN}   ✓ Process killed${NC}"
            fi
            sleep 1
        fi
        echo ""
        return 0
    fi
    return 1
}

# Check for existing processes on relevant ports
echo -e "${BLUE}Checking for existing processes on ports...${NC}"
FOUND_PROCESSES=false

# Check backend port (3008)
if check_port_process 3008 "Backend Server"; then
    FOUND_PROCESSES=true
fi

# Check common frontend ports (3009, 3010, 3001)
if check_port_process 3009 "Frontend Dev Server"; then
    FOUND_PROCESSES=true
fi

if check_port_process 3010 "Frontend Dev Server"; then
    FOUND_PROCESSES=true
fi

if check_port_process 3001 "Frontend Dev Server"; then
    FOUND_PROCESSES=true
fi

if [ "$FOUND_PROCESSES" = false ]; then
    echo -e "${GREEN}✓ No conflicting processes found${NC}"
    echo ""
fi

# Clear browser data for clean start  
echo -e "${BLUE}Clearing browser cache/cookies...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "Would clear browser data for orca.best"
else
    echo -e "${YELLOW}🧹 To fix authentication issues:${NC}"
    echo -e "${YELLOW}   1. Open Developer Tools (F12) on orca.best${NC}"
    echo -e "${YELLOW}   2. Go to Application/Storage tab${NC}"
    echo -e "${YELLOW}   3. Clear 'Local Storage' and 'Session Storage' for orca.best${NC}"
    echo -e "${YELLOW}   4. Or use Incognito/Private mode${NC}"
    echo ""
    echo -e "${BLUE}📱 Quick fix: localStorage.clear() in browser console${NC}"
fi

# Start development servers first
echo -e "${BLUE}Starting development servers...${NC}"
cd /Users/robin/Code/claudecodeui

if [ "$DRY_RUN" = true ]; then
    echo "Would execute: npm run dev"
else
    npm run dev &
    SERVER_PID=$!
    
    # Wait for servers to be ready
    echo -e "${BLUE}Waiting for servers to be ready...${NC}"
    timeout 30 bash -c 'while ! nc -z localhost 3008; do sleep 1; done' && echo -e "${GREEN}✓ Backend ready${NC}"
    timeout 30 bash -c 'while ! nc -z localhost 3009; do sleep 1; done' && echo -e "${GREEN}✓ Frontend ready${NC}"
fi

# Handle Cloudflare tunnel (skip if localhost-only mode)
if [ "$LOCALHOST_ONLY" = true ]; then
    echo -e "${YELLOW}🏠 Localhost-only mode: Skipping Cloudflare tunnel${NC}"
    TUNNEL_PID=""
else
    # Check if tunnel is already running
    CONNECTIONS=$(cloudflared tunnel info orca-tunnel 2>/dev/null | grep -o 'Connections:.*' | awk '{print $2}')

    if [ "$CONNECTIONS" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✓ Tunnel already running with $CONNECTIONS connections${NC}"
    else
        echo -e "${BLUE}Starting Cloudflare tunnel...${NC}"
        if [ "$DRY_RUN" = true ]; then
            echo "Would execute: cloudflared tunnel run orca-tunnel &"
            TUNNEL_PID=""
        else
            cloudflared tunnel run orca-tunnel &
            TUNNEL_PID=$!
            echo "Tunnel PID: $TUNNEL_PID"
            
            echo "Waiting for tunnel to connect..."
            sleep 5
            
            if ps -p $TUNNEL_PID > /dev/null; then
                echo -e "${GREEN}✓ Tunnel started successfully${NC}"
            else
                echo -e "${RED}✗ Tunnel failed to start${NC}"
                exit 1
            fi
        fi
    fi
fi

if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}✅ All services started! Access via:${NC}"
    echo -e "${BLUE}  Localhost: http://localhost:3009${NC}"
    if [ "$LOCALHOST_ONLY" = false ]; then
        echo -e "${BLUE}  Domain: https://orca.best${NC}"
    fi
    wait $SERVER_PID
fi

# Cleanup
if [ ! -z "$TUNNEL_PID" ]; then
    echo -e "${BLUE}Stopping tunnel...${NC}"
    kill $TUNNEL_PID 2>/dev/null
fi