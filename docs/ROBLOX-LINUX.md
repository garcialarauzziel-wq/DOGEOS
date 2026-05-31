# Roblox on DogeOS

Roblox does not provide an official Linux client. DogeOS prepares the practical Linux path: Sober installed from Flathub.

## How It Works

1. DogeOS installs Flatpak and adds Flathub.
2. A first-boot systemd service tries to install Sober automatically.
3. If networking is unavailable during first boot, launch `Install Roblox (Sober)` from the app menu.
4. Open Sober and follow its first-run Roblox installation flow.

## About Roblox EXE Files

DogeOS includes Wine, Winetricks, and an `Install EXE Support` launcher for ordinary Windows `.exe` programs. That does not make the Windows Roblox Player `.exe` a reliable Linux option. For Roblox, use Sober.

## Requirements

- x86-64/AMD64 CPU.
- SSE4.1 minimum; SSE4.2 recommended.
- OpenGL ES 3.0 minimum; Vulkan 1.1 recommended.
- Internet connection for Flatpak/Sober and Roblox setup.

## Limitations

- Sober is unofficial and experimental.
- Roblox can break Linux compatibility without notice.
- DogeOS does not bypass Roblox security or anti-cheat systems.
