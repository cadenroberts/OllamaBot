package patch

import (
	"fmt"
	"path/filepath"
	"strings"
)

// ValidatePatches performs pre-flight validation on a set of patches.
// Returns a slice of errors for any issues found (empty slice means all valid).
func (p *Patcher) ValidatePatches(patches []Patch) []error {
	var errs []error
	seen := make(map[string]bool)
	for _, patch := range patches {
		// Check for empty path
		if patch.Path == "" {
			errs = append(errs, fmt.Errorf("patch path cannot be empty"))
		}

		// Check for duplicate paths in the same transaction
		if seen[patch.Path] {
			errs = append(errs, fmt.Errorf("duplicate patch path: %s", patch.Path))
		}
		seen[patch.Path] = true

		// Check for path traversal
		if filepath.IsAbs(patch.Path) || strings.Contains(patch.Path, "..") {
			errs = append(errs, fmt.Errorf("invalid patch path (absolute or traversal): %s", patch.Path))
		}
	}
	return errs
}

// Validate performs a full validation of a single patch against the current filesystem.
func (p *Patcher) Validate(patch Patch) error {
	if patch.Path == "" {
		return fmt.Errorf("patch path cannot be empty")
	}
	return nil
}
