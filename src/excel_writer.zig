const std = @import("std");

/// Simple XLSX (Excel) file writer
/// Creates OpenXML-compliant Excel files without external dependencies
pub const ExcelWriter = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    rows: std.ArrayList(Row),
    sheet_name: []const u8,
    freeze_header: bool,
    auto_filter: bool,

    const Row = struct {
        cells: []Cell,

        pub fn deinit(self: Row, allocator: std.mem.Allocator) void {
            for (self.cells) |cell| {
                cell.deinit(allocator);
            }
            allocator.free(self.cells);
        }
    };

    const Cell = struct {
        value: []const u8,
        cell_type: CellType,

        const CellType = enum {
            string,
            number,
        };

        pub fn deinit(self: Cell, allocator: std.mem.Allocator) void {
            allocator.free(self.value);
        }
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !ExcelWriter {
        return ExcelWriter{
            .allocator = allocator,
            .path = try allocator.dupe(u8, path),
            .rows = std.ArrayList(Row).init(allocator),
            .sheet_name = "Sheet1",
            .freeze_header = false,
            .auto_filter = false,
        };
    }

    pub fn deinit(self: *ExcelWriter) void {
        for (self.rows.items) |row| {
            row.deinit(self.allocator);
        }
        self.rows.deinit();
        self.allocator.free(self.path);
    }

    pub fn setSheetName(self: *ExcelWriter, name: []const u8) void {
        self.sheet_name = name;
    }

    pub fn setFreezeHeader(self: *ExcelWriter, freeze: bool) void {
        self.freeze_header = freeze;
    }

    pub fn setAutoFilter(self: *ExcelWriter, enable: bool) void {
        self.auto_filter = enable;
    }

    /// Add a row of cells to the worksheet
    pub fn addRow(self: *ExcelWriter, values: []const []const u8) !void {
        var cells = try self.allocator.alloc(Cell, values.len);
        for (values, 0..) |value, i| {
            const cell_type = detectCellType(value);
            cells[i] = Cell{
                .value = try self.allocator.dupe(u8, value),
                .cell_type = cell_type,
            };
        }
        try self.rows.append(Row{ .cells = cells });
    }

    /// Detect if a value is a number or string
    fn detectCellType(value: []const u8) Cell.CellType {
        if (value.len == 0) return .string;

        // Try to parse as float
        _ = std.fmt.parseFloat(f64, value) catch {
            return .string;
        };

        return .number;
    }

    /// Write the Excel file to disk
    pub fn write(self: *ExcelWriter) !void {
        // Create temporary directory for XLSX structure
        const temp_dir = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{self.path});
        defer self.allocator.free(temp_dir);

        // Create directory structure
        try std.fs.cwd().makePath(temp_dir);
        defer std.fs.cwd().deleteTree(temp_dir) catch {};

        const rels_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "_rels" });
        defer self.allocator.free(rels_path);
        try std.fs.cwd().makePath(rels_path);

        const xl_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl" });
        defer self.allocator.free(xl_path);
        try std.fs.cwd().makePath(xl_path);

        const xl_rels_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "_rels" });
        defer self.allocator.free(xl_rels_path);
        try std.fs.cwd().makePath(xl_rels_path);

        const worksheets_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "worksheets" });
        defer self.allocator.free(worksheets_path);
        try std.fs.cwd().makePath(worksheets_path);

        // Write all required files
        try self.writeContentTypes(temp_dir);
        try self.writeRootRels(temp_dir);
        try self.writeWorkbook(temp_dir);
        try self.writeWorkbookRels(temp_dir);
        try self.writeWorksheet(temp_dir);
        try self.writeSharedStrings(temp_dir);
        try self.writeStyles(temp_dir);

        // Create ZIP archive
        try self.createZipArchive(temp_dir);
    }

    fn writeContentTypes(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "[Content_Types].xml" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            \\  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            \\  <Default Extension="xml" ContentType="application/xml"/>
            \\  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            \\  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            \\  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
            \\  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
            \\</Types>
            \\
        );
    }

    fn writeRootRels(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "_rels", ".rels" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            \\  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            \\</Relationships>
            \\
        );
    }

    fn writeWorkbook(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "workbook.xml" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.print(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            \\  <sheets>
            \\    <sheet name="{s}" sheetId="1" r:id="rId1"/>
            \\  </sheets>
            \\</workbook>
            \\
        , .{self.sheet_name});
    }

    fn writeWorkbookRels(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "_rels", "workbook.xml.rels" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            \\  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            \\  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
            \\  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            \\</Relationships>
            \\
        );
    }

    fn writeWorksheet(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "worksheets", "sheet1.xml" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        // Build shared strings table
        var shared_strings = std.StringHashMap(usize).init(self.allocator);
        defer shared_strings.deinit();
        var string_index: usize = 0;

        for (self.rows.items) |row| {
            for (row.cells) |cell| {
                if (cell.cell_type == .string) {
                    if (!shared_strings.contains(cell.value)) {
                        try shared_strings.put(try self.allocator.dupe(u8, cell.value), string_index);
                        string_index += 1;
                    }
                }
            }
        }

        // Write worksheet header
        try writer.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            \\
        );

        // Add freeze panes if header should be frozen
        if (self.freeze_header and self.rows.items.len > 0) {
            try writer.writeAll(
                \\  <sheetViews>
                \\    <sheetView workbookViewId="0">
                \\      <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
                \\    </sheetView>
                \\  </sheetViews>
                \\
            );
        }

        // Add auto filter
        if (self.auto_filter and self.rows.items.len > 0) {
            const last_col = if (self.rows.items[0].cells.len > 0) self.rows.items[0].cells.len - 1 else 0;
            const last_col_letter = try columnNumberToLetter(self.allocator, last_col);
            defer self.allocator.free(last_col_letter);

            try writer.print("  <autoFilter ref=\"A1:{s}{d}\"/>\n", .{ last_col_letter, self.rows.items.len });
        }

        try writer.writeAll("  <sheetData>\n");

        // Write rows
        for (self.rows.items, 0..) |row, row_idx| {
            try writer.print("    <row r=\"{d}\">\n", .{row_idx + 1});

            for (row.cells, 0..) |cell, col_idx| {
                const col_letter = try columnNumberToLetter(self.allocator, col_idx);
                defer self.allocator.free(col_letter);

                if (cell.cell_type == .string) {
                    const str_idx = shared_strings.get(cell.value).?;
                    try writer.print("      <c r=\"{s}{d}\" t=\"s\"><v>{d}</v></c>\n", .{ col_letter, row_idx + 1, str_idx });
                } else {
                    try writer.print("      <c r=\"{s}{d}\"><v>{s}</v></c>\n", .{ col_letter, row_idx + 1, cell.value });
                }
            }

            try writer.writeAll("    </row>\n");
        }

        try writer.writeAll(
            \\  </sheetData>
            \\</worksheet>
            \\
        );

        // Free shared strings keys
        var iter = shared_strings.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
    }

    fn writeSharedStrings(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "sharedStrings.xml" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        // Collect unique strings
        var strings = std.ArrayList([]const u8).init(self.allocator);
        defer strings.deinit();
        var seen = std.StringHashMap(void).init(self.allocator);
        defer seen.deinit();

        for (self.rows.items) |row| {
            for (row.cells) |cell| {
                if (cell.cell_type == .string and !seen.contains(cell.value)) {
                    try strings.append(cell.value);
                    try seen.put(cell.value, {});
                }
            }
        }

        try writer.print(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{d}" uniqueCount="{d}">
            \\
        , .{ strings.items.len, strings.items.len });

        for (strings.items) |str| {
            try writer.writeAll("  <si><t>");
            try writeXmlEscaped(writer, str);
            try writer.writeAll("</t></si>\n");
        }

        try writer.writeAll("</sst>\n");
    }

    fn writeStyles(self: *ExcelWriter, temp_dir: []const u8) !void {
        const path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_dir, "xl", "styles.xml" });
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            \\  <fonts count="1">
            \\    <font><sz val="11"/><name val="Calibri"/></font>
            \\  </fonts>
            \\  <fills count="1">
            \\    <fill><patternFill patternType="none"/></fill>
            \\  </fills>
            \\  <borders count="1">
            \\    <border><left/><right/><top/><bottom/><diagonal/></border>
            \\  </borders>
            \\  <cellXfs count="1">
            \\    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
            \\  </cellXfs>
            \\</styleSheet>
            \\
        );
    }

    fn createZipArchive(self: *ExcelWriter, temp_dir: []const u8) !void {
        // Use system zip command to create the archive
        const cmd = try std.fmt.allocPrint(self.allocator, "cd {s} && zip -r -q ../{s} . && cd ..", .{ temp_dir, std.fs.path.basename(self.path) });
        defer self.allocator.free(cmd);

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{
                "sh",
                "-c",
                cmd,
            },
            .cwd = std.fs.path.dirname(self.path),
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("Error creating ZIP: {s}\n", .{result.stderr});
            return error.ZipCreationFailed;
        }
    }

    fn writeXmlEscaped(writer: anytype, str: []const u8) !void {
        for (str) |c| {
            switch (c) {
                '&' => try writer.writeAll("&amp;"),
                '<' => try writer.writeAll("&lt;"),
                '>' => try writer.writeAll("&gt;"),
                '"' => try writer.writeAll("&quot;"),
                '\'' => try writer.writeAll("&apos;"),
                else => try writer.writeByte(c),
            }
        }
    }

    fn columnNumberToLetter(allocator: std.mem.Allocator, col: usize) ![]const u8 {
        var result = std.ArrayList(u8).init(allocator);
        errdefer result.deinit();

        var n = col + 1;
        while (n > 0) {
            n -= 1;
            const letter = @as(u8, @intCast((n % 26) + 'A'));
            try result.insert(0, letter);
            n /= 26;
        }

        return result.toOwnedSlice();
    }
};
