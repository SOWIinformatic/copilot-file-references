<#
.SYNOPSIS
    Exportiert aktuell in Visual Studio geöffnete Dateien in eine SourceFiles.txt im Copilot #file:'<path>' Format.
    Optional Gruppierung nach Typ (Controllers, Services, Razor Pages, ...). Standard-Ausgabepfad ist das Verzeichnis des Skripts.

.PARAMETER OutputPath
    Pfad zur Ausgabedatei. Wenn leer, wird "<ScriptDir>\SourceFiles.txt" verwendet.

.PARAMETER WorkspaceRoot
    Optionaler Workspace-Root. Falls angegeben und -UseRelativePaths gesetzt ist, werden Pfade relativ zu diesem Root geschrieben.

.PARAMETER UseRelativePaths
    Wenn gesetzt, werden Pfade relativ zu -WorkspaceRoot ausgegeben (nur wenn WorkspaceRoot gesetzt und Datei im Root liegt).

.PARAMETER Group
    Wenn gesetzt (Standard), werden Dateien nach Typ gruppiert (Controllers, Services, Razor Pages, ...).

.EXAMPLE
    .\Export-OpenVsFilesToSourceFiles.ps1 -WorkspaceRoot "C:\Data\Projects\Velo2024\Source\Velo" -UseRelativePaths
#>

param(
    [string]$OutputPath = "",
    [string]$WorkspaceRoot = "",
    [switch]$UseRelativePaths,
    [switch]$Group = $true
)

Set-StrictMode -Version Latest

# Admin/Hilfe Hinweis (ROT funktioniert nur wenn gleiche Rechte)
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Hinweis: PowerShell läuft nicht als Administrator. Falls Visual Studio als Administrator läuft, wird die ROT-Verbindung fehlschlagen." -ForegroundColor Yellow
}

# --- Default OutputPath: Verzeichnis des Skripts falls nicht gesetzt ---
$scriptDir = if ($PSCommandPath) { [System.IO.Path]::GetDirectoryName($PSCommandPath) } else { (Get-Location).Path }
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptDir "SourceFiles.txt"
}
$fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$fullOutputDir = [System.IO.Path]::GetDirectoryName($fullOutputPath)
if (-not (Test-Path $fullOutputDir)) {
    New-Item -ItemType Directory -Path $fullOutputDir | Out-Null
}

# --- ROT helper: get running Visual Studio DTE object ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class RotHelper {
    [DllImport("ole32.dll")]
    private static extern int GetRunningObjectTable(int reserved, out IRunningObjectTable prot);

    [DllImport("ole32.dll")]
    private static extern int CreateBindCtx(int reserved, out IBindCtx ppbc);

    public static object GetDte() {
        IRunningObjectTable rot;
        if (GetRunningObjectTable(0, out rot) != 0) return null;
        IEnumMoniker enumMoniker;
        rot.EnumRunning(out enumMoniker);
        IMoniker[] moniker = new IMoniker[1];
        IntPtr fetched = IntPtr.Zero;
        IBindCtx bindCtx;
        CreateBindCtx(0, out bindCtx);
        while (enumMoniker.Next(1, moniker, fetched) == 0) {
            string displayName = null;
            try {
                moniker[0].GetDisplayName(bindCtx, null, out displayName);
                if (!string.IsNullOrEmpty(displayName) && displayName.StartsWith("!VisualStudio.DTE.17.0")) {
                    object comObject;
                    rot.GetObject(moniker[0], out comObject);
                    return comObject;
                }
            } catch {}
        }
        return null;
    }
}
"@ -ErrorAction Stop

$dte = [RotHelper]::GetDte()
if ($null -eq $dte) {
    Write-Error "Keine laufende Visual Studio 2022 Instanz gefunden. Stelle sicher, dass VS geöffnet ist und du dieselben Rechtegrenzen verwendest."
    exit 1
}

# --- Grouping helper ---
function Get-GroupFromPath {
    param([string]$path)
    if (-not $path) { return "Other" }
    $p = $path.ToLowerInvariant()
    if ($p -match "\\interfaces\\") { return "Interfaces" }
    if ($p -match "\\controllers\\") { return "Controllers" }
    if ($p -match "\\services\\") { return "Services" }
    if ($p -match "\\pages\\") { return "Razor Pages" }
    if ($p -match "\\views\\") { return "Views" }
    if ($p -match "\\models\\") { return "Models" }
    if ($p -match "\\repositories\\") { return "Repositories" }
    if ($p -match "\\wwwroot\\") { return "Web Assets" }
    if ($p -match "\\docs\\") { return "Docs" }
    if ($p -match "\.md$") { return "Docs" }
    if ($p -match "\.txt$") { return "Docs" }
    if ($p -match "\\exceptions\\") { return "Exceptions" }
    if ($p -match "controller\.cs$") { return "Controllers" }
    if ($p -match "\.cshtml$" -or $p -match "\.cshtml\.cs$") { return "Razor Pages" }
    return "Other"
}

# --- Collect open documents ---
$regexEscape = "#file:'{0}'"
$groups = @{}

try {
    $docCount = $dte.Documents.Count
    for ($i = 1; $i -le $docCount; $i++) {
        $doc = $dte.Documents.Item($i)
        $fullName = $null
        try { $fullName = $doc.FullName } catch {}
        if ([string]::IsNullOrWhiteSpace($fullName)) { continue } # unsaved/temporary

        $pathToWrite = $fullName

        if ($UseRelativePaths -and -not [string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
            try {
                $workspaceFull = [System.IO.Path]::GetFullPath($WorkspaceRoot)
                $uriWorkspace = New-Object System.Uri((if ($workspaceFull.EndsWith('\')) { $workspaceFull } else { $workspaceFull + '\' }))
                $uriFile = New-Object System.Uri($fullName)
                if ($uriFile.AbsolutePath.StartsWith($uriWorkspace.AbsolutePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $relative = $uriWorkspace.MakeRelativeUri($uriFile).ToString().Replace('/', '\')
                    $pathToWrite = $relative
                }
            } catch {
                $pathToWrite = $fullName
            }
        }

        if ($Group) {
            $g = Get-GroupFromPath -path $fullName
            if (-not $groups.ContainsKey($g)) { $groups[$g] = @() }
            $groups[$g] += ("#file:'{0}'" -f $pathToWrite)
        } else {
            if (-not $groups.ContainsKey("All")) { $groups["All"] = @() }
            $groups["All"] += ("#file:'{0}'" -f $pathToWrite)
        }
    }

    # --- Build output lines with preferred group order ---
    $ordered = @("Controllers","Services","Razor Pages","Repositories","Models","Views","Web Assets","Docs","Other","All")
    $lines = @()
    $lines += "Relevanten Implementierungen / Source:"
    $lines += ""

    foreach ($key in $ordered) {
        if ($groups.ContainsKey($key)) {
            $lines += $key
            $lines += $groups[$key]
            $lines += "" # blank line
        }
    }

    # If any other groups not listed above, append them
    $remaining = $groups.Keys | Where-Object { $ordered -notcontains $_ }
    foreach ($key in $remaining) {
        $lines += $key
        $lines += $groups[$key]
        $lines += ""
    }

    # Write file (UTF8 without BOM)
    $lines | Set-Content -Path $fullOutputPath -Encoding utf8

    $count = ($groups.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "Export abgeschlossen. $count Dateien geschrieben nach: $fullOutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Fehler beim Auslesen der geöffneten Dateien: $($_.Exception.Message)"
    exit 1
}