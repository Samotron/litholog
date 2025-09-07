# Agent Guidelines for Litholog

## Build/Test Commands
- Build: `zig build`
- Run: `zig build run`
- Test: `zig build test`
- Library: `zig build lib`
- Single test: `zig test src/parser/bs5930.zig` (or specific test file)

## Code Style Guidelines
- **Language**: Zig (main), with Go/Python bindings
- **Imports**: Group std imports first, then project imports
- **Naming**: snake_case for functions/variables, PascalCase for types/structs
- **Memory**: Use allocator parameter for dynamic allocation, defer cleanup
- **Error handling**: Use Zig's `!` error unions, provide specific error types
- **Types**: Explicit enum types with toString/fromString methods
- **Comments**: Minimal, focus on "why" not "what"
- **Tests**: Place tests in same directory as source files

## Project Structure
- `src/`: Core Zig implementation (parser, CLI, TUI)
- `bindings/`: Go and Python bindings
- `include/`: C header for FFI
- Main entry: `src/main.zig`