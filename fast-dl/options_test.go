package main

import (
	"flag"
	"testing"
)

func TestParseOptionsRejectsRemovedFlags(t *testing.T) {
	removedFlags := [][]string{
		{"-gallery-dl", "gallery-dl"},
		{"-resolver", "gallery-dl"},
	}

	for _, args := range removedFlags {
		t.Run(args[0], func(t *testing.T) {
			_, err := parseOptions(args)
			if err == nil {
				t.Fatalf("parseOptions(%v) succeeded, want error", args)
			}
			if err != flag.ErrHelp && err.Error() == "" {
				t.Fatalf("parseOptions(%v) returned empty error", args)
			}
		})
	}
}

func TestParseOptionsAcceptsCustomTmpDir(t *testing.T) {
	opts, err := parseOptions([]string{"-tmp-dir", "custom"})
	if err != nil {
		t.Fatalf("parseOptions(-tmp-dir custom) error = %v", err)
	}
	if opts.tmpDir != "custom" {
		t.Fatalf("tmpDir = %q, want %q", opts.tmpDir, "custom")
	}
}

func TestParseOptionsUsesInternalDefaultTmpDir(t *testing.T) {
	opts, err := parseOptions(nil)
	if err != nil {
		t.Fatalf("parseOptions(nil) error = %v", err)
	}
	if opts.tmpDir != defaultTmpDir {
		t.Fatalf("tmpDir = %q, want %q", opts.tmpDir, defaultTmpDir)
	}
}
