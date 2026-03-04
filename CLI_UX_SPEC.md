# Litholog CLI UX Modernisation Specification

## Executive Summary

Transform the litholog CLI from a flat, flag-heavy interface into a modern, Cobra-style subcommand-driven CLI with rich coloured output, structured help, progress feedback, and sensible defaults — all while maintaining backward compatibility with the existing single-description parsing workflow.

**Guiding principles** (from [clig.dev](https://clig.dev)):
- Human-first design with machine-readable output behind `--json`
- Ease of discovery via comprehensive help text and examples
- Consistency across subcommands
- Saying just enough — don't overwhelm

---

## 1. Architecture: Subcommand-Based Design

### Current State

```
litholog "Firm CLAY"                          # positional — works
litholog --csv input.csv --csv-output ...     # flat flags — clunky
litholog inspect data.ags                     # subcommand — partially done
litholog web                                  # subcommand — works
litholog tui                                  # subcommand — works
```

The current CLI mixes subcommands (`inspect`, `web`, `tui`) with a flat flag-based interface for everything else. This is confusing and hard to discover.

### Proposed Command Tree

```
litholog                                       # No args → concise help (not an error)
litholog <DESCRIPTION>                         # Quick parse (backward compat)
litholog parse <DESCRIPTION>                   # Explicit parse command
litholog parse --file descriptions.txt         # Parse from file
litholog parse --mode summary                  # Output mode

litholog csv <INPUT> -o <OUTPUT>               # CSV processing (was --csv)
  --column <COL>                               # Description column
  --output-columns <COLS>                      # Result columns
  --no-header                                  # No header row
  --excel                                      # Excel output format
  --sheet-name <NAME>                          # Excel sheet name
  --freeze-header                              # Excel: freeze header
  --auto-filter                                # Excel: auto-filter

litholog inspect <FILE.ags>                    # AGS inspection (existing)
  --format svg|json|csv|summary
  --borehole <ID>
  --output <PATH>
  --scale <N>
  --width <N>
  --title <TEXT>
  --no-confidence
  --show-strength
  --no-corrections

litholog enhance <FILE.ags> -o <OUT.ags>       # AGS enhancement (existing)

litholog validate <FILE.ags>                   # AGS validation (existing)

litholog generate random [--count N] [--seed S]   # Generate descriptions
litholog generate variations <DESC>               # Generate variations

litholog units <CSV>                           # Geological unit identification
  --column <COL>
  --borehole-id <COL>
  --depth-top <COL>
  --depth-bottom <COL>
  -o <OUTPUT>

litholog convert --from-json <FILE>            # JSON→description roundtrip
  --format standard|concise|verbose|bs5930

litholog web [--port N]                        # Web UI (existing)
litholog tui                                   # Interactive TUI (existing)

litholog version                               # Version info
litholog help [COMMAND]                        # Help for any command
litholog completions <bash|zsh|fish>           # Shell completions
```

### Design Rules

1. **Every subcommand has its own `--help`** with description, usage, flags, and examples
2. **Global flags** appear before the subcommand: `litholog --no-color parse "Firm CLAY"`
3. **Backward compatibility**: bare `litholog "Firm CLAY"` continues to work (detected as positional with no subcommand match)
4. **Unknown subcommands** print a "did you mean?" suggestion using Levenshtein distance (we already have this in the parser!)

### Global Flags

```
--no-color, -C        Disable coloured output
--json                Force JSON output for any command
--quiet, -q           Suppress non-essential output
--verbose, -v         Show additional detail / debug info
--help, -h            Show help
--version, -V         Show version
```

---

## 2. Help System

### 2.1 Root Help (no args or `--help`)

When invoked with no arguments, display concise help — not an error. This follows the `jq` and Cobra patterns.

```
⛏  litholog v0.6.0 — Geological description parser (BS 5930)

Usage:
  litholog <DESCRIPTION>              Parse a single description
  litholog <command> [flags]          Run a command

Commands:
  parse       Parse geological descriptions from text, file, or stdin
  csv         Process CSV/Excel files with geological descriptions
  inspect     Inspect AGS4 files and render SVG borehole logs
  enhance     Add parsed data columns to AGS4 files
  validate    Validate AGS4 file structure
  generate    Generate random or varied descriptions
  units       Identify geological units across boreholes
  convert     Convert between JSON and text descriptions
  web         Launch the web-based GUI
  tui         Interactive terminal mode

Flags:
  -C, --no-color   Disable coloured output
  -h, --help       Show this help
  -V, --version    Show version

Examples:
  litholog "Firm brown slightly sandy CLAY"
  litholog csv input.csv -o output.csv --column Description
  litholog inspect site_data.ags --format svg
  litholog web

Run 'litholog <command> --help' for more information on a command.
Docs: https://github.com/samotron/litholog
```

### 2.2 Subcommand Help

Each subcommand follows this structure (inspired by Cobra/Heroku CLI):

```
litholog csv --help
```
```
Process CSV or Excel files containing geological descriptions

Usage:
  litholog csv <INPUT_FILE> [flags]

Flags:
  -o, --output <FILE>           Output file path (required)
      --column <NAME|INDEX>     Column containing descriptions (required)
      --output-columns <COLS>   Comma-separated result columns to append
      --no-header               Input has no header row
      --excel                   Export as Excel (.xlsx)
      --freeze-header           Freeze header row (Excel only)
      --auto-filter             Enable auto-filter (Excel only)
      --sheet-name <NAME>       Worksheet name (default: Sheet1)
  -h, --help                    Show this help

Available Output Columns:
  material_type, consistency, density, primary_soil_type,
  primary_rock_type, rock_strength, weathering_grade, color,
  moisture_content, confidence, is_valid, strength_lower,
  strength_upper, strength_typical, strength_unit, json

Examples:
  # Basic CSV processing
  litholog csv input.csv -o output.csv --column "Description" \
    --output-columns "material_type,consistency,confidence"

  # Excel output with formatting
  litholog csv input.csv -o output.xlsx --column 2 \
    --output-columns "material_type,primary_soil_type" \
    --excel --freeze-header --auto-filter
```

### 2.3 Did-You-Mean Suggestions

When an unknown subcommand is entered:

```
$ litholog insect data.ags

  Error: unknown command "insect"

  Did you mean?
    inspect    Inspect AGS4 files and render SVG borehole logs

  Run 'litholog --help' for a list of commands.
```

---

## 3. Coloured & Styled Output

### 3.1 Colour Palette

Define a consistent theme used across all output. Use ANSI 256-colour codes for broad terminal compatibility. All colours are disabled when `--no-color` is passed, `NO_COLOR` env is set, or stdout is not a TTY.

| Element               | Colour                        | ANSI Code       |
|------------------------|-------------------------------|-----------------|
| App name / branding    | Bold cyan                     | `\x1b[1;36m`   |
| Command names          | Bold white                    | `\x1b[1;37m`   |
| Flag names             | Yellow                        | `\x1b[33m`      |
| Flag values / placeholders | Dim / italic               | `\x1b[2;3m`    |
| Section headers        | Bold magenta                  | `\x1b[1;35m`   |
| Success messages       | Bold green                    | `\x1b[1;32m`   |
| Warnings               | Bold yellow                   | `\x1b[1;33m`   |
| Errors                 | Bold red                      | `\x1b[1;31m`   |
| Dim / secondary text   | Dim                           | `\x1b[2m`       |
| Soil types (CAPS)      | Bold (terminal default)       | `\x1b[1m`       |
| Confidence ≥ 0.85      | Green                         | `\x1b[32m`      |
| Confidence 0.60–0.84   | Yellow                        | `\x1b[33m`      |
| Confidence < 0.60      | Red                           | `\x1b[31m`      |
| Key labels             | Cyan                          | `\x1b[36m`      |
| Values                 | Default (no colour)           |                 |

### 3.2 Styled Parse Output (Default: `summary` mode for TTY)

When a user runs `litholog "Firm brown slightly sandy CLAY"` in a terminal, show rich styled output by default (not compact JSON):

```
⛏  litholog parse

  Description    Firm brown slightly sandy CLAY
  Material       Soil
  Consistency    Firm
  Primary Type   CLAY
  Colour         brown
  Secondary      slightly sandy
  Strength       Cu: 25–50 kPa (typical: 37.5 kPa)
  Confidence     0.95 ✓
  Valid          Yes ✓
```

- Labels are **cyan**, values are default
- Soil types in **bold**
- Confidence coloured (green/yellow/red) with checkmark/warning symbol
- Valid: green ✓ or red ✗

When piped (`litholog "Firm CLAY" | jq .`), automatically switch to compact JSON (detect TTY).

### 3.3 Status Symbols

Use Unicode symbols consistently:

| Symbol | Meaning              |
|--------|----------------------|
| `✓`    | Success / valid      |
| `✗`    | Failure / invalid    |
| `⚠`    | Warning              |
| `⛏`    | Litholog branding    |
| `→`    | Next step / hint     |
| `•`    | List item            |
| `▸`    | Sub-item             |

Fallback to ASCII (`[ok]`, `[FAIL]`, `[!]`, `>`, `-`, `*`) when `TERM=dumb` or colour is disabled.

---

## 4. Error Handling & Messaging

### 4.1 Error Format

Errors go to stderr. Structure:

```
Error: <what went wrong>

  <context / details>

  <suggestion on how to fix>
```

### 4.2 Examples

**Missing required argument:**
```
Error: missing required flag --column

  The --column flag specifies which column in your CSV contains
  geological descriptions.

  Usage: litholog csv input.csv -o output.csv --column "Description"
```

**File not found:**
```
Error: cannot open 'data.ag' — file not found

  Did you mean 'data.ags'?
```

**Invalid description:**
```
Warning: low confidence parse (0.42) for "Dense CLAY"

  ⚠  'Dense' is typically used for granular soils (sand, gravel),
     not cohesive soils (clay, silt).

  → Did you mean 'Stiff CLAY' or 'Dense SAND'?
```

### 4.3 Exit Codes

| Code | Meaning                         |
|------|---------------------------------|
| 0    | Success                         |
| 1    | General error                   |
| 2    | Usage error (bad flags/args)    |
| 3    | Input file error                |
| 4    | Parse error (all inputs failed) |
| 5    | Validation failure (AGS)        |

---

## 5. Progress & Feedback

### 5.1 Spinner for Long Operations

When processing CSV files or AGS files with many records, show a spinner on stderr:

```
⛏  Parsing descriptions... ⠋  (142 / 1,203)
```

Use braille spinner characters: `⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏`

Only show when stderr is a TTY. Clear the spinner line on completion.

### 5.2 Completion Summary

After batch operations, show a summary:

```
✓  Processed 1,203 descriptions in 0.8s

  Results:  1,142 valid (94.9%)  •  61 warnings  •  0 errors
  Output:   output.csv (1,203 rows, 8 columns added)
```

### 5.3 No Animations in Non-TTY

When stderr is not a TTY (CI, piped), suppress spinners and progress entirely. Only print the final summary line.

---

## 6. Output Modes

### 6.1 Auto-Detection

| Scenario                           | Default behaviour                     |
|------------------------------------|---------------------------------------|
| TTY stdout, single description     | `summary` (styled key-value)          |
| TTY stdout, batch/file             | `summary` per item                    |
| Non-TTY stdout (piped/redirected)  | `compact` (one JSON per line / JSONL) |
| `--json` flag                      | Pretty-printed JSON (TTY) or compact  |
| `--mode compact`                   | Explicit compact JSON override        |

### 6.2 Mode Summary

| Mode      | Format                    | When to use                    |
|-----------|---------------------------|--------------------------------|
| `summary` | Styled key-value          | Human reading in terminal      |
| `compact` | Single-line JSON          | Piping, scripting              |
| `pretty`  | Indented + coloured JSON  | Human-readable JSON inspection |
| `verbose` | JSON + warnings + extras  | Debugging, detailed analysis   |
| `table`   | Aligned columns           | Batch results in terminal      |

### 6.3 Table Output (New)

For batch processing with `--mode table`:

```
$ litholog parse --file descriptions.txt --mode table

  DESCRIPTION                              MATERIAL   TYPE        CONSISTENCY   CONFIDENCE
  ──────────────────────────────────────────────────────────────────────────────────────────
  Firm brown slightly sandy CLAY           Soil       CLAY        Firm          0.95 ✓
  Dense SAND                               Soil       SAND        —             0.90 ✓
  Strong slightly weathered LIMESTONE      Rock       LIMESTONE   —             0.92 ✓
  Medium dense GRAVEL                      Soil       GRAVEL      —             0.88 ✓

  ✓ 4/4 parsed successfully
```

---

## 7. Version Display

```
$ litholog version

  litholog v0.6.0
  Built with Zig 0.12.0
  Platform: linux/x86_64
  https://github.com/samotron/litholog

$ litholog --version
litholog v0.6.0

$ litholog -V
litholog v0.6.0
```

The short forms (`--version`, `-V`) output a single line for scripting. The `version` subcommand gives the full block.

---

## 8. Shell Completions

Generate shell completion scripts for bash, zsh, and fish:

```
$ litholog completions bash > /etc/bash_completion.d/litholog
$ litholog completions zsh > ~/.zfunc/_litholog
$ litholog completions fish > ~/.config/fish/completions/litholog.fish
```

Implementation: Generate static completion scripts that enumerate subcommands and their flags. No dynamic completion needed initially.

---

## 9. Configuration File Support (Future)

Support an optional `~/.config/litholog/config.toml` or `.litholog.toml` in the project directory:

```toml
[output]
mode = "summary"
color = true

[csv]
default_columns = ["material_type", "consistency", "primary_soil_type", "confidence"]

[web]
port = 8080
```

Flags always override config file values. Environment variables (`LITHOLOG_NO_COLOR`, `LITHOLOG_MODE`) sit between config and flags in precedence.

**Precedence**: flags > env vars > project config > user config > defaults

---

## 10. Implementation Plan

### 10.1 Refactoring Strategy

The implementation requires no external dependencies — all colour and CLI parsing is done with Zig's stdlib and hand-rolled ANSI helpers. This keeps the binary small and dependency-free.

#### New Source Files

| File | Purpose |
|------|---------|
| `src/style.zig` | ANSI colour/style helpers, theme constants, TTY detection (extracted from cli.zig/tui.zig — **eliminates the duplicated 200+ lines** of colour detection code) |
| `src/cli_help.zig` | Structured help text renderer with colour, auto-wrapping |
| `src/cli_router.zig` | Subcommand routing, global flag parsing, did-you-mean |
| `src/cli_output.zig` | Output formatting: summary, table, compact, pretty JSON |
| `src/cli_progress.zig` | Spinner and progress counter for stderr |

#### Modified Source Files

| File | Changes |
|------|---------|
| `src/main.zig` | Replace flat arg dispatch with `cli_router` |
| `src/cli.zig` | Refactor to be the `parse` subcommand handler; remove duplicated colour detection |
| `src/ags_cli.zig` | Adapt to use shared `style.zig` and `cli_output.zig` |
| `src/tui.zig` | Remove duplicated colour detection, use `style.zig` |
| `src/version.zig` | Add build metadata (compiler version, platform) |

### 10.2 Phased Rollout

| Phase | Scope | Effort |
|-------|-------|--------|
| **Phase 1** | `style.zig` — extract & deduplicate colour/TTY detection from cli.zig and tui.zig | S |
| **Phase 2** | `cli_router.zig` — subcommand routing, global flags, did-you-mean | M |
| **Phase 3** | `cli_help.zig` — structured help renderer for root + each subcommand | M |
| **Phase 4** | `cli_output.zig` — summary, table, and pretty output modes; auto TTY detection | M |
| **Phase 5** | `cli_progress.zig` — spinner for batch CSV/AGS operations | S |
| **Phase 6** | Refactor `cli.zig` → `parse` command; refactor `csv` path into `csv` command | L |
| **Phase 7** | Adapt `ags_cli.zig`, wire up `enhance`, `validate`; add `convert`, `units`, `generate` subcommands | M |
| **Phase 8** | Error message improvements (context, suggestions, did-you-mean for files) | S |
| **Phase 9** | `completions` subcommand — static bash/zsh/fish scripts | S |
| **Phase 10** | `version` subcommand with build metadata | S |

### 10.3 Backward Compatibility

- `litholog "Firm CLAY"` continues to work (no subcommand → falls through to `parse`)
- All existing `--csv`, `--file`, `--mode` flags still work on the root command (mapped to subcommands internally)
- `litholog inspect`, `litholog enhance`, `litholog validate` — unchanged
- `litholog web`, `litholog gui`, `litholog tui` — unchanged
- Deprecation warnings printed to stderr for old-style flags (e.g., `--csv` → `litholog csv`)

---

## 11. Testing Strategy

### Unit Tests
- `style.zig`: Colour code generation, TTY detection mocking, NO_COLOR respect
- `cli_router.zig`: Subcommand matching, global flag extraction, did-you-mean
- `cli_help.zig`: Help text generation (assert structure, not colours)
- `cli_output.zig`: Each output mode produces expected structure

### Integration Tests
- End-to-end: `litholog "Firm CLAY"` produces valid summary output
- End-to-end: `litholog "Firm CLAY" | cat` produces valid JSON (non-TTY detection)
- End-to-end: `litholog csv ...` produces expected output file
- Backward compat: old-style flags still work with deprecation warnings
- Exit codes: verify correct codes for each error scenario

### Visual Tests
- Manual test script (`test_cli_ux.sh`) that exercises every subcommand and output mode for visual inspection of colours, alignment, and styling

---

## 12. Inspiration & References

| Tool | What to Learn |
|------|---------------|
| **Cobra** (Go) | Subcommand architecture, auto-generated help, completions |
| **ripgrep** | Coloured output, smart TTY detection, `--no-color` |
| **bat** | Syntax highlighting, pager integration, beautiful defaults |
| **Charm/BubbleTea** | Spinner design, styled output components |
| **Heroku CLI** | Help text layout with examples, flags, and subcommands sections |
| **gh** (GitHub CLI) | Consistent subcommand verbs, `--json` with `--jq` |
| **clig.dev** | Comprehensive CLI design guidelines |
| **jq** | Concise default help, progressive disclosure |
| **fd / exa** | Modern defaults that "just work" for humans |
