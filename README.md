# DogeOS

DogeOS is a small Ubuntu-based ISO recipe that prepares a desktop system for Roblox through Sober.

Important: Roblox does not officially support Linux. DogeOS uses Flatpak and the unofficial Sober runtime from VinegarHQ so Roblox can be installed and launched on Linux when Sober is working upstream.

## What This Builds

- Base: Ubuntu 26.04 LTS Desktop amd64.
- Output ISO name: `DogeOS-0.1-amd64.iso`.
- Branding: `DogeOS` release files, hostname, issue banner, and a simple wallpaper.
- Roblox path: Flatpak + Flathub + Sober installer service/launcher.
- Windows `.exe` path: Wine, Winetricks, 32-bit Wine support, and a Bottles installer/repair launcher.
- Gaming packages: Mesa Vulkan drivers, Vulkan tools, GameMode, MangoHud.

## Build Without Installing Anything On Your PC

Use the included GitHub Actions workflow to build the ISO in the cloud:

1. Put this project in a GitHub repository.
2. Open the repository on GitHub.
3. Go to `Actions` -> `Build DogeOS ISO` -> `Run workflow`.
4. Download the artifact named `DogeOS-0.1-amd64`.

That artifact contains:

```text
DogeOS-0.1-amd64.iso
DogeOS-0.1-amd64.iso.sha256
```

## Local Build Requirements

Build from an Ubuntu/Debian Linux environment. WSL 2 usually works if it has enough disk space.

Recommended free disk space: 35 GB or more.

```bash
sudo bash build-dogeos.sh
```

The script downloads the official Ubuntu 26.04 Desktop ISO, verifies it against Ubuntu's SHA256SUMS file, customizes the live filesystem, and writes:

```text
dist/DogeOS-0.1-amd64.iso
```

On Windows, use the helper only if you already have an Ubuntu WSL distro:

```powershell
.\build-dogeos.ps1
```

## Roblox Notes

DogeOS does not ship a native Roblox Linux client because Roblox does not provide one. It prepares Sober:

- First boot attempts to install Sober from Flathub automatically when networking is available.
- The app menu also contains `Install Roblox (Sober)` to install or repair Sober manually.
- On first Sober launch, Sober prompts for the Roblox install flow.

Minimum Sober requirements include an x86-64 CPU with SSE4.1 and OpenGL ES 3.0-capable graphics. Vulkan 1.1 and SSE4.2 are recommended.

## Windows EXE Support

DogeOS includes Wine and Winetricks for ordinary Windows `.exe` programs. It also includes `Install EXE Support`, a menu launcher that repairs Wine and installs Bottles from Flathub.

Use:

```bash
wine setup.exe
```

For managed prefixes, open Bottles after running `Install EXE Support`.

Roblox's Windows `.exe` is not the supported Roblox path on DogeOS. Roblox currently lists Linux as unsupported, and Wine-based Roblox has been unreliable because of Roblox client/anti-cheat changes. Use Sober for Roblox.

## Customization

Useful environment variables:

```bash
DOGEOS_VERSION=0.2 sudo -E bash build-dogeos.sh
UBUNTU_RELEASE=26.04 sudo -E bash build-dogeos.sh
BASE_ISO_URL=https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso sudo -E bash build-dogeos.sh
```

Files copied into the ISO live filesystem live under `overlay/`.

## Caveats

- Sober is unofficial, closed-source, and experimental.
- Roblox can change compatibility at any time.
- Wine/Bottles are for general Windows `.exe` compatibility; they do not guarantee Roblox Player for Windows will run.
- This project does not bypass Roblox anti-cheat or platform restrictions.
- You should test the ISO in a VM before installing it on real hardware.

## References

- Ubuntu 26.04 LTS downloads: https://releases.ubuntu.com/26.04/
- Roblox OS requirements: https://en.help.roblox.com/hc/es/articles/203312800-Requisitos-de-hardware-y-sistema-operativo-de-la-computadora
- Sober install docs: https://vinegarhq.org/Sober/Installation.html
- Sober homepage: https://sober.vinegarhq.org/
