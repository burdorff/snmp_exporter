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
