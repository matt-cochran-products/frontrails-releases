# FrontRails releases

Prebuilt FrontRails executables for Linux, macOS, and Windows. Every release archive includes `intent`, `intentos-mcp`, `intentos-lsp`, `export-param-schemas`, `fr`, `frontrails-health-mcp`, `frontrails-mcp`, `structureos`, `structureos-mcp`, `securityos-mcp`, and `uxos-mcp`. DocumentOS functionality ships through StructureOS.

## Install

Linux or macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/matt-cochran-products/frontrails-releases/main/install.sh | bash
```

Windows x86_64, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/matt-cochran-products/frontrails-releases/main/install.ps1 | iex
```

The installers download the version named in `releases/latest`, require its SHA-256 checksum to match before extraction or installation, and install all 11 executables. The default directory is `~/.cargo/bin` (`$CARGO_HOME/bin` when set). Add it to PATH if necessary, then run `fr --version`.

Set `FRONTRAILS_INSTALL_DIR` to choose another directory, or `FRONTRAILS_VERSION` to select an existing release such as `v0.0.23`. You can download and inspect either installer before running it. Archive assets and their `.sha256` files are also available on the [releases page](https://github.com/matt-cochran-products/frontrails-releases/releases).

Unix updates replace each executable atomically. On Windows, close running FrontRails executables before updating; run this PowerShell installer to update `fr.exe` while it is closed. A failed update can be retried.

## Platforms

| Platform | Archive target | Requirement |
| --- | --- | --- |
| Linux x86_64 | `x86_64-unknown-linux-gnu` | glibc 2.35 or newer |
| Linux ARM64 | `aarch64-unknown-linux-gnu` | glibc 2.39 or newer |
| macOS Apple Silicon | `aarch64-apple-darwin` | Apple Silicon |
| macOS Intel | `x86_64-apple-darwin` | Intel Mac |
| Windows x86_64 | `x86_64-pc-windows-msvc` | 64-bit Windows |

Unix archives use `.tar.gz`; Windows uses `.zip`. The filename format is `frontrails-vX.Y.Z-<target>.<extension>`. Unix installation requires Bash, curl, tar, and either sha256sum or shasum. Windows installation requires PowerShell 5.1 or newer.
