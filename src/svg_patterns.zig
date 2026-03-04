const std = @import("std");
const ags_reader = @import("ags_reader.zig");

pub fn defs() []const u8 {
    return 
    \\<defs>
    \\  <pattern id="pat-default" patternUnits="userSpaceOnUse" width="8" height="8">
    \\    <rect width="8" height="8" fill="#f8f8f8"/>
    \\  </pattern>
    \\  <pattern id="pat-clay" patternUnits="userSpaceOnUse" width="8" height="8">
    \\    <rect width="8" height="8" fill="#f4f4f4"/>
    \\    <line x1="0" y1="2" x2="8" y2="2" stroke="#666" stroke-width="0.6"/>
    \\    <line x1="0" y1="6" x2="8" y2="6" stroke="#666" stroke-width="0.6"/>
    \\  </pattern>
    \\  <pattern id="pat-silt" patternUnits="userSpaceOnUse" width="8" height="8">
    \\    <rect width="8" height="8" fill="#f7f7f7"/>
    \\    <circle cx="2" cy="2" r="0.7" fill="#666"/>
    \\    <circle cx="6" cy="6" r="0.7" fill="#666"/>
    \\  </pattern>
    \\  <pattern id="pat-sand" patternUnits="userSpaceOnUse" width="10" height="10">
    \\    <rect width="10" height="10" fill="#fafafa"/>
    \\    <circle cx="2" cy="2" r="0.8" fill="#666"/>
    \\    <circle cx="7" cy="4" r="0.8" fill="#666"/>
    \\    <circle cx="4" cy="8" r="0.8" fill="#666"/>
    \\  </pattern>
    \\  <pattern id="pat-gravel" patternUnits="userSpaceOnUse" width="14" height="14">
    \\    <rect width="14" height="14" fill="#fbfbfb"/>
    \\    <ellipse cx="3" cy="4" rx="2" ry="1.5" fill="none" stroke="#555" stroke-width="0.7"/>
    \\    <ellipse cx="10" cy="5" rx="2.2" ry="1.7" fill="none" stroke="#555" stroke-width="0.7"/>
    \\    <ellipse cx="7" cy="11" rx="2" ry="1.5" fill="none" stroke="#555" stroke-width="0.7"/>
    \\  </pattern>
    \\  <pattern id="pat-sand-gravel" patternUnits="userSpaceOnUse" width="14" height="14">
    \\    <rect width="14" height="14" fill="#fbfbfb"/>
    \\    <ellipse cx="3" cy="4" rx="2" ry="1.5" fill="none" stroke="#555" stroke-width="0.7"/>
    \\    <ellipse cx="10" cy="9" rx="2" ry="1.5" fill="none" stroke="#555" stroke-width="0.7"/>
    \\    <circle cx="7" cy="3" r="0.8" fill="#666"/>
    \\    <circle cx="5" cy="12" r="0.8" fill="#666"/>
    \\  </pattern>
    \\  <pattern id="pat-peat" patternUnits="userSpaceOnUse" width="12" height="10">
    \\    <rect width="12" height="10" fill="#f5f5f5"/>
    \\    <path d="M0,5 C2,3 4,7 6,5 C8,3 10,7 12,5" fill="none" stroke="#555" stroke-width="0.7"/>
    \\  </pattern>
    \\  <pattern id="pat-made-ground" patternUnits="userSpaceOnUse" width="12" height="12">
    \\    <rect width="12" height="12" fill="#f5f5f5"/>
    \\    <polygon points="1,9 4,3 7,9" fill="none" stroke="#555" stroke-width="0.7"/>
    \\    <circle cx="9" cy="4" r="1" fill="#666"/>
    \\  </pattern>
    \\  <pattern id="pat-rock" patternUnits="userSpaceOnUse" width="10" height="10">
    \\    <rect width="10" height="10" fill="#f6f6f6"/>
    \\    <path d="M0,10 L5,4 L10,10" fill="none" stroke="#555" stroke-width="0.7"/>
    \\  </pattern>
    \\</defs>
    ;
}

pub fn patternForStratum(stratum: ags_reader.AgsStratum) []const u8 {
    if (stratum.parsed) |p| {
        if (p.is_made_ground) return "pat-made-ground";
        if (p.material_type == .soil) {
            if (p.secondary_primary_soil_type != null and p.primary_soil_type != null) {
                const a = p.primary_soil_type.?;
                const b = p.secondary_primary_soil_type.?;
                const sand_gravel = (a == .sand and b == .gravel) or (a == .gravel and b == .sand);
                if (sand_gravel) return "pat-sand-gravel";
            }
            if (p.primary_soil_type) |st| {
                return switch (st) {
                    .clay => "pat-clay",
                    .silt => "pat-silt",
                    .sand => "pat-sand",
                    .gravel, .cobbles, .boulders => "pat-gravel",
                    .peat, .organic => "pat-peat",
                };
            }
        }
        if (p.material_type == .rock) return "pat-rock";
    }
    return "pat-default";
}
