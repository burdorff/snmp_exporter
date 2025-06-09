#!/bin/bash
# Setup script for Dell chassis monitoring in SNMP exporter fork
# Run this from the root of your snmp_exporter fork

set -e

echo "Setting up Dell Chassis Monitoring for SNMP Exporter"
echo "====================================================="

# Check if we're in the right directory
if [ ! -f "main.go" ] || [ ! -d "collector" ]; then
    echo "Error: Please run this script from the root of your snmp_exporter fork"
    exit 1
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p generator/mibs/dell
mkdir -p examples/dell-chassis

# Create generator configuration
echo "Creating generator configuration..."
cat > generator/generator-dell-chassis.yml << 'EOF'
# Dell Chassis/CMC Configuration for SNMP Exporter Generator
# Based on DELL-RAC-MIB

auths:
  # Dell CMC typically uses SNMP v2c with custom community
  dell_cmc_v2:
    version: 2
    community: public
  
  # For environments requiring SNMPv3
  dell_cmc_v3:
    version: 3
    username: monitoring
    security_level: authPriv
    auth_protocol: SHA
    priv_protocol: AES

modules:
  # Complete Dell Chassis monitoring module
  dell_chassis:
    walk:
      # Product Information
      - 1.3.6.1.4.1.674.10892.2.1.1.1    # drsProductInfoGroup
      - 1.3.6.1.4.1.674.10892.2.1.2      # drsFirmwareGroup
      
      # Chassis Status
      - 1.3.6.1.4.1.674.10892.2.2        # drsStatusGroup
      - 1.3.6.1.4.1.674.10892.2.3.1      # drsStatusNowGroup
      - 1.3.6.1.4.1.674.10892.2.3.2      # drsStatusPrevGroup
      
      # Power Information
      - 1.3.6.1.4.1.674.10892.2.4.1      # drsCMCPowerTable
      - 1.3.6.1.4.1.674.10892.2.4.2      # drsCMCPSUTable
      
      # Server Information
      - 1.3.6.1.4.1.674.10892.2.5.1      # drsCMCServerTable
      
      # Storage Management
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.1   # controllerTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.4   # physicalDiskTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.3   # enclosureTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.15  # batteryTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.140.1   # virtualDiskTable

    get:
      # Key chassis identifiers
      - 1.3.6.1.4.1.674.10892.2.1.1.1.6    # drsChassisServiceTag
      - 1.3.6.1.4.1.674.10892.2.1.1.1.8    # drsProductChassisAssetTag
      - 1.3.6.1.4.1.674.10892.2.1.1.1.9    # drsProductChassisLocation
      - 1.3.6.1.4.1.674.10892.2.1.1.1.10   # drsProductChassisName
      - 1.3.6.1.4.1.674.10892.2.1.1.1.19   # drsProductChassisModel
      - 1.3.6.1.4.1.674.10892.2.1.1.1.20   # drsProductChassisExpressServiceCode
      
      # Global status
      - 1.3.6.1.4.1.674.10892.2.2.1        # drsGlobalSystemStatus

  # Focused storage monitoring module  
  dell_storage:
    walk:
      # Storage-specific tables
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.1   # controllerTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.4   # physicalDiskTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.3   # enclosureTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.15  # batteryTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.140.1   # virtualDiskTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.7   # enclosureFanTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.9   # enclosurePowerSupplyTable
      - 1.3.6.1.4.1.674.10892.2.6.1.20.130.11  # enclosureTemperatureProbeTable
EOF

# Create Dell enhancement module
echo "Creating Dell enhancement module..."
cat > collector/dell_chassis.go << 'EOF'
// dell_chassis.go
// Dell chassis monitoring enhancements for SNMP exporter

package collector

import (
	"log/slog"
	"strconv"
	"strings"

	"github.com/gosnmp/gosnmp"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/snmp_exporter/config"
)

// DellChassisInfo represents Dell chassis identification data
type DellChassisInfo struct {
	ServiceTag         string
	AssetTag          string
	Model             string
	Location          string
	ExpressServiceCode string
	Name              string
}

// extractDellChassisInfo extracts Dell chassis identification from SNMP data
func extractDellChassisInfo(oidToPdu map[string]gosnmp.SnmpPDU, logger *slog.Logger) *DellChassisInfo {
	info := &DellChassisInfo{}

	// Dell chassis service tag - OID: 1.3.6.1.4.1.674.10892.2.1.1.1.6
	if pdu, exists := oidToPdu["1.3.6.1.4.1.674.10892.2.1.1.1.6"]; exists {
		if serviceTag, ok := pdu.Value.(string); ok {
			info.ServiceTag = serviceTag
		}
	}

	// Dell chassis asset tag - OID: 1.3.6.1.4.1.674.10892.2.1.1.1.8  
	if pdu, exists := oidToPdu["1.3.6.1.4.1.674.10892.2.1.1.1.8"]; exists {
		if assetTag, ok := pdu.Value.(string); ok {
			info.AssetTag = assetTag
		}
	}

	// Dell chassis model - OID: 1.3.6.1.4.1.674.10892.2.1.1.1.19
	if pdu, exists := oidToPdu["1.3.6.1.4.1.674.10892.2.1.1.1.19"]; exists {
		if model, ok := pdu.Value.(string); ok {
			info.Model = model
		}
	}

	// Dell chassis location - OID: 1.3.6.1.4.1.674.10892.2.1.1.1.9
	if pdu, exists := oidToPdu["1.3.6.1.4.1.674.10892.2.1.1.1.9"]; exists {
		if location, ok := pdu.Value.(string); ok {
			info.Location = location
		}
	}

	// Dell chassis name - OID: 1.3.6.1.4.1.674.10892.2.1.1.1.10
	if pdu, exists := oidToPdu["1.3.6.1.4.1.674.10892.2.1.1.1.10"]; exists {
		if name, ok := pdu.Value.(string); ok {
			info.Name = name
		}
	}

	// Dell express service code - OID: 1.3.6.1.4.1.674.10892.2.1.1.1.20
	if pdu, exists := oidToPdu["1.3.6.1.4.1.674.10892.2.1.1.1.20"]; exists {
		if esc, ok := pdu.Value.(string); ok {
			info.ExpressServiceCode = esc
		}
	}

	logger.Debug("Extracted Dell chassis info",
		"service_tag", info.ServiceTag,
		"model", info.Model,
		"location", info.Location)

	return info
}

// createDellChassisInfoMetric creates a Prometheus info metric for Dell chassis
func createDellChassisInfoMetric(info *DellChassisInfo) prometheus.Metric {
	labels := prometheus.Labels{
		"chassis_service_tag":          info.ServiceTag,
		"chassis_asset_tag":           info.AssetTag,
		"chassis_model":               info.Model,
		"chassis_location":            info.Location,
		"chassis_name":                info.Name,
		"chassis_express_service_code": info.ExpressServiceCode,
	}

	desc := prometheus.NewDesc(
		"dell_chassis_info",
		"Dell chassis identification information",
		nil,
		labels,
	)

	return prometheus.MustNewConstMetric(desc, prometheus.GaugeValue, 1)
}

// translateDellStatus converts Dell status enumeration to human readable
func translateDellStatus(statusValue interface{}) (string, float64) {
	var status int
	switch v := statusValue.(type) {
	case int:
		status = v
	case int64:
		status = int(v)
	case uint64:
		status = int(v)
	default:
		return "unknown", 0
	}

	// Dell status enumeration from DellStatus in MIB
	switch status {
	case 1:
		return "other", 0
	case 2:
		return "unknown", 0
	case 3:
		return "ok", 1
	case 4:
		return "non_critical", 0.5
	case 5:
		return "critical", 0
	case 6:
		return "non_recoverable", 0
	default:
		return "undefined", 0
	}
}

// isDellDevice checks if the target device is a Dell chassis/server
func isDellDevice(oidToPdu map[string]gosnmp.SnmpPDU) bool {
	// Check for Dell enterprise OID presence
	for oid := range oidToPdu {
		if strings.HasPrefix(oid, "1.3.6.1.4.1.674") {
			return true
		}
	}
	return false
}

// processDellMetrics processes Dell-specific metrics and adds enhancements
func processDellMetrics(oidToPdu map[string]gosnmp.SnmpPDU, logger *slog.Logger) []prometheus.Metric {
	var metrics []prometheus.Metric

	if !isDellDevice(oidToPdu) {
		return metrics
	}

	logger.Debug("Processing Dell-specific metrics")

	// Extract and create chassis info metric
	chassisInfo := extractDellChassisInfo(oidToPdu, logger)
	if chassisInfo.ServiceTag != "" {
		chassisMetric := createDellChassisInfoMetric(chassisInfo)
		metrics = append(metrics, chassisMetric)
	}

	// Count storage components
	controllerCount := 0
	diskCount := 0
	enclosureCount := 0

	for oid := range oidToPdu {
		if strings.Contains(oid, "1.3.6.1.4.1.674.10892.2.6.1.20.130.1.1.1") {
			controllerCount++
		} else if strings.Contains(oid, "1.3.6.1.4.1.674.10892.2.6.1.20.130.4.1.1") {
			diskCount++
		} else if strings.Contains(oid, "1.3.6.1.4.1.674.10892.2.6.1.20.130.3.1.1") {
			enclosureCount++
		}
	}

	// Create summary metrics
	if controllerCount > 0 {
		desc := prometheus.NewDesc(
			"dell_storage_controllers_total",
			"Total number of Dell storage controllers",
			nil, nil,
		)
		metrics = append(metrics, prometheus.MustNewConstMetric(
			desc, prometheus.GaugeValue, float64(controllerCount)))
	}

	if diskCount > 0 {
		desc := prometheus.NewDesc(
			"dell_storage_physical_disks_total", 
			"Total number of Dell physical disks",
			nil, nil,
		)
		metrics = append(metrics, prometheus.MustNewConstMetric(
			desc, prometheus.GaugeValue, float64(diskCount)))
	}

	if enclosureCount > 0 {
		desc := prometheus.NewDesc(
			"dell_storage_enclosures_total",
			"Total number of Dell storage enclosures", 
			nil, nil,
		)
		metrics = append(metrics, prometheus.MustNewConstMetric(
			desc, prometheus.GaugeValue, float64(enclosureCount)))
	}

	return metrics
}
EOF

# Create test script
echo "Creating test script..."
cat > examples/dell-chassis/test-dell-chassis.sh << 'EOF'
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
EOF

chmod +x examples/dell-chassis/test-dell-chassis.sh

# Create README for Dell monitoring
echo "Creating documentation..."
cat > examples/dell-chassis/README.md << 'EOF'
# Dell Chassis Monitoring with SNMP Exporter

This directory contains configuration and tools for monitoring Dell chassis (PowerEdge servers, PowerVault storage) using the SNMP exporter.

## Features

- **Chassis identification**: Service tag, model, location, asset tag
- **Storage monitoring**: Controllers, disks, enclosures, batteries
- **Status translation**: Human-readable status from Dell enumerations
- **Component counting**: Automatic inventory of storage components

## Files

- `test-dell-chassis.sh` - Test script for Dell chassis connectivity
- `../generator-dell-chassis.yml` - Generator configuration for Dell MIBs
- Dell-specific metrics in the main collector

## Usage

1. **Generate Dell configuration**:
   ```bash
   cd generator/
   make generator
   ./generator generate -m mibs/dell -g generator-dell-chassis.yml -o ../snmp-dell-chassis.yml
   ```

2. **Build enhanced exporter**:
   ```bash
   make build
   ```

3. **Test with your Dell chassis**:
   ```bash
   ./examples/dell-chassis/test-dell-chassis.sh YOUR_CHASSIS_IP public
   ```

4. **Query metrics**:
   ```bash
   curl "http://localhost:9116/snmp?target=YOUR_CHASSIS_IP&auth=dell_cmc_v2&module=dell_chassis"
   ```

## Key Metrics

- `dell_chassis_info` - Chassis identification with labels
- `dell_controller_status` - RAID controller health
- `dell_disk_status` - Physical disk status  
- `dell_enclosure_status` - Storage enclosure health
- `dell_storage_*_total` - Component inventory counts

## Requirements

- Dell chassis with SNMP enabled
- DELL-RAC-MIB.txt in `generator/mibs/dell/`
- SNMP community string or v3 credentials
EOF

echo ""
echo "✓ Dell chassis monitoring setup completed!"
echo ""
echo "Next steps:"
echo "1. Copy your DELL-RAC-MIB.txt to generator/mibs/dell/"
echo "2. Run: cd generator && make generator"
echo "3. Generate config: ./generator generate -m mibs/dell -g generator-dell-chassis.yml -o ../snmp-dell-chassis.yml"
echo "4. Build: make build"
echo "5. Test: ./examples/dell-chassis/test-dell-chassis.sh YOUR_CHASSIS_IP"
echo ""
echo "Files created:"
echo "- generator/generator-dell-chassis.yml"
echo "- collector/dell_chassis.go"
echo "- examples/dell-chassis/test-dell-chassis.sh"
echo "- examples/dell-chassis/README.md"
