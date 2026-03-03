# Litholog Enhancement Spec

## Vision

Litholog becomes the **only open-source tool** that can ingest an AGS4 `.ags` file and instantly render professional SVG borehole strip logs with enhanced BS 5930 parsing overlaid — all from a single binary, in under a second.

```
litholog inspect site_data.ags                    # SVG logs to stdout
litholog inspect site_data.ags --output logs/     # One SVG per borehole
litholog inspect site_data.ags --web              # Open in browser with interactive viewer
```

---

## Phase 1: Parser Enhancements (Foundation)

These extend the BS 5930 parser to handle real-world descriptions found in AGS files.

### 1.1 Geological Formation Parsing

BS 5930 §33.5 requires every stratum description to end with the geological formation in parentheses.

**Input**: `"Firm closely fissured yellowish brown CLAY (LONDON CLAY FORMATION)"`
**Output**: `geological_formation = "LONDON CLAY FORMATION"`

**Implementation**:
- Add `geological_formation: ?[]const u8` to `SoilDescription`
- In `Lexer.tokenize()`, detect `(...)` suffix and extract as a `TokenType.geological_formation` token
- Handle nested parens gracefully: `"(GLACIAL TILL - BOULDER CLAY)"`
- Strip trailing formation before parsing the rest of the description

### 1.2 Soil Discontinuities / Structure

BS 5930 §33.3 requires mass characteristics for fine soils. Real logs include:
- `"Very stiff fissured brown CLAY"`
- `"Stiff closely fissured and sheared dark grey CLAY"`
- `"Firm intact grey CLAY"`

**Implementation**:
- Add `SoilStructure` enum:
  ```
  intact, fissured, closely_fissured, very_closely_fissured,
  sheared, laminated, interbedded, homogeneous
  ```
- Add `soil_structure: ?SoilStructure` to `SoilDescription`
- Add `fissured`, `sheared`, `intact`, `laminated`, `interbedded`, `homogeneous` to lexer as `TokenType.soil_structure`

### 1.3 Compound Primary Types ("SAND and GRAVEL")

BS 5930 supports dual primary constituents connected by "and":
- `"Dense brown SAND and GRAVEL"`
- `"Stiff grey CLAY and SILT"`

**Implementation**:
- Add `secondary_primary_soil_type: ?SoilType` to `SoilDescription`
- In parser, when encountering `"and"` between two soil types, treat as compound primary
- Output both in JSON: `"primary_soil_type": "SAND", "secondary_primary_soil_type": "GRAVEL"`
- SVG renderer uses combined hatch pattern

### 1.4 Tertiary "with" Clause Parsing

BS 5930 uses "with occasional/frequent/some/rare" for tertiary inclusions:
- `"with occasional cobbles"`
- `"with pockets of peat"`
- `"with shell fragments"`
- `"with calcite veins"`

**Implementation**:
- Add `TertiaryInclusion` struct: `{ frequency: []const u8, material: []const u8 }`
- Add `tertiary_inclusions: []TertiaryInclusion` to `SoilDescription`
- Frequencies per BS 5930: `rare, occasional, some, frequent, abundant`
- Lexer detects `"with"` keyword and captures the following frequency + material

### 1.5 Particle Shape (Coarse Soils)

EN ISO 14688-1 §6.1.2 / BS 5930 requires shape for coarse soils:
- `"Dense brown subrounded fine to coarse GRAVEL"`

**Implementation**:
- Add `ParticleShape` enum: `angular, subangular, subrounded, rounded, well_rounded`
- Add `particle_shape: ?ParticleShape` to `SoilDescription`
- Add to lexer classification

### 1.6 Cobbles & Boulders

EN ISO 14688-1 Table 1 defines very coarse soil fractions. Real logs include:
- `"COBBLES and BOULDERS"`
- `"with occasional cobbles"`

**Implementation**:
- Add `cobbles` and `boulders` to `SoilType` enum
- Handle as primary or tertiary depending on context

### 1.7 Density Ranges

Mirror the existing `Consistency` range pattern for density:
- `"Medium dense to dense SAND"`
- `"Loose to medium dense GRAVEL"`

**Implementation**:
- Add `loose_to_medium_dense`, `medium_dense_to_dense` variants to `Density` enum
- Add corresponding strength DB entries (SPT ranges spanning both categories)

### 1.8 Enhanced Colour System

BS 5930 uses compound colours with `-ish` modifiers and patterns:

**Implementation**:
- Replace enum with a `Colour` struct:
  ```
  Colour {
      primary: ColourName,          // brown, grey, etc.
      modifier: ?ColourName,        // yellowish, reddish, etc.
      pattern: ?ColourPattern,      // mottled, speckled, banded
      secondary_colour: ?ColourName // for mottled/speckled: "mottled brown and grey"
  }
  ```
- `ColourName` enum: `grey, brown, red, yellow, orange, black, white, green, blue, pink, purple, tan, buff, cream`
- `ColourPattern` enum: `mottled, speckled, banded, streaked`
- Parse compound forms: `"brownish grey"` → modifier=brownish, primary=grey
- Keep `"grey"` as valid (don't normalize to "gray" — this is a British standard)

### 1.9 "Made Ground" / Anthropogenic Soils

Real UK logs commonly start with:
- `"MADE GROUND: firm dark brown slightly sandy CLAY with fragments of brick"`
- `"TOPSOIL"`

**Implementation**:
- Add `is_made_ground: bool` and `made_ground_label: ?[]const u8` to `SoilDescription`
- Detect `"MADE GROUND"`, `"FILL"`, `"TOPSOIL"` prefixes
- Parse the remainder normally

---

## Phase 2: AGS4 File Support

### 2.1 AGS4 Parser

The AGS4 format is a structured CSV-like text format with specific rules.

**File structure** (from AGS4 Edition 4.1.1):
```
"GROUP","PROJ"
"HEADING","PROJ_ID","PROJ_NAME","PROJ_LOC","PROJ_CLNT"
"UNIT","","","",""
"TYPE","ID","X","X","X"
"DATA","25001","M1 Junction 12","Bedfordshire","Highways England"

"GROUP","LOCA"
"HEADING","LOCA_ID","LOCA_NATE","LOCA_NATN","LOCA_GL","LOCA_TYPE","LOCA_FDEP"
"UNIT","","m","m","m","",""
"TYPE","ID","2DP","2DP","2DP","PA","2DP"
"DATA","BH01","510234.00","226789.00","85.40","BH","15.50"
"DATA","BH02","510256.00","226801.00","84.90","BH","12.00"

"GROUP","GEOL"
"HEADING","LOCA_ID","GEOL_TOP","GEOL_BASE","GEOL_DESC","GEOL_LEG","GEOL_GEOL","GEOL_FORM"
"UNIT","","m","m","","","",""
"TYPE","ID","2DP","2DP","X","PA","PA","X"
"DATA","BH01","0.00","0.30","TOPSOIL","","TS","TOPSOIL"
"DATA","BH01","0.30","2.50","Firm brown slightly sandy CLAY","102","LC","London Clay Formation"
"DATA","BH01","2.50","5.00","Dense brown fine to coarse SAND and GRAVEL","","RTD","River Terrace Deposits"
```

**Implementation** — new file `src/ags_reader.zig`:

```
AgsFile {
    project: AgsProject,
    locations: []AgsLocation,
    strata: []AgsStratum,
    samples: []AgsSample,         // optional
    spt_results: []AgsSptResult,  // optional
    core_data: []AgsCoreData,     // optional
}

AgsProject {
    id: []const u8,
    name: []const u8,
    location: []const u8,
    client: []const u8,
}

AgsLocation {
    id: []const u8,
    easting: f64,
    northing: f64,
    ground_level: f64,
    hole_type: []const u8,       // BH, TP, WS, etc.
    final_depth: f64,
}

AgsStratum {
    location_id: []const u8,
    depth_top: f64,
    depth_base: f64,
    description: []const u8,      // GEOL_DESC - raw text
    legend_code: ?[]const u8,     // GEOL_LEG
    geology_code: ?[]const u8,    // GEOL_GEOL
    formation: ?[]const u8,       // GEOL_FORM
    parsed: ?SoilDescription,     // Our enhanced parse result
}
```

**Parsing rules**:
- ASCII only (AGS Rule 1)
- All values double-quoted, comma-separated (AGS Rules 5, 6)
- Groups identified by `"GROUP"` descriptor row
- Header order: `GROUP` → `HEADING` → `UNIT` → `TYPE` → `DATA` rows
- Key groups to parse: `PROJ`, `LOCA`, `GEOL`, `SAMP`, `ISPT`, `CORE`, `WETH`, `FRAC`
- Unknown groups: skip gracefully (forward compatibility)

### 2.2 AGS4 Writer

Enable round-trip: parse → enhance → write back.

```
litholog enhance site_data.ags --output enhanced.ags
```

Adds extra headings to the GEOL group (using AGS Rule 18 user-defined headings via DICT group):
- `GEOL_MTYP` — material_type (soil/rock)
- `GEOL_CONS` — consistency
- `GEOL_DENS` — density
- `GEOL_PSOL` — primary_soil_type
- `GEOL_PRCK` — primary_rock_type
- `GEOL_RSTR` — rock_strength
- `GEOL_WETH` — weathering_grade
- `GEOL_CONF` — confidence score
- `GEOL_WARN` — warnings/anomalies

### 2.3 AGS4 Validation

Basic AGS4 format validation (complement to the BGS validator):
- Rule 2: Required GROUP/HEADING/UNIT/TYPE rows present
- Rule 5/6: Proper quoting and comma separation
- Rule 10: KEY fields present and unique
- Rule 13: PROJ group present with one DATA row
- Rule 14: TRAN group present
- Rule 15/16/17: UNIT, ABBR, TYPE groups present when needed

---

## Phase 3: SVG Borehole Strip Log Renderer

### 3.1 Strip Log Layout

Based on BS 5930 Table 16 and standard UK borehole log format:

```
┌─────────────────────────────────────────────────────────────────────┐
│  PROJECT: M1 Junction 12          BOREHOLE: BH01                  │
│  LOCATION: E510234 N226789        GROUND LEVEL: 85.40 m OD       │
│  HOLE TYPE: Cable Percussion      FINAL DEPTH: 15.50 m           │
│  DATE: 2024-03-15                 LOGGED BY: (from AGS)           │
├──────┬────────┬──────────┬────────────────────────┬───────────────┤
│Depth │ Level  │ Legend   │ Description            │ Samples/Tests │
│  (m) │ (m OD) │          │                        │               │
├──────┼────────┼──────────┼────────────────────────┼───────────────┤
│ 0.00 │ 85.40  │ ░░░░░░░░ │ TOPSOIL                │               │
│      │        │ ░░░░░░░░ │                        │               │
│ 0.30 │ 85.10  │──────────│────────────────────────│               │
│      │        │ ──── ─── │ Firm brown slightly    │ D1  0.50      │
│      │        │ ──── ─── │ sandy CLAY             │               │
│      │        │ ──── ─── │ (LONDON CLAY FM)       │ U1  1.50      │
│      │        │ ──── ─── │                        │               │
│ 2.50 │ 82.90  │──────────│────────────────────────│ SPT 2.50 N=12 │
│      │        │ · ○· ○·  │ Dense brown fine to    │               │
│      │        │ ○· ○· ○  │ coarse SAND and GRAVEL │ B2  3.00      │
│      │        │ · ○· ○·  │ (RIVER TERRACE         │               │
│      │        │ ○· ○· ○  │  DEPOSITS)             │ SPT 4.00 N=35 │
│ 5.00 │ 80.40  │──────────│────────────────────────│               │
│      │        │ ∧∧∧∧∧∧∧∧ │ Strong grey slightly   │               │
│      │        │ ∧∧∧∧∧∧∧∧ │ weathered LIMESTONE    │               │
│      │        │ ∧∧∧∧∧∧∧∧ │ (CORNBRASH FM)         │               │
└──────┴────────┴──────────┴────────────────────────┴───────────────┘
```

### 3.2 SVG Hatch Patterns (BS 5930 Table 16)

SVG `<pattern>` definitions for each soil/rock type:

| Material | Pattern Description | SVG Pattern |
|---|---|---|
| **TOPSOIL** | Grass tufts on stipple | Short vertical lines with dots |
| **MADE GROUND** | Random mixed pattern | Irregular triangles and dots |
| **CLAY** | Horizontal dashes | `──── ────` repeated |
| **SILT** | Fine horizontal dots | `· · · · · ·` repeated |
| **SAND** | Stipple dots | Random dots pattern |
| **GRAVEL** | Circles/ovals | `○ ○ ○` pattern |
| **SAND and GRAVEL** | Combined dots + circles | Dots with interspersed circles |
| **PEAT** | Organic symbols | Short horizontal wavy lines |
| **COBBLES/BOULDERS** | Large irregular shapes | Large ovals/polygons |
| **CHALK** | Brick-like with dots | Cross-hatched with stipple |
| **LIMESTONE** | Brick pattern | `∧∧∧∧` or brick-like |
| **SANDSTONE** | Dotted brickwork | Dots within brick outlines |
| **MUDSTONE** | Dashed brickwork | Dashes within brick outlines |
| **SILTSTONE** | Fine dotted brickwork | Fine dots within bricks |
| **SHALE** | Fissile dashes | Thin parallel wavy lines |
| **GRANITE** | Igneous coarse | Cross pattern with `+` |
| **BASALT** | Igneous fine | Dense `v` pattern |
| **SLATE** | Metamorphic fine | Parallel diagonal lines |
| **SCHIST** | Metamorphic medium | Wavy parallel lines |
| **GNEISS** | Metamorphic coarse | Bold wavy parallel lines |
| **MARBLE** | Metamorphic | Brick-like, clean lines |

**Composite patterns**: For descriptions with secondary constituents, blend patterns proportionally. E.g., "slightly sandy CLAY" = mostly clay dashes with sparse sand dots.

### 3.3 SVG Structure

New file: `src/svg_renderer.zig`

```zig
pub const SvgRenderer = struct {
    allocator: std.mem.Allocator,
    config: SvgConfig,

    pub const SvgConfig = struct {
        // Layout
        width: f32 = 800,                   // Total SVG width in px
        depth_scale: f32 = 40,              // Pixels per metre depth
        min_stratum_height: f32 = 30,       // Minimum px height for thin layers

        // Column widths (proportional)
        depth_column_width: f32 = 60,
        level_column_width: f32 = 60,
        legend_column_width: f32 = 80,
        description_column_width: f32 = 350,
        samples_column_width: f32 = 150,

        // Typography
        font_family: []const u8 = "Arial, Helvetica, sans-serif",
        title_font_size: f32 = 14,
        header_font_size: f32 = 11,
        body_font_size: f32 = 10,
        depth_font_size: f32 = 9,

        // Styling
        background_colour: []const u8 = "#ffffff",
        border_colour: []const u8 = "#000000",
        stratum_border_colour: []const u8 = "#333333",
        grid_colour: []const u8 = "#cccccc",
        water_strike_colour: []const u8 = "#2196F3",

        // Groundwater
        show_water_strikes: bool = true,
        water_symbol_size: f32 = 8,

        // Enhanced parsing overlay
        show_confidence: bool = true,       // Show confidence score colour band
        show_warnings: bool = true,         // Highlight anomalous descriptions
        show_strength_params: bool = false, // Show inferred strength column
        highlight_corrections: bool = true, // Highlight spelling corrections
    };

    pub fn renderBorehole(self: *SvgRenderer, borehole: BoreholeData) ![]u8 { ... }
    pub fn renderMultiple(self: *SvgRenderer, boreholes: []BoreholeData) ![][]u8 { ... }
};

pub const BoreholeData = struct {
    // From AGS LOCA group
    id: []const u8,
    easting: ?f64,
    northing: ?f64,
    ground_level: ?f64,
    hole_type: ?[]const u8,
    final_depth: f64,

    // From AGS GEOL group (with our parsed overlay)
    strata: []StratumData,

    // Optional from AGS SAMP/ISPT/CORE groups
    samples: []SampleData,
    spt_results: []SptData,
    core_data: []CoreRunData,
    water_strikes: []WaterStrikeData,
};

pub const StratumData = struct {
    depth_top: f64,
    depth_base: f64,
    raw_description: []const u8,
    formation: ?[]const u8,
    parsed: ?types.SoilDescription,   // Enhanced parse result

    // Rendering hints (derived from parsed)
    legend_pattern: LegendPattern,
    confidence_colour: []const u8,    // Green/amber/red based on confidence
};
```

### 3.4 Enhanced Parsing Overlay

The killer feature: litholog re-parses every `GEOL_DESC` string and overlays structured data:

**Visual overlays on the strip log**:

1. **Confidence band**: A thin coloured stripe along the left edge of the description column
   - 🟢 Green (>0.85): High confidence parse
   - 🟡 Amber (0.60–0.85): Partial parse / some unknowns
   - 🔴 Red (<0.60): Low confidence / major issues

2. **Warning icons**: Small ⚠️ symbols next to descriptions with anomalies
   - Hover text (in web view) shows the anomaly detail
   - In SVG: `<title>` element for tooltip

3. **Spelling corrections**: Corrected words shown with dotted underline
   - Original word in tooltip

4. **Inferred strength column** (optional): Show the inferred Cu/SPT-N/UCS range from the description, so engineers can cross-check against actual test data in the same log

### 3.5 Web Viewer for SVG Logs

Extend the existing web UI (`src/web_ui.html`) with a new "AGS Inspector" tab:

**Upload flow**:
1. User drags & drops `.ags` file
2. Server parses AGS4, extracts LOCA + GEOL groups
3. Parses each GEOL_DESC with enhanced parser
4. Renders SVG strip log for each borehole
5. Returns interactive HTML page with:
   - **Borehole selector** sidebar (list all LOCA_IDs)
   - **SVG log viewer** main area (pan/zoom on the strip log)
   - **Parse details panel** (click a stratum to see full parse JSON)
   - **Site plan** mini-map (plot borehole locations from LOCA coordinates)
   - **Anomaly summary** table (all warnings across all boreholes)
   - **Download options**: Individual SVGs, all SVGs as ZIP, enhanced AGS file

**API endpoints**:
```
POST /api/ags/upload         → Upload .ags file, returns summary JSON
GET  /api/ags/boreholes      → List all boreholes from uploaded file
GET  /api/ags/log/:id        → Get SVG strip log for a borehole
GET  /api/ags/log/:id/json   → Get parsed data for a borehole
GET  /api/ags/enhanced       → Download enhanced .ags file
GET  /api/ags/svg/:id        → Download SVG file for a borehole
POST /api/ags/svg/all        → Download ZIP of all SVG logs
```

---

## Phase 4: CLI Integration

### 4.1 New Commands

```bash
# Inspect: parse AGS and render SVG logs
litholog inspect data.ags                           # Summary to stdout
litholog inspect data.ags --svg                      # SVG to stdout (first borehole)
litholog inspect data.ags --svg --borehole BH01      # Specific borehole
litholog inspect data.ags --output ./logs/            # All boreholes as separate SVGs
litholog inspect data.ags --web                       # Open in browser

# Enhance: add parsed columns back to AGS
litholog enhance data.ags --output enhanced.ags

# Validate: check AGS format + description quality
litholog validate data.ags

# Existing commands continue to work
litholog "Firm brown slightly sandy CLAY"
litholog --csv data.csv --column Description
```

### 4.2 Output Format Options

```bash
litholog inspect data.ags --format svg      # SVG strip logs (default)
litholog inspect data.ags --format json     # Parsed data as JSON
litholog inspect data.ags --format summary  # Text summary of all boreholes
litholog inspect data.ags --format csv      # Parsed data as CSV
```

### 4.3 SVG Customisation Flags

```bash
litholog inspect data.ags --svg \
  --scale 50                    # 50 px per metre (default: 40)
  --width 1000                  # SVG width in px (default: 800)
  --no-confidence               # Hide confidence band
  --show-strength               # Show inferred strength column
  --no-corrections              # Don't highlight spelling corrections
  --title "Site Investigation"  # Custom title
```

---

## Phase 5: Code Quality Fixes

Address issues identified in the review alongside the new features:

### 5.1 Fix compliance.zig Stubs
Implement `checkTerminologyCompliance()` and `checkDescriptorOrder()` properly, or remove the placeholder code.

### 5.2 Fix terminology.zig Grey→Gray Normalisation
Remove the `grey→gray` normalisation. Both are valid; store as-is. BS 5930 is a British standard and "grey" is correct.

### 5.3 Fix constituent_db.zig Global Allocator
Replace `std.heap.page_allocator` with a passed-in allocator parameter to match the rest of the codebase.

### 5.4 Fix ANSI in Pretty JSON
Separate the coloured terminal output from JSON serialization. `toPrettyJson()` should produce valid JSON. Add a separate `toColouredTerminal()` for CLI display.

### 5.5 Increase Web Server Buffer
Increase the 4KB request buffer in `web.zig` to at least 64KB to handle batch requests and AGS file uploads.

---

## Implementation Priority

| Phase | Feature | Effort | Impact |
|---|---|---|---|
| 1.1 | Geological formation parsing | S | High |
| 1.3 | Compound primaries (SAND and GRAVEL) | S | High |
| 1.2 | Soil discontinuities | S | High |
| 1.9 | Made ground / topsoil | S | Medium |
| 1.7 | Density ranges | S | Medium |
| 1.4 | Tertiary "with" clauses | M | Medium |
| 1.5 | Particle shape | S | Medium |
| 1.6 | Cobbles & boulders | S | Medium |
| 1.8 | Enhanced colour system | M | Medium |
| 2.1 | AGS4 parser | L | Very High |
| 2.2 | AGS4 writer | M | High |
| 2.3 | AGS4 validation | M | Medium |
| 3.1-3.2 | SVG renderer + hatch patterns | L | Very High |
| 3.3-3.4 | SVG structure + parse overlay | L | Very High |
| 3.5 | Web AGS inspector | L | Very High |
| 4.1-4.3 | CLI integration | M | High |
| 5.1-5.5 | Code quality fixes | S | Medium |

**Suggested order**: Phase 1 (parser) → Phase 5 (fixes) → Phase 2 (AGS) → Phase 3 (SVG) → Phase 4 (CLI) → Phase 3.5 (Web)

---

## File Structure (New Files)

```
src/
├── parser/
│   ├── bs5930.zig              # Enhanced (Phase 1 changes)
│   ├── types.zig               # Enhanced (new fields)
│   ├── lexer.zig               # Enhanced (new token types)
│   └── ... (existing files)
├── ags_reader.zig              # NEW: AGS4 file parser
├── ags_writer.zig              # NEW: AGS4 file writer
├── ags_validator.zig           # NEW: AGS4 format validator
├── svg_renderer.zig            # NEW: SVG borehole log renderer
├── svg_patterns.zig            # NEW: BS 5930 hatch pattern SVG defs
├── web.zig                     # Enhanced (AGS endpoints)
├── web_ui.html                 # Enhanced (AGS Inspector tab)
├── cli.zig                     # Enhanced (inspect/enhance/validate)
└── ...
tests/
├── ags_reader_test.zig         # NEW
├── ags_writer_test.zig         # NEW
├── svg_renderer_test.zig       # NEW
└── ...
test_data/
├── example.ags                 # NEW: Example AGS4 file for testing
├── multi_borehole.ags          # NEW: Multi-borehole AGS file
├── real_world_descriptions.txt # NEW: Real messy descriptions from practice
└── ...
```

---

## Test Strategy

### Parser Enhancement Tests
- Real-world descriptions from Norbury (2010) textbook examples
- Descriptions with geological formations in parentheses
- Compound primary types
- Tertiary inclusions
- Full BS 5930 word-order compliance
- Descriptions with mixed fissuring/shearing terms

### AGS4 Tests
- Parse well-formed AGS4 files
- Handle missing optional groups gracefully
- Validate KEY field uniqueness
- Round-trip: read → write → read produces identical data
- Handle user-defined groups/headings (DICT)
- Test with real AGS files from BGS open data

### SVG Renderer Tests
- Each soil/rock type renders correct hatch pattern
- Depth scale is accurate
- Stratum boundaries align correctly
- Composite patterns blend properly
- Formation names appear in correct position
- Water strike symbols render at correct depth
- Output is valid SVG (parseable by browsers)

### Integration Tests
- End-to-end: `.ags` file → parsed data → SVG output
- Web UI: upload AGS → view SVG in browser
- CLI: `litholog inspect` produces valid SVG files
- Performance: 50-borehole AGS file processes in <1 second
