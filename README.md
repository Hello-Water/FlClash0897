# FlClash — Ubuntu 20.04 + Chain Proxy Edition

This branch is a customized FlClash build focused on:

* **Ubuntu 20.04 / glibc 2.31 compatibility**
* **Mihomo ****`dialer-proxy`**** chain proxy support**
* Local SQLite native compilation for improved compatibility
* Prebuilt `.deb`, `.rpm`, and `.AppImage` packages

Branch:

```text
feature/dialer-proxy-chain
```

This branch is based on the upstream FlClash project and keeps the original FlClash functionality while adding compatibility and chain-proxy enhancements.

---

## Prebuilt Packages

Prebuilt Linux AMD64 packages are available for users who do not want to compile from source.

### OneDrive

[Download prebuilt packages from OneDrive](https://1drv.ms/f/c/04017f21f5709366/IgApu70LGda9QpKYAHFTn064AfUsVqB_nqKV40Mjr57zK0o?e=Zlik5R)

Available packages:

```text
FlClash-*.deb
FlClash-*.rpm
FlClash-*.AppImage
```

### Recommended package

For Ubuntu 20.04:

```bash
sudo apt install ./FlClash-*.deb
```

For AppImage:

```bash
chmod +x FlClash-*.AppImage
./FlClash-*.AppImage
```

---

# Ubuntu 20.04 Compatibility

## Problem

The upstream prebuilt Linux binary may require a newer version of glibc, for example:

```text
GLIBC_2.34
```

Ubuntu 20.04 provides:

```text
glibc 2.31
```

Therefore, newer prebuilt FlClash binaries may fail to start on Ubuntu 20.04.

This branch is built and tested directly against an Ubuntu 20.04-compatible environment.

---

## Tested Environment

```text
OS           Ubuntu 20.04 x86_64
glibc        2.31
GLib         2.64.x

Flutter      3.47.1
Dart         3.13.1
Rust         1.95.0
```

---

## 1. GLib Compatibility Fix

Ubuntu 20.04 ships with GLib 2.64.x.

The original Linux `wifi_ssid` plugin uses:

```cpp
g_spawn_check_wait_status(...)
```

which is only available in newer GLib versions.

The compatibility implementation uses:

```cpp
#if GLIB_CHECK_VERSION(2, 70, 0)
  if (!g_spawn_check_wait_status(wait_status, &error)) {
#else
  if (!g_spawn_check_exit_status(wait_status, &error)) {
#endif
    return nullptr;
  }
```

Therefore:

```text
GLib >= 2.70
    → g_spawn_check_wait_status()

GLib < 2.70
    → g_spawn_check_exit_status()
```

This allows the same source code to compile on both Ubuntu 20.04 and newer Linux distributions.

---

## 2. `g_steal_pointer()` C++ Compatibility

Two explicit casts are added for the Ubuntu 20.04 C++ toolchain.

Changed:

```cpp
return g_steal_pointer(&cached);
```

to:

```cpp
return static_cast<GVariant*>(g_steal_pointer(&cached));
```

and:

```cpp
return g_steal_pointer(&ssid);
```

to:

```cpp
return static_cast<gchar*>(g_steal_pointer(&ssid));
```

The affected file is:

```text
plugins/wifi_ssid/linux/wifi_ssid_plugin.cc
```

---

# SQLite Source Build

This branch includes the SQLite amalgamation source under:

```text
third_party/sqlite/
├── sqlite3.c
├── sqlite3.h
└── sqlite3ext.h
```

The tested SQLite version is:

```text
SQLite 3.53.4
```

The root `pubspec.yaml` contains:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: source
      path: third_party/sqlite/sqlite3.c
```

This makes the SQLite native library compile locally instead of relying on downloading a prebuilt native library during the Flutter build.

The resulting `libsqlite3.so` is compatible with Ubuntu 20.04.

---

# Chain Proxy Support

This branch adds a graphical interface for configuring **multi-hop / chained proxies** using Mihomo's native:

```yaml
dialer-proxy
```

mechanism.

It does not rely on the legacy `relay` proxy-group mechanism.

---

## Normal Proxy

A normal proxy connection looks like:

```text
Client
  ↓
Exit Proxy
  ↓
Internet
```

---

## Chain Proxy

With chain proxy enabled:

```text
Client
  ↓
First Hop
  ↓
Exit Proxy
  ↓
Internet
```

For example:

```text
Node B
  ↓
Node A
  ↓
Internet
```

In the FlClash UI:

```text
First Hop : Node B
Exit Proxy: Node A
```

The generated Mihomo configuration becomes:

```yaml
proxies:
  - name: "Node A"
    type: ss
    ...
    dialer-proxy: "Node B"
```

The actual connection path is therefore:

```text
Client
→ Node B
→ Node A
→ Internet
```

`Node A` remains the final Internet exit.

---

# Configuring Chain Proxy

Open:

```text
Profiles
  ↓
Select the original profile
  ↓
More
  ↓
Override
  ↓
Proxy Chain
```

Click the add button and select:

```text
Exit Proxy
First Hop
```

Example:

```text
Exit Proxy:
Node A

First Hop:
Node B
```

This creates:

```text
Client → Node B → Node A → Internet
```

---

# Verify Chain Proxy Configuration

After applying the profile, check the generated Mihomo configuration:

```bash
grep -n -B5 -A15 'dialer-proxy' \
  ~/.local/share/com.follow.clash/config.yaml
```

A successful chain should contain a non-empty entry similar to:

```yaml
name: "Node A"
type: "ss"
...
dialer-proxy: "Node B"
```

If this entry exists, FlClash has successfully generated the Mihomo chain configuration.

---

# Multi-Hop Proxy

Multiple `dialer-proxy` relationships can be combined.

For example:

```text
Client
 ↓
Node C
 ↓
Node B
 ↓
Node A
 ↓
Internet
```

can be represented as:

```yaml
Node A:
  dialer-proxy: Node B

Node B:
  dialer-proxy: Node C
```

The final Internet exit is:

```text
Node A
```

---

# Loop Protection

The chain configuration logic checks for obvious circular relationships.

Invalid examples include:

```text
A → A
```

and:

```text
A → B → A
```

These configurations are rejected to avoid proxy routing loops.

When using a proxy group as the First Hop, users should also avoid configurations where the group can select the Exit Proxy itself.

For initial testing, using two different real proxy nodes is recommended.

---

# Chain Proxy Persistence

Chain settings are stored separately from the original subscription YAML.

The existing profile `selectedMap` is reused with an internal prefix:

```text
__flclash_dialer_proxy__::
```

Conceptually:

```text
__flclash_dialer_proxy__::Node-A
=
Node-B
```

means:

```text
Node-B → Node-A
```

This design provides several advantages:

* No database schema migration
* Original subscription configuration remains unchanged
* Chain settings can survive subscription updates
* Existing profile persistence logic can be reused

Before the final Mihomo configuration is generated, FlClash converts these stored relationships into native:

```yaml
dialer-proxy:
```

entries.

---

# Connection Details Limitation

The existing FlClash `Connection Details → Proxy Chain` display should not currently be treated as the authoritative representation of the complete `dialer-proxy` path.

For example, Connection Details may show:

```text
Rule Group
→ Fallback Group
→ Exit Node
```

while the actual configured connection is:

```text
First Hop
→ Exit Node
→ Internet
```

This happens because the existing connection view displays the logical chain information returned by the Mihomo connection API.

It may include:

```text
select
fallback
url-test
```

proxy groups and may not fully expand the underlying `dialer-proxy` relationship.

To verify the configured chain, check the generated:

```text
config.yaml
```

and confirm that the Exit Proxy contains a non-empty:

```yaml
dialer-proxy:
```

entry.

---

# Main Chain Proxy Source Changes

The feature mainly adds or modifies:

```text
arb/intl_en.arb
arb/intl_ja.arb
arb/intl_ru.arb
arb/intl_zh_CN.arb

lib/common/chain_proxy.dart
lib/common/common.dart

lib/providers/actions/setup.dart

lib/views/profiles/overwrite/chain_proxy.dart
lib/views/profiles/overwrite/overwrite.dart

test/common/chain_proxy_test.dart
```

Responsibilities:

```text
lib/common/chain_proxy.dart
    → chain parsing
    → persistence
    → validation
    → cycle detection

lib/providers/actions/setup.dart
    → inject dialer-proxy into generated Mihomo config

lib/views/profiles/overwrite/chain_proxy.dart
    → chain proxy configuration UI

lib/views/profiles/overwrite/overwrite.dart
    → entry point in the existing Override page

arb/*
    → localization
```

---

# Ubuntu 20.04 Build Dependencies

Install:

```bash
sudo apt update

sudo apt install -y \
  curl \
  wget \
  git \
  unzip \
  xz-utils \
  zip \
  build-essential \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  liblzma-dev \
  libglu1-mesa \
  libayatana-appindicator3-dev
```

---

# Flutter

The tested Flutter version is:

```text
Flutter 3.47.1
Dart 3.13.1
```

After changing Flutter versions:

```bash
rm -rf .dart_tool
flutter pub get
```

---

# Rust

Install Rust 1.95.0:

```bash
rustup toolchain install 1.95.0
rustup target add x86_64-unknown-linux-gnu --toolchain 1.95.0
```

---

# Build From Source

Install Flutter dependencies:

```bash
flutter pub get
```

Generate localization files:

```bash
dart run intl_utils:generate
```

`intl_utils` may print messages such as:

```text
No @@locale or _locale field found...
```

when locale metadata is inferred from the ARB filename.

These informational messages do not prevent generation.

Run static analysis:

```bash
flutter analyze --no-fatal-infos
```

Build the Linux release:

```bash
flutter build linux --release \
  --dart-define-from-file=env.json
```

The output is generated under:

```text
build/linux/x64/release/bundle/
```

---

# Build Verification

The Ubuntu 20.04 build has been successfully verified with:

```text
Flutter localization generation    PASS
Flutter static analysis            PASS
Linux release compilation          PASS
Release build exit code            0
```

The resulting Linux binaries were also checked for glibc compatibility.

Representative requirements:

```text
FlClashHelperService      GLIBC_2.30
librust_api.so            GLIBC_2.30
libsqlite3.so             GLIBC_2.28
libflutter_linux_gtk.so   GLIBC_2.18
FlClashCore               statically linked
```

Ubuntu 20.04 provides:

```text
GLIBC_2.31
```

---

# Runtime Verification

The following functionality has been tested:

```text
FlClash GUI                 PASS
FlClashCore                 PASS
GUI/Core IPC                PASS
Helper Service              PASS
systemd integration         PASS
Profile loading             PASS
TUN interface               PASS
Automatic routing           PASS
Proxy traffic               PASS
Chain proxy config          PASS
dialer-proxy generation     PASS
```

A configured chain successfully generated a non-empty:

```yaml
dialer-proxy:
```

entry under the selected Exit Proxy.

---

# Package Formats

The following Linux package formats can be generated:

```text
.deb
.rpm
.AppImage
```

For Ubuntu 20.04, `.deb` is recommended.

---

# Branch Scope

This branch is intended as an integrated version containing:

```text
Upstream FlClash
       +
Ubuntu 20.04 / GLib compatibility
       +
SQLite source build
       +
Mihomo dialer-proxy chain configuration
       +
Chain Proxy GUI
```

It is primarily intended for users who:

* still use Ubuntu 20.04;
* cannot run newer glibc-dependent upstream binaries;
* need graphical chain-proxy configuration;
* want prebuilt Ubuntu 20.04-compatible Linux packages.

---

# Upstream

This is a customized fork of FlClash.

For the original project, updates, documentation, and official releases, please refer to the upstream FlClash repository.

Changes in this branch are maintained separately and may differ from the upstream implementation.
