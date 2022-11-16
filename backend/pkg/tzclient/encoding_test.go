package tzclient

import (
	"testing"
)

func TestMichelsonToString(t *testing.T) {
	testcases := []struct {
		input    string
		expected string
		isValid  bool
	}{
		{
			"05010000000473656c66",
			"self",
			true,
		},
		{
			"0501000000096f74686572206f7267",
			"other org",
			true,
		},
		{
			"05010000000c6578616d706c6520636f7270",
			"example corp",
			true,
		},
		{
			"hello",
			"",
			false,
		},
	}
	for index, testcase := range testcases {
		result, err := MichelsonToString(testcase.input)
		if testcase.isValid {
			if err != nil {
				t.Errorf("Got unexpected error for case %d: %v", index, err)
			}
			if result != testcase.expected {
				t.Errorf("Got unexpected result for case %d: %s", index, result)
			}
		} else {
			if err == nil {
				t.Errorf("Expected error for case %d", index)
			}
		}
	}
}
