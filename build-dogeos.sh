#!/usr/bin/env bash
set -Eeuo pipefail

DOGEOS_NAME="${DOGEOS_NAME:-DogeOS}"
DOGEOS_VERSION="${DOGEOS_VERSION:-0.1}"
DOGEOS_ARCH="${DOGEOS_ARCH:-amd64}"
UBUNTU_RELEASE="${UBUNTU_RELEASE:-26.04}"
BASE_ISO_URL="${BASE_ISO_URL:-https://releases.ubuntu.com/${UBUNTU_RELEASE}/ubuntu-${UBUNTU_RELEASE}-desktop-amd64.iso}"
SHA256SUMS_URL="${SHA256SUMS_URL:-https://releases.ubuntu.com/${UBUNTU_RELEASE}/SHA256SUMS}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/cache}"
WORK_DIR="${WORK_DIR:-${SCRIPT_DIR}/work}"
DIST_DIR="${DIST_DIR:-${SCRIPT_DIR}/dist}"
ISO_ROOT="${WORK_DIR}/iso-root"
EDIT_ROOT="${WORK_DIR}/edit-root"
LIVE_SQUASHFS=""
LIVE_MANIFEST=""
LIVE_MANIFEST_DESKTOP=""
LIVE_SIZE_FILE=""
BASE_ISO="${CACHE_DIR}/$(basename "${BASE_ISO_URL}")"
OUTPUT_ISO="${DIST_DIR}/${DOGEOS_NAME}-${DOGEOS_VERSION}-${DOGEOS_ARCH}.iso"
OUTPUT_SHA256="${DIST_DIR}/${DOGEOS_NAME}-${DOGEOS_VERSION}-${DOGEOS_ARCH}.sha256"
VOLUME_ID="${DOGEOS_VOLUME_ID:-DOGEOS_${DOGEOS_VERSION//./_}}"

log() {
    printf '[dogeos] %s\n' "$*"
}

die() {
    printf '[dogeos] ERROR: %s\n' "$*" >&2
    exit 1
}

need_linux() {
    [ "$(uname -s)" = "Linux" ] || die "This builder must run on Linux."
}

need_root() {
    if [ "${EUID}" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            exec sudo -E bash "$0" "$@"
        fi
        die "Run as root or install sudo."
    fi
}

install_deps() {
    local missing=()
    local cmd
    for cmd in wget xorriso unsquashfs mksquashfs rsync chroot sha256sum awk sed find xargs du; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [ "${#missing[@]}" -eq 0 ] && [ -f /usr/lib/grub/i386-pc/boot_hybrid.img ]; then
        return
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        die "Missing build tools: ${missing[*]}. Install xorriso squashfs-tools rsync wget and GRUB tools."
    fi

    log "Installing build dependencies with apt."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates \
        grub-efi-amd64-bin \
        grub-pc-bin \
        rsync \
        squashfs-tools \
        wget \
        xorriso
}

download_base_iso() {
    mkdir -p "$CACHE_DIR"
    if [ ! -f "$BASE_ISO" ]; then
        log "Downloading base Ubuntu ISO: $BASE_ISO_URL"
        wget -c -O "$BASE_ISO" "$BASE_ISO_URL"
    else
        log "Using cached base ISO: $BASE_ISO"
    fi

    log "Downloading SHA256SUMS."
    wget -O "${CACHE_DIR}/SHA256SUMS" "$SHA256SUMS_URL"

    local iso_name
    iso_name="$(basename "$BASE_ISO")"
    if awk -v file="$iso_name" '{
        for (i = 1; i < NF; i += 2) {
            name = $(i + 1)
            sub(/^\*/, "", name)
            if (name == file) {
                print $i " *" name
                found = 1
            }
        }
    } END { if (!found) exit 1 }' "${CACHE_DIR}/SHA256SUMS" > "${CACHE_DIR}/SHA256SUMS.${iso_name}"; then
        (cd "$CACHE_DIR" && sha256sum -c "SHA256SUMS.${iso_name}")
    else
        die "Could not find ${iso_name} in SHA256SUMS."
    fi
}

cleanup_mounts() {
    local target
    for target in dev/pts proc sys run dev; do
        if mountpoint -q "${EDIT_ROOT}/${target}"; then
            umount -lf "${EDIT_ROOT}/${target}" || true
        fi
    done
}

select_live_squashfs() {
    local selected
    selected="$(find "$ISO_ROOT/casper" -maxdepth 1 -type f -name '*.squashfs' -printf '%s\t%p\n' \
        | sort -rn \
        | head -n 1 \
        | cut -f 2-)"

    [ -n "$selected" ] || die "Could not find a live SquashFS image in ${ISO_ROOT}/casper."

    LIVE_SQUASHFS="$selected"
    LIVE_MANIFEST="${LIVE_SQUASHFS%.squashfs}.manifest"
    LIVE_MANIFEST_DESKTOP="${LIVE_SQUASHFS%.squashfs}.manifest-desktop"
    LIVE_SIZE_FILE="${LIVE_SQUASHFS%.squashfs}.size"

    log "Using live filesystem: ${LIVE_SQUASHFS#$ISO_ROOT/}"
}

extract_iso() {
    log "Cleaning previous work directory."
    cleanup_mounts
    rm -rf "$ISO_ROOT" "$EDIT_ROOT"
    mkdir -p "$ISO_ROOT" "$EDIT_ROOT" "$DIST_DIR"

    log "Extracting Ubuntu ISO."
    xorriso -osirrox on -indev "$BASE_ISO" -extract / "$ISO_ROOT" >/dev/null
    chmod -R u+w "$ISO_ROOT"

    select_live_squashfs

    log "Extracting live filesystem."
    unsquashfs -d "$EDIT_ROOT" "$LIVE_SQUASHFS" >/dev/null
}

mount_chroot() {
    log "Mounting chroot support filesystems."
    mount --bind /dev "${EDIT_ROOT}/dev"
    mount --bind /run "${EDIT_ROOT}/run"
    mount -t proc proc "${EDIT_ROOT}/proc"
    mount -t sysfs sysfs "${EDIT_ROOT}/sys"
    mount -t devpts devpts "${EDIT_ROOT}/dev/pts"
    cp /etc/resolv.conf "${EDIT_ROOT}/etc/resolv.conf"
}

copy_overlay() {
    log "Copying DogeOS overlay."
    rsync -a "${SCRIPT_DIR}/overlay/" "$EDIT_ROOT/"
    chmod +x "${EDIT_ROOT}/usr/local/bin/dogeos-roblox-setup"
    chmod +x "${EDIT_ROOT}/usr/local/bin/dogeos-roblox-setup-gui"
    chmod +x "${EDIT_ROOT}/usr/local/bin/dogeos-exe-setup"
    chmod +x "${EDIT_ROOT}/usr/local/bin/dogeos-exe-setup-gui"
}

customize_chroot() {
    log "Customizing packages and branding."
    chroot "$EDIT_ROOT" /bin/bash -s <<'CHROOT'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    desktop-file-utils \
    software-properties-common

add-apt-repository -y universe || true
add-apt-repository -y multiverse || true
dpkg --add-architecture i386 || true
apt-get update
apt-get install -y --no-install-recommends \
    cabextract \
    flatpak \
    fonts-wine \
    gamemode \
    gnome-software-plugin-flatpak \
    libegl1 \
    libegl1:i386 \
    libgl1 \
    libgl1:i386 \
    libgles2 \
    libvulkan1 \
    libvulkan1:i386 \
    mangohud \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    sudo \
    unzip \
    vulkan-tools \
    wine \
    wine32:i386 \
    wine64 \
    winetricks \
    xdg-utils

flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

cat >/etc/dogeos-release <<'EOF'
DogeOS 0.1
Based on Ubuntu 26.04 LTS
Roblox support path: Sober via Flatpak/Flathub
EOF

cat >/etc/hostname <<'EOF'
dogeos
EOF

cat >/etc/issue <<'EOF'
DogeOS 0.1 \n \l
EOF

cat >/etc/issue.net <<'EOF'
DogeOS 0.1
EOF

if [ -f /etc/os-release ]; then
    cp /etc/os-release /etc/os-release.ubuntu
fi

cat >/etc/os-release <<'EOF'
PRETTY_NAME="DogeOS 0.1 (based on Ubuntu 26.04 LTS)"
NAME="DogeOS"
VERSION_ID="0.1"
VERSION="0.1"
VERSION_CODENAME=resolute
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=resolute
LOGO=ubuntu-logo
EOF

cat >/etc/lsb-release <<'EOF'
DISTRIB_ID=DogeOS
DISTRIB_RELEASE=0.1
DISTRIB_CODENAME=resolute
DISTRIB_DESCRIPTION="DogeOS 0.1 (based on Ubuntu 26.04 LTS)"
EOF

mkdir -p /var/lib/dogeos
systemctl enable dogeos-roblox-setup.timer || true

if command -v glib-compile-schemas >/dev/null 2>&1; then
    glib-compile-schemas /usr/share/glib-2.0/schemas || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT
}

update_manifests() {
    log "Updating filesystem manifests."
    chroot "$EDIT_ROOT" dpkg-query -W --showformat='${Package} ${Version}\n' > "$LIVE_MANIFEST"
    cp "$LIVE_MANIFEST" "$LIVE_MANIFEST_DESKTOP" || true
    du -sx --block-size=1 "$EDIT_ROOT" | awk '{print $1}' > "$LIVE_SIZE_FILE"
}

repack_squashfs() {
    log "Repacking squashfs. This can take a while."
    rm -f "$LIVE_SQUASHFS"
    mksquashfs "$EDIT_ROOT" "$LIVE_SQUASHFS" \
        -comp xz \
        -b 1048576 \
        -processors "${MKSQUASHFS_PROCESSORS:-2}" \
        -mem "${MKSQUASHFS_MEM:-1024M}" \
        -noappend >/dev/null
}

update_checksums() {
    log "Updating ISO checksums."
    (
        cd "$ISO_ROOT"
        rm -f md5sum.txt
        find . -type f \
            ! -name md5sum.txt \
            ! -path './boot.catalog' \
            ! -path './isolinux/boot.cat' \
            -print0 | xargs -0 md5sum > md5sum.txt
    )
}

build_iso() {
    log "Building bootable ISO: $OUTPUT_ISO"
    rm -f "$OUTPUT_ISO" "$OUTPUT_SHA256"

    local boot_opts
    boot_opts="$(xorriso -indev "$BASE_ISO" -report_el_torito as_mkisofs 2>/dev/null \
        | sed -e '/^-V /d' -e '/^--modification-date=/d')"

    if [ -z "$boot_opts" ]; then
        die "Could not derive boot options from base ISO."
    fi

    local -a boot_args=()
    eval "boot_args=(${boot_opts})"

    xorriso -as mkisofs -r -V "$VOLUME_ID" -o "$OUTPUT_ISO" "${boot_args[@]}" "$ISO_ROOT" >/dev/null
    [ -s "$OUTPUT_ISO" ] || die "ISO was not created: $OUTPUT_ISO"

    (
        cd "$DIST_DIR"
        sha256sum "$(basename "$OUTPUT_ISO")" > "$(basename "$OUTPUT_SHA256")"
    )
}

main() {
    need_linux
    need_root "$@"
    trap cleanup_mounts EXIT

    install_deps
    download_base_iso
    extract_iso
    mount_chroot
    copy_overlay
    customize_chroot
    update_manifests
    cleanup_mounts
    repack_squashfs
    update_checksums
    build_iso

    log "Done."
    log "ISO: $OUTPUT_ISO"
    log "SHA256: $OUTPUT_SHA256"
}

main "$@"
