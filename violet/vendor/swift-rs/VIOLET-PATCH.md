# Local Xcode 27 compatibility patch

Based on the crates.io `swift-rs` 1.0.8 source. Original MIT/Apache-2.0
licenses are included.

The upstream Xcode 27 workaround exports a package's own C bridge symbols,
but leaves the SwiftRs bridge embedded in `libTauri.a` internal. This causes
undefined `retain_object`, `release_object`, and `string_from_bytes` symbols
when linking the iOS simulator app.

`globalize_cdecl_symbols` also considers the `SwiftRs.o` member when processing
the Tauri archive. Plugin archives keep their embedded SwiftRs copies local,
so there is only one exported copy. Existing C identifier and uniqueness
checks remain in place. This path only runs for Xcode 27 and newer.

Remove the Cargo patch once upstream includes an equivalent fix.
