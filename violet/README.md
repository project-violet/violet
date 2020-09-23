<p align="center">
 <img width="150px" src="https://raw.githubusercontent.com/project-violet/violet/dev/assets/images/logo.png" align="center" alt="GitHub Readme Stats" />
 <h2 align="center">Project Violet</h2>
  <p align="center">
    Open Source Hentai Viewer App
  </p>
  <p align="center">
    <b><a href="https://github.com/project-violet/violet/wiki/Screenshots">Screenshots</a></b>
    •
    <b><a href="https://github.com/project-violet/violet/releases/latest">Download</a></b>
    •
    <b><a href="/manual">User Manual</a></b>
    •
    <b><a href="/doc">docs</a></b>
  </p>
</p>

### Community

Leave any questions on the github issue or on the Discord channel below.

Discord Channel: https://discord.gg/fqrtRxC

### Sub Projects

 - [Violet Server](https://github.com/project-violet/violet-server) - Real-time statistics provided by collecting user behavior
 - [libviolet](https://github.com/project-violet/libviolet) - Native multithread downloader for android, ios
 - [hsync](https://github.com/project-violet/hsync) - Very fast metadata synchronizer

### iOS Support

iOS version of violet is already ready.
However, unlike the Android version, 7z decompression and downloader are omitted.

#### How to build?

Install `flutter` and `Xcode` and make the following changes:

```
1. Remove 'firebase_*' and 'flutter_downloader' packages
2. Remove validator on lib/server/violet.dart
3. Run 'flutter run --release' command
   or Run ios/Runner.xcworkspace and build release
```

Developer certificate renewal is required once a week, so use `AltStore` if necessary.

### Code Refactoring Plan

Violet is my first mobile app project.
Since I started without knowing anything, I didn't even know basic concepts like state management, so the code is very dirty.
I have plans to refactor all my code until 2.0.0 version using bloc and provider etc.

### Multiple Language Support

If you want to add your language to the app,
please translate https://github.com/project-violet/violet/blob/dev/assets/locale/en.json.
I can translate it by google translator, but the quality is low.

Thanks for translation

```
Italiano - https://github.com/AlexZorzi
中文-简化字 - https://github.com/casteryh
Español - https://github.com/Culombiano
```

If you want to support language in source code, please refer to the following commits.

https://github.com/project-violet/violet/commit/203723c9d898bd99fc9200a7ba0ea5f354e1e90d