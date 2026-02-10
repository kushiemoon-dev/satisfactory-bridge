#!/usr/bin/env python3
"""
Satisfactory Save File Parser (v1.1/v52 format)
Parses .sav files and outputs factory statistics as JSON

Supports: Satisfactory 1.0+ (save format v46-52, header v13-14)
"""

import struct
import zlib
import json
import sys
import re
from datetime import datetime
from typing import Dict, Any
from collections import Counter

class Reader:
    """Binary reader with position tracking"""
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0
    
    def read_uint8(self) -> int:
        if self.offset + 1 > len(self.data):
            raise ValueError(f"EOF reading uint8 at offset {self.offset}")
        v = self.data[self.offset]
        self.offset += 1
        return v
    
    def read_uint32(self) -> int:
        if self.offset + 4 > len(self.data):
            raise ValueError(f"EOF reading uint32 at offset {self.offset}")
        v = struct.unpack('<I', self.data[self.offset:self.offset+4])[0]
        self.offset += 4
        return v
    
    def read_int32(self) -> int:
        if self.offset + 4 > len(self.data):
            raise ValueError(f"EOF reading int32 at offset {self.offset}")
        v = struct.unpack('<i', self.data[self.offset:self.offset+4])[0]
        self.offset += 4
        return v
    
    def read_uint64(self) -> int:
        if self.offset + 8 > len(self.data):
            raise ValueError(f"EOF reading uint64 at offset {self.offset}")
        v = struct.unpack('<Q', self.data[self.offset:self.offset+8])[0]
        self.offset += 8
        return v
    
    def read_string(self) -> str:
        length = self.read_int32()
        if length == 0:
            return ""
        
        if length > 0:
            if self.offset + length > len(self.data):
                raise ValueError(f"String too long: {length} at offset {self.offset}")
            s = self.data[self.offset:self.offset+length-1].decode('utf-8', errors='replace')
            self.offset += length
        else:
            str_len = -length * 2
            if self.offset + str_len > len(self.data):
                raise ValueError(f"String too long: {str_len} at offset {self.offset}")
            s = self.data[self.offset:self.offset+str_len-2].decode('utf-16-le', errors='replace')
            self.offset += str_len
        return s
    
    def skip(self, n: int):
        self.offset += n
    
    def remaining(self) -> int:
        return len(self.data) - self.offset
    
    def get_bytes(self, n: int) -> bytes:
        b = self.data[self.offset:self.offset+n]
        self.offset += n
        return b

# Magic number for Unreal Engine compressed chunks
CHUNK_MAGIC = 0x9E2A83C1

# Patterns for counting buildables (pattern -> display name)
# These match the actual references in save files
MACHINE_PATTERNS = {
    "Build_ConstructorMk1": "Constructor",
    "Build_SmelterMk1": "Smelter",
    "Build_FoundryMk1": "Foundry",
    "Build_AssemblerMk1": "Assembler",
    "Build_ManufacturerMk1": "Manufacturer",
    "Build_OilRefinery": "Refinery",
    "Build_Packager": "Packager",
    "Build_Blender": "Blender",
    "Build_HadronCollider": "Particle Accelerator",
    "Build_QuantumEncoder": "Quantum Encoder",
    "Build_Converter": "Converter",
}

EXTRACTOR_PATTERNS = {
    "Build_MinerMk1": "Miner Mk.1",
    "Build_MinerMk2": "Miner Mk.2",
    "Build_MinerMk3": "Miner Mk.3",
    "Build_WaterPump": "Water Extractor",
    "Build_OilPump": "Oil Extractor",
    "Build_FrackingExtractor": "Resource Well Extractor",
    "Build_FrackingSmasher": "Resource Well Pressurizer",
}

GENERATOR_PATTERNS = {
    "Build_GeneratorBiomass": "Biomass Burner",
    "Build_GeneratorCoal": "Coal Generator",
    "Build_GeneratorFuel": "Fuel Generator",
    "Build_GeneratorNuclear": "Nuclear Power Plant",
    "Build_GeneratorGeoThermal": "Geothermal Generator",
}

LOGISTICS_PATTERNS = {
    "Build_ConveyorBeltMk1": "Conveyor Belt Mk.1",
    "Build_ConveyorBeltMk2": "Conveyor Belt Mk.2",
    "Build_ConveyorBeltMk3": "Conveyor Belt Mk.3",
    "Build_ConveyorBeltMk4": "Conveyor Belt Mk.4",
    "Build_ConveyorBeltMk5": "Conveyor Belt Mk.5",
    "Build_ConveyorBeltMk6": "Conveyor Belt Mk.6",
    "Build_ConveyorLiftMk1": "Conveyor Lift Mk.1",
    "Build_ConveyorLiftMk2": "Conveyor Lift Mk.2",
    "Build_ConveyorLiftMk3": "Conveyor Lift Mk.3",
    "Build_ConveyorLiftMk4": "Conveyor Lift Mk.4",
    "Build_ConveyorLiftMk5": "Conveyor Lift Mk.5",
    "Build_ConveyorLiftMk6": "Conveyor Lift Mk.6",
    "Build_ConveyorAttachmentSplitter": "Splitter",
    "Build_ConveyorAttachmentMerger": "Merger",
    "Build_ConveyorPole": "Conveyor Pole",
    "Build_Pipeline": "Pipeline",
    "Build_PipelineSupport": "Pipeline Support",
    "Build_PipelinePump": "Pipeline Pump Mk.1",
    "Build_PipelinePumpMk2": "Pipeline Pump Mk.2",
    "Build_PipelineJunction_Cross": "Pipeline Junction Cross",
    "Build_Valve": "Valve",
}

STORAGE_PATTERNS = {
    "Build_StorageContainerMk1": "Storage Container",
    "Build_StorageContainerMk2": "Industrial Storage Container",
    "Build_IndustrialTank": "Industrial Fluid Buffer",
    "Build_PipeStorageTank": "Fluid Buffer",
}

POWER_PATTERNS = {
    "Build_PowerLine": "Power Line",
    "Build_PowerPoleMk1": "Power Pole Mk.1",
    "Build_PowerPoleMk2": "Power Pole Mk.2",
    "Build_PowerPoleMk3": "Power Pole Mk.3",
    "Build_PowerStorage": "Power Storage",
    "Build_PowerSwitch": "Power Switch",
    "Build_PriorityPowerSwitch": "Priority Power Switch",
}

TRANSPORT_PATTERNS = {
    "Build_TrainStation": "Train Station",
    "Build_RailroadTrack": "Railway",
    "Build_TrainDockingStation": "Freight Platform",
    "Build_DroneStation": "Drone Port",
    "Build_TruckStation": "Truck Station",
}

VEHICLE_PATTERNS = {
    "BP_Tractor": "Tractor",
    "BP_Truck": "Truck",
    "BP_Explorer": "Explorer",
    "BP_Locomotive": "Locomotive",
    "BP_FreightWagon": "Freight Car",
    "Testa_BP_WB": "Cyber Wagon",
    "BP_Golfcart": "Factory Cart",
    "BP_DroneTransport": "Drone",
}

OTHER_PATTERNS = {
    "Build_SpaceElevator": "Space Elevator",
    "Build_HubTerminal": "HUB",
    "Build_WorkBench": "Craft Bench",
    "Build_Workshop": "Equipment Workshop",
    "Build_RadarTower": "Radar Tower",
    "Build_ResourceSink": "AWESOME Sink",
    "Build_ResourceSinkShop": "AWESOME Shop",
}

def parse_header(r: Reader) -> Dict[str, Any]:
    """Parse the save file header"""
    header = {}
    
    header['headerVersion'] = r.read_uint32()
    header['saveVersion'] = r.read_uint32()
    header['buildVersion'] = r.read_uint32()
    header['saveName'] = r.read_string()
    header['mapName'] = r.read_string()
    
    # Don't include map options in output (too long)
    r.read_string()
    
    header['sessionName'] = r.read_string()
    
    play_seconds = r.read_uint32()
    header['playTimeSeconds'] = play_seconds
    hours = play_seconds // 3600
    mins = (play_seconds % 3600) // 60
    secs = play_seconds % 60
    header['playTimeFormatted'] = f"{hours}h {mins}m {secs}s"
    
    ticks = r.read_uint64()
    try:
        TICKS_PER_SECOND = 10_000_000
        EPOCH_DIFF = 62135596800
        unix_secs = ticks // TICKS_PER_SECOND - EPOCH_DIFF
        header['saveTime'] = datetime.fromtimestamp(unix_secs).isoformat()
    except:
        header['saveTime'] = None
    
    header['visibility'] = r.read_uint8()
    header['editorObjectVersion'] = r.read_uint32()
    
    mod_metadata = r.read_string()
    if mod_metadata:
        try:
            mod_info = json.loads(mod_metadata)
            header['modCount'] = len(mod_info.get('Mods', []))
            header['mods'] = [m.get('Name', m.get('Reference', '?')) for m in mod_info.get('Mods', [])]
        except:
            header['modMetadata'] = mod_metadata[:200] + "..." if len(mod_metadata) > 200 else mod_metadata
    
    header['isModded'] = r.read_uint32() != 0
    header['persistentId'] = r.read_string()
    
    return header

def find_compressed_start(data: bytes) -> int:
    """Find the magic number marking start of compressed data"""
    magic = bytes([0xC1, 0x83, 0x2A, 0x9E])
    return data.find(magic)

def decompress_body(data: bytes, start_offset: int) -> bytes:
    """Decompress all zlib-compressed body chunks"""
    decompressed = bytearray()
    offset = start_offset
    
    chunk_num = 0
    while offset < len(data):
        # Check for magic
        if offset + 4 > len(data):
            break
        magic = struct.unpack('<I', data[offset:offset+4])[0]
        if magic != CHUNK_MAGIC:
            break
        offset += 4
        
        # Archive version
        archive_version = struct.unpack('<I', data[offset:offset+4])[0]
        offset += 4
        
        # Max chunk size
        offset += 8
        
        # Compression algorithm (v2 only)
        if archive_version == 0x22222222:
            offset += 1
        
        # Sizes
        compressed_size = struct.unpack('<Q', data[offset:offset+8])[0]
        offset += 8
        offset += 24  # Skip uncompressed, repeated compressed, repeated uncompressed
        
        # Decompress
        if offset + compressed_size > len(data):
            break
        compressed_data = data[offset:offset+int(compressed_size)]
        offset += int(compressed_size)
        
        try:
            decompressed.extend(zlib.decompress(compressed_data))
            chunk_num += 1
        except Exception as e:
            print(f"Warning: Failed to decompress chunk {chunk_num}: {e}", file=sys.stderr)
            break
    
    return bytes(decompressed)

def count_buildables(body: bytes) -> Dict[str, Any]:
    """Count buildables by searching for patterns in the decompressed body"""
    
    # Find all Build_* references
    buildable_pattern = rb'Build_[A-Za-z0-9_]+'
    matches = re.findall(buildable_pattern, body)
    buildable_counter = Counter(m.decode('utf-8') for m in matches)
    
    # Also find vehicle patterns (BP_*)
    vehicle_pattern = rb'BP_[A-Za-z0-9_]+'
    v_matches = re.findall(vehicle_pattern, body)
    vehicle_counter = Counter(m.decode('utf-8') for m in v_matches)
    
    # Map to display names and categories
    results = {
        'machines': {},
        'extractors': {},
        'generators': {},
        'logistics': {},
        'storage': {},
        'power': {},
        'transport': {},
        'vehicles': {},
        'other': {},
    }
    
    def count_category(patterns, counter, category_name):
        for pattern, display_name in patterns.items():
            # Count both exact and _C suffix versions
            count = counter.get(pattern, 0)
            count += counter.get(f"{pattern}_C", 0)
            # Divide by 2 because each buildable typically has both patterns
            count = count // 2 if count > 0 else 0
            if count > 0:
                results[category_name][display_name] = count
    
    # Count each category from buildables
    count_category(MACHINE_PATTERNS, buildable_counter, 'machines')
    count_category(EXTRACTOR_PATTERNS, buildable_counter, 'extractors')
    count_category(GENERATOR_PATTERNS, buildable_counter, 'generators')
    count_category(LOGISTICS_PATTERNS, buildable_counter, 'logistics')
    count_category(STORAGE_PATTERNS, buildable_counter, 'storage')
    count_category(POWER_PATTERNS, buildable_counter, 'power')
    count_category(TRANSPORT_PATTERNS, buildable_counter, 'transport')
    count_category(OTHER_PATTERNS, buildable_counter, 'other')
    
    # Count vehicles (different pattern - use vehicle counter)
    for pattern, display_name in VEHICLE_PATTERNS.items():
        count = 0
        for key, val in vehicle_counter.items():
            if key.startswith(pattern):
                count += val
        # Vehicles are usually referenced multiple times, estimate based on unique instances
        # This is approximate
        count = count // 4 if count > 0 else 0
        if count > 0:
            results['vehicles'][display_name] = max(1, count)
    
    return results

def parse_save(filename: str) -> Dict[str, Any]:
    """Main entry point - parse a save file and return statistics"""
    with open(filename, 'rb') as f:
        data = f.read()
    
    print(f"Read {len(data)} bytes from {filename}", file=sys.stderr)
    
    # Parse header
    r = Reader(data)
    header = parse_header(r)
    
    print(f"Parsed header: {header['sessionName']} (v{header['saveVersion']}, build {header['buildVersion']})", file=sys.stderr)
    
    # Find and decompress body
    compressed_start = find_compressed_start(data)
    if compressed_start < 0:
        raise ValueError("Could not find compressed data magic number")
    
    print(f"Found compressed data at offset {compressed_start}", file=sys.stderr)
    
    body = decompress_body(data, compressed_start)
    print(f"Decompressed {len(body):,} bytes", file=sys.stderr)
    
    # Count buildables
    counts = count_buildables(body)
    
    # Build final stats
    stats = {
        'header': header,
        'machines': counts['machines'],
        'totalMachines': sum(counts['machines'].values()),
        'extractors': counts['extractors'],
        'totalExtractors': sum(counts['extractors'].values()),
        'generators': counts['generators'],
        'totalGenerators': sum(counts['generators'].values()),
        'logistics': counts['logistics'],
        'storage': counts['storage'],
        'power': counts['power'],
        'transport': counts['transport'],
        'vehicles': counts['vehicles'],
        'totalVehicles': sum(counts['vehicles'].values()),
        'other': counts['other'],
    }
    
    # Calculate totals
    stats['totalBuildings'] = (
        stats['totalMachines'] + 
        stats['totalExtractors'] + 
        stats['totalGenerators'] + 
        sum(counts['logistics'].values()) +
        sum(counts['storage'].values()) +
        sum(counts['power'].values()) +
        sum(counts['transport'].values()) +
        sum(counts['other'].values())
    )
    
    return stats

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <save_file.sav>", file=sys.stderr)
        sys.exit(1)
    
    filename = sys.argv[1]
    try:
        stats = parse_save(filename)
        print(json.dumps(stats, indent=2))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
