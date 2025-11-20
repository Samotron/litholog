# Litholog Web UI Guide

## Overview

The Litholog Web UI provides a user-friendly graphical interface for parsing geological descriptions without needing to use the command line.

## Launching the Web UI

### Method 1: Double-Click (Easiest for Windows users)
1. Download the `litholog-windows-x86_64.exe` from the releases page
2. Double-click the executable
3. Your default browser will automatically open to `http://localhost:8080`

### Method 2: Command Line
```bash
# Start the web server
litholog web
# or
litholog gui

# Your browser will open automatically to http://localhost:8080
```

## Features

### Single Description Parsing
- Type or paste a geological description
- Click "Parse Description" to see results
- View structured output including:
  - Material type (soil/rock)
  - Consistency, density, or strength
  - Primary and secondary constituents
  - Confidence scores
  - Strength parameters

### Batch Processing
- Enter multiple descriptions (one per line)
- Parse all at once
- Download results as JSON
- View summary of all parsed descriptions

### Example Descriptions
Quick-access buttons to try common descriptions:
- Firm CLAY
- Dense SAND
- Strong LIMESTONE
- Complex descriptions with secondary constituents

## API Endpoints

The web server exposes these REST endpoints:

### `POST /api/parse`
Parse a single description
```json
{
  "description": "Firm CLAY"
}
```

### `POST /api/parse-batch`
Parse multiple descriptions
```json
{
  "descriptions": ["Firm CLAY", "Dense SAND"]
}
```

### `GET /api/health`
Health check endpoint
```json
{
  "status": "ok"
}
```

## Technical Details

- **Server**: Built-in HTTP server (no external dependencies)
- **Port**: 8080 (localhost only for security)
- **Frontend**: Single-page application (vanilla JavaScript)
- **Performance**: Handles 1M+ descriptions/second
- **Memory**: <10MB footprint

## Security

- Server binds to `127.0.0.1` only (localhost)
- Not accessible from other machines
- No data is sent to external services
- All processing happens locally

## Troubleshooting

### Browser doesn't open automatically
- Manually navigate to `http://localhost:8080`
- Check if another application is using port 8080

### Port 8080 already in use
- Stop other applications using port 8080
- Or modify the port in `src/main.zig` and rebuild

### UI not loading
- Check that the server started successfully
- Verify no firewall is blocking localhost connections
- Try refreshing the browser

## Development

The web UI is embedded directly in the binary:
- HTML/CSS/JS in `src/web_ui.html`
- Server implementation in `src/web.zig`
- No build tools or npm required
- Changes require rebuilding with `zig build`
