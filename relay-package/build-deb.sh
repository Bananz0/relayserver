#!/usr/bin/env bash
# Build the universal dev.copper.relayserver .deb (Architecture: iphoneos-arm).
#
# One package serves both 32-bit devices (armv7s slice) and 64-bit devices on rootful
# jailbreaks (arm64 slice). A rootful jailbreak's dpkg architecture is iphoneos-arm on both,
# so an armv7s-only package gets installed on 64-bit phones and cannot run there.
#
# Usage:
#   relay-package/build-deb.sh <version> <armv7s-binary> <arm64-binary> [output-dir]
#
# Both binaries must already be signed with ldid; the script merges them unmodified.
#
# Environment:
#   TOOLCHAIN  directory holding lipo and ldid (default: /opt/theos/toolchain/linux/iphone/bin)
#   EXTRA_DIR  optional directory copied over the package root before building
#              (e.g. var/mobile/bin_variants/, var/mobile/relay-sensors)
set -euo pipefail

if [ "$#" -lt 3 ]; then
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi

VERSION=$1
ARMV7S_BIN=$2
ARM64_BIN=$3
OUT_DIR=${4:-$PWD}
TOOLCHAIN=${TOOLCHAIN:-/opt/theos/toolchain/linux/iphone/bin}
HERE=$(cd "$(dirname "$0")" && pwd)

LIPO=$TOOLCHAIN/lipo
LDID=$TOOLCHAIN/ldid
for tool in "$LIPO" "$LDID"; do
    [ -x "$tool" ] || { echo "missing tool: $tool (set TOOLCHAIN)" >&2; exit 1; }
done
command -v dpkg-deb > /dev/null || { echo "dpkg-deb not found" >&2; exit 1; }

check_slice() {
    local file=$1 want=$2
    "$LIPO" -info "$file" | grep -q "architecture: $want\$" \
        || { echo "$file is not a thin $want binary" >&2; exit 1; }
    "$LDID" -e "$file" | grep -q "<plist" \
        || { echo "$file is not signed with entitlements (run ldid -S<entitlements> first)" >&2; exit 1; }
}
check_slice "$ARMV7S_BIN" armv7s
check_slice "$ARM64_BIN" arm64

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -a "$HERE/layout/." "$STAGE/"
mkdir -p "$STAGE/var/mobile" "$STAGE/usr/local/bin"

"$LIPO" -create "$ARMV7S_BIN" "$ARM64_BIN" -output "$STAGE/var/mobile/relayserver"
chmod 0755 "$STAGE/var/mobile/relayserver"
ln -sf /var/mobile/relayserver "$STAGE/usr/local/bin/relayserver"

if [ -n "${EXTRA_DIR:-}" ]; then
    cp -a "$EXTRA_DIR/." "$STAGE/"
fi

# Fill in the templates. postinst embeds the public halves of the host keys that old
# releases shipped, so it can recognise and replace them on the device.
BLOBS=$HERE/published-hostkeys.txt VERSION=$VERSION python3 - "$STAGE/DEBIAN/control" "$STAGE/DEBIAN/postinst" << 'PY'
import os, sys
blobs = open(os.environ["BLOBS"]).read().strip()
for path in sys.argv[1:]:
    text = open(path).read()
    text = text.replace("@@VERSION@@", os.environ["VERSION"]).replace("@@PUBLISHED_KEYS@@", blobs)
    assert "@@" not in text, f"unfilled placeholder in {path}"
    open(path, "w").write(text)
PY

find "$STAGE" -type d -exec chmod 0755 {} +
chmod 0755 "$STAGE/DEBIAN/preinst" "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm"
chmod 0644 "$STAGE/DEBIAN/control" "$STAGE/Library/LaunchDaemons/dev.copper.relayserver.plist"

if grep -rIl "PRIVATE KEY" "$STAGE" > /dev/null; then
    echo "refusing to build: the package contains a private key" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
DEB=$OUT_DIR/dev.copper.relayserver_${VERSION}_iphoneos-arm.deb
# gzip members: the dpkg on iOS 10 cannot read xz or zstd archives.
dpkg-deb -Zgzip --uniform-compression --root-owner-group -b "$STAGE" "$DEB" > /dev/null

echo "built $DEB"
"$LIPO" -info "$STAGE/var/mobile/relayserver"
sha256sum "$DEB"
