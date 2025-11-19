#!/usr/bin/env bash

# Test spelling correction functionality

echo "=== Litholog Spelling Correction Demo ==="
echo ""

echo "1. Testing typo: 'Firn CLAY' (should correct 'Firn' to 'firm')"
./zig-out/bin/litholog parse "Firn CLAY"
echo ""

echo "2. Testing typo: 'Stif brown CLAY' (should correct 'Stif' to 'stiff')"
./zig-out/bin/litholog parse "Stif brown CLAY"
echo ""

echo "3. Testing multiple typos: 'Firn slighty snady CLAI'"
./zig-out/bin/litholog parse "Firn slighty snady CLAI"
echo ""

echo "4. Testing rock typo: 'Strong LIMSTONE'"
./zig-out/bin/litholog parse "Strong LIMSTONE"
echo ""

echo "5. Testing correct spelling (no corrections): 'Firm brown CLAY'"
./zig-out/bin/litholog parse "Firm brown CLAY"
echo ""

echo "=== Demo Complete ===" 
