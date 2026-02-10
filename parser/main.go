package main

import (
	"bytes"
	"compress/zlib"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
	"time"
)

// SaveHeader contains metadata about the save file
type SaveHeader struct {
	HeaderVersion     uint32    `json:"headerVersion"`
	SaveVersion       uint32    `json:"saveVersion"`
	BuildVersion      uint32    `json:"buildVersion"`
	SaveName          string    `json:"saveName"`
	MapName           string    `json:"mapName"`
	SessionName       string    `json:"sessionName"`
	PlayTimeSeconds   uint32    `json:"playTimeSeconds"`
	PlayTimeFormatted string    `json:"playTimeFormatted"`
	SaveTime          time.Time `json:"saveTime"`
	Visibility        uint8     `json:"visibility"`
	EditorObjVersion  uint32    `json:"editorObjectVersion"`
	ModCount          int       `json:"modCount,omitempty"`
	IsModded          bool      `json:"isModded"`
	PersistentID      string    `json:"persistentId"`
}

// FactoryStats contains aggregated statistics
type FactoryStats struct {
	Header          SaveHeader     `json:"header"`
	Machines        map[string]int `json:"machines"`
	TotalMachines   int            `json:"totalMachines"`
	Extractors      map[string]int `json:"extractors"`
	TotalExtractors int            `json:"totalExtractors"`
	Generators      map[string]int `json:"generators"`
	TotalGenerators int            `json:"totalGenerators"`
	Logistics       map[string]int `json:"logistics"`
	Storage         map[string]int `json:"storage"`
	Power           map[string]int `json:"power"`
	Transport       map[string]int `json:"transport"`
	Vehicles        map[string]int `json:"vehicles"`
	TotalVehicles   int            `json:"totalVehicles"`
	Other           map[string]int `json:"other"`
	TotalBuildings  int            `json:"totalBuildings"`
}

// Reader wraps byte slice with position tracking
type Reader struct {
	data   []byte
	offset int
}

func NewReader(data []byte) *Reader {
	return &Reader{data: data, offset: 0}
}

func (r *Reader) ReadUint8() (uint8, error) {
	if r.offset+1 > len(r.data) {
		return 0, fmt.Errorf("EOF reading uint8 at offset %d", r.offset)
	}
	v := r.data[r.offset]
	r.offset++
	return v, nil
}

func (r *Reader) ReadUint32() (uint32, error) {
	if r.offset+4 > len(r.data) {
		return 0, fmt.Errorf("EOF reading uint32 at offset %d", r.offset)
	}
	v := binary.LittleEndian.Uint32(r.data[r.offset : r.offset+4])
	r.offset += 4
	return v, nil
}

func (r *Reader) ReadUint64() (uint64, error) {
	if r.offset+8 > len(r.data) {
		return 0, fmt.Errorf("EOF reading uint64 at offset %d", r.offset)
	}
	v := binary.LittleEndian.Uint64(r.data[r.offset : r.offset+8])
	r.offset += 8
	return v, nil
}

func (r *Reader) ReadInt32() (int32, error) {
	if r.offset+4 > len(r.data) {
		return 0, fmt.Errorf("EOF reading int32 at offset %d", r.offset)
	}
	v := int32(binary.LittleEndian.Uint32(r.data[r.offset : r.offset+4]))
	r.offset += 4
	return v, nil
}

func (r *Reader) ReadString() (string, error) {
	length, err := r.ReadInt32()
	if err != nil {
		return "", err
	}
	if length == 0 {
		return "", nil
	}

	var strLen int
	var isUtf16 bool
	if length > 0 {
		strLen = int(length)
		isUtf16 = false
	} else {
		strLen = int(-length) * 2
		isUtf16 = true
	}

	if r.offset+strLen > len(r.data) {
		return "", fmt.Errorf("string too long: %d at offset %d", strLen, r.offset)
	}

	var s string
	if isUtf16 {
		runes := make([]rune, 0, strLen/2)
		for i := 0; i < strLen-2; i += 2 {
			r := rune(binary.LittleEndian.Uint16(r.data[r.offset+i : r.offset+i+2]))
			runes = append(runes, r)
		}
		s = string(runes)
	} else {
		s = string(r.data[r.offset : r.offset+strLen-1])
	}
	r.offset += strLen
	return s, nil
}

func (r *Reader) Skip(n int) {
	r.offset += n
}

func (r *Reader) Remaining() int {
	return len(r.data) - r.offset
}

const ChunkMagic uint32 = 0x9E2A83C1

// Pattern maps for buildables
var machinePatterns = map[string]string{
	"Build_ConstructorMk1":  "Constructor",
	"Build_SmelterMk1":      "Smelter",
	"Build_FoundryMk1":      "Foundry",
	"Build_AssemblerMk1":    "Assembler",
	"Build_ManufacturerMk1": "Manufacturer",
	"Build_OilRefinery":     "Refinery",
	"Build_Packager":        "Packager",
	"Build_Blender":         "Blender",
	"Build_HadronCollider":  "Particle Accelerator",
	"Build_QuantumEncoder":  "Quantum Encoder",
	"Build_Converter":       "Converter",
}

var extractorPatterns = map[string]string{
	"Build_MinerMk1":           "Miner Mk.1",
	"Build_MinerMk2":           "Miner Mk.2",
	"Build_MinerMk3":           "Miner Mk.3",
	"Build_WaterPump":          "Water Extractor",
	"Build_OilPump":            "Oil Extractor",
	"Build_FrackingExtractor":  "Resource Well Extractor",
	"Build_FrackingSmasher":    "Resource Well Pressurizer",
}

var generatorPatterns = map[string]string{
	"Build_GeneratorBiomass":    "Biomass Burner",
	"Build_GeneratorCoal":       "Coal Generator",
	"Build_GeneratorFuel":       "Fuel Generator",
	"Build_GeneratorNuclear":    "Nuclear Power Plant",
	"Build_GeneratorGeoThermal": "Geothermal Generator",
}

var logisticsPatterns = map[string]string{
	"Build_ConveyorBeltMk1":            "Conveyor Belt Mk.1",
	"Build_ConveyorBeltMk2":            "Conveyor Belt Mk.2",
	"Build_ConveyorBeltMk3":            "Conveyor Belt Mk.3",
	"Build_ConveyorBeltMk4":            "Conveyor Belt Mk.4",
	"Build_ConveyorBeltMk5":            "Conveyor Belt Mk.5",
	"Build_ConveyorBeltMk6":            "Conveyor Belt Mk.6",
	"Build_ConveyorLiftMk1":            "Conveyor Lift Mk.1",
	"Build_ConveyorLiftMk2":            "Conveyor Lift Mk.2",
	"Build_ConveyorLiftMk3":            "Conveyor Lift Mk.3",
	"Build_ConveyorLiftMk4":            "Conveyor Lift Mk.4",
	"Build_ConveyorLiftMk5":            "Conveyor Lift Mk.5",
	"Build_ConveyorLiftMk6":            "Conveyor Lift Mk.6",
	"Build_ConveyorAttachmentSplitter": "Splitter",
	"Build_ConveyorAttachmentMerger":   "Merger",
	"Build_ConveyorPole":               "Conveyor Pole",
	"Build_Pipeline":                   "Pipeline",
	"Build_PipelineSupport":            "Pipeline Support",
	"Build_PipelinePump":               "Pipeline Pump Mk.1",
	"Build_PipelinePumpMk2":            "Pipeline Pump Mk.2",
	"Build_PipelineJunction_Cross":     "Pipeline Junction Cross",
	"Build_Valve":                      "Valve",
}

var storagePatterns = map[string]string{
	"Build_StorageContainerMk1": "Storage Container",
	"Build_StorageContainerMk2": "Industrial Storage Container",
	"Build_IndustrialTank":      "Industrial Fluid Buffer",
	"Build_PipeStorageTank":     "Fluid Buffer",
}

var powerPatterns = map[string]string{
	"Build_PowerLine":           "Power Line",
	"Build_PowerPoleMk1":        "Power Pole Mk.1",
	"Build_PowerPoleMk2":        "Power Pole Mk.2",
	"Build_PowerPoleMk3":        "Power Pole Mk.3",
	"Build_PowerStorage":        "Power Storage",
	"Build_PowerSwitch":         "Power Switch",
	"Build_PriorityPowerSwitch": "Priority Power Switch",
}

var transportPatterns = map[string]string{
	"Build_TrainStation":        "Train Station",
	"Build_RailroadTrack":       "Railway",
	"Build_TrainDockingStation": "Freight Platform",
	"Build_DroneStation":        "Drone Port",
	"Build_TruckStation":        "Truck Station",
}

var vehiclePatterns = map[string]string{
	"BP_Tractor":        "Tractor",
	"BP_Truck":          "Truck",
	"BP_Explorer":       "Explorer",
	"BP_Locomotive":     "Locomotive",
	"BP_FreightWagon":   "Freight Car",
	"Testa_BP_WB":       "Cyber Wagon",
	"BP_Golfcart":       "Factory Cart",
	"BP_DroneTransport": "Drone",
}

var otherPatterns = map[string]string{
	"Build_SpaceElevator":   "Space Elevator",
	"Build_HubTerminal":     "HUB",
	"Build_WorkBench":       "Craft Bench",
	"Build_Workshop":        "Equipment Workshop",
	"Build_RadarTower":      "Radar Tower",
	"Build_ResourceSink":    "AWESOME Sink",
	"Build_ResourceSinkShop": "AWESOME Shop",
}

func parseHeader(r *Reader) (*SaveHeader, error) {
	header := &SaveHeader{}
	var err error

	header.HeaderVersion, err = r.ReadUint32()
	if err != nil {
		return nil, err
	}

	header.SaveVersion, err = r.ReadUint32()
	if err != nil {
		return nil, err
	}

	header.BuildVersion, err = r.ReadUint32()
	if err != nil {
		return nil, err
	}

	header.SaveName, err = r.ReadString()
	if err != nil {
		return nil, err
	}

	header.MapName, err = r.ReadString()
	if err != nil {
		return nil, err
	}

	// Skip map options (too long)
	_, err = r.ReadString()
	if err != nil {
		return nil, err
	}

	header.SessionName, err = r.ReadString()
	if err != nil {
		return nil, err
	}

	header.PlayTimeSeconds, err = r.ReadUint32()
	if err != nil {
		return nil, err
	}
	hours := header.PlayTimeSeconds / 3600
	mins := (header.PlayTimeSeconds % 3600) / 60
	secs := header.PlayTimeSeconds % 60
	header.PlayTimeFormatted = fmt.Sprintf("%dh %dm %ds", hours, mins, secs)

	ticks, err := r.ReadUint64()
	if err != nil {
		return nil, err
	}
	const ticksPerSecond = 10000000
	const epochDiff = 62135596800
	unixSecs := int64(ticks/ticksPerSecond) - epochDiff
	header.SaveTime = time.Unix(unixSecs, int64(ticks%ticksPerSecond)*100)

	header.Visibility, err = r.ReadUint8()
	if err != nil {
		return nil, err
	}

	header.EditorObjVersion, err = r.ReadUint32()
	if err != nil {
		return nil, err
	}

	modMetadata, err := r.ReadString()
	if err != nil {
		return nil, err
	}
	if modMetadata != "" {
		// Count mods
		var modInfo struct {
			Mods []struct {
				Name string `json:"Name"`
			} `json:"Mods"`
		}
		if json.Unmarshal([]byte(modMetadata), &modInfo) == nil {
			header.ModCount = len(modInfo.Mods)
		}
	}

	isModded, err := r.ReadUint32()
	if err != nil {
		return nil, err
	}
	header.IsModded = isModded != 0

	header.PersistentID, err = r.ReadString()
	if err != nil {
		return nil, err
	}

	return header, nil
}

func findCompressedStart(data []byte) int {
	magic := []byte{0xC1, 0x83, 0x2A, 0x9E}
	return bytes.Index(data, magic)
}

func decompressBody(data []byte, startOffset int) ([]byte, error) {
	var decompressed bytes.Buffer
	offset := startOffset

	chunkNum := 0
	for offset < len(data) {
		if offset+4 > len(data) {
			break
		}
		magic := binary.LittleEndian.Uint32(data[offset : offset+4])
		if magic != ChunkMagic {
			break
		}
		offset += 4

		archiveVersion := binary.LittleEndian.Uint32(data[offset : offset+4])
		offset += 4
		offset += 8 // max chunk size

		if archiveVersion == 0x22222222 {
			offset++ // compression algo
		}

		compressedSize := binary.LittleEndian.Uint64(data[offset : offset+8])
		offset += 8
		offset += 24 // skip repeated sizes

		if offset+int(compressedSize) > len(data) {
			break
		}
		compressedData := data[offset : offset+int(compressedSize)]
		offset += int(compressedSize)

		zlibReader, err := zlib.NewReader(bytes.NewReader(compressedData))
		if err != nil {
			break
		}
		_, err = io.Copy(&decompressed, zlibReader)
		zlibReader.Close()
		if err != nil {
			break
		}
		chunkNum++
	}

	return decompressed.Bytes(), nil
}

func countBuildables(body []byte) *FactoryStats {
	stats := &FactoryStats{
		Machines:   make(map[string]int),
		Extractors: make(map[string]int),
		Generators: make(map[string]int),
		Logistics:  make(map[string]int),
		Storage:    make(map[string]int),
		Power:      make(map[string]int),
		Transport:  make(map[string]int),
		Vehicles:   make(map[string]int),
		Other:      make(map[string]int),
	}

	bodyStr := string(body)

	// Find all Build_* references
	buildableRe := regexp.MustCompile(`Build_[A-Za-z0-9_]+`)
	matches := buildableRe.FindAllString(bodyStr, -1)
	buildableCounts := make(map[string]int)
	for _, m := range matches {
		buildableCounts[m]++
	}

	// Find vehicle patterns
	vehicleRe := regexp.MustCompile(`BP_[A-Za-z0-9_]+`)
	vMatches := vehicleRe.FindAllString(bodyStr, -1)
	vehicleCounts := make(map[string]int)
	for _, m := range vMatches {
		vehicleCounts[m]++
	}

	countCategory := func(patterns map[string]string, counts map[string]int, target map[string]int) {
		for pattern, displayName := range patterns {
			count := counts[pattern]
			count += counts[pattern+"_C"]
			count = count / 2
			if count > 0 {
				target[displayName] = count
			}
		}
	}

	countCategory(machinePatterns, buildableCounts, stats.Machines)
	countCategory(extractorPatterns, buildableCounts, stats.Extractors)
	countCategory(generatorPatterns, buildableCounts, stats.Generators)
	countCategory(logisticsPatterns, buildableCounts, stats.Logistics)
	countCategory(storagePatterns, buildableCounts, stats.Storage)
	countCategory(powerPatterns, buildableCounts, stats.Power)
	countCategory(transportPatterns, buildableCounts, stats.Transport)
	countCategory(otherPatterns, buildableCounts, stats.Other)

	// Count vehicles
	for pattern, displayName := range vehiclePatterns {
		count := 0
		for key, val := range vehicleCounts {
			if strings.HasPrefix(key, pattern) {
				count += val
			}
		}
		count = count / 4
		if count > 0 {
			stats.Vehicles[displayName] = count
			if count < 1 {
				stats.Vehicles[displayName] = 1
			}
		}
	}

	// Calculate totals
	for _, v := range stats.Machines {
		stats.TotalMachines += v
	}
	for _, v := range stats.Extractors {
		stats.TotalExtractors += v
	}
	for _, v := range stats.Generators {
		stats.TotalGenerators += v
	}
	for _, v := range stats.Vehicles {
		stats.TotalVehicles += v
	}

	stats.TotalBuildings = stats.TotalMachines + stats.TotalExtractors + stats.TotalGenerators
	for _, v := range stats.Logistics {
		stats.TotalBuildings += v
	}
	for _, v := range stats.Storage {
		stats.TotalBuildings += v
	}
	for _, v := range stats.Power {
		stats.TotalBuildings += v
	}
	for _, v := range stats.Transport {
		stats.TotalBuildings += v
	}
	for _, v := range stats.Other {
		stats.TotalBuildings += v
	}

	return stats
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <save_file.sav>\n", os.Args[0])
		os.Exit(1)
	}

	filename := os.Args[1]
	data, err := os.ReadFile(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "Read %d bytes from %s\n", len(data), filename)

	r := NewReader(data)
	header, err := parseHeader(r)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing header: %v\n", err)
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "Parsed header: %s (v%d, build %d)\n", header.SessionName, header.SaveVersion, header.BuildVersion)

	compressedStart := findCompressedStart(data)
	if compressedStart < 0 {
		fmt.Fprintf(os.Stderr, "Could not find compressed data\n")
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "Found compressed data at offset %d\n", compressedStart)

	body, err := decompressBody(data, compressedStart)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error decompressing: %v\n", err)
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "Decompressed %d bytes\n", len(body))

	stats := countBuildables(body)
	stats.Header = *header

	output, err := json.MarshalIndent(stats, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(string(output))
}
