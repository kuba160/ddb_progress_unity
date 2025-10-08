<!--
SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
SPDX-License-Identifier: CC0-1.0
-->
# ddb_progress_unity

Shows progressbar in taskbar using com.canonical.Unity.LauncherEntry. Written using `zig` and `dbus-1`.

## Building

Building in same directory (default output: `zig-out/lib/deadbeef/progress_unity.so`)

```$ zig build --release```

You can use prefix `-p` to change output directory (but plugin will still be put in `$prefix/lib/deadbeef`). For example to install plugin locally on linux:

```$ zig build --release -p ~/.local```

Or globally:

```# zig build --release -p /usr/local/lib``` or ```# zig build --release -p /usr/lib```

## Testing

To run tests:

```
$ zig build test
Build Summary: 3/3 steps succeeded; 7/7 tests passed
test success
└─ run test 7 passed 1ms MaxRSS:4M
   └─ compile test Debug native cached 25ms MaxRSS:132M
```