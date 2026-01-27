# Update-FolderStructure.ps1
# Dieses Skript erzeugt/aktualisiert die Datei FolderStructure.txt im selben Ordner.
# Verwendet $PSScriptRoot 
# Ruft tree /f /a im Projekt‑Root auf und schreibt die Ausgabe nach docs/FolderStructure.txt.
# /A sorgt für ASCII-Zeichen (vermeidet OEM Box‑Drawing Probleme)

# Errechne Projekt-Root (Parent von docs)
$scriptDir = $PSScriptRoot
$projectRoot = Resolve-Path (Join-Path $scriptDir '..')

# Sicherstellen, dass docs existiert (falls Skript an welchem Ort ausgeführt wird)
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Ziel-Datei (im docs-Ordner)
$targetFile = Join-Path $scriptDir 'FolderStructure.txt'

# In das Projekt-Root wechseln und Baumstruktur erzeugen
Set-Location $projectRoot

# tree /f | Out-File -FilePath $targetFile -Encoding utf8

# Verwende /A um ASCII-Zeichen zu erzwingen und so Korrekten Zeichen zu vermeiden
tree /f /a | Out-File -FilePath $targetFile -Encoding utf8

Write-Output "Folder structure written to $targetFile"