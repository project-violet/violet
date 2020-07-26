# libviolet

Native downloader for `violet-app` written by `rust-lang`.

## How to build?

```
You must build in linux environment.
1. Install rust & cargo
2. Download and unzip ndk https://developer.android.com/ndk/downloads
3. Settings up your ndk path below two files
libviolet/.cargo/config
libviolet/build.sh
4. Run ./build.sh
```

## Why is libviolet written by rust?

I don't know anything about java, kotlin, swift and object-c.
But similar to flutter, I wanted to find a way to support both `ios` and `Android`.
C++ library dependencies and builds were too complex, so I used rust.