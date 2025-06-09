// dell_chassis.go
// Dell chassis monitoring enhancements for SNMP exporter

package collector

import (
	"log/slog"
	"strings"

	"github.com/gosnmp/gosnmp"
	"github.com/prometheus/client_golang/prometheus"
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
