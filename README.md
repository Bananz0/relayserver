# OpenBubbles RelayServer (Platform Enhancements & 32-Bit Port)

> [!IMPORTANT]
> ### Upstream Attribution & Development Scope
> **The core relay logic, network protocol, and fundamental codebase are the intellectual property of [OpenBubbles](https://github.com/OpenBubbles/relayserver).**
> 
> This repository is **not** an independent fork and is **not** maintained as a divergent implementation. We do **not** work on the core relay logic independently. All core Apple NAC registration logic, cryptography, and protocol handling belong to and are driven by OpenBubbles upstream.
> 
> This repository exists exclusively to provide platform-specific enhancements and backward-compatibility ports:
> - **Legacy 32-bit Target (`armv7s`):** Compilation toolchain patches and runtime fixes enabling execution on 32-bit iOS 10.0–10.3.4 hardware (iPhone 5, iPhone 5c, iPad 4).
> - **Hardware Status Telemetry:** Local battery capacity and charging power state monitoring for headless operation.
> - **Home Assistant Push Integration:** Real-time push reporting of daemon health, pairing code, and battery state directly to Home Assistant REST API.
> - **Daemon Lifecycle & Singleton Control:** Port 8080 listener mutex to prevent concurrent instance conflicts under `launchd`.
> - **Cydia / Sileo / Zebra APT Packaging:** Standardized Debian packaging and repository distribution.

---

## Hardware & Environment Support

| Parameter | Specification |
| :--- | :--- |
| **Supported Devices** | iPhone 5c, iPhone 5, iPad (4th generation) |
| **Architecture** | 32-bit ARM (`armv7s` / `thumbv7s`) |
| **Operating System** | iOS 10.0 through 10.3.4 (H3lix / socket / kok3shi jailbreak) |
| **Core Service** | Background registration relay daemon |
| **Local Web Interface** | `http://<device-ip>:8080/` |

---

## Features Added in This Distribution

### 1. Hardware Status Telemetry
Extracts real-time hardware status for headless monitoring:
- Battery percentage reporting
- External power and charging state detection

### 2. Home Assistant Push Reporter
Periodically pushes hardware and service telemetry directly to your Home Assistant instance without requiring polling:
- `sensor.openbubbles_relay`: Service state (`Online`, `Connecting`)
- `sensor.openbubbles_relay_code`: Current 6-digit registration code
- `sensor.openbubbles_relay_battery`: Battery level percentage and charging state

Configuration is managed dynamically via `/var/mobile/config.json` or the local web UI at `http://<device-ip>:8080/`—**no secrets or tokens are hardcoded into the binary**.

### 3. Singleton Daemon Lock
Prevents duplicate instances from spawning and fighting over TCP socket 8080:
```rust
let listener = TcpListener::bind("0.0.0.0:8080").await
    .expect("Failed to bind port 8080: another instance is already running");
```

---

## Installation via APT Repository

Add the community repository to your package manager of choice:

- **Repository URL:** `https://cydia.glenmuthoka.com/` (or `https://bananz0.github.io/cydia-repo/`)
- **Package:** `dev.copper.relayserver` (RelayServer)

### 1-Tap Links
- **Sileo:** `sileo://source/https%3A%2F%2Fcydia.glenmuthoka.com%2F`
- **Zebra:** `zbra://sources/add/https%3A%2F%2Fcydia.glenmuthoka.com%2F`
- **Cydia:** `cydia://url/https://cydia.saurik.com/api/share#?source=https%3A%2F%2Fcydia.glenmuthoka.com%2F`

---

## Packaging

`relay-package/build-deb.sh` builds the `.deb` that the APT repository serves:

```bash
relay-package/build-deb.sh <version> <signed-armv7s-binary> <signed-arm64-binary> [output-dir]
```

- **One universal package.** The script merges the `armv7s` build from this repository and the `arm64` build from [`relayserver-arm64`](https://github.com/Bananz0/relayserver-arm64) into a single fat binary. A rootful jailbreak reports the dpkg architecture `iphoneos-arm` on 64-bit phones too, so an `armv7s`-only package gets installed there and cannot run.
- **Inputs must already be signed** with `ldid -S<entitlements>`; the script checks this and does not modify the binaries.
- **No SSH host keys in the package.** Releases 0.0.6 – 0.0.16-1 shipped host keys, which made them public. `postinst` now recognises those keys (their public halves are listed in `relay-package/published-hostkeys.txt`) and replaces them with keys generated on the device. The build fails if a private key ends up in the package.
- **32-bit workarounds are gated.** Root filesystem stashing, the `sshd-keygen-wrapper` replacement and the standalone `dev.copper.sshd` job (h3lix's launchd never spawns the socket-activated `com.openssh.sshd`) only run on 32-bit devices.
- **64-bit devices run the relay from `/usr/local/bin`.** On iOS 12 launchd cannot spawn a daemon whose binary is on the data partition (job status 78), so `postinst` copies it to the root filesystem and points the launchd job there.
- **Entitlements must have LF line endings.** iOS 12 SIGKILLs a binary whose embedded entitlements contain CRLF; `.gitattributes` pins `*.xml` to LF and the build script refuses CRLF-signed inputs.
- `EXTRA_DIR=<dir>` copies additional payload (for example `var/mobile/bin_variants/`) over the package root.

The package layout lives in `relay-package/layout/`; `@@VERSION@@` and `@@PUBLISHED_KEYS@@` are filled in at build time.

---

## Credits & Upstream Links

- **Upstream OpenBubbles:** [github.com/OpenBubbles/relayserver](https://github.com/OpenBubbles/relayserver)
- **OpenBubbles Project:** [openbubbles.app](https://openbubbles.app)
- **Enhancements & Maintenance:** [github.com/Bananz0/relayserver](https://github.com/Bananz0/relayserver)
- **APT Repository:** [github.com/Bananz0/cydia-repo](https://github.com/Bananz0/cydia-repo)
