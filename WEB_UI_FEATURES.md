# Litholog Web UI - Feature Overview

## New Modern Design (PostHog-Inspired)

The web interface has been completely redesigned with a modern, professional look:

### Visual Design
- **Gradient headers** - Blue gradient (navy to royal blue) for premium feel
- **Clean cards** - White cards with subtle shadows and rounded corners
- **Modern typography** - System fonts with improved readability
- **Smooth animations** - Fade-in transitions and hover effects
- **Professional badges** - Gradient badges for material types (soil/rock)
- **Responsive layout** - Works perfectly on desktop, tablet, and mobile

### Color Scheme
- Primary: Deep blue gradients (#1e3a8a → #1d4ed8)
- Success: Emerald green (#059669)
- Error: Red (#dc2626)
- Background: Warm gray (#fafaf9)
- Surface: Pure white (#ffffff)
- Text: Stone gray hierarchy for readability

## Features by Tab

### 1. Single Description Parser
**Perfect for quick lookups**
- Large text input area with monospace font
- Real-time parsing on button click
- Structured results display with:
  - Material type badge (gradient)
  - Consistency, density, strength properties
  - Secondary constituents
  - Confidence scores
  - Strength parameters with units
- 6 example buttons for quick testing

### 2. Batch Processing
**Process multiple descriptions at once**
- Multi-line text input (one description per line)
- Parse all descriptions in a single request
- Visual results grid showing:
  - Each description with parsed data
  - Material type badges
  - Key properties summary
  - Confidence scores
- Download all results as JSON (timestamped)

### 3. CSV Upload (NEW!)
**Professional workflow for large datasets**

#### Upload Methods:
1. Click the upload area to browse files
2. Drag and drop CSV files directly

#### Features:
- **File preview** - Shows first 5 rows of your CSV
- **Column selection** - Dropdown to choose which column contains descriptions
- **Smart parsing** - Handles quoted fields and commas correctly
- **Progress indication** - Loading spinners during processing
- **Auto-download** - Processed CSV downloads automatically

#### Output:
The processed CSV includes your original columns PLUS:
- `material_type` - soil or rock
- `consistency` - for soils (firm, stiff, etc.)
- `density` - for granular soils (dense, loose, etc.)
- `primary_soil_type` - CLAY, SAND, GRAVEL, etc.
- `primary_rock_type` - LIMESTONE, SANDSTONE, etc.
- `rock_strength` - for rocks (strong, weak, etc.)
- `confidence` - percentage confidence score

### 4. About
- Feature list
- Performance metrics
- Links to documentation

## Technical Improvements

### Performance
- Embedded HTML (no external files) - ~37KB
- Zero dependencies (vanilla JavaScript)
- Instant page load
- Local processing (no network latency)

### User Experience
- Smooth animations and transitions
- Hover effects on all interactive elements
- Clear loading states with spinners
- Success/error alerts with icons
- Drag-and-drop support
- Keyboard-friendly

### Security
- Localhost only (127.0.0.1:8080)
- No data sent to external servers
- All processing happens locally
- CORS headers for API access

## API Endpoints

All endpoints return JSON:

### `POST /api/parse`
Parse single description
```json
Request: {"description": "Firm CLAY"}
Response: {parsed geological data}
```

### `POST /api/parse-batch`
Parse multiple descriptions
```json
Request: {"descriptions": ["Firm CLAY", "Dense SAND"]}
Response: [{...}, {...}]
```

### `GET /api/health`
Server health check
```json
Response: {"status": "ok"}
```

## Browser Compatibility

Works in all modern browsers:
- Chrome/Edge (recommended)
- Firefox
- Safari
- Opera

Minimum versions:
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## File Size Comparison

- Old UI: ~20KB HTML
- New UI: ~37KB HTML
- Binary impact: +17KB (negligible)
- Benefits: Much better UX, CSV support, modern design

## Usage Tips

1. **For quick lookups**: Use the Single Description tab with example buttons
2. **For multiple items**: Use Batch Processing tab and paste from Excel/notepad
3. **For large datasets**: Use CSV Upload tab - processes thousands of rows efficiently
4. **Mobile users**: All features work on phone/tablet browsers

## Future Enhancements (Potential)

- Excel (.xlsx) direct upload (currently CSV only)
- Dark mode toggle
- Result visualization (charts, graphs)
- Export to multiple formats (PDF, Excel)
- Column mapping wizard for complex CSVs
- Batch editing and re-parsing
- History of recent analyses
