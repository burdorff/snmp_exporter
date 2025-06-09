#!/bin/bash
# Test script for Dell chassis monitoring

# Set your Dell chassis IP
DELL_CHASSIS_IP="${1:-192.168.1.100}"  # Use first argument or default
SNMP_COMMUNITY="${2:-public}"           # Use second argument or default

echo "Testing Dell Chassis SNMP Monitoring"
echo "======================================="
echo "Target: $DELL_CHASSIS_IP"
echo "Community: $SNMP_COMMUNITY"
echo ""

# Test 1: Basic connectivity
echo "1. Testing SNMP connectivity..."
if command -v snmpget >/dev/null 2>&1; then
    snmpget -v2c -c $SNMP_COMMUNITY $DELL_CHASSIS_IP 1.3.6.1.4.1.674.10892.2.1.1.1.6 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ SNMP connectivity successful"
    else
        echo "✗ SNMP connectivity failed"
        echo "  Make sure SNMP is enabled on the Dell chassis and the community string is correct"
        exit 1
    fi
else
    echo "⚠ snmpget not found, skipping SNMP connectivity test"
fi

# Test 2: Chassis service tag
echo -e "\n2. Retrieving chassis service tag..."
if command -v snmpget >/dev/null 2>&1; then
    SERVICE_TAG=$(snmpget -v2c -c $SNMP_COMMUNITY $DELL_CHASSIS_IP 1.3.6.1.4.1.674.10892.2.1.1.1.6 -Oqv 2>/dev/null | tr -d '"')
    echo "Service Tag: $SERVICE_TAG"
else
    echo "⚠ snmpget not available"
fi

# Test 3: Test with SNMP exporter
echo -e "\n3. Testing with SNMP exporter..."
if [ -f "../../snmp_exporter" ]; then
    echo "Starting SNMP exporter test..."
    timeout 10s ../../snmp_exporter --config.file=../../snmp-dell-chassis.yml &
    EXPORTER_PID=$!
    sleep 3
    
    # Test the exporter endpoint
    echo "Querying exporter endpoint..."
    curl -s "http://localhost:9116/snmp?target=$DELL_CHASSIS_IP&auth=dell_cmc_v2&module=dell_chassis" | grep -E "(dell_chassis|dell_storage)" | head -10
    
    kill $EXPORTER_PID 2>/dev/null
else
    echo "snmp_exporter binary not found. Build it first with 'make build'"
fi

echo -e "\nDell chassis monitoring test completed!"
