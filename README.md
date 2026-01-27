# GitHub Copilot File‑Referenzen  

Automation PowerShell Scripts für die Anwendungen von File-Referenzen in GitHub Copilot.    

---

## Export-OpenedVsFilesToSourceFileList

`Export-OpenedVsFilesToSourceFileList` schreibt die Dateinamen, die in Visual Studio 2022 geöffnete Dateien, in eine Datei, im GitHub Copilot File-Referenz Format  `#file:'<path>'`

### Parameter

| Parameter          | Typ    | Standard                        | Beschreibung                                              |
| ------------------ | ------ | ------------------------------- | --------------------------------------------------------- |
| `OutputPath`       | String | `"<ScriptDir>\SourceFiles.txt"` | Pfad zur Ausgabedatei                                     |
| `WorkspaceRoot`    | String | `""`                            | Optionaler Workspace-Root für relative Pfade              |
| `UseRelativePaths` | Switch | `$false`                        | Pfade relativ zu WorkspaceRoot ausgeben                   |
| `Group`            | Switch | `$true`                         | Dateien nach Typ gruppieren (Controllers, Services, etc.) |

### Anwendungsbeispiel

```powershell
# Grundlegende Verwendung - exportiert alle geöffneten Dateien mit absoluten Pfaden
.\Export-OpenedVsFilesToSourceFileList.ps1

# Mit relativen Pfaden und Workspace-Root
.\Export-OpenedVsFilesToSourceFileList.ps1 -WorkspaceRoot "C:\Projects\MyApp" -UseRelativePaths

# Ohne Gruppierung, alle Dateien in einer Liste
.\Export-OpenedVsFilesToSourceFileList.ps1 -Group:$false
```

Beispiel Ergebnis: Die generierte `SourceFiles.txt` enthält:

```
Relevanten Implementierungen / Source:

Controllers
#file:'Controllers\HomeController.cs'
#file:'Controllers\ApiController.cs'

Services
#file:'Services\UserService.cs'
#file:'Services\EmailService.cs'

Razor Pages
#file:'Pages\Index.cshtml'
#file:'Pages\Privacy.cshtml'

Other
#file:'Program.cs'
#file:'appsettings.json'
```

### Voraussetzungen

- Visual Studio 2022 muss geöffnet sein
- PowerShell muss mit gleichen Rechten wie Visual Studio ausgeführt werden (Administrator falls VS als Admin läuft)

---

## Open-VsFiles

`Open-VsFiles` liest eine Textdatei mit GitHub Copilot File-Referenzen und öffnet diese Dateien automatisch in einer laufenden Visual Studio 2022 Instanz.

### Parameter

| Parameter      | Typ    | Standard       | Beschreibung                                                 |
| -------------- | ------ | -------------- | ------------------------------------------------------------ |
| `FileListPath` | String | (erforderlich) | Vollständiger Pfad zur Textdatei mit den zu öffnenden Dateien |

### Anwendungsbeispiel

```powershell
# Dateien aus einer SourceFiles.txt öffnen
.\Open-VsFiles.ps1 -FileListPath "SourceFiles.txt"

# Dateien aus einer anderen Liste öffnen
.\Open-VsFiles.ps1 -FileListPath "ProviderSourceFilesForGitHubCopilot.txt"
```

Beispiel Ergebnis: Das Skript öffnet alle in der Datei enthaltenen `#file:'<path>'` Referenzen in Visual Studio:

```
Suche nach Visual Studio 2022 Instanzen...
Verbunden mit: Microsoft Visual Studio 2022
Öffne: Controllers\HomeController.cs
Öffne: Services\UserService.cs
Öffne: Pages\Index.cshtml
...
--------------------------------------------------
Fertig. 15 Dateien geöffnet.
```

### Voraussetzungen

- Visual Studio 2022 muss geöffnet sein
- PowerShell muss mit gleichen Rechten wie Visual Studio ausgeführt werden
- Die Quelldatei muss `#file:'<path>'` Format enthalten

---

## SourceFilesToOpen

`SourceFilesToOpen` ist ein vereinfachter Wrapper für `Open-VsFiles.ps1` mit einem fest codierten Dateipfad. Ideal für schnellen Zugriff auf häufig verwendete Dateilisten.

Das Skript ist ein Einzeiler:

```powershell
.\Open-VsFiles.ps1 -FileListPath "SourceFiles.txt"
```

### Definieren weitere Workspaces

**Schritt 1: Dateiliste erstellen**
Erstellen Sie eine Textdatei mit Ihrem gewünschten Namen, z.B. `ProviderV2SourceFiles.txt` 

> [!TIP]
>
> Die Datei kann mit `Export-OpenedVsFilesToSourceFileList` erstellt werden, wenn die entsprechenden Dateien in Visual Studio geöffnet sind. 

Beispiel einer Source File List für den Workspace Provider Version 2 `ProviderV2SourceFiles.txt`

```
Relevanten Implementierungen / Source:

Controllers
#file:'Controllers\ProviderController.cs'

Services
#file:'Services\ProviderServiceV2.cs'
#file:'Services\ValidationService.cs'

Models
#file:'Models\ProviderModel.cs'

Other
#file:'Program.cs'
```

**Schritt 2: PowerShell Wrapper erstellen**
Erstellen Sie eine entsprechende `.ps1` Datei, z.B. `ProviderV2SourceFilesToOpen.ps1`:

```powershell
.\Open-VsFiles.ps1 -FileListPath "ProviderV2SourceFiles.txt"
```

**Schritt 3: Verwendung**
Führen Sie das Wrapper-Skript aus:

```powershell
.\ProviderV2SourceFilesToOpen.ps1
```

**Nutzen**

- *Schneller Zugriff*: Keine Parameter erforderlich
- *Workspace-spezifisch*: Jede Projektgruppe kann eigene Listen haben
- *Einfache Handhabung*: Doppelklick genügt zum Öffnen aller relevanten Dateien
- *Konsistente Benennung*: `SourceFiles.txt` + `*SourceFilesToOpen.ps1`

### Voraussetzungen

- `Open-VsFiles.ps1` muss im selben Verzeichnis liegen
- Visual Studio 2022 muss geöffnet sein
- Die Quelldatei muss existieren und `#file:'<path>'` Format enthalten

---

## Update-FolderStructure.ps1

`Update-FolderStructure` erstellt eine einfache Ordnerstruktur-Übersicht mit dem Windows `tree` Befehl. Ideal für schnelle Dokumentation der Projektstruktur.

Das Skript verwendet den nativen Windows `tree` Befehl mit ASCII-Zeichen:

```powershell
tree /f /a | Out-File -FilePath $targetFile -Encoding utf8
```

Das Skript verwendet:

| Eigenschaft     | Wert                                   | Beschreibung                            |
| --------------- | -------------------------------------- | --------------------------------------- |
| **Quellordner** | Parent-Verzeichnis des Skript-Ordners  | Projekt-Root wird automatisch ermittelt |
| **Zieldatei**   | `FolderStructure.txt` im Skript-Ordner | Ausgabedatei mit Baumstruktur           |

### Anwendungsbeispiel

```powershell
# Aus dem scripts/ Ordner ausführen
.\Update-FolderStructure.ps1
```

---

## Update-FolderStructureV2

`Update-FolderStructureV2` ist die erweiterte Version mit vollständiger Parameter-Kontrolle, Ausschluss-Filtern und erweiterten Formatierungsoptionen.

### Parameter

| Parameter         | Typ      | Standard                | Beschreibung                       |
| ----------------- | -------- | ----------------------- | ---------------------------------- |
| `treeFolder`      | String   | `Get-Location`          | Startordner für die Baumstruktur   |
| `targetFolder`    | String   | `$PSScriptRoot`         | Zielordner für die Ausgabedatei    |
| `targetFile`      | String   | `"FolderStructure.txt"` | Name der Zieldatei                 |
| `excludeFolders`  | String[] | `@('bin','obj')`        | Auszuschließende Ordner            |
| `ShowHiddenItems` | Switch   | `$false`                | Versteckte Dateien/Ordner anzeigen |

### Anwendungsbeispiele

```powershell
# Standardverwendung (wie V1, aber mit erweiterten Optionen)
.\Update-FolderStructureV2.ps1

# Benutzerdefinierte Ordner ausschließen
.\Update-FolderStructureV2.ps1 -excludeFolders @("bin","obj","node_modules",".git")

# Bestimmtes Verzeichnis dokumentieren
.\Update-FolderStructureV2.ps1 -treeFolder "C:\Projects\MyApp\src" -targetFolder "docs"

# Versteckte Dateien miteinbeziehen
.\Update-FolderStructureV2.ps1 -ShowHiddenItems
```

Beispiel Ergebnis

```
Folder Structure [dd.mm.yyyy hh:MM]
Z:\...\...\content\topic\GitHubCopilotReferenz\scripts\FolderStructure.txt

Z:\...\...\content\topic\GitHubCopilotReferenz
|   GitHubCopilotReferenzGuide.md
|   GitHubMd.css
|   PowerShellScripts.md
|   README.md
|   
+---images
|       github-copilot-logo.jpeg
|   
\---scripts
        Export-OpenedVsFilesToSourceFileList.ps1
        Export-OpenedVsFilesToSourceFileList-Examples.ps1
        FolderStructure.txt
        Open-VsFiles.ps1
        Open-VsFiles-Examples.ps1
        Run-VSAllCleanups.ps1
        SourceFiles.txt
        SourceFilesToOpen.ps1
        Update-FolderStructure.ps1
        Update-FolderStructureV2.ps1

```

### Voraussetzungen

- PowerShell 5.0 oder höher
- Schreibrechte im Zielverzeichnis
