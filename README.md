# TOONZ

A Zig parser implementation for the TOON (Token-Oriented Object Notation) format.

See the [full specification](https://github.com/toon-format/spec) for details in depth.

## Features

- [x] **Core Encoding/Decoding**: Full JSON ↔ TOON conversion
- [x] **Primitives**: strings, numbers, booleans, null with smart quoting
- [x] **Objects**: Nested objects with indentation-based structure
- [x] **Arrays**: Both inline (primitives) and multi-line (objects/nested)
- [x] **Tabular Arrays**: Compact `[N]{field1,field2}:` format for uniform object arrays
- [x] **Alternative Delimiters**: Comma (default), tab (`\t`), and pipe (`|`) support
- [x] **Delimiter Detection**: Automatic delimiter detection in array headers `[N<delim>]`
- [x] **CLI Tool**: Encode and decode via command line or pipes

## Usage

The project provides both a simple CLI for JSON to TOON conversion and vice versa, and its library.

## Status & Roadmap

### Implemented ✅
- Core TOON encoder and decoder
- Nested objects with indentation
- Tabular arrays with field lists
- Alternative delimiters (comma, tab, pipe)
- Delimiter detection from array headers
- Smart string quoting
- CLI tool
- Field order preservation (deterministic output)
- Comprehensive error messages with line/column information

### Planned 📋
- Key folding (`keyFolding="safe"` mode) - collapse single-key object chains into dotted notation
- Path expansion (`expandPaths="safe"` mode) - split dotted keys into nested objects
- Strict mode validation (length mismatches, malformed headers)
- Conformance test suite from `spec/tests/fixtures/`
- Performance optimizations
- Benchmarks vs JSON

### Known Limitations ⚠️
- Some edge cases from spec may not be fully covered
- Non-strict mode has limited validation

## Next Steps

To continue improving this implementation:

2. **Strict Mode**: Implement validation for length mismatches, invalid characters, and malformed headers
3. **Key Folding**: Implement optional `keyFolding="safe"` mode for dotted-path notation
4. **Path Expansion**: Implement optional `expandPaths="safe"` mode for splitting dotted keys
5. **Better Delimiters**: Auto-select optimal delimiter on encode based on content analysis
6. **Performance**: Profile and optimize hot paths, especially for large tabular arrays

## Testing

Testing depends on the specification submodule fixtures.
