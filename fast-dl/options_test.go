package main

import (
	"flag"
	"testing"
)

func TestParseOptionsRejectsRemovedFlags(t *testing.T) {
	removedFlags := [][]string{
		{"-tmp-dir", "custom"},
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

func TestParseOptionsUsesInternalDefaultTmpDir(t *testing.T) {
	opts, err := parseOptions(nil)
	if err != nil {
		t.Fatalf("parseOptions(nil) error = %v", err)
	}
	if opts.tmpDir != defaultTmpDir {
		t.Fatalf("tmpDir = %q, want %q", opts.tmpDir, defaultTmpDir)
	}
}
