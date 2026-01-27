# Update-FolderStructureV2.ps1
# Schreibt Ordner Struktur gemäss den Parameter
# Parameter:
#   - treeFolder       : ab Ordner, in dem der Baum erzeugt werden soll. Default = aktueller Ordner (Get-Location).
#   - targetFolder     : Ordner, in den die Zieldatei geschrieben wird. Default = Skript-Ordner ($PSScriptRoot).
#   - targetFile       : Name der Zieldatei. Default = "FolderStructure.txt".
#   - excludeFolders   : Array von Ordnernamen (z.B. "bin","obj"), die komplett ausgeschlossen werden. 
#                        Wenn kein Wert übergeben wird oder das Array leer ist,
#                        werden standardmässig "bin" und "obj" ausgeschlossen.
#   - ShowHiddenItems  : Optionaler Switch; wenn gesetzt (true), werden versteckte Dateien/Ordner mit ausgegeben.
#                        Default = false (versteckte Elemente werden nicht angezeigt).
#
# Ausgabeformat:
#   - Ordnerzeilen: "+---Ordnername" oder "\---Ordnername" (letztes Kind)
#   - Dateien: werden vor Unterordnern gelistet, mit Pipe-Zeichen entsprechend der Hierarchie
#   - Leerzeile wird zwischen Dateigruppe und nachfolgender Unterordnerliste eingefügt (wenn beide vorhanden).
# Hinweis: Die Baum-Ausgabe wird in ASCII erzeugt und in UTF-8 geschrieben.

param(
    [Parameter(Position = 0)]
    [string]$treeFolder,

    [Parameter(Position = 1)]
    [string]$targetFolder,

    [Parameter(Position = 2)]
    [string]$targetFile,

    [Parameter(Position = 3)]
    [string[]]$excludeFolders,

    [Parameter(Position = 4)]
    [switch]$ShowHiddenItems
)

# ----- Default-Werte setzen und Pfade validieren -----

# Default für treeFolder: aktueller Arbeitsordner (Get-Location)
if (-not $PSBoundParameters.ContainsKey('treeFolder') -or [string]::IsNullOrWhiteSpace($treeFolder)) {
    $treeFolder = (Get-Location).Path
} else {
    try {
        $treeFolder = (Resolve-Path -Path $treeFolder -ErrorAction Stop).Path
    }
    catch {
        Write-Error "Der angegebene treeFolder-Pfad '$treeFolder' konnte nicht gefunden werden."
        exit 1
    }
}

# Default für targetFolder: Skript-Ordner ($PSScriptRoot)
if (-not $PSBoundParameters.ContainsKey('targetFolder') -or [string]::IsNullOrWhiteSpace($targetFolder)) {
    $targetFolder = $PSScriptRoot
} else {
    try {
        $targetFolder = (Resolve-Path -Path $targetFolder -ErrorAction Stop).Path
    }
    catch {
        New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        $targetFolder = (Resolve-Path -Path $targetFolder).Path
    }
}

# Default für targetFile: "FolderStructure.txt"
if (-not $PSBoundParameters.ContainsKey('targetFile') -or [string]::IsNullOrWhiteSpace($targetFile)) {
    $targetFile = 'FolderStructure.txt'
}

# Default für excludeFolders: wenn kein Parameter übergeben oder leer -> standardmäsig bin, obj
if (-not $PSBoundParameters.ContainsKey('excludeFolders') -or $null -eq $excludeFolders -or $excludeFolders.Count -eq 0) {
    $excludeFolders = @('bin','obj')
}

# Normiere exclude-Liste auf Lowercase für case-insensitive Vergleich
$excludeSet = $excludeFolders | ForEach-Object { $_.ToString().ToLowerInvariant() }

# Sicherstellen, dass targetFolder existiert
New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null

# Vollständiger Pfad zur Ziel-Datei
$targetFilePath = Join-Path $targetFolder $targetFile

# ----- Funktion zum Erzeugen des formatierten ASCII-Baums -----
function Write-Tree {
    param(
        [Parameter(Mandatory = $true)] [string]$DirPath,
        [string]$Prefix = ''
    )

    # Hole Kinder (Dirs und Files). Verwende -Force, filtere Hidden später falls nötig.
    try {
        $allDirs = Get-ChildItem -LiteralPath $DirPath -Directory -Force -ErrorAction Stop
        $files   = Get-ChildItem -LiteralPath $DirPath -File      -Force -ErrorAction Stop
    } catch {
        return
    }

    # Exclude-Folder entfernen (auf allen Dirs; wichtig für korrekte IsLast-Berechnung)
    if ($allDirs.Count -gt 0) {
        $allDirs = $allDirs | Where-Object { -not ($excludeSet -contains $_.Name.ToLowerInvariant()) }
    }

    # Sichtbare Dirs und Files bestimmen: abhängig von ShowHiddenItems
    $visibleDirs = $allDirs
    $visibleFiles = $files
    if (-not $ShowHiddenItems) {
        $visibleDirs = $visibleDirs | Where-Object { -not ( ($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0 ) }
        $visibleFiles = $visibleFiles | Where-Object { -not ( ($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0 ) }
    }

    # Sortierung: erst Einträge ohne führenden "_" (Unterstrich), danach alphabetisch (case-insensitive)
    $allDirs      = @($allDirs)      | Sort-Object @{ Expression = { $_.Name.StartsWith('_') }; Ascending = $true }, @{ Expression = { $_.Name.ToLowerInvariant() }; Ascending = $true }
    $visibleDirs  = @($visibleDirs)  | Sort-Object @{ Expression = { $_.Name.StartsWith('_') }; Ascending = $true }, @{ Expression = { $_.Name.ToLowerInvariant() }; Ascending = $true }
    $visibleFiles = @($visibleFiles) | Sort-Object @{ Expression = { $_.Name.StartsWith('_') }; Ascending = $true }, @{ Expression = { $_.Name.ToLowerInvariant() }; Ascending = $true }

    # Prüfen, ob nachfolgende Unterverzeichnisse existieren (alle Ordner inkl. versteckter)
    $hasSubsequentDirs = ($allDirs.Count -gt 0)

    # Dateien mit korrekter Pipe-Einrückung ausgeben
    foreach ($f in $visibleFiles) {
        if ($hasSubsequentDirs) {
            # Wenn nachfolgende Ordner existieren (auch versteckte), verwende "|   " für vertikale Linie
            $script:lines += $Prefix + '|   ' + $f.Name
        } else {
            # Wenn keine nachfolgenden Ordner, verwende "    " (nur Spaces)
            $script:lines += $Prefix + '    ' + $f.Name
        }
    }

    # Leerzeile zwischen Dateien und Unterverzeichnissen
    if ($visibleFiles.Count -gt 0 -and $visibleDirs.Count -gt 0) {
        if ($hasSubsequentDirs) {
            $script:lines += $Prefix + '|   '
        } else {
            $script:lines += $Prefix + '    '
        }
    }

    # Unterverzeichnisse (rekursiv)
    for ($i = 0; $i -lt $visibleDirs.Count; $i++) {
        $d = $visibleDirs[$i]

        # IsLast wird gegen die "vollständige" Liste berechnet, damit die Linienführung
        # auch dann stimmt, wenn versteckte Ordner nicht ausgegeben werden.
        $isLastInVisible = ($i -eq $visibleDirs.Count - 1)
        $isLastDir = $isLastInVisible
        if (-not $ShowHiddenItems) {
            $lastAllDirName = if ($allDirs.Count -gt 0) { $allDirs[$allDirs.Count - 1].Name } else { $null }
            $isLastDir = ($d.Name -eq $lastAllDirName)
        }

        # Branch-Zeichen: "+---" für normale Ordner, "\---" für letzten Ordner
        $branch = if ($isLastDir) { '\---' } else { '+---' }
        $script:lines += $Prefix + $branch + $d.Name

        # Prefix für Kinder anpassen
        $childPrefix = $Prefix + $(if ($isLastDir) { '    ' } else { '|   ' })
        Write-Tree -DirPath $d.FullName -Prefix $childPrefix

        # Leerzeile nach letztem Unterverzeichnis, wenn nicht letzter Ordner auf dieser Ebene
        if ($isLastDir -and $i -lt $visibleDirs.Count - 1) {
            $script:lines += $Prefix + '    '
        }
        # ODER: Leerzeile nach jedem Unterverzeichnis ausser dem letzten
        elseif (-not $isLastInVisible -and $i -lt $visibleDirs.Count - 1) {
            $script:lines += $Prefix + '|   '
        }
    }
}

# ----- Baum erzeugen und in Datei schreiben -----

$script:lines = @()

# Header hinzufügen
$script:lines += "Folder Structure [$(Get-Date -Format 'dd.MM.yyyy HH:mm')]"
$script:lines += "$targetFilePath"
$script:lines += ""
$script:lines += "$treeFolder"

# Baumstruktur für den Root-Ordner erzeugen
Write-Tree -DirPath $treeFolder -Prefix ''

# Schreibe in Datei (UTF8)
$script:lines | Out-File -FilePath $targetFilePath -Encoding utf8

Write-Output "Folder structure written to $targetFilePath"