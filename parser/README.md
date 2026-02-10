# Satisfactory Save Parser

A parser for Satisfactory save files (.sav) that extracts factory statistics and outputs JSON.

## Features

- Parses Satisfactory 1.0+ save files (format v46-52, header v13-14)
- Extracts save metadata (session name, play time, save time, mod count)
- Counts all buildables by category:
  - Production machines (constructors, smelters, assemblers, etc.)
  - Resource extractors (miners, water pumps, etc.)
  - Power generators
  - Logistics (conveyors, pipes, splitters, mergers)
  - Storage containers
  - Power infrastructure
  - Transport (train stations, truck stations, drone ports)
  - Vehicles
- Outputs clean JSON for integration with other tools

## Implementations

### Python (recommended for quick usage)

```bash
python3 satisfactory_parser.py <save_file.sav>
```

### Go (for performance/embedding)

```bash
go build -o satisfactory-parser .
./satisfactory-parser <save_file.sav>
```

## Example Output

```json
{
  "header": {
    "sessionName": "My Factory",
    "playTimeFormatted": "22h 48m 15s",
    "saveVersion": 52,
    "buildVersion": 463028,
    "isModded": true,
    "modCount": 131
  },
  "machines": {
    "Constructor": 38,
    "Assembler": 22,
    "Smelter": 15,
    "Foundry": 5
  },
  "totalMachines": 80,
  "extractors": {
    "Miner Mk.2": 10,
    "Water Extractor": 9,
    "Miner Mk.1": 4
  },
  "generators": {
    "Coal Generator": 17
  },
  "logistics": {
    "Conveyor Belt Mk.1": 296,
    "Conveyor Belt Mk.3": 279,
    "Splitter": 87,
    "Merger": 65
  },
  "totalBuildings": 1495
}
```

## How It Works

1. **Header Parsing**: Reads the uncompressed save header containing metadata
2. **Decompression**: Locates the zlib-compressed body chunks and decompresses them
3. **Object Counting**: Scans the decompressed data for buildable type references
4. **Aggregation**: Groups counts by category and outputs JSON

## Supported Buildables

### Machines
- Constructor, Smelter, Foundry, Assembler, Manufacturer
- Refinery, Packager, Blender, Particle Accelerator
- Quantum Encoder, Converter

### Extractors
- Miner Mk.1/2/3, Water Extractor, Oil Extractor
- Resource Well Extractor, Resource Well Pressurizer

### Generators
- Biomass Burner, Coal Generator, Fuel Generator
- Nuclear Power Plant, Geothermal Generator

### Logistics
- Conveyor Belts Mk.1-6, Conveyor Lifts Mk.1-6
- Splitters, Mergers, Conveyor Poles
- Pipelines, Pipeline Supports, Pipeline Pumps
- Pipeline Junctions, Valves

### And more...

## License

MIT License
