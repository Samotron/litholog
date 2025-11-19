const std = @import("std");
const bs5930 = @import("parser/bs5930.zig");
const unit_identifier = @import("parser/unit_identifier.zig");
const spatial = @import("parser/spatial.zig");
const excel_writer = @import("excel_writer.zig");
const excel_reader = @import("excel_reader.zig");

pub const CsvOptions = struct {
    input_column: []const u8,
    output_columns: []const []const u8,
    has_header: bool = true,
    delimiter: u8 = ',',
    // Unit identification options
    identify_units: bool = false,
    borehole_id_column: ?[]const u8 = null,
    depth_top_column: ?[]const u8 = null,
    depth_bottom_column: ?[]const u8 = null,
    // Spatial analysis options
    spatial_analysis: bool = false,
    x_column: ?[]const u8 = null,
    y_column: ?[]const u8 = null,
    z_column: ?[]const u8 = null,
    spatial_cluster: bool = false,
    cluster_epsilon: f64 = 10.0, // Default 10 meters
    cluster_min_points: usize = 3,
    // Excel options
    excel_format: bool = false,
    freeze_header: bool = false,
    auto_filter: bool = false,
    sheet_name: ?[]const u8 = null,
};

pub const CsvProcessor = struct {
    allocator: std.mem.Allocator,
    parser: bs5930.Parser,

    pub fn init(allocator: std.mem.Allocator) CsvProcessor {
        return CsvProcessor{
            .allocator = allocator,
            .parser = bs5930.Parser.init(allocator),
        };
    }

    pub fn processFile(
        self: *CsvProcessor,
        input_path: []const u8,
        output_path: []const u8,
        options: CsvOptions,
    ) !void {
        // Detect input format
        const is_input_excel = std.mem.endsWith(u8, input_path, ".xlsx");

        // Detect output format from file extension or excel_format flag
        const is_output_excel = options.excel_format or std.mem.endsWith(u8, output_path, ".xlsx");

        // If input is Excel, read it first
        if (is_input_excel) {
            return self.processExcelFile(input_path, output_path, options);
        }

        if (is_output_excel) {
            return self.processFileToExcel(input_path, output_path, options);
        }

        // If unit identification is requested, use the enhanced processor
        if (options.identify_units) {
            return self.processFileWithUnits(input_path, output_path, options);
        }

        // Original processing without unit identification
        // Read input file
        const file = try std.fs.cwd().openFile(input_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 100 * 1024 * 1024); // 100MB max
        defer self.allocator.free(content);

        // Create output file
        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();

        const writer = output_file.writer();

        // Parse CSV and process
        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_num: usize = 0;
        var input_col_idx: ?usize = null;

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            // Parse columns from line
            const columns = try self.parseCsvLine(trimmed, options.delimiter);
            defer {
                for (columns) |col| {
                    self.allocator.free(col);
                }
                self.allocator.free(columns);
            }

            // First row - handle header
            if (line_num == 0 and options.has_header) {
                // Find input column index
                for (columns, 0..) |col, idx| {
                    if (std.mem.eql(u8, col, options.input_column)) {
                        input_col_idx = idx;
                    }
                }

                if (input_col_idx == null) {
                    return error.InputColumnNotFound;
                }

                // Write output header
                try self.writeHeader(writer, columns, options.output_columns);
                continue;
            }

            // For rows without header, assume column is a number (0-indexed)
            if (input_col_idx == null) {
                input_col_idx = std.fmt.parseInt(usize, options.input_column, 10) catch {
                    return error.InvalidInputColumn;
                };
            }

            const col_idx = input_col_idx.?;
            if (col_idx >= columns.len) {
                // Skip rows with missing column
                continue;
            }

            const description = columns[col_idx];

            // Parse the description
            const result = self.parser.parse(description) catch |err| {
                std.debug.print("Error parsing row {}: {}\n", .{ line_num + 1, err });
                continue;
            };
            defer result.deinit(self.allocator);

            // Write output row
            try self.writeRow(writer, columns, &result, options.output_columns);
        }
    }

    fn processFileToExcel(
        self: *CsvProcessor,
        input_path: []const u8,
        output_path: []const u8,
        options: CsvOptions,
    ) !void {
        // Read input file
        const file = try std.fs.cwd().openFile(input_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 100 * 1024 * 1024); // 100MB max
        defer self.allocator.free(content);

        // Create Excel writer
        var excel = try excel_writer.ExcelWriter.init(self.allocator, output_path);
        defer excel.deinit();

        // Configure Excel options
        if (options.sheet_name) |name| {
            excel.setSheetName(name);
        }
        excel.setFreezeHeader(options.freeze_header);
        excel.setAutoFilter(options.auto_filter);

        // Parse CSV and process
        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_num: usize = 0;
        var input_col_idx: ?usize = null;

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            // Parse columns from line
            const columns = try self.parseCsvLine(trimmed, options.delimiter);
            defer {
                for (columns) |col| {
                    self.allocator.free(col);
                }
                self.allocator.free(columns);
            }

            // First row - handle header
            if (line_num == 0 and options.has_header) {
                // Find input column index
                for (columns, 0..) |col, idx| {
                    if (std.mem.eql(u8, col, options.input_column)) {
                        input_col_idx = idx;
                    }
                }

                if (input_col_idx == null) {
                    return error.InputColumnNotFound;
                }

                // Write header to Excel
                var header_row = std.ArrayList([]const u8).init(self.allocator);
                defer header_row.deinit();

                for (columns) |col| {
                    try header_row.append(col);
                }
                for (options.output_columns) |col| {
                    try header_row.append(col);
                }

                try excel.addRow(header_row.items);
                continue;
            }

            // For rows without header, assume column is a number (0-indexed)
            if (input_col_idx == null) {
                input_col_idx = std.fmt.parseInt(usize, options.input_column, 10) catch {
                    return error.InvalidInputColumn;
                };
            }

            const col_idx = input_col_idx.?;
            if (col_idx >= columns.len) {
                // Skip rows with missing column
                continue;
            }

            const description = columns[col_idx];

            // Parse the description
            const result = self.parser.parse(description) catch |err| {
                std.debug.print("Error parsing row {}: {}\n", .{ line_num + 1, err });
                continue;
            };
            defer result.deinit(self.allocator);

            // Build Excel row
            var row = std.ArrayList([]const u8).init(self.allocator);
            defer row.deinit();

            // Track allocated values to free later
            var allocated_values = std.ArrayList([]const u8).init(self.allocator);
            defer {
                for (allocated_values.items) |v| {
                    self.allocator.free(v);
                }
                allocated_values.deinit();
            }

            for (columns) |col| {
                try row.append(col);
            }

            // Add result columns
            for (options.output_columns) |col_name| {
                const value = try self.getResultValue(&result, col_name);
                if (value) |v| {
                    try row.append(v);
                    try allocated_values.append(v); // Track for later freeing
                } else {
                    try row.append("");
                }
            }

            try excel.addRow(row.items);
        }

        // Write Excel file
        try excel.write();
    }

    fn processFileWithUnits(
        self: *CsvProcessor,
        input_path: []const u8,
        output_path: []const u8,
        options: CsvOptions,
    ) !void {
        // Validate required columns for unit identification
        if (options.borehole_id_column == null or
            options.depth_top_column == null or
            options.depth_bottom_column == null)
        {
            return error.MissingUnitIdentificationColumns;
        }

        // Read input file
        const file = try std.fs.cwd().openFile(input_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 100 * 1024 * 1024); // 100MB max
        defer self.allocator.free(content);

        // First pass: collect all entries for unit identification
        var entries = std.ArrayList(unit_identifier.BoreholeEntry).init(self.allocator);
        defer {
            for (entries.items) |*entry| {
                entry.deinit(self.allocator);
            }
            entries.deinit();
        }

        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_num: usize = 0;
        var input_col_idx: ?usize = null;
        var bh_col_idx: ?usize = null;
        var depth_top_col_idx: ?usize = null;
        var depth_bottom_col_idx: ?usize = null;
        var header_columns: ?[][]const u8 = null;
        defer if (header_columns) |hc| {
            for (hc) |col| {
                self.allocator.free(col);
            }
            self.allocator.free(hc);
        };

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            const columns = try self.parseCsvLine(trimmed, options.delimiter);
            defer {
                if (line_num > 0 or !options.has_header) {
                    for (columns) |col| {
                        self.allocator.free(col);
                    }
                    self.allocator.free(columns);
                }
            }

            // First row - handle header
            if (line_num == 0 and options.has_header) {
                header_columns = columns;
                for (columns, 0..) |col, idx| {
                    if (std.mem.eql(u8, col, options.input_column)) {
                        input_col_idx = idx;
                    }
                    if (std.mem.eql(u8, col, options.borehole_id_column.?)) {
                        bh_col_idx = idx;
                    }
                    if (std.mem.eql(u8, col, options.depth_top_column.?)) {
                        depth_top_col_idx = idx;
                    }
                    if (std.mem.eql(u8, col, options.depth_bottom_column.?)) {
                        depth_bottom_col_idx = idx;
                    }
                }

                if (input_col_idx == null) return error.InputColumnNotFound;
                if (bh_col_idx == null) return error.BoreholeIdColumnNotFound;
                if (depth_top_col_idx == null) return error.DepthTopColumnNotFound;
                if (depth_bottom_col_idx == null) return error.DepthBottomColumnNotFound;
                continue;
            }

            // For rows without header, use column indices
            if (input_col_idx == null) {
                input_col_idx = try std.fmt.parseInt(usize, options.input_column, 10);
                bh_col_idx = try std.fmt.parseInt(usize, options.borehole_id_column.?, 10);
                depth_top_col_idx = try std.fmt.parseInt(usize, options.depth_top_column.?, 10);
                depth_bottom_col_idx = try std.fmt.parseInt(usize, options.depth_bottom_column.?, 10);
            }

            // Extract values
            if (input_col_idx.? >= columns.len or
                bh_col_idx.? >= columns.len or
                depth_top_col_idx.? >= columns.len or
                depth_bottom_col_idx.? >= columns.len)
            {
                continue;
            }

            const description = columns[input_col_idx.?];
            const borehole_id = columns[bh_col_idx.?];
            const depth_top_str = columns[depth_top_col_idx.?];
            const depth_bottom_str = columns[depth_bottom_col_idx.?];

            // Parse depths
            const depth_top = std.fmt.parseFloat(f64, depth_top_str) catch {
                std.debug.print("Warning: Invalid depth_top '{s}' on row {}\n", .{ depth_top_str, line_num + 1 });
                continue;
            };
            const depth_bottom = std.fmt.parseFloat(f64, depth_bottom_str) catch {
                std.debug.print("Warning: Invalid depth_bottom '{s}' on row {}\n", .{ depth_bottom_str, line_num + 1 });
                continue;
            };

            // Parse the geological description
            const result = self.parser.parse(description) catch |err| {
                std.debug.print("Error parsing row {}: {}\n", .{ line_num + 1, err });
                continue;
            };

            // Store entry
            try entries.append(.{
                .borehole_id = try self.allocator.dupe(u8, borehole_id),
                .depth_top = depth_top,
                .depth_bottom = depth_bottom,
                .description = result,
            });
        }

        // Identify geological units
        var identifier = unit_identifier.UnitIdentifier.init(self.allocator);
        var summary = try identifier.identifyUnits(entries.items);
        defer summary.deinit(self.allocator);

        // Format and print unit summary to stdout
        const table = try unit_identifier.formatUnitsTable(self.allocator, &summary);
        defer self.allocator.free(table);

        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll(table);

        // Second pass: write output CSV with unit assignments
        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();
        const writer = output_file.writer();

        // Reset for second pass
        lines = std.mem.splitScalar(u8, content, '\n');
        line_num = 0;
        var entry_idx: usize = 0;

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;

            const columns = try self.parseCsvLine(trimmed, options.delimiter);
            defer {
                for (columns) |col| {
                    self.allocator.free(col);
                }
                self.allocator.free(columns);
            }

            // First row - write header with unit_id column
            if (line_num == 0 and options.has_header) {
                for (columns, 0..) |col, idx| {
                    if (idx > 0) try writer.writeAll(",");
                    try self.writeCsvField(writer, col);
                }
                try writer.writeAll(",unit_id\n");
                continue;
            }

            // Skip invalid rows
            if (input_col_idx.? >= columns.len) {
                continue;
            }

            // Write original columns
            for (columns, 0..) |col, idx| {
                if (idx > 0) try writer.writeAll(",");
                try self.writeCsvField(writer, col);
            }

            // Add unit ID from mapping
            if (entry_idx < summary.entry_to_unit.len) {
                try writer.print(",{d}\n", .{summary.entry_to_unit[entry_idx]});
                entry_idx += 1;
            } else {
                try writer.writeAll(",\n");
            }
        }
    }

    fn parseCsvLine(self: *CsvProcessor, line: []const u8, delimiter: u8) ![][]const u8 {
        var columns = std.ArrayList([]const u8).init(self.allocator);
        errdefer columns.deinit();

        var i: usize = 0;
        var start: usize = 0;
        var in_quotes = false;

        while (i < line.len) : (i += 1) {
            const char = line[i];

            if (char == '"') {
                in_quotes = !in_quotes;
            } else if (char == delimiter and !in_quotes) {
                const field = try self.unquoteCsvField(line[start..i]);
                try columns.append(field);
                start = i + 1;
            }
        }

        // Add last field
        const field = try self.unquoteCsvField(line[start..]);
        try columns.append(field);

        return columns.toOwnedSlice();
    }

    fn unquoteCsvField(self: *CsvProcessor, field: []const u8) ![]const u8 {
        const trimmed = std.mem.trim(u8, field, " \t");

        if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
            // Remove quotes and unescape double quotes
            const unquoted = trimmed[1 .. trimmed.len - 1];
            // Handle escaped quotes (double quotes inside quoted strings)
            if (std.mem.indexOf(u8, unquoted, "\"\"")) |_| {
                var result = std.ArrayList(u8).init(self.allocator);
                defer result.deinit();

                var i: usize = 0;
                while (i < unquoted.len) : (i += 1) {
                    if (i + 1 < unquoted.len and unquoted[i] == '"' and unquoted[i + 1] == '"') {
                        try result.append('"');
                        i += 1; // Skip second quote
                    } else {
                        try result.append(unquoted[i]);
                    }
                }
                return result.toOwnedSlice();
            }
            return try self.allocator.dupe(u8, unquoted);
        }

        return try self.allocator.dupe(u8, trimmed);
    }

    fn writeHeader(
        self: *CsvProcessor,
        writer: anytype,
        input_columns: [][]const u8,
        output_columns: []const []const u8,
    ) !void {
        // Write all original columns
        for (input_columns, 0..) |col, idx| {
            if (idx > 0) try writer.writeAll(",");
            try self.writeCsvField(writer, col);
        }

        // Add result columns
        for (output_columns) |col| {
            try writer.writeAll(",");
            try self.writeCsvField(writer, col);
        }

        try writer.writeAll("\n");
    }

    fn writeRow(
        self: *CsvProcessor,
        writer: anytype,
        input_columns: [][]const u8,
        result: *const bs5930.SoilDescription,
        output_columns: []const []const u8,
    ) !void {
        // Write all original columns
        for (input_columns, 0..) |col, idx| {
            if (idx > 0) try writer.writeAll(",");
            try self.writeCsvField(writer, col);
        }

        // Add result columns
        for (output_columns) |col_name| {
            try writer.writeAll(",");

            const value = try self.getResultValue(result, col_name);
            defer if (value) |v| self.allocator.free(v);

            if (value) |v| {
                try self.writeCsvField(writer, v);
            }
        }

        try writer.writeAll("\n");
    }

    fn writeCsvField(self: *CsvProcessor, writer: anytype, field: []const u8) !void {
        _ = self;

        // Check if field needs quoting (contains comma, quote, or newline)
        const needs_quotes = std.mem.indexOfAny(u8, field, ",\"\n\r") != null;

        if (needs_quotes) {
            try writer.writeAll("\"");
            // Escape quotes by doubling them
            var i: usize = 0;
            while (i < field.len) : (i += 1) {
                if (field[i] == '"') {
                    try writer.writeAll("\"\"");
                } else {
                    try writer.writeByte(field[i]);
                }
            }
            try writer.writeAll("\"");
        } else {
            try writer.writeAll(field);
        }
    }

    fn getResultValue(
        self: *CsvProcessor,
        result: *const bs5930.SoilDescription,
        field_name: []const u8,
    ) !?[]const u8 {
        // Map field names to result properties
        if (std.mem.eql(u8, field_name, "material_type")) {
            return try std.fmt.allocPrint(self.allocator, "{s}", .{result.material_type.toString()});
        } else if (std.mem.eql(u8, field_name, "consistency")) {
            if (result.consistency) |c| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{c.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "density")) {
            if (result.density) |d| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{d.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "primary_soil_type")) {
            if (result.primary_soil_type) |pst| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{pst.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "primary_rock_type")) {
            if (result.primary_rock_type) |prt| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{prt.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "rock_strength")) {
            if (result.rock_strength) |rs| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{rs.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "weathering_grade")) {
            if (result.weathering_grade) |wg| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{wg.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "color")) {
            if (result.color) |color| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{color.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "moisture_content")) {
            if (result.moisture_content) |mc| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{mc.toString()});
            }
        } else if (std.mem.eql(u8, field_name, "confidence")) {
            return try std.fmt.allocPrint(self.allocator, "{d:.3}", .{result.confidence});
        } else if (std.mem.eql(u8, field_name, "is_valid")) {
            return try std.fmt.allocPrint(self.allocator, "{s}", .{if (result.is_valid) "true" else "false"});
        } else if (std.mem.eql(u8, field_name, "strength_lower")) {
            if (result.strength_parameters) |sp| {
                return try std.fmt.allocPrint(self.allocator, "{d}", .{sp.range.lower_bound});
            }
        } else if (std.mem.eql(u8, field_name, "strength_upper")) {
            if (result.strength_parameters) |sp| {
                return try std.fmt.allocPrint(self.allocator, "{d}", .{sp.range.upper_bound});
            }
        } else if (std.mem.eql(u8, field_name, "strength_typical")) {
            if (result.strength_parameters) |sp| {
                if (sp.range.typical_value) |tv| {
                    return try std.fmt.allocPrint(self.allocator, "{d}", .{tv});
                } else {
                    return try std.fmt.allocPrint(self.allocator, "{d}", .{sp.range.getMidpoint()});
                }
            }
        } else if (std.mem.eql(u8, field_name, "strength_unit")) {
            if (result.strength_parameters) |sp| {
                return try std.fmt.allocPrint(self.allocator, "{s}", .{sp.parameter_type.getUnits()});
            }
        } else if (std.mem.eql(u8, field_name, "json")) {
            return try result.toJson(self.allocator);
        }

        return null;
    }

    /// Helper to get spatial-specific field values
    fn getSpatialValue(
        self: *CsvProcessor,
        unit: *const spatial.SpatialUnit,
        field_name: []const u8,
    ) !?[]const u8 {
        if (std.mem.eql(u8, field_name, "x_coord")) {
            return try std.fmt.allocPrint(self.allocator, "{d:.2}", .{unit.location.x});
        } else if (std.mem.eql(u8, field_name, "y_coord")) {
            return try std.fmt.allocPrint(self.allocator, "{d:.2}", .{unit.location.y});
        } else if (std.mem.eql(u8, field_name, "z_coord")) {
            return try std.fmt.allocPrint(self.allocator, "{d:.2}", .{unit.location.z});
        } else if (std.mem.eql(u8, field_name, "thickness")) {
            return try std.fmt.allocPrint(self.allocator, "{d:.2}", .{unit.thickness});
        } else if (std.mem.eql(u8, field_name, "mid_depth")) {
            return try std.fmt.allocPrint(self.allocator, "{d:.2}", .{unit.mid_depth});
        } else if (std.mem.eql(u8, field_name, "elevation")) {
            const elevation = unit.location.z - unit.mid_depth;
            return try std.fmt.allocPrint(self.allocator, "{d:.2}", .{elevation});
        }
        return null;
    }

    /// Process an Excel file (read .xlsx, process data, write to CSV or Excel)
    fn processExcelFile(
        self: *CsvProcessor,
        input_path: []const u8,
        output_path: []const u8,
        options: CsvOptions,
    ) !void {
        // Read Excel file
        var reader = try excel_reader.ExcelReader.init(self.allocator, input_path);
        defer reader.deinit();

        try reader.read();

        // Get the first sheet
        const sheet = reader.getFirstSheet() orelse return error.NoSheetsFound;

        if (sheet.rows.len == 0) return error.EmptySheet;

        // Detect output format
        const is_output_excel = options.excel_format or std.mem.endsWith(u8, output_path, ".xlsx");

        // Find input column index from header row
        var input_col_idx: ?usize = null;
        if (options.has_header and sheet.rows.len > 0) {
            const header_row = sheet.rows[0];
            for (header_row.cells, 0..) |cell, idx| {
                if (std.mem.eql(u8, cell, options.input_column)) {
                    input_col_idx = idx;
                    break;
                }
            }
        }

        if (input_col_idx == null) {
            return error.InputColumnNotFound;
        }

        const col_idx = input_col_idx.?;

        // Process based on output format
        if (is_output_excel) {
            try self.processExcelToExcel(sheet, output_path, options, col_idx);
        } else {
            try self.processExcelToCsv(sheet, output_path, options, col_idx);
        }
    }

    fn processExcelToExcel(
        self: *CsvProcessor,
        sheet: *const excel_reader.ExcelReader.Sheet,
        output_path: []const u8,
        options: CsvOptions,
        input_col_idx: usize,
    ) !void {
        var writer = try excel_writer.ExcelWriter.init(
            self.allocator,
            output_path,
        );
        defer writer.deinit();

        // Set writer options
        writer.sheet_name = options.sheet_name orelse "Lithology";
        writer.freeze_header = options.freeze_header;
        writer.auto_filter = options.auto_filter;

        // Process each row
        var row_idx: usize = 0;
        for (sheet.rows) |row| {
            if (row_idx == 0 and options.has_header) {
                // Write header row
                var header_cells = std.ArrayList([]const u8).init(self.allocator);
                defer header_cells.deinit();

                // Add original columns
                for (row.cells) |cell| {
                    try header_cells.append(cell);
                }

                // Add output columns
                for (options.output_columns) |col_name| {
                    try header_cells.append(col_name);
                }

                try writer.addRow(header_cells.items);
                row_idx += 1;
                continue;
            }

            // Get description from input column
            if (input_col_idx >= row.cells.len) continue;
            const description = row.cells[input_col_idx];

            // Parse the description
            const result = try self.parser.parse(description);
            defer result.deinit(self.allocator);

            // Build output row
            var output_cells = std.ArrayList([]const u8).init(self.allocator);
            defer {
                for (output_cells.items) |cell| {
                    self.allocator.free(cell);
                }
                output_cells.deinit();
            }

            // Add original columns
            for (row.cells) |cell| {
                try output_cells.append(try self.allocator.dupe(u8, cell));
            }

            // Add parsed columns
            for (options.output_columns) |col_name| {
                if (try self.getResultValue(&result, col_name)) |value| {
                    try output_cells.append(value);
                } else {
                    try output_cells.append(try self.allocator.dupe(u8, ""));
                }
            }

            try writer.addRow(output_cells.items);
            row_idx += 1;
        }

        // Write to file
        try writer.write();
    }

    fn processExcelToCsv(
        self: *CsvProcessor,
        sheet: *const excel_reader.ExcelReader.Sheet,
        output_path: []const u8,
        options: CsvOptions,
        input_col_idx: usize,
    ) !void {
        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();

        const writer = output_file.writer();

        // Process each row
        var row_idx: usize = 0;
        for (sheet.rows) |row| {
            if (row_idx == 0 and options.has_header) {
                // Write header row
                for (row.cells, 0..) |cell, idx| {
                    if (idx > 0) try writer.writeByte(options.delimiter);
                    try self.writeCsvField(writer, cell);
                }

                // Add output columns
                for (options.output_columns) |col_name| {
                    try writer.writeByte(options.delimiter);
                    try self.writeCsvField(writer, col_name);
                }

                try writer.writeByte('\n');
                row_idx += 1;
                continue;
            }

            // Get description from input column
            if (input_col_idx >= row.cells.len) continue;
            const description = row.cells[input_col_idx];

            // Parse the description
            const result = try self.parser.parse(description);
            defer result.deinit(self.allocator);

            // Write original columns
            for (row.cells, 0..) |cell, idx| {
                if (idx > 0) try writer.writeByte(options.delimiter);
                try self.writeCsvField(writer, cell);
            }

            // Write parsed columns
            for (options.output_columns) |col_name| {
                try writer.writeByte(options.delimiter);
                if (try self.getResultValue(&result, col_name)) |value| {
                    defer self.allocator.free(value);
                    try self.writeCsvField(writer, value);
                } else {
                    try self.writeCsvField(writer, "");
                }
            }

            try writer.writeByte('\n');
            row_idx += 1;
        }
    }
};
