#!/bin/bash
# Test script for Dockerized Dell SNMP exporter

DELL_CHASSIS_IP="${1:-192.168.1.100}"
SNMP_COMMUNITY="${2:-public}"

echo "Testing Dockerized Dell SNMP Exporter"
echo "======================================"
echo "Target: $DELL_CHASSIS_IP"
echo "Community: $SNMP_COMMUNITY"
echo ""

# Test if container is running
if docker ps | grep -q snmp_exporter_dell; then
    echo "✓ Container is running"
else
    echo "✗ Container not found, starting..."
    docker-compose -f docker-compose.dell.yml up -d
    sleep 10
fi

# Test exporter endpoint
echo -e "\nTesting exporter endpoint..."
curl -s "http://localhost:9116/" && echo "✓ Exporter accessible"

# Test Dell monitoring
echo -e "\nTesting Dell chassis monitoring..."
curl -s "http://localhost:9116/snmp?target=${DELL_CHASSIS_IP}&auth=dell_cmc_v2&module=dell_chassis_minimal" | grep -E "(dell_|snmp_)" | head -5

echo -e "\nTest completed!"
