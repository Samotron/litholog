#!/usr/bin/env python3
"""
Extract version from Zig source and update Python package version.
"""

import re
import os
import sys

def extract_zig_version():
    """Extract version from Zig version.zig file."""
    version_file = os.path.join(os.path.dirname(__file__), '../../src/version.zig')
    
    if not os.path.exists(version_file):
        print(f"Version file not found: {version_file}")
        return None
    
    with open(version_file, 'r') as f:
        content = f.read()
    
    # Extract VERSION_STRING value
    match = re.search(r'VERSION_STRING\s*=\s*"([^"]+)"', content)
    if match:
        return match.group(1)
    
    # Fallback: extract from semantic version
    major_match = re.search(r'\.major\s*=\s*(\d+)', content)
    minor_match = re.search(r'\.minor\s*=\s*(\d+)', content)
    patch_match = re.search(r'\.patch\s*=\s*(\d+)', content)
    
    if major_match and minor_match and patch_match:
        return f"{major_match.group(1)}.{minor_match.group(1)}.{patch_match.group(1)}"
    
    return None

def update_python_version():
    """Update Python package version to match Zig version."""
    zig_version = extract_zig_version()
    if not zig_version:
        print("Could not extract version from Zig source")
        return False
    
    print(f"Extracted Zig version: {zig_version}")
    
    # Update litholog.py
    litholog_file = os.path.join(os.path.dirname(__file__), 'litholog.py')
    if os.path.exists(litholog_file):
        with open(litholog_file, 'r') as f:
            content = f.read()
        
        # Update __version__ = "x.x.x"
        content = re.sub(
            r'__version__\s*=\s*"[^"]*"',
            f'__version__ = "{zig_version}"',
            content
        )
        
        with open(litholog_file, 'w') as f:
            f.write(content)
        print(f"Updated {litholog_file}")
    
    # Update setup.py
    setup_file = os.path.join(os.path.dirname(__file__), 'setup.py')
    if os.path.exists(setup_file):
        with open(setup_file, 'r') as f:
            content = f.read()
        
        # Update version="x.x.x"
        content = re.sub(
            r'version\s*=\s*"[^"]*"',
            f'version="{zig_version}"',
            content
        )
        
        with open(setup_file, 'w') as f:
            f.write(content)
        print(f"Updated {setup_file}")
    
    return True

if __name__ == "__main__":
    if update_python_version():
        print("Python version successfully synced with Zig version")
        sys.exit(0)
    else:
        print("Failed to sync Python version")
        sys.exit(1)