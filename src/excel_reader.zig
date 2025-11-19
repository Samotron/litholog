const std = @import("std");

/// Simple XLSX (Excel) file reader
/// Reads OpenXML-compliant Excel files without external dependencies
pub const ExcelReader = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    sheets: std.StringHashMap(Sheet),

    pub const Sheet = struct {
        name: []const u8,
        rows: []Row,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *Sheet) void {
            for (self.rows) |*row| {
                row.deinit();
            }
            self.allocator.free(self.rows);
            self.allocator.free(self.name);
        }
    };

    pub const Row = struct {
        cells: [][]const u8,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *Row) void {
            for (self.cells) |cell| {
                self.allocator.free(cell);
            }
            self.allocator.free(self.cells);
        }
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !ExcelReader {
        return ExcelReader{
            .allocator = allocator,
            .path = try allocator.dupe(u8, path),
            .sheets = std.StringHashMap(Sheet).init(allocator),
        };
    }

    pub fn deinit(self: *ExcelReader) void {
        var iter = self.sheets.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var mutable_sheet = entry.value_ptr.*;
            mutable_sheet.deinit();
        }
        self.sheets.deinit();
        self.allocator.free(self.path);
    }

    /// Read the Excel file and parse all sheets
    pub fn read(self: *ExcelReader) !void {
        // Create temporary directory to extract XLSX
        const temp_dir = try std.fmt.allocPrint(self.allocator, "{s}.extract", .{self.path});
        defer self.allocator.free(temp_dir);

        // Clean up any existing temp directory
        std.fs.cwd().deleteTree(temp_dir) catch {};

        // Extract the XLSX file (which is a ZIP archive)
        try self.extractZip(temp_dir);
        defer std.fs.cwd().deleteTree(temp_dir) catch {};

        // Parse shared strings
        const shared_strings = try self.parseSharedStrings(temp_dir);
        defer {
            for (shared_strings) |str| {
                self.allocator.free(str);
            }
            self.allocator.free(shared_strings);
        }

        // Parse workbook to get sheet names
        const sheet_names = try self.parseWorkbook(temp_dir);
        defer {
            for (sheet_names) |name| {
                self.allocator.free(name);
            }
            self.allocator.free(sheet_names);
        }

        // Parse each worksheet
        for (sheet_names, 1..) |sheet_name, sheet_idx| {
            const sheet = try self.parseWorksheet(temp_dir, sheet_idx, sheet_name, shared_strings);
            try self.sheets.put(try self.allocator.dupe(u8, sheet_name), sheet);
        }
    }

    /// Get a sheet by name
    pub fn getSheet(self: *ExcelReader, name: []const u8) ?*const Sheet {
        return self.sheets.getPtr(name);
    }

    /// Get the first sheet
    pub fn getFirstSheet(self: *ExcelReader) ?*const Sheet {
        var iter = self.sheets.valueIterator();
        return iter.next();
    }

    fn extractZip(self: *ExcelReader, dest_dir: []const u8) !void {
        // Use system unzip command
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{
                "unzip",
                "-q",
                "-o",
                self.path,
                "-d",
                dest_dir,
            },
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("Error extracting ZIP: {s}\n", .{result.stderr});
            return error.ZipExtractionFailed;
        }
    }

    fn parseSharedStrings(self: *ExcelReader, temp_dir: []const u8) ![][]const u8 {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "sharedStrings.xml" });
        defer self.allocator.free(path);

        const file = std.fs.cwd().openFile(path, .{}) catch {
            // No shared strings file - return empty array
            return try self.allocator.alloc([]const u8, 0);
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 100 * 1024 * 1024);
        defer self.allocator.free(content);

        var strings = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (strings.items) |str| {
                self.allocator.free(str);
            }
            strings.deinit();
        }

        // Simple XML parsing - find all <t>...</t> tags
        var i: usize = 0;
        while (i < content.len) {
            if (std.mem.indexOf(u8, content[i..], "<t>")) |start_idx| {
                const text_start = i + start_idx + 3;
                if (std.mem.indexOf(u8, content[text_start..], "</t>")) |end_idx| {
                    const text = content[text_start .. text_start + end_idx];
                    const decoded = try self.decodeXml(text);
                    try strings.append(decoded);
                    i = text_start + end_idx + 4;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        return strings.toOwnedSlice();
    }

    fn parseWorkbook(self: *ExcelReader, temp_dir: []const u8) ![][]const u8 {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "workbook.xml" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        var sheet_names = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (sheet_names.items) |name| {
                self.allocator.free(name);
            }
            sheet_names.deinit();
        }

        // Parse sheet names from <sheet name="..." /> tags
        var i: usize = 0;
        while (i < content.len) {
            if (std.mem.indexOf(u8, content[i..], "<sheet ")) |start_idx| {
                const tag_start = i + start_idx;
                if (std.mem.indexOf(u8, content[tag_start..], "name=\"")) |name_start_idx| {
                    const name_start = tag_start + name_start_idx + 6;
                    if (std.mem.indexOf(u8, content[name_start..], "\"")) |name_end_idx| {
                        const name = content[name_start .. name_start + name_end_idx];
                        try sheet_names.append(try self.allocator.dupe(u8, name));
                        i = name_start + name_end_idx;
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        return sheet_names.toOwnedSlice();
    }

    fn parseWorksheet(
        self: *ExcelReader,
        temp_dir: []const u8,
        sheet_idx: usize,
        sheet_name: []const u8,
        shared_strings: [][]const u8,
    ) !Sheet {
        const filename = try std.fmt.allocPrint(self.allocator, "sheet{d}.xml", .{sheet_idx});
        defer self.allocator.free(filename);

        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "worksheets", filename });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 100 * 1024 * 1024);
        defer self.allocator.free(content);

        var rows = std.ArrayList(Row).init(self.allocator);
        errdefer {
            for (rows.items) |*row| {
                row.deinit();
            }
            rows.deinit();
        }

        // Parse rows - simple approach: find <row> tags and extract cells
        var i: usize = 0;
        while (i < content.len) {
            if (std.mem.indexOf(u8, content[i..], "<row ")) |row_start_idx| {
                const row_start = i + row_start_idx;
                if (std.mem.indexOf(u8, content[row_start..], "</row>")) |row_end_idx| {
                    const row_content = content[row_start .. row_start + row_end_idx + 6];
                    const row = try self.parseRow(row_content, shared_strings);
                    try rows.append(row);
                    i = row_start + row_end_idx + 6;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        return Sheet{
            .name = try self.allocator.dupe(u8, sheet_name),
            .rows = try rows.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    fn parseRow(self: *ExcelReader, row_xml: []const u8, shared_strings: [][]const u8) !Row {
        var cells = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (cells.items) |cell| {
                self.allocator.free(cell);
            }
            cells.deinit();
        }

        var i: usize = 0;
        while (i < row_xml.len) {
            if (std.mem.indexOf(u8, row_xml[i..], "<c ")) |cell_start_idx| {
                const cell_start = i + cell_start_idx;
                if (std.mem.indexOf(u8, row_xml[cell_start..], "</c>")) |cell_end_idx| {
                    const cell_xml = row_xml[cell_start .. cell_start + cell_end_idx + 4];
                    const cell_value = try self.parseCellValue(cell_xml, shared_strings);
                    try cells.append(cell_value);
                    i = cell_start + cell_end_idx + 4;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        return Row{
            .cells = try cells.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    fn parseCellValue(self: *ExcelReader, cell_xml: []const u8, shared_strings: [][]const u8) ![]const u8 {
        // Check if it's a shared string (t="s")
        const is_shared_string = std.mem.indexOf(u8, cell_xml, "t=\"s\"") != null;

        // Find the value
        if (std.mem.indexOf(u8, cell_xml, "<v>")) |v_start_idx| {
            const value_start = v_start_idx + 3;
            if (std.mem.indexOf(u8, cell_xml[value_start..], "</v>")) |v_end_idx| {
                const value = cell_xml[value_start .. value_start + v_end_idx];

                if (is_shared_string) {
                    // Look up in shared strings
                    const index = try std.fmt.parseInt(usize, value, 10);
                    if (index < shared_strings.len) {
                        return try self.allocator.dupe(u8, shared_strings[index]);
                    }
                }

                return try self.allocator.dupe(u8, value);
            }
        }

        // Empty cell
        return try self.allocator.dupe(u8, "");
    }

    fn decodeXml(self: *ExcelReader, text: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == '&') {
                if (std.mem.startsWith(u8, text[i..], "&amp;")) {
                    try result.append('&');
                    i += 5;
                } else if (std.mem.startsWith(u8, text[i..], "&lt;")) {
                    try result.append('<');
                    i += 4;
                } else if (std.mem.startsWith(u8, text[i..], "&gt;")) {
                    try result.append('>');
                    i += 4;
                } else if (std.mem.startsWith(u8, text[i..], "&quot;")) {
                    try result.append('"');
                    i += 6;
                } else if (std.mem.startsWith(u8, text[i..], "&apos;")) {
                    try result.append('\'');
                    i += 6;
                } else {
                    try result.append(text[i]);
                    i += 1;
                }
            } else {
                try result.append(text[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice();
    }
};
