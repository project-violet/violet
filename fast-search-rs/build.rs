#![allow(warnings)]

use std::env;
use std::path::PathBuf;
use std::process::Command;

use cmake::Config;

fn main() {
    // Path to the C++ project
    let cpp_project_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("cxx");

    // Configure and build the C++ project
    let dst = Config::new(&cpp_project_dir)
        .generator("Ninja")
        .build_target("binding")
        .build();

    // Inform cargo to link the C++ library
    println!("cargo:rustc-link-search=native={}", dst.display());

    // Ninja Path
    println!("cargo:rustc-link-lib=static=build/binding");

    // Generate bindings using bindgen
    let bindings = bindgen::Builder::default()
        .header(
            cpp_project_dir
                .join("RapidFuzz-cpp/rapidfuzz/fuzz.hpp")
                .to_str()
                .unwrap(),
        )
        .header(cpp_project_dir.join("main.hpp").to_str().unwrap())
        .clang_arg("-Icxx")
        .clang_arg("-Icxx/RapidFuzz-cpp")
        .clang_arg("--std=c++20")
        .opaque_type("std::.*")
        .opaque_type("rapidfuzz::.*")
        .opaque_type("binding::.*")
        .allowlist_item("binding::create.*")
        .allowlist_item("binding::similarity.*")
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    // Invalidate the built crate whenever the wrapper or C++ sources change
    println!("cargo:rerun-if-changed=cxx/main.cpp");
    println!("cargo:rerun-if-changed=cxx/main.hpp");
    println!("cargo:rerun-if-changed=cxx/CMakeLists.txt");
}
