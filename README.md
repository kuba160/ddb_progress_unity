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

Deadbeef header file is not included. If it cannot be located in your filesystem you can add additional search path using `--search-prefix`:

```
$  find ./deadbeef -type f
./deadbeef/include/deadbeef/deadbeef.h
$ zig build --search-prefix ./deadbeef
```

With `zig` you can target a specific arch and libc (including specific glibc version) as long as you also have compatible dependencies. As an example let's try to compile this plugin for aarch64 using static-deps provided by deadbeef. The target will be `aarch64-linux-gnu.2.17`. Static deps will be placed in `static-deps` leading to this dbus path: `static-deps/lib-aarch64/lib/libdbus-1.a`. Since deadbeef provides both static and shared dbus you can also choose preferred linking mode.

```$ zig build --search-prefix ./deadbeef -Dtarget=aarch64-linux-gnu.2.17 --search-prefix ./static-deps/lib-aarch64/```

### Additional build Configuration

| Option                  | Default value: type              | Description                             |
|-------------------------|----------------------------------|-----------------------------------------|
| `-Dpreferred_link_mode` | `.dynamic: std.builtin.LinkMode` | Preferred link mode                     |
| `-Dlink_libc`           | `true: bool`                     | Experimental: disable linking with libc |

## Testing

To run tests:

```
$ zig build test
Build Summary: 3/3 steps succeeded; 7/7 tests passed
test success
└─ run test 7 passed 1ms MaxRSS:4M
   └─ compile test Debug native cached 25ms MaxRSS:132M
```
