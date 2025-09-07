package litholog

/*
#cgo CFLAGS: -I../../include
#cgo LDFLAGS: -L../../ -llitholog
#include "litholog.h"
#include <stdlib.h>
*/
import "C"

// Version information extracted from Zig source
const (
	Version = "0.1.0"
)

// GetVersion returns the library version
func GetVersion() string {
	return Version
}

// GetVersionFromC returns the version directly from the C library
func GetVersionFromC() string {
	if cVersion := C.litholog_version_string(); cVersion != nil {
		return C.GoString(cVersion)
	}
	return Version // fallback
}
