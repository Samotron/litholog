# Version Management

This document explains how version management works across all components of the litholog project.

## 🎯 Single Source of Truth

All versions are centrally managed from **`src/version.zig`**. This ensures consistency across:

- Zig library and CLI
- Go bindings
- Python package  
- GitHub releases
- Documentation

## 📁 Version Structure

### Primary Version File: `src/version.zig`

```zig
pub const VERSION = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

pub const VERSION_STRING = "0.1.0";
```

This file defines the canonical version used by all components.

## 🔄 Synchronization Scripts

### Root Level: `sync_versions.sh`

Syncs all binding versions with the Zig source:

```bash
./sync_versions.sh
```

This script:
1. Extracts version from `src/version.zig`
2. Updates Python package version
3. Updates Go package version  
4. Creates a `VERSION` file for CI/CD

### Python: `bindings/python/sync_version.py`

Updates Python package files:
- `litholog.py` - Updates `__version__`
- `setup.py` - Updates version parameter

### Go: `bindings/go/sync_version.sh`

Updates Go package files:
- `version.go` - Updates version constant

## 🚀 Release Process

### 1. Update Version

Edit `src/version.zig` to the new version:

```zig
pub const VERSION = std.SemanticVersion{
    .major = 1,
    .minor = 0,
    .patch = 0,
};

pub const VERSION_STRING = "1.0.0";
```

### 2. Sync All Versions

```bash
./sync_versions.sh
```

### 3. Commit Changes

```bash
git add .
git commit -m "Bump version to 1.0.0"
```

### 4. Create Tag

```bash
git tag v1.0.0
git push origin v1.0.0
```

**Important**: The tag version (e.g., `v1.0.0`) must match the Zig version (`1.0.0`). The GitHub Actions will validate this and fail if they don't match.

## ⚙️ Automated Validation

GitHub Actions automatically:

1. **Extract version** from `src/version.zig`
2. **Validate** that git tag matches Zig version
3. **Sync** all binding versions
4. **Build and publish** with consistent versioning

### Version Validation

When you push a tag like `v1.0.0`, the CI will:

```bash
TAG_VERSION=${GITHUB_REF#refs/tags/v}  # "1.0.0"
ZIG_VERSION=$(extract from src/version.zig)  # "1.0.0"

if [ "$TAG_VERSION" != "$ZIG_VERSION" ]; then
  echo "❌ Version mismatch!"
  exit 1
fi
```

## 📦 Package Versions

All packages will have synchronized versions:

| Package | Version Source | Files Updated |
|---------|---------------|---------------|
| **Zig CLI** | `src/version.zig` | Built-in |
| **Zig Library** | `src/version.zig` | Built-in |
| **Go Package** | `bindings/go/version.go` | Auto-generated |
| **Python Package** | `bindings/python/litholog.py` | Auto-updated |

## 🔍 Version Access

### From Zig Code
```zig
const version = @import("version.zig");
std.log.info("Version: {s}", .{version.VERSION_STRING});
```

### From C Library
```c
printf("Version: %s\n", litholog_version_string());
```

### From Go
```go
import "github.com/samotron/litholog/bindings/go"

fmt.Println("Version:", litholog.GetVersion())
// Or from C library:
fmt.Println("Version:", litholog.GetVersionFromC())
```

### From Python
```python
import litholog

print(f"Version: {litholog.__version__}")
```

## 🐛 Troubleshooting

### Version Mismatch Error

If you get a version mismatch error in CI:

1. Check `src/version.zig` version
2. Check git tag version
3. Make sure they match exactly
4. Re-run `./sync_versions.sh` if needed

### Binding Version Out of Sync

If binding versions are wrong:

```bash
# Sync all versions
./sync_versions.sh

# Or sync individual bindings
cd bindings/python && python sync_version.py
cd bindings/go && ./sync_version.sh
```

### Manual Version Override

In emergencies, you can manually update versions:

```bash
# Python
sed -i 's/__version__ = ".*"/__version__ = "1.0.1"/' bindings/python/litholog.py

# Go  
sed -i 's/Version = ".*"/Version = "1.0.1"/' bindings/go/version.go
```

## 📋 Pre-Release Checklist

Before creating a release tag:

- [ ] Update `src/version.zig` with new version
- [ ] Run `./sync_versions.sh` to sync all bindings
- [ ] Test that everything builds: `zig build && zig build lib`
- [ ] Commit version changes
- [ ] Create matching git tag: `git tag v1.0.0`
- [ ] Push tag: `git push origin v1.0.0`

The automated release process will handle the rest! 🎉