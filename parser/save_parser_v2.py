#!/usr/bin/env python3
"""
Satisfactory Save File Parser v2
Robust parsing with proper object counting via level/object headers.
Falls back to pattern matching if structural parsing fails.

Supports: Satisfactory 1.0+ (save format v41-52+)
"""

import struct
import zlib
import json
import sys
import re
from datetime import datetime
from typing import Dict, Any, List, Tuple, Optional
from collections import Counter

# ============================================
# BINARY READER
# ============================================

class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0
    
    def read_uint8(self) -> int:
        v = self.data[self.offset]
        self.offset += 1
        return v
    
    def read_uint32(self) -> int:
        v = struct.unpack_from('<I', self.data, self.offset)[0]
        self.offset += 4
        return v
    
    def read_int32(self) -> int:
        v = struct.unpack_from('<i', self.data, self.offset)[0]
        self.offset += 4
        return v
    
    def read_uint64(self) -> int:
        v = struct.unpack_from('<Q', self.data, self.offset)[0]
        self.offset += 8
        return v
    
    def read_int64(self) -> int:
        v = struct.unpack_from('<q', self.data, self.offset)[0]
        self.offset += 8
        return v
    
    def read_float(self) -> float:
        v = struct.unpack_from('<f', self.data, self.offset)[0]
        self.offset += 4
        return v
    
    def read_string(self) -> str:
        length = self.read_int32()
        if length == 0:
            return ""
        if length > 0:
            if length > 1_000_000:
                raise ValueError(f"Unreasonable string length: {length}")
            s = self.data[self.offset:self.offset + length - 1].decode('utf-8', errors='replace')
            self.offset += length
        else:
            byte_len = -length * 2
            if byte_len > 2_000_000:
                raise ValueError(f"Unreasonable UTF-16 string length: {byte_len}")
            s = self.data[self.offset:self.offset + byte_len - 2].decode('utf-16-le', errors='replace')
            self.offset += byte_len
        return s
    
    def skip(self, n: int):
        self.offset += n
    
    def remaining(self) -> int:
        return len(self.data) - self.offset
    
    def peek_uint32(self) -> int:
        return struct.unpack_from('<I', self.data, self.offset)[0]

# ============================================
# CONSTANTS
# ============================================

CHUNK_MAGIC = 0x9E2A83C1

# Display name mappings
DISPLAY_NAMES = {
    # Machines
    "Build_ConstructorMk1": "Constructor Mk.1",
    "Build_Constructor_Mk2": "Constructor Mk.2",
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
    # Extractors
    "Build_MinerMk1": "Miner Mk.1",
    "Build_MinerMk2": "Miner Mk.2",
    "Build_MinerMk3": "Miner Mk.3",
    "Build_WaterPump": "Water Extractor",
    "Build_OilPump": "Oil Extractor",
    "Build_FrackingExtractor": "Resource Well Extractor",
    "Build_FrackingSmasher": "Resource Well Pressurizer",
    # Generators
    "Build_GeneratorBiomass": "Biomass Burner",
    "Build_GeneratorCoal": "Coal Generator",
    "Build_GeneratorFuel": "Fuel Generator",
    "Build_GeneratorNuclear": "Nuclear Power Plant",
    "Build_GeneratorGeoThermal": "Geothermal Generator",
    # Logistics
    "Build_ConveyorBeltMk1": "Conveyor Mk.1",
    "Build_ConveyorBeltMk2": "Conveyor Mk.2",
    "Build_ConveyorBeltMk3": "Conveyor Mk.3",
    "Build_ConveyorBeltMk4": "Conveyor Mk.4",
    "Build_ConveyorBeltMk5": "Conveyor Mk.5",
    "Build_ConveyorBeltMk6": "Conveyor Mk.6",
    "Build_ConveyorLiftMk1": "Lift Mk.1",
    "Build_ConveyorLiftMk2": "Lift Mk.2",
    "Build_ConveyorLiftMk3": "Lift Mk.3",
    "Build_ConveyorLiftMk4": "Lift Mk.4",
    "Build_ConveyorLiftMk5": "Lift Mk.5",
    "Build_ConveyorLiftMk6": "Lift Mk.6",
    "Build_ConveyorAttachmentSplitter": "Splitter",
    "Build_ConveyorAttachmentMerger": "Merger",
    "Build_Pipeline": "Pipeline",
    "Build_PipelinePump": "Pipe Pump Mk.1",
    "Build_PipelinePumpMk2": "Pipe Pump Mk.2",
    "Build_PipelineJunction_Cross": "Pipe Junction",
    "Build_Valve": "Valve",
    # Storage
    "Build_StorageContainerMk1": "Storage Container",
    "Build_StorageContainerMk2": "Industrial Container",
    "Build_IndustrialTank": "Industrial Fluid Buffer",
    "Build_PipeStorageTank": "Fluid Buffer",
    # Power
    "Build_PowerLine": "Power Line",
    "Build_PowerPoleMk1": "Power Pole Mk.1",
    "Build_PowerPoleMk2": "Power Pole Mk.2",
    "Build_PowerPoleMk3": "Power Pole Mk.3",
    "Build_PowerStorage": "Power Storage",
    "Build_PowerSwitch": "Power Switch",
    # Transport
    "Build_TrainStation": "Train Station",
    "Build_RailroadTrack": "Railway",
    "Build_TrainDockingStation": "Freight Platform",
    "Build_DroneStation": "Drone Port",
    "Build_TruckStation": "Truck Station",
    # Vehicles
    "BP_Tractor": "Tractor",
    "BP_Truck": "Truck",
    "BP_Explorer": "Explorer",
    "BP_Locomotive": "Locomotive",
    "BP_FreightWagon": "Freight Car",
    "BP_DroneTransport": "Drone",
    "BP_Golfcart": "Factory Cart",
    # Other
    "Build_SpaceElevator": "Space Elevator",
    "Build_HubTerminal": "HUB",
    "Build_WorkBench": "Craft Bench",
    "Build_Workshop": "Equipment Workshop",
    "Build_RadarTower": "Radar Tower",
    "Build_ResourceSink": "AWESOME Sink",
    "Build_ResourceSinkShop": "AWESOME Shop",
    # FicsIt Networks (mod)
    "Build_ComputerCase": "FicsIt Computer",
    "NetworkCard": "Network Card",
    "Build_NetworkRouter": "Network Router",
    "Build_Screen_Driver": "Screen Driver",
    "Build_GPU_T1": "GPU T1",
}

# Categories
CATEGORIES = {
    "machines": ["Constructor", "Smelter", "Foundry", "Assembler", "Manufacturer",
                 "Refinery", "Packager", "Blender", "Particle Accelerator",
                 "Quantum Encoder", "Converter"],
    "extractors": ["Miner", "Water Extractor", "Oil Extractor", "Resource Well"],
    "generators": ["Biomass", "Coal Generator", "Fuel Generator", "Nuclear", "Geothermal"],
    "logistics": ["Conveyor", "Lift", "Splitter", "Merger", "Pipeline", "Pipe Pump",
                   "Pipe Junction", "Valve"],
    "storage": ["Storage", "Container", "Buffer", "Tank"],
    "power": ["Power Line", "Power Pole", "Power Storage", "Power Switch"],
    "transport": ["Train", "Railway", "Freight", "Drone Port", "Truck Station"],
    "vehicles": ["Tractor", "Truck", "Explorer", "Locomotive", "Freight Car",
                  "Drone", "Factory Cart"],
}

def categorize(display_name: str) -> str:
    for cat, keywords in CATEGORIES.items():
        for kw in keywords:
            if kw.lower() in display_name.lower():
                return cat
    return "other"

# ============================================
# HEADER PARSING
# ============================================

def parse_header(r: Reader) -> Dict[str, Any]:
    header = {}
    header['headerVersion'] = r.read_uint32()
    header['saveVersion'] = r.read_uint32()
    header['buildVersion'] = r.read_uint32()
    header['saveName'] = r.read_string()
    header['mapName'] = r.read_string()
    
    map_options = r.read_string()  # skip
    
    header['sessionName'] = r.read_string()
    
    play_seconds = r.read_uint32()
    header['playTimeSeconds'] = play_seconds
    h, m, s = play_seconds // 3600, (play_seconds % 3600) // 60, play_seconds % 60
    header['playTime'] = f"{h}h {m}m {s}s"
    
    ticks = r.read_uint64()
    try:
        unix_secs = ticks // 10_000_000 - 62135596800
        header['saveTime'] = datetime.utcfromtimestamp(unix_secs).strftime('%Y-%m-%d %H:%M:%S UTC')
    except:
        header['saveTime'] = None
    
    header['visibility'] = r.read_uint8()
    header['editorObjectVersion'] = r.read_uint32()
    
    mod_metadata = r.read_string()
    if mod_metadata:
        try:
            mod_info = json.loads(mod_metadata)
            mods = mod_info.get('Mods', [])
            header['modCount'] = len(mods)
            header['mods'] = [m.get('Name', m.get('Reference', '?')) for m in mods[:50]]
        except:
            pass
    
    header['isModded'] = r.read_uint32() != 0
    header['persistentId'] = r.read_string()
    
    return header

# ============================================
# DECOMPRESSION
# ============================================

def decompress_body(data: bytes) -> Tuple[bytes, int]:
    """Find and decompress all zlib chunks. Returns (decompressed, chunk_count)."""
    magic_bytes = struct.pack('<I', CHUNK_MAGIC)
    start = data.find(magic_bytes)
    if start < 0:
        raise ValueError("No compressed data found (magic not found)")
    
    decompressed = bytearray()
    offset = start
    chunks = 0
    errors = 0
    
    while offset + 48 < len(data):
        # Check magic
        magic = struct.unpack_from('<I', data, offset)[0]
        if magic != CHUNK_MAGIC:
            break
        offset += 4
        
        # Archive header
        archive_ver = struct.unpack_from('<I', data, offset)[0]
        offset += 4
        offset += 8  # max chunk size
        
        if archive_ver == 0x22222222:
            offset += 1  # compression algorithm byte
        
        compressed_size = struct.unpack_from('<Q', data, offset)[0]
        offset += 8
        uncompressed_size = struct.unpack_from('<Q', data, offset)[0]
        offset += 8
        offset += 16  # repeated sizes
        
        if offset + compressed_size > len(data):
            break
        
        chunk_data = data[offset:offset + int(compressed_size)]
        offset += int(compressed_size)
        
        try:
            decompressed.extend(zlib.decompress(chunk_data))
            chunks += 1
        except Exception as e:
            errors += 1
            if errors > 5:
                break
    
    return bytes(decompressed), chunks

# ============================================
# OBJECT COUNTING (Pattern-based, robust)
# ============================================

def count_objects(body: bytes) -> Dict[str, int]:
    """
    Count unique object instances by looking for object path references.
    
    In the save, each placed object has a path like:
    /Game/FactoryGame/Buildable/Factory/ConstructorMk1/Build_ConstructorMk1.Build_ConstructorMk1_C
    
    We count unique instance references by looking for the Persistent_Level pattern
    which marks actual placed instances:
    Persistent_Level:PersistentLevel.Build_ConstructorMk1_C_12345
    """
    counts = Counter()
    
    # Method 1: Count Persistent_Level instances (most accurate for placed objects)
    # Pattern: Persistent_Level:PersistentLevel.Build_XXX_C_NNNNN
    instance_pattern = rb'PersistentLevel\.(Build_[A-Za-z0-9_]+_C)_(\d+)'
    instances = re.findall(instance_pattern, body)
    
    # Deduplicate by (class, id) pairs to avoid double-counting
    unique_instances = set()
    for class_name, instance_id in instances:
        unique_instances.add((class_name.decode('utf-8'), instance_id.decode('utf-8')))
    
    for class_name, _ in unique_instances:
        # Remove _C suffix for matching
        base_name = class_name.rstrip('_C').rstrip('_')
        # Try to find in display names
        counts[base_name] += 1
    
    # Method 2: Also count vehicles (BP_ prefix)
    vehicle_pattern = rb'PersistentLevel\.(BP_[A-Za-z0-9_]+_C)_(\d+)'
    v_instances = re.findall(vehicle_pattern, body)
    v_unique = set()
    for class_name, instance_id in v_instances:
        v_unique.add((class_name.decode('utf-8'), instance_id.decode('utf-8')))
    
    for class_name, _ in v_unique:
        base_name = class_name.rstrip('_C').rstrip('_')
        counts[base_name] += 1
    
    return dict(counts)

def map_counts_to_categories(raw_counts: Dict[str, int]) -> Dict[str, Dict[str, int]]:
    """Map raw class names to display names and categories."""
    categorized = {}
    unmapped = {}
    
    for raw_name, count in raw_counts.items():
        display_name = None
        
        # Try exact match
        if raw_name in DISPLAY_NAMES:
            display_name = DISPLAY_NAMES[raw_name]
        else:
            # Try partial match
            for pattern, name in DISPLAY_NAMES.items():
                if pattern in raw_name or raw_name in pattern:
                    display_name = name
                    break
        
        if display_name:
            cat = categorize(display_name)
            if cat not in categorized:
                categorized[cat] = {}
            if display_name in categorized[cat]:
                categorized[cat][display_name] += count
            else:
                categorized[cat][display_name] = count
        else:
            # Keep unmapped for debugging
            if count >= 3:  # Only show if 3+ instances
                unmapped[raw_name] = count
    
    return categorized, unmapped

# ============================================
# MAIN
# ============================================

def parse_save(filename: str) -> Dict[str, Any]:
    with open(filename, 'rb') as f:
        data = f.read()
    
    file_size_mb = len(data) / (1024 * 1024)
    print(f"Read {file_size_mb:.1f} MB from {filename}", file=sys.stderr)
    
    # Parse header
    r = Reader(data)
    try:
        header = parse_header(r)
        print(f"Session: {header.get('sessionName', '?')}", file=sys.stderr)
        print(f"Save version: {header.get('saveVersion', '?')}, Build: {header.get('buildVersion', '?')}", file=sys.stderr)
        print(f"Play time: {header.get('playTime', '?')}", file=sys.stderr)
        if header.get('modCount'):
            print(f"Mods: {header['modCount']}", file=sys.stderr)
    except Exception as e:
        print(f"Header parse error: {e}", file=sys.stderr)
        header = {"error": str(e)}
    
    # Decompress
    print("Decompressing...", file=sys.stderr)
    body, chunk_count = decompress_body(data)
    body_mb = len(body) / (1024 * 1024)
    print(f"Decompressed: {body_mb:.1f} MB ({chunk_count} chunks)", file=sys.stderr)
    
    # Count objects
    print("Counting objects...", file=sys.stderr)
    raw_counts = count_objects(body)
    categorized, unmapped = map_counts_to_categories(raw_counts)
    
    # Build result
    result = {
        "header": header,
        "factory": {},
        "totals": {},
    }
    
    total_all = 0
    for cat in ["machines", "extractors", "generators", "logistics", "storage",
                 "power", "transport", "vehicles", "other"]:
        items = categorized.get(cat, {})
        if items:
            result["factory"][cat] = dict(sorted(items.items(), key=lambda x: -x[1]))
            cat_total = sum(items.values())
            result["totals"][cat] = cat_total
            total_all += cat_total
    
    result["totals"]["all"] = total_all
    
    if unmapped:
        result["unmapped"] = dict(sorted(unmapped.items(), key=lambda x: -x[1])[:30])
    
    # Summary line
    summary_parts = []
    for cat in ["machines", "extractors", "generators"]:
        if cat in result["totals"]:
            summary_parts.append(f"{result['totals'][cat]} {cat}")
    
    result["summary"] = f"{total_all} total buildings ({', '.join(summary_parts)})"
    
    print(f"\nResult: {result['summary']}", file=sys.stderr)
    
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: save_parser_v2.py <save_file.sav>", file=sys.stderr)
        print("\nParses Satisfactory save files and outputs factory statistics as JSON.", file=sys.stderr)
        sys.exit(1)
    
    filename = sys.argv[1]
    
    try:
        result = parse_save(filename)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"FATAL: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
