package tzclient

import (
	"testing"
)

func TestLoadInvalidPath (t *testing.T) {
	_, err := LoadClient("/this/isnt/a/real/path/hopefully")
	if err == nil {
		t.Error("Expected an error value, got nil")
	}
}