// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

use crate::utils::decompress::to_parent_entry_extract_fn;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

pub async fn decompress_7z(src: String, dest: String) {
    sevenz_rust::decompress_file_with_extract_fn(src, dest, to_parent_entry_extract_fn)
        .expect("complete");
}

#[cfg(test)]
mod tests {
    use super::decompress_7z;

    #[test]
    fn test_decompress() {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(async {
                decompress_7z(
                    "../test/rawdata-korean.7z".to_string(),
                    "../test/rawdata".to_string(),
                )
                .await;
            });
    }
}
