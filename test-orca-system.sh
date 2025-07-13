#!/bin/bash

# Orca.best System Test Suite
# Comprehensive testing framework for debugging WebSocket communication issues

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TEST_LOG="/tmp/orca-test-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}🧪 Orca.best System Test Suite${NC}"
echo "==============================="
echo "Log file: $TEST_LOG"
echo ""

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -e "${BLUE}Testing: $test_name${NC}"
    echo "Command: $test_command" >> "$TEST_LOG"
    
    if eval "$test_command" >> "$TEST_LOG" 2>&1; then
        if [ -n "$expected_result" ]; then
            # Check if expected result is in the output
            if eval "$test_command" 2>/dev/null | grep -q "$expected_result"; then
                echo -e "${GREEN}✅ PASS: $test_name${NC}"
                ((TESTS_PASSED++))
            else
                echo -e "${RED}❌ FAIL: $test_name (unexpected result)${NC}"
                ((TESTS_FAILED++))
            fi
        else
            echo -e "${GREEN}✅ PASS: $test_name${NC}"
            ((TESTS_PASSED++))
        fi
    else
        echo -e "${RED}❌ FAIL: $test_name${NC}"
        ((TESTS_FAILED++))
    fi
    echo "" >> "$TEST_LOG"
}

# Function to reset to clean state
reset_to_clean_state() {
    echo -e "${YELLOW}🔄 Resetting to clean state...${NC}"
    
    # Kill all running processes
    pkill -f "cloudflared\|npm run\|node server" 2>/dev/null || true
    sleep 2
    
    # Restore any git changes
    cd /Users/robin/Code/claudecodeui
    git restore . 2>/dev/null || true
    git status | grep "clean" > /dev/null && echo -e "${GREEN}✓ Git workspace clean${NC}" || echo -e "${YELLOW}⚠ Git workspace has changes${NC}"
    
    echo -e "${GREEN}✓ Clean state restored${NC}"
    echo ""
}

# Function to start orca system
start_orca_system() {
    echo -e "${YELLOW}🚀 Starting Orca system...${NC}"
    cd /Users/robin/Code/claudecodeui
    ./start-orca.sh > /tmp/orca-test-startup.log 2>&1 &
    sleep 15  # Give it time to start
    echo -e "${GREEN}✓ Orca system started${NC}"
    echo ""
}

# Test Suite Functions

test_basic_connectivity() {
    echo -e "${BLUE}🌐 Basic Connectivity Tests${NC}"
    echo "----------------------------"
    
    run_test "Localhost Frontend" "curl -s -o /dev/null -w '%{http_code}' http://localhost:3009" "200"
    run_test "Localhost Backend" "curl -s -o /dev/null -w '%{http_code}' http://localhost:3008/api/config" "200"
    run_test "Domain Frontend" "curl -s -o /dev/null -w '%{http_code}' https://orca.best" "200"
    run_test "Domain API" "curl -s -o /dev/null -w '%{http_code}' https://orca.best/api/config" "200"
    
    echo ""
}

test_websocket_endpoints() {
    echo -e "${BLUE}🔌 WebSocket Endpoint Tests${NC}"
    echo "-----------------------------"
    
    # Test WebSocket upgrade capability
    run_test "Localhost WS Upgrade" "curl -H 'Upgrade: websocket' -H 'Connection: Upgrade' -H 'Sec-WebSocket-Key: test' -H 'Sec-WebSocket-Version: 13' -s -o /dev/null -w '%{http_code}' http://localhost:3008/ws" ""
    
    run_test "Domain WS Upgrade" "curl -H 'Upgrade: websocket' -H 'Connection: Upgrade' -H 'Sec-WebSocket-Key: test' -H 'Sec-WebSocket-Version: 13' -s -o /dev/null -w '%{http_code}' https://orca.best/ws" ""
    
    echo ""
}

test_config_api() {
    echo -e "${BLUE}⚙️ Configuration API Tests${NC}"
    echo "----------------------------"
    
    # Test config API response
    CONFIG_RESPONSE=$(curl -s https://orca.best/api/config)
    echo "Config API Response: $CONFIG_RESPONSE" >> "$TEST_LOG"
    
    if echo "$CONFIG_RESPONSE" | grep -q "wsUrl"; then
        echo -e "${GREEN}✅ PASS: Config API returns wsUrl${NC}"
        ((TESTS_PASSED++))
        
        # Extract wsUrl for further testing
        WS_URL=$(echo "$CONFIG_RESPONSE" | grep -o '"wsUrl":"[^"]*"' | cut -d'"' -f4)
        echo "Extracted wsUrl: $WS_URL" >> "$TEST_LOG"
        echo -e "${BLUE}📋 WebSocket URL from config: $WS_URL${NC}"
    else
        echo -e "${RED}❌ FAIL: Config API missing wsUrl${NC}"
        ((TESTS_FAILED++))
    fi
    
    echo ""
}

test_server_logs() {
    echo -e "${BLUE}📋 Server Log Analysis${NC}"
    echo "----------------------"
    
    # Check for WebSocket connections in logs
    if [ -f "/tmp/orca-test-startup.log" ]; then
        WS_CONNECTIONS=$(grep -c "WebSocket\|ws:" /tmp/orca-test-startup.log || echo "0")
        CONFIG_CALLS=$(grep -c "Config API called" /tmp/orca-test-startup.log || echo "0")
        
        echo "WebSocket mentions in logs: $WS_CONNECTIONS" >> "$TEST_LOG"
        echo "Config API calls in logs: $CONFIG_CALLS" >> "$TEST_LOG"
        
        echo -e "${BLUE}📊 Log Analysis:${NC}"
        echo "  - WebSocket mentions: $WS_CONNECTIONS"
        echo "  - Config API calls: $CONFIG_CALLS"
        
        if [ "$CONFIG_CALLS" -gt 0 ]; then
            echo -e "${GREEN}✅ PASS: Config API is being called${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}❌ FAIL: No Config API calls detected${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${YELLOW}⚠ Server log file not found${NC}"
    fi
    
    echo ""
}

test_cloudflare_tunnel() {
    echo -e "${BLUE}☁️ Cloudflare Tunnel Tests${NC}"
    echo "---------------------------"
    
    # Check tunnel status
    TUNNEL_INFO=$(cloudflared tunnel info orca-tunnel 2>/dev/null || echo "No tunnel info")
    echo "Tunnel info: $TUNNEL_INFO" >> "$TEST_LOG"
    
    if echo "$TUNNEL_INFO" | grep -q "Connections:"; then
        CONNECTIONS=$(echo "$TUNNEL_INFO" | grep -o 'Connections:.*' | awk '{print $2}')
        echo -e "${GREEN}✅ PASS: Tunnel active with $CONNECTIONS connections${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL: Tunnel not active or no connections${NC}"
        ((TESTS_FAILED++))
    fi
    
    echo ""
}

show_diagnostic_info() {
    echo -e "${BLUE}🔍 Diagnostic Information${NC}"
    echo "-------------------------"
    
    echo -e "${BLUE}Current Git Status:${NC}"
    cd /Users/robin/Code/claudecodeui
    git status --short
    
    echo -e "\n${BLUE}Running Processes:${NC}"
    ps aux | grep -E "(cloudflared|node|npm)" | grep -v grep || echo "No relevant processes found"
    
    echo -e "\n${BLUE}Port Usage:${NC}"
    lsof -i :3008 -i :3009 2>/dev/null || echo "No processes on ports 3008/3009"
    
    echo -e "\n${BLUE}Recent WebSocket Activity:${NC}"
    if [ -f "/tmp/orca-test-startup.log" ]; then
        tail -20 /tmp/orca-test-startup.log | grep -E "(WebSocket|ws:|Config|claude-command)" || echo "No recent WebSocket activity"
    fi
    
    echo ""
}

# Test execution with checkpoint system
run_checkpoint_test() {
    local checkpoint_name="$1"
    echo -e "${YELLOW}🎯 CHECKPOINT: $checkpoint_name${NC}"
    echo "=================================="
    
    # Always start fresh for checkpoint tests
    reset_to_clean_state
    start_orca_system
    
    # Run all tests
    test_basic_connectivity
    test_websocket_endpoints  
    test_config_api
    test_server_logs
    test_cloudflare_tunnel
    show_diagnostic_info
    
    # Show results
    echo -e "${BLUE}📊 Test Results for $checkpoint_name:${NC}"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED" 
    echo "Log: $TEST_LOG"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed for $checkpoint_name!${NC}"
        return 0
    else
        echo -e "${RED}⚠️ Some tests failed for $checkpoint_name${NC}"
        return 1
    fi
}

# Main execution
case "${1:-full}" in
    "connectivity")
        test_basic_connectivity
        ;;
    "websocket")
        test_websocket_endpoints
        ;;
    "config")
        test_config_api
        ;;
    "logs")
        test_server_logs
        ;;
    "cloudflare")
        test_cloudflare_tunnel
        ;;
    "diagnostic")
        show_diagnostic_info
        ;;
    "clean")
        reset_to_clean_state
        ;;
    "start")
        start_orca_system
        ;;
    "checkpoint")
        run_checkpoint_test "${2:-Baseline}"
        ;;
    "full")
        run_checkpoint_test "Full System Test"
        ;;
    *)
        echo "Usage: $0 [connectivity|websocket|config|logs|cloudflare|diagnostic|clean|start|checkpoint|full]"
        echo ""
        echo "Examples:"
        echo "  $0 full                    # Run complete test suite"
        echo "  $0 checkpoint \"After Fix\"  # Run checkpoint test with custom name"
        echo "  $0 connectivity            # Test only basic connectivity"
        echo "  $0 clean                   # Reset to clean state"
        echo "  $0 diagnostic              # Show diagnostic information"
        exit 1
        ;;
esac

echo -e "${BLUE}Final Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}"