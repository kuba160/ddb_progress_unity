<!--
SPDX-FileCopyrightText: 2025 Jakub Wasylków <kuba_160@protonmail.com>
SPDX-License-Identifier: CC0-1.0
-->
# ddb_progress_unity

Shows progressbar and number of enqueued songs in taskbar using `com.canonical.Unity.LauncherEntry`. Written using `zig` and `dbus-1`. Ensure your DE supports this extension before using. Result using KDE Plasma 6.4.5:

<img width="259" height="62" alt="image" src="https://github.com/user-attachments/assets/9aea80c9-6a6d-4797-9fd6-28ae52afc30b" />

## Building

Building in same directory (default output: `zig-out/lib/deadbeef/progress_unity.so`)

```$ zig build --release```

You can use prefix `-p` to change output directory (but plugin will still be put in `$prefix/lib/deadbeef`). For example to install plugin locally on linux:

```$ zig build --release -p ~/.local```

Or globally:

```# zig build --release -p /usr/local/lib``` or ```# zig build --release -p /usr/lib```

### Additional build Configuration

| Option            | Default value: type | Description                                              |
|-------------------|---------------------|----------------------------------------------------------|
| `-Dstatic-dbus`   | `false: bool`       | Prefer linking statically with `dbus-1`                  |
| `-Dglibc-version` | `undefined: string` | Override glibc target (alternative for using `-Dtarget`) |
| `-Dlink-libc`     | `true: bool`        | Experimental: disable linking with libc                  |

## Testing

To run tests:

```
$ zig build test
Build Summary: 3/3 steps succeeded; 7/7 tests passed
test success
└─ run test 7 passed 1ms MaxRSS:4M
   └─ compile test Debug native cached 25ms MaxRSS:132M
```
