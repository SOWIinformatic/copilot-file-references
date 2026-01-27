<#
.SYNOPSIS
    Lädt Dateien aus einer definierten Liste in eine laufende Visual Studio 2022 Instanz.

.DESCRIPTION
    Dieses Skript liest eine Textdatei, parst Zeilen mit dem Format #file:'<Pfad>'
    und öffnet diese Dateien in der aktiven Visual Studio 2022 (DTE 17.0) Umgebung.

.PARAMETER FileListPath
    Der vollständige Pfad zur Textdatei, welche die Liste der zu öffnenden Dateien enthält.

#>
<#
.\Open-VsFiles.ps1 -FileListPath "ProviderSourceFilesForGitHubCopilot.txt"
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Bitte geben Sie den Pfad zur Dateiliste an.")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$FileListPath
)

Set-StrictMode -Version Latest

# ---------------------------------------------------------
# 0. Admin-Check
# ---------------------------------------------------------
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "ACHTUNG: PowerShell läuft NICHT als Administrator."
    Write-Warning "Da Visual Studio als Administrator läuft, wird der Zugriff höchstwahrscheinlich verweigert."
}

# ---------------------------------------------------------
# 1. ROT Helper Definition (Namespace V9)
# ---------------------------------------------------------
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Runtime.InteropServices.ComTypes;
    using System.Collections.Generic;

    namespace VSUtilsNativeV9
    {
        public static class RotHelper
        {
            [DllImport("ole32.dll")]
            private static extern int GetRunningObjectTable(int reserved, out IRunningObjectTable prot);

            [DllImport("ole32.dll")]
            private static extern int CreateBindCtx(int reserved, out IBindCtx ppbc);

            public static object GetDteObject()
            {
                IRunningObjectTable rot;
                if (GetRunningObjectTable(0, out rot) != 0) return null;
                
                IEnumMoniker enumMoniker;
                rot.EnumRunning(out enumMoniker);
                
                IMoniker[] moniker = new IMoniker[1];
                IntPtr fetched = IntPtr.Zero;
                
                IBindCtx bindCtx;
                CreateBindCtx(0, out bindCtx);

                while (enumMoniker.Next(1, moniker, fetched) == 0)
                {
                    string displayName;
                    try 
                    {
                        moniker[0].GetDisplayName(bindCtx, null, out displayName);
                        if (!string.IsNullOrEmpty(displayName) && displayName.StartsWith("!VisualStudio.DTE.17.0"))
                        {
                            object comObject;
                            rot.GetObject(moniker[0], out comObject);
                            return comObject;
                        }
                    }
                    catch { }
                }
                return null;
            }
        }
    }
"@ -ErrorAction SilentlyContinue
} catch { }

# ---------------------------------------------------------
# 2. Visual Studio Instanz finden und verbinden
# ---------------------------------------------------------
Write-Host "Suche nach Visual Studio 2022 Instanzen..." -ForegroundColor Gray

try {
    $dte = [VSUtilsNativeV9.RotHelper]::GetDteObject()
    
    if ($null -eq $dte) {
        throw "Keine erreichbare Visual Studio Instanz gefunden. (Prüfen Sie Admin-Rechte)"
    }

    $appName = $dte.GetType().InvokeMember("Name", [System.Reflection.BindingFlags]::GetProperty, $null, $dte, $null)
    Write-Host "Verbunden mit: $appName" -ForegroundColor Green
}
catch {
    Write-Error "Konnte nicht mit der Visual Studio Instanz verbinden.`nFehler: $_"
    exit
}

# ---------------------------------------------------------
# 3. Dateien öffnen mit Retry-Logik
# ---------------------------------------------------------
if (-not (Test-Path $FileListPath)) {
    Write-Error "Die Dateiliste wurde nicht gefunden: $FileListPath"
    exit
}

$content = Get-Content -Path $FileListPath
$regexPattern = "#file:'([^']+)'"
$filesOpened = 0

# Reflection Setup für Performance
$bindingFlags = [System.Reflection.BindingFlags]::GetProperty
$invokeMethod = [System.Reflection.BindingFlags]::InvokeMethod

foreach ($line in $content) {
    if ($line -match $regexPattern) {
        $filePath = $matches[1].Trim()

        if (Test-Path -Path $filePath) {
            $retryCount = 0
            $maxRetries = 10
            $success = $false

            while (-not $success -and $retryCount -lt $maxRetries) {
                try {
                    if ($retryCount -gt 0) {
                        Write-Host "  ... Retry $($retryCount)/$maxRetries (VS Busy)" -ForegroundColor DarkGray
                    } else {
                        Write-Host "Öffne: $filePath" -ForegroundColor Cyan
                    }

                    # ItemOperations holen
                    $itemOps = $dte.GetType().InvokeMember("ItemOperations", $bindingFlags, $null, $dte, $null)
                    
                    # OpenFile aufrufen
                    $itemOps.GetType().InvokeMember("OpenFile", $invokeMethod, $null, $itemOps, @($filePath)) | Out-Null
                    
                    $success = $true
                    $filesOpened++
                    
                    # Kurze Pause nach Erfolg
                    Start-Sleep -Milliseconds 100 
                }
                catch {
                    # HResult sicher abrufen (Fix für PropertyNotFoundException)
                    $hResult = 0
                    if ($_.Exception.InnerException) {
                        $hResult = $_.Exception.InnerException.HResult
                    } elseif ($_.Exception) {
                        $hResult = $_.Exception.HResult
                    }

                    # Prüfen auf RPC_E_CALL_REJECTED (0x80010001 = -2147418111)
                    if ($hResult -eq -2147418111) {
                        $retryCount++
                        Start-Sleep -Milliseconds 500 # Wartezeit bei Busy
                    }
                    else {
                        Write-Warning "Fehler beim Öffnen von $filePath : $($_.Exception.Message)"
                        break # Anderer Fehler, Abbruch für diese Datei
                    }
                }
            }

            if (-not $success -and $retryCount -eq $maxRetries) {
                Write-Warning "Timeout: Konnte $filePath nicht öffnen (VS antwortet nicht)."
            }
        }
        else {
            Write-Warning "Datei nicht gefunden: $filePath"
        }
    }
}

Write-Host "--------------------------------------------------"
Write-Host "Fertig. $filesOpened Dateien geöffnet." -ForegroundColor Green