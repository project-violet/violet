export PATH=$PATH:/home/<username>/ndk/android-ndk-r21b/toolchains/llvm/prebuilt/linux-x86_64/bin/
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add i686-linux-android
cargo build --target aarch64-linux-android --release
cargo build --target armv7-linux-androideabi --release
cargo build --target i686-linux-android --release