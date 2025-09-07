"""
Python bindings for litholog geological description parser.

This module provides Python access to the litholog C library for parsing
geological descriptions according to BS5930 standards.
"""

__version__ = "0.1.0"

import ctypes
import json
from ctypes import Structure, POINTER, c_char_p, c_int, c_double, c_void_p
from enum import IntEnum
from typing import Optional, List, Dict, Any


class MaterialType(IntEnum):
    """Geological material type enumeration."""
    SOIL = 0
    ROCK = 1


class Consistency(IntEnum):
    """Soil consistency enumeration."""
    VERY_SOFT = 0
    SOFT = 1
    FIRM = 2
    STIFF = 3
    VERY_STIFF = 4
    HARD = 5
    SOFT_TO_FIRM = 6
    FIRM_TO_STIFF = 7
    STIFF_TO_VERY_STIFF = 8


class Density(IntEnum):
    """Soil density enumeration."""
    VERY_LOOSE = 0
    LOOSE = 1
    MEDIUM_DENSE = 2
    DENSE = 3
    VERY_DENSE = 4


class RockStrength(IntEnum):
    """Rock strength enumeration."""
    VERY_WEAK = 0
    WEAK = 1
    MODERATELY_WEAK = 2
    MODERATELY_STRONG = 3
    STRONG = 4
    VERY_STRONG = 5
    EXTREMELY_STRONG = 6


class SoilType(IntEnum):
    """Primary soil type enumeration."""
    CLAY = 0
    SILT = 1
    SAND = 2
    GRAVEL = 3
    PEAT = 4
    ORGANIC = 5


class RockType(IntEnum):
    """Primary rock type enumeration."""
    LIMESTONE = 0
    SANDSTONE = 1
    MUDSTONE = 2
    SHALE = 3
    GRANITE = 4
    BASALT = 5
    CHALK = 6
    DOLOMITE = 7
    QUARTZITE = 8
    SLATE = 9
    SCHIST = 10
    GNEISS = 11
    MARBLE = 12
    CONGLOMERATE = 13
    BRECCIA = 14


class WeatheringGrade(IntEnum):
    """Rock weathering grade enumeration."""
    FRESH = 0
    SLIGHTLY_WEATHERED = 1
    MODERATELY_WEATHERED = 2
    HIGHLY_WEATHERED = 3
    COMPLETELY_WEATHERED = 4


class RockStructure(IntEnum):
    """Rock structure enumeration."""
    MASSIVE = 0
    BEDDED = 1
    JOINTED = 2
    FRACTURED = 3
    FOLIATED = 4
    LAMINATED = 5


class StrengthParameterType(IntEnum):
    """Strength parameter type enumeration."""
    UCS = 0
    UNDRAINED_SHEAR_STRENGTH = 1
    SPT_N_VALUE = 2
    FRICTION_ANGLE = 3


# C Structure definitions
class CSecondaryConstituent(Structure):
    """C structure for secondary constituents."""
    _fields_ = [
        ("amount", c_char_p),
        ("soil_type", c_char_p),
    ]


class CStrengthRange(Structure):
    """C structure for strength ranges."""
    _fields_ = [
        ("lower_bound", c_double),
        ("upper_bound", c_double),
        ("typical_value", c_double),
        ("has_typical_value", c_int),
    ]


class CStrengthParameters(Structure):
    """C structure for strength parameters."""
    _fields_ = [
        ("parameter_type", c_int),
        ("value_range", CStrengthRange),
        ("confidence", c_double),
    ]


class CSoilDescription(Structure):
    """C structure for soil descriptions."""
    _fields_ = [
        ("raw_description", c_char_p),
        ("material_type", c_int),
        ("consistency", c_int),
        ("density", c_int),
        ("primary_soil_type", c_int),
        ("rock_strength", c_int),
        ("weathering_grade", c_int),
        ("rock_structure", c_int),
        ("primary_rock_type", c_int),
        ("secondary_constituents", POINTER(CSecondaryConstituent)),
        ("secondary_constituents_count", c_int),
        ("strength_parameters", POINTER(CStrengthParameters)),
        ("has_strength_parameters", c_int),
        ("confidence", c_double),
    ]


class SecondaryConstituent:
    """Represents a secondary constituent in the soil."""
    
    def __init__(self, amount: str, soil_type: str):
        self.amount = amount
        self.soil_type = soil_type
    
    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary representation."""
        return {
            "amount": self.amount,
            "soil_type": self.soil_type
        }


class StrengthRange:
    """Represents a range of strength values."""
    
    def __init__(self, lower_bound: float, upper_bound: float, 
                 typical_value: float, has_typical: bool):
        self.lower_bound = lower_bound
        self.upper_bound = upper_bound
        self.typical_value = typical_value
        self.has_typical = has_typical
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        return {
            "lower_bound": self.lower_bound,
            "upper_bound": self.upper_bound,
            "typical_value": self.typical_value,
            "has_typical": self.has_typical
        }


class StrengthParameters:
    """Represents strength parameters for the material."""
    
    def __init__(self, parameter_type: StrengthParameterType, 
                 value_range: StrengthRange, confidence: float):
        self.parameter_type = parameter_type
        self.value_range = value_range
        self.confidence = confidence
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        return {
            "parameter_type": self.parameter_type.name,
            "value_range": self.value_range.to_dict(),
            "confidence": self.confidence
        }


class SoilDescription:
    """Represents a parsed geological description."""
    
    def __init__(self):
        self.raw_description: str = ""
        self.material_type: MaterialType = MaterialType.SOIL
        self.consistency: Optional[Consistency] = None
        self.density: Optional[Density] = None
        self.primary_soil_type: Optional[SoilType] = None
        self.rock_strength: Optional[RockStrength] = None
        self.weathering_grade: Optional[WeatheringGrade] = None
        self.rock_structure: Optional[RockStructure] = None
        self.primary_rock_type: Optional[RockType] = None
        self.secondary_constituents: List[SecondaryConstituent] = []
        self.strength_parameters: Optional[StrengthParameters] = None
        self.confidence: float = 1.0
        self._c_ptr: Optional[ctypes.POINTER(CSoilDescription)] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        result = {
            "raw_description": self.raw_description,
            "material_type": self.material_type.name,
            "confidence": self.confidence,
            "secondary_constituents": [sc.to_dict() for sc in self.secondary_constituents]
        }
        
        # Add optional fields
        if self.consistency is not None:
            result["consistency"] = self.consistency.name
        if self.density is not None:
            result["density"] = self.density.name
        if self.primary_soil_type is not None:
            result["primary_soil_type"] = self.primary_soil_type.name
        if self.rock_strength is not None:
            result["rock_strength"] = self.rock_strength.name
        if self.weathering_grade is not None:
            result["weathering_grade"] = self.weathering_grade.name
        if self.rock_structure is not None:
            result["rock_structure"] = self.rock_structure.name
        if self.primary_rock_type is not None:
            result["primary_rock_type"] = self.primary_rock_type.name
        if self.strength_parameters is not None:
            result["strength_parameters"] = self.strength_parameters.to_dict()
        
        return result
    
    def to_json(self) -> str:
        """Convert to JSON string."""
        return json.dumps(self.to_dict(), indent=2)


class LithologLibrary:
    """Interface to the litholog C library."""
    
    def __init__(self, library_path: str = "./liblitholog.so"):
        """Initialize the library interface.
        
        Args:
            library_path: Path to the shared library file
        """
        try:
            self.lib = ctypes.CDLL(library_path)
        except OSError as e:
            raise RuntimeError(f"Failed to load litholog library at {library_path}: {e}")
        
        # Set up function signatures
        self._setup_function_signatures()
    
    def _setup_function_signatures(self):
        """Set up C function signatures."""
        # litholog_parse
        self.lib.litholog_parse.argtypes = [c_char_p]
        self.lib.litholog_parse.restype = POINTER(CSoilDescription)
        
        # litholog_free_description
        self.lib.litholog_free_description.argtypes = [POINTER(CSoilDescription)]
        self.lib.litholog_free_description.restype = None
        
        # litholog_description_to_json
        self.lib.litholog_description_to_json.argtypes = [POINTER(CSoilDescription)]
        self.lib.litholog_description_to_json.restype = c_char_p
        
        # litholog_free_string
        self.lib.litholog_free_string.argtypes = [c_char_p]
        self.lib.litholog_free_string.restype = None
    
    def parse(self, description: str) -> Optional[SoilDescription]:
        """Parse a geological description string.
        
        Args:
            description: The geological description to parse
            
        Returns:
            Parsed SoilDescription object or None if parsing failed
        """
        # Convert to bytes for C function
        desc_bytes = description.encode('utf-8')
        
        # Call C function
        c_result = self.lib.litholog_parse(desc_bytes)
        if not c_result:
            return None
        
        # Convert C structure to Python object
        result = SoilDescription()
        result._c_ptr = c_result
        
        # Copy basic fields
        result.raw_description = c_result.contents.raw_description.decode('utf-8')
        result.material_type = MaterialType(c_result.contents.material_type)
        result.confidence = c_result.contents.confidence
        
        # Copy optional fields
        if c_result.contents.consistency >= 0:
            result.consistency = Consistency(c_result.contents.consistency)
        if c_result.contents.density >= 0:
            result.density = Density(c_result.contents.density)
        if c_result.contents.primary_soil_type >= 0:
            result.primary_soil_type = SoilType(c_result.contents.primary_soil_type)
        if c_result.contents.rock_strength >= 0:
            result.rock_strength = RockStrength(c_result.contents.rock_strength)
        if c_result.contents.weathering_grade >= 0:
            result.weathering_grade = WeatheringGrade(c_result.contents.weathering_grade)
        if c_result.contents.rock_structure >= 0:
            result.rock_structure = RockStructure(c_result.contents.rock_structure)
        if c_result.contents.primary_rock_type >= 0:
            result.primary_rock_type = RockType(c_result.contents.primary_rock_type)
        
        # Copy secondary constituents
        if c_result.contents.secondary_constituents_count > 0:
            for i in range(c_result.contents.secondary_constituents_count):
                sc = c_result.contents.secondary_constituents[i]
                amount = sc.amount.decode('utf-8') if sc.amount else ""
                soil_type = sc.soil_type.decode('utf-8') if sc.soil_type else ""
                result.secondary_constituents.append(SecondaryConstituent(amount, soil_type))
        
        # Copy strength parameters
        if c_result.contents.has_strength_parameters and c_result.contents.strength_parameters:
            sp = c_result.contents.strength_parameters.contents
            param_type = StrengthParameterType(sp.parameter_type)
            value_range = StrengthRange(
                sp.value_range.lower_bound,
                sp.value_range.upper_bound,
                sp.value_range.typical_value,
                bool(sp.value_range.has_typical_value)
            )
            result.strength_parameters = StrengthParameters(param_type, value_range, sp.confidence)
        
        return result
    
    def get_json(self, description: SoilDescription) -> Optional[str]:
        """Get JSON representation of a description using the C library.
        
        Args:
            description: The SoilDescription object
            
        Returns:
            JSON string or None if conversion failed
        """
        if not description._c_ptr:
            return description.to_json()  # Fallback to Python serialization
        
        json_ptr = self.lib.litholog_description_to_json(description._c_ptr)
        if not json_ptr:
            return None
        
        try:
            json_str = json_ptr.decode('utf-8')
            return json_str
        finally:
            self.lib.litholog_free_string(json_ptr)
    
    def free_description(self, description: SoilDescription):
        """Free the C memory associated with a description.
        
        Args:
            description: The SoilDescription object to free
        """
        if description._c_ptr:
            self.lib.litholog_free_description(description._c_ptr)
            description._c_ptr = None


# Global library instance
_lib_instance: Optional[LithologLibrary] = None


def get_library(library_path: str = "./liblitholog.so") -> LithologLibrary:
    """Get or create the global library instance.
    
    Args:
        library_path: Path to the shared library file
        
    Returns:
        LithologLibrary instance
    """
    global _lib_instance
    if _lib_instance is None:
        _lib_instance = LithologLibrary(library_path)
    return _lib_instance


def parse(description: str, library_path: str = "./liblitholog.so") -> Optional[SoilDescription]:
    """Parse a geological description string.
    
    This is a convenience function that uses the global library instance.
    
    Args:
        description: The geological description to parse
        library_path: Path to the shared library file
        
    Returns:
        Parsed SoilDescription object or None if parsing failed
    """
    lib = get_library(library_path)
    return lib.parse(description)


# Example usage and testing
if __name__ == "__main__":
    # Test data
    test_descriptions = [
        "Firm CLAY",
        "Dense SAND",
        "Strong LIMESTONE",
        "Firm to stiff slightly sandy gravelly CLAY",
        "Moderately strong slightly weathered SANDSTONE"
    ]
    
    try:
        lib = LithologLibrary()
        
        for desc in test_descriptions:
            print(f"\nParsing: '{desc}'")
            try:
                result = lib.parse(desc)
                if result:
                    print(f"Material Type: {result.material_type.name}")
                    if result.consistency:
                        print(f"Consistency: {result.consistency.name}")
                    if result.density:
                        print(f"Density: {result.density.name}")
                    if result.primary_soil_type:
                        print(f"Soil Type: {result.primary_soil_type.name}")
                    if result.rock_strength:
                        print(f"Rock Strength: {result.rock_strength.name}")
                    if result.primary_rock_type:
                        print(f"Rock Type: {result.primary_rock_type.name}")
                    if result.secondary_constituents:
                        print("Secondary Constituents:")
                        for sc in result.secondary_constituents:
                            print(f"  - {sc.amount} {sc.soil_type}")
                    if result.strength_parameters:
                        sp = result.strength_parameters
                        print(f"Strength Parameters: {sp.parameter_type.name}")
                        print(f"  Range: {sp.value_range.lower_bound} - {sp.value_range.upper_bound}")
                    print(f"Confidence: {result.confidence}")
                    
                    # Clean up
                    lib.free_description(result)
                else:
                    print("Failed to parse")
            except Exception as e:
                print(f"Error: {e}")
    
    except RuntimeError as e:
        print(f"Library initialization error: {e}")
        print("Note: This is expected if the C library hasn't been built yet.")