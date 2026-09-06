$ErrorActionPreference = 'Stop'
$repo = 'matt-cochran-products/frontrails-releases'
$binaries = @('intent', 'intentos-mcp', 'intentos-lsp', 'export-param-schemas', 'fr', 'frontrails-health-mcp', 'frontrails-mcp', 'structureos', 'structureos-mcp', 'securityos-mcp', 'uxos-mcp')
if ($env:OS -ne 'Windows_NT' -or [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'This installer supports Windows x86_64. Use install.sh for Linux or macOS.'
}
$version = $env:FRONTRAILS_VERSION
if (-not $version) {
    $version = (Invoke-RestMethod "https://raw.githubusercontent.com/$repo/main/releases/latest").ToString().Trim()
}
if ($version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Version must be vX.Y.Z.' }
$prefix = $env:FRONTRAILS_INSTALL_DIR
if (-not $prefix) {
    $cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $HOME '.cargo' }
    $prefix = Join-Path $cargoHome 'bin'
}
$archive = "frontrails-$version-x86_64-pc-windows-msvc.zip"
$base = "https://github.com/$repo/releases/download/$version"
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('frontrails-download-' + [guid]::NewGuid())
$stage = $null
try {
    New-Item -ItemType Directory -Path $work | Out-Null
    $archivePath = Join-Path $work $archive
    $checksumPath = "$archivePath.sha256"
    Invoke-WebRequest -UseBasicParsing "$base/$archive" -OutFile $archivePath
    Invoke-WebRequest -UseBasicParsing "$base/$archive.sha256" -OutFile $checksumPath
    $checksum = (Get-Content -Raw -LiteralPath $checksumPath).Trim()
    if ($checksum -notmatch '^([0-9a-fA-F]{64})\s+(.+)$') { throw 'Missing or invalid SHA256 checksum.' }
    $expected = $Matches[1]
    if ($Matches[2] -ne $archive) { throw 'Checksum filename does not match archive.' }
    $actual = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw 'SHA256 mismatch; nothing installed.' }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $expectedNames = @($binaries | ForEach-Object { "$_.exe" })
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
        if ($names.Count -ne 11 -or @($names | Select-Object -Unique).Count -ne 11) {
            throw 'Archive must contain all 11 executables exactly once.'
        }
        foreach ($name in $names) {
            if ($expectedNames -cnotcontains $name) { throw "Unexpected archive entry: $name" }
        }
    } finally { $zip.Dispose() }
    $unpacked = Join-Path $work 'unpacked'
    Expand-Archive -LiteralPath $archivePath -DestinationPath $unpacked
    foreach ($binary in $binaries) {
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked "$binary.exe") -PathType Leaf)) {
            throw "Missing executable: $binary.exe"
        }
    }
    New-Item -ItemType Directory -Path $prefix -Force | Out-Null
    $stage = Join-Path $prefix ('.frontrails-install-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $stage | Out-Null
    foreach ($binary in $binaries) {
        Copy-Item -LiteralPath (Join-Path $unpacked "$binary.exe") -Destination $stage
    }
    foreach ($binary in $binaries) {
        try {
            Move-Item -LiteralPath (Join-Path $stage "$binary.exe") -Destination (Join-Path $prefix "$binary.exe") -Force
        } catch {
            throw "Cannot replace $binary.exe. Close all running FrontRails executables (including fr.exe) and rerun this PowerShell installer. $($_.Exception.Message)"
        }
    }
    Write-Host "Installed FrontRails $version (11 executables) in $prefix"
    if ($env:PATH.Split(';') -notcontains $prefix) {
        Write-Host "Add $prefix to your user PATH, open a new terminal, then run: fr --version"
    }
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force }
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
