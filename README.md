# CDK Drive / BlueZone Reset Tool

A PowerShell remediation utility for resetting or removing legacy CDK Drive, ADP webSuite, BlueZone, BlueZone VBA, ADPInit, CDKInit, and related local data.

The script supports:

- Basic reset of user-specific cache and configuration data.
- Thorough machine-wide cleanup and removal of known BlueZone/CDK/ADP components.
- Full user-profile cleanup followed by machine-wide removal.
- Microsoft Entra joined, AD-joined, workgroup, and local-account Windows computers.
- Current-user, exact profile-path, SID, best-effort identity, and all-local-profile targeting.
- Microsoft Edge cache cleanup.
- BlueZone configuration/macro backups before active data is removed.
- Detailed text logging and Windows Application Event Log summaries.
- Interactive menu or scripted PowerShell use.

> **Warning:** The tool force-closes CDK Drive, BlueZone, Edge, and related processes. Unsaved work can be lost. Thorough and FullUser modes can uninstall applications, remove local data, delete application folders, and remove selected machine-wide registry entries. Test on a pilot machine before production use.

---

## Requirements

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 or newer PowerShell with Windows management cmdlets available.
- `robocopy.exe`, `eventcreate.exe`, `msiexec.exe`, `takeown.exe`, `icacls.exe`, and `regsvr32.exe`.
- Administrator permissions for:
  - `Thorough` mode.
  - `FullUser` mode.
  - Any profile targeting other than the current account.
  - `-AllUsers`.
- Targeted profiles must already exist locally on the computer.

---

## Installation

Save the script as:

```text
CDK-BlueZone-Reset.ps1
```

Before running downloaded scripts, review the code and follow your organization’s PowerShell execution-policy and code-signing requirements.

For a one-time local launch, an administrator may use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CDK-BlueZone-Reset.ps1
```

This does not change the computer’s persistent execution policy.

---

## Quick Start

Open an interactive menu:

```powershell
.\CDK-BlueZone-Reset.ps1
```

Run a Basic reset for the current user:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Basic
```

Run Thorough machine-wide cleanup from an elevated PowerShell session:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Thorough
```

Run profile cleanup for every existing normal local user profile:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Basic -AllUsers
```

Run selected user-profile cleanup plus machine-wide removal:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode FullUser -AllUsers
```

Show help:

```powershell
.\CDK-BlueZone-Reset.ps1 -Help
```

---

## Interactive Menu

When run without `-Mode`, the tool displays:

```text
[1] Basic profile reset
    Reset cache and configuration data for the current account.
    Does not uninstall CDK Drive, BlueZone, or ADP components.

[2] Thorough machine cleanup
    Requires Administrator privileges.
    Removes machine-wide CDK/BlueZone/ADP components, cache data,
    residual folders, and selected registry entries.
    Does not alter any user profile.

[3] Full user and machine cleanup
    Requires Administrator privileges.
    Resets the current account profile, then runs machine cleanup.
    Use only when the current account is the profile to be reset.

[Q] Quit
    Exit without making any changes.
```

The interactive menu intentionally targets only the account that launches PowerShell. To target another profile or all profiles, use the command-line options below.

---

## Modes

| Mode | Purpose | Administrator required | User profiles affected |
|---|---|---:|---|
| `Basic` | Clears selected profile cache/configuration data | Only for non-current targets | Current account by default; explicit selected profiles when specified |
| `Thorough` | Removes machine-wide BlueZone/CDK/ADP components and remnants | Yes | None |
| `FullUser` | Runs selected profile cleanup, then Thorough machine cleanup | Yes | Current account by default; explicit selected profiles when specified |

### Recommended workflow

For a normal cache/profile remediation:

1. Have the affected user run:

   ```powershell
   .\CDK-BlueZone-Reset.ps1 -Mode Basic
   ```

2. If a full uninstall/removal is necessary, IT runs:

   ```powershell
   .\CDK-BlueZone-Reset.ps1 -Mode Thorough
   ```

This two-stage method prevents an elevated IT account from inadvertently clearing its own profile while handling a different user’s computer.

---

## Profile Targeting

The script uses `Win32_UserProfile` to identify actual existing Windows profiles. It does not assume the Entra UPN, AD account name, or local username matches the folder beneath `C:\Users`.

For example, an Entra sign-in identity might be:

```text
jane.smith@contoso.com
```

while the Windows profile folder might be:

```text
C:\Users\janes
```

### Current process account

With no targeting argument, the script selects the profile belonging to the account that runs PowerShell:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Basic
```

### Exact local profile path

Use `-ProfilePath` when you know the existing local profile folder:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Basic -ProfilePath 'C:\Users\janes'
```

Target more than one profile:

```powershell
.\CDK-BlueZone-Reset.ps1 `
  -Mode Basic `
  -ProfilePath 'C:\Users\janes', 'C:\Users\jdoe'
```

### Windows profile SID

Use `-Sid` when your RMM, Intune, SCCM, or inventory system has the profile SID:

```powershell
.\CDK-BlueZone-Reset.ps1 `
  -Mode Basic `
  -Sid 'S-1-12-1-123456789-123456789-123456789-123456789'
```

Multiple SIDs:

```powershell
.\CDK-BlueZone-Reset.ps1 `
  -Mode Basic `
  -Sid 'S-1-12-1-111111111-222222222-333333333-444444444',
       'S-1-5-21-111111111-222222222-333333333-1001'
```

### Best-effort user identity

Use `-User` to attempt matching against existing local profile-folder names:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Basic -User 'jane.smith@contoso.com'
```

The script accepts inputs shaped like:

```text
user@company.com
AzureAD\user@company.com
DOMAIN\username
COMPUTER\localuser
```

> `-User` is best-effort only. On Entra-joined and AD-joined computers, an identity cannot always be mapped offline to a unique profile folder or SID. For unattended deployment, use `-ProfilePath`, `-Sid`, or `-AllUsers`.

### All normal local profiles

Use `-AllUsers` to clean every existing non-special Windows profile:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode Basic -AllUsers
```

It excludes Windows profiles marked as Special, including service/system-style profiles such as:

- Default
- Public
- SYSTEM
- Local Service
- Network Service

> **Caution:** `-AllUsers` can reset cache/configuration data for every eligible profile on the endpoint. Run it elevated and use it only when that scope is intended.

---

## Command Reference

| Action | Example |
|---|---|
| Interactive menu | `.\CDK-BlueZone-Reset.ps1` |
| Help | `.\CDK-BlueZone-Reset.ps1 -Help` |
| Basic reset, current user | `.\CDK-BlueZone-Reset.ps1 -Mode Basic` |
| Basic reset, one profile | `.\CDK-BlueZone-Reset.ps1 -Mode Basic -ProfilePath 'C:\Users\janes'` |
| Basic reset, one SID | `.\CDK-BlueZone-Reset.ps1 -Mode Basic -Sid 'S-1-12-1-...'` |
| Basic reset, all profiles | `.\CDK-BlueZone-Reset.ps1 -Mode Basic -AllUsers` |
| Thorough machine cleanup | `.\CDK-BlueZone-Reset.ps1 -Mode Thorough` |
| Full cleanup, selected profile | `.\CDK-BlueZone-Reset.ps1 -Mode FullUser -ProfilePath 'C:\Users\janes'` |
| Full cleanup, all profiles | `.\CDK-BlueZone-Reset.ps1 -Mode FullUser -AllUsers` |

---

## Basic Mode

Basic mode performs user-profile cleanup only.

For each selected Windows profile, it:

- Stops CDK Drive, BlueZone, Edge, and related processes.
- Clears Microsoft Edge cache-focused folders.
- Removes the ClickOnce application cache:

  ```text
  AppData\Local\Apps\2.0
  ```

- Removes the downloaded .NET assembly cache:

  ```text
  AppData\Local\assembly\dl3
  ```

- Removes local ADP roaming-profile data:

  ```text
  AppData\Roaming\ADP
  ```

- Backs up and then removes active BlueZone profile folders:

  ```text
  AppData\Roaming\BlueZone
  AppData\Roaming\BlueZone Web
  Documents\BlueZone
  ```

When Basic mode targets the account running PowerShell, it also clears legacy Internet Explorer / Internet Options browsing data for that account.

When Basic mode targets another user profile or `-AllUsers`, Internet Explorer cleanup is intentionally skipped. It is a per-user browser operation that cannot safely be redirected to another offline profile with the same mechanism.

---

## Thorough Mode

Thorough mode is machine-wide only and requires Administrator privileges.

It:

- Stops CDK Drive, BlueZone, Edge, and related processes.
- Removes machine cache folders:

  ```text
  C:\ProgramData\ADP\websuite
  C:\ProgramData\CDK\Drive
  ```

- Attempts silent MSI uninstalls for known legacy BlueZone, BlueZone VBA, ADPInit, CDKInit, and related components.
- Runs the legacy BlueZone VBA executable uninstaller if it exists.
- Removes known residual ADP/BlueZone program folders.
- Removes selected machine-wide BlueZone/ADP registry entries.
- Unregisters and moves `sglw2hcm.ocx` if present.

Thorough mode intentionally does **not** change:

- User `%APPDATA%`
- User `%LOCALAPPDATA%`
- User Documents folders
- User `HKCU` registry keys
- Microsoft Edge user-profile data
- Legacy IE data

Target arguments passed with Thorough mode are ignored because Thorough mode is designed as machine-only cleanup.

---

## FullUser Mode

`FullUser` requires Administrator privileges and combines:

1. Selected user-profile cleanup.
2. Thorough machine-wide cleanup.

Example:

```powershell
.\CDK-BlueZone-Reset.ps1 -Mode FullUser -AllUsers
```

For a managed deployment running as `SYSTEM`, use `-ProfilePath`, `-Sid`, or `-AllUsers` rather than relying on the process account. The SYSTEM profile is not the interactive user’s profile.

---

## Microsoft Edge Cleanup

The script force-closes:

```text
msedge.exe
msedgewebview2.exe
```

For each selected profile, it clears cache-oriented data below:

```text
AppData\Local\Microsoft\Edge\User Data
```

This includes cache locations such as:

- `Cache`
- `Code Cache`
- `GPUCache`
- `Network\Cache`
- `Service Worker\CacheStorage`
- `Service Worker\ScriptCache`
- Shader/graphics cache folders

The script deliberately does **not** remove Edge’s full `User Data` folder.

It should preserve:

- Browser profiles
- Favorites
- Saved passwords
- Extensions
- Browser preferences
- Most session and sign-in state
- Browsing history

Users may need to reload websites after cache cleanup.

---

## BlueZone Backup Locations

When elevated, BlueZone data is backed up under:

```text
C:\ProgramData\CDKBlueZoneReset\Backups\<ProfileFolder>\<Timestamp>\
```

When Basic mode runs without elevation, backup data is stored under:

```text
%LOCALAPPDATA%\CDKBlueZoneReset\Backups\<ProfileFolder>\<Timestamp>\
```

The backup operation uses `robocopy`. If a backup returns an exit code of 8 or higher, the source BlueZone folder is retained and a warning is logged.

---

## Logging and Event Viewer

### Text logs

When elevated:

```text
C:\ProgramData\CDKBlueZoneReset\Logs\
```

When running non-elevated Basic mode:

```text
%LOCALAPPDATA%\CDKBlueZoneReset\Logs\
```

### Windows Event Log

Summary entries are written to:

```text
Event Viewer
  > Windows Logs
    > Application
```

Use this Event source filter:

```text
CDKBlueZoneReset
```

| Event ID | Meaning |
|---:|---|
| 1000 | Basic profile reset started |
| 1001 | Basic profile reset completed |
| 1002 | Basic profile reset completed with warnings |
| 2000 | Thorough machine cleanup started |
| 2001 | Thorough machine cleanup completed |
| 2100 | MSI uninstall returned an unexpected exit code |
| 3000 | Full user and machine cleanup started |
| 3001 | Full user and machine cleanup completed |
| 3003 | Full user and machine cleanup completed with warnings |
| 4002 | Administrator privileges were required but unavailable |
| 4100 | Individual profile cleanup started |
| 4101 | Individual profile cleanup completed |
| 4102 | Profile or cleanup warning |

---

## Exit Codes

| Exit code | Meaning |
|---:|---|
| `0` | Completed successfully |
| `1` | Completed with warnings, or no eligible profile was selected |
| `2` | Invalid or unsupported mode |
| `5` | Administrator privileges were required but unavailable |

Review the text log and Event Viewer after a non-zero exit code.

---

## Warnings and Limitations

- The tool force-closes applications. Unsaved work can be lost.
- Test all modes in a VM or pilot group before wider deployment.
- Confirm the included MSI product codes match software actually used in your environment.
- The script intentionally does **not** manually delete generic Windows Installer database entries under `Installer\Products`, `Installer\Components`, or `Installer\UserData`; manual deletion can damage Windows Installer repair/uninstall behavior.
- Target profiles must exist locally before they can be selected.
- `-User` may not reliably resolve Entra UPNs or AD identities to a local profile. Use `-Sid` or `-ProfilePath` for deterministic automation.
- OneDrive Known Folder Move or folder redirection may place user Documents data elsewhere than `C:\Users\<profile>\Documents`.
- BlueZone backups stay on the endpoint unless you collect or copy them through a separate process.
- The script does not configure Edge to clear browsing data on exit. That is intentionally excluded because it is a persistent browser-policy change, not a one-time reset.

---

## Repository Layout

```text
CDK-Global-resetscript/
├── CDK-BlueZone-Reset.ps1
├── README.md
├── CHANGELOG.md
└── .gitignore
```

Suggested `.gitignore` entries:

```gitignore
*.log
*.bak
*.old
```

---

## Script

Save the production script as:

```text
CDK-BlueZone-Reset.ps1
```

```powershell
<#
.SYNOPSIS
    CDK Drive / BlueZone Reset and Removal Tool.

.DESCRIPTION
    A single-file PowerShell remediation utility for legacy CDK Drive, ADP
    webSuite, BlueZone, BlueZone VBA, ADPInit, and CDKInit installations.

    Modes:
      Basic    - Selected user-profile cache/configuration reset.
      Thorough - Elevated machine-wide removal only.
      FullUser - Elevated selected profile reset plus machine-wide removal.

    Supported profile targeting:
      - Current process account (default)
      - Exact local profile path
      - Windows profile SID
      - Best-effort profile-folder match from an identity
      - All existing normal local profiles

.NOTES
    Requires Windows PowerShell 5.1+ or PowerShell with Windows management
    cmdlets available. Run -Help for usage.
#>

[CmdletBinding()]
param(
    [ValidateSet('Basic', 'Thorough', 'FullUser', 'Help')]
    [string]$Mode,

    [string[]]$ProfilePath,

    [string[]]$Sid,

    [string[]]$User,

    [switch]$AllUsers,

    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$script:ToolName = 'CDKBlueZoneReset'
$script:EventLogName = 'Application'
$script:HadWarnings = $false
$script:Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$script:CurrentSid = $script:CurrentIdentity.User.Value
$script:CurrentAccount = $script:CurrentIdentity.Name

$principal = New-Object System.Security.Principal.WindowsPrincipal($script:CurrentIdentity)
$script:IsAdministrator = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

$programDataRoot = Join-Path $env:ProgramData $script:ToolName
$userLocalRoot = Join-Path $env:LOCALAPPDATA $script:ToolName

if ($script:IsAdministrator) {
    $script:LogRoot = Join-Path $programDataRoot 'Logs'
    $script:BackupRoot = Join-Path $programDataRoot 'Backups'
}
else {
    $script:LogRoot = Join-Path $userLocalRoot 'Logs'
    $script:BackupRoot = Join-Path $userLocalRoot 'Backups'
}

New-Item -ItemType Directory -Path $script:LogRoot -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $script:BackupRoot -Force -ErrorAction SilentlyContinue | Out-Null

$script:LogFile = Join-Path $script:LogRoot ('{0}_{1}.log' -f $script:ToolName, $script:Timestamp)

function Write-ToolLog {
    param([Parameter(Mandatory)][string]$Message)

    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try {
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    }
    catch {
        Write-Verbose $line
    }
}

function Write-ToolEvent {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$EntryType,

        [Parameter(Mandatory)][int]$EventId,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        & eventcreate.exe `
            /l $script:EventLogName `
            /so $script:ToolName `
            /t $EntryType.ToUpperInvariant() `
            /id $EventId `
            /d $Message 2>&1 | Out-Null
    }
    catch {
        Write-ToolLog "Unable to create Application Event Log entry $EventId. $($_.Exception.Message)"
    }
}

function Add-ToolWarning {
    param(
        [Parameter(Mandatory)][string]$Message,
        [int]$EventId = 4102
    )

    $script:HadWarnings = $true
    Write-ToolLog "WARNING: $Message"
    Write-ToolEvent -EntryType Warning -EventId $EventId -Message $Message
}

function Test-Administrator {
    return $script:IsAdministrator
}

function Require-Administrator {
    param([Parameter(Mandatory)][string]$Operation)

    if (Test-Administrator) {
        return $true
    }

    $message = "$Operation requires Administrator privileges."
    Write-ToolLog "ERROR: $message"
    Write-ToolEvent -EntryType Warning -EventId 4002 -Message $message

    Write-Host ''
    Write-Host "ERROR: $message" -ForegroundColor Red
    Write-Host 'Start PowerShell with Run as administrator and try again.'
    Write-Host ''
    return $false
}

function Show-ToolHelp {
@'
CDK Drive / BlueZone Reset and Removal Tool

SYNTAX
  .\CDK-BlueZone-Reset.ps1 [-Mode Basic|Thorough|FullUser] [target options]
  .\CDK-BlueZone-Reset.ps1 -Help

MODES
  Basic
      Resets selected user-profile cache/configuration data. It does not
      uninstall CDK Drive, BlueZone, or ADP components.

  Thorough
      Requires Administrator privileges. Performs machine-wide removal only.
      It does not clean user profiles.

  FullUser
      Requires Administrator privileges. Cleans selected user profile(s), then
      runs Thorough machine-wide removal.

TARGET OPTIONS
  No targeting option
      Selects the current process account's Windows profile.

  -ProfilePath 'C:\Users\ProfileName'
      Selects an existing Windows profile by exact local profile path.
      Multiple values are supported.

  -Sid 'S-1-...'
      Selects existing Windows profile(s) by SID.
      Multiple values are supported.

  -User 'identity'
      Best-effort local profile-folder matching. Examples:
        user@company.com
        AzureAD\user@company.com
        DOMAIN\username
        COMPUTER\localuser
      For unattended remediation, -Sid or -ProfilePath is preferred.

  -AllUsers
      Selects every existing non-special Windows user profile. This excludes
      Windows-managed special profiles such as Default, Public, SYSTEM,
      Local Service, and Network Service.

EXAMPLES
  .\CDK-BlueZone-Reset.ps1
  .\CDK-BlueZone-Reset.ps1 -Mode Basic
  .\CDK-BlueZone-Reset.ps1 -Mode Basic -AllUsers
  .\CDK-BlueZone-Reset.ps1 -Mode Basic -ProfilePath 'C:\Users\janes'
  .\CDK-BlueZone-Reset.ps1 -Mode Basic -Sid 'S-1-12-1-...'
  .\CDK-BlueZone-Reset.ps1 -Mode Thorough
  .\CDK-BlueZone-Reset.ps1 -Mode FullUser -AllUsers

SAFETY NOTES
  - CDK Drive, BlueZone, Edge, and related processes are force-closed.
    Unsaved work can be lost.
  - Basic mode backs up BlueZone profile folders before removing active copies.
  - Edge cleanup removes cache-oriented data only, not full Edge profiles,
    saved passwords, favorites, extensions, or browser settings.
  - Targeting a non-current account or using -AllUsers requires elevation.
  - Detailed logs are written to ProgramData when elevated, otherwise the
    current user's LocalAppData.
  - Summary events are written to Event Viewer > Windows Logs > Application
    under source: CDKBlueZoneReset.
'@ | Write-Host
}

function Stop-RelatedProcesses {
    Write-ToolLog 'Stopping CDK Drive, BlueZone, Internet Explorer, Edge, and WebView processes.'

    foreach ($processName in @(
        'wsstart', 'wsstart_2', 'wsstart_4', 'BZVT', 'BZVBA', 'dfsvc',
        'sw9c', 'legaclt', 'iexplore', 'msedge', 'msedgewebview2'
    )) {
        try {
            Get-Process -Name $processName -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-ToolLog "Could not stop process '$processName'. $($_.Exception.Message)"
        }
    }
}

function Clear-LegacyInternetExplorerData {
    Write-ToolLog 'Clearing legacy Internet Explorer / Internet Options data for the current process account.'

    try {
        Start-Process `
            -FilePath 'RunDll32.exe' `
            -ArgumentList 'InetCpl.cpl,ClearMyTracksByProcess 255' `
            -Wait `
            -NoNewWindow `
            -ErrorAction Stop
    }
    catch {
        Add-ToolWarning "Could not clear legacy Internet Explorer data. $($_.Exception.Message)"
    }
}

function Get-NormalWindowsProfiles {
    try {
        return @(
            Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
                Where-Object {
                    -not $_.Special -and
                    $_.SID -and
                    $_.LocalPath -and
                    (Test-Path -LiteralPath $_.LocalPath)
                }
        )
    }
    catch {
        Add-ToolWarning "Unable to query Win32_UserProfile. $($_.Exception.Message)"
        return @()
    }
}

function Resolve-TargetProfiles {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Current', 'ProfilePath', 'Sid', 'User', 'AllUsers')]
        [string]$SelectionType,

        [string[]]$SelectionValues
    )

    $normalProfiles = @(Get-NormalWindowsProfiles)

    if ($normalProfiles.Count -eq 0) {
        Add-ToolWarning 'No normal local Windows profiles were found.'
        return @()
    }

    switch ($SelectionType) {
        'Current' {
            $currentProfile = $normalProfiles |
                Where-Object { $_.SID -eq $script:CurrentSid } |
                Select-Object -First 1

            if ($null -eq $currentProfile) {
                Add-ToolWarning ('Could not resolve current process account profile. SID: {0}' -f $script:CurrentSid)
                return @()
            }

            return @($currentProfile)
        }

        'AllUsers' {
            return $normalProfiles
        }

        'ProfilePath' {
            $matchedProfiles = @()

            foreach ($targetPath in $SelectionValues) {
                $expandedPath = [Environment]::ExpandEnvironmentVariables($targetPath)

                $match = $normalProfiles | Where-Object {
                    $_.LocalPath.TrimEnd('\') -ieq $expandedPath.TrimEnd('\')
                }

                if ($null -eq $match) {
                    Add-ToolWarning ('No normal Windows profile matched requested path: {0}' -f $targetPath)
                }
                else {
                    $matchedProfiles += $match
                }
            }

            return @($matchedProfiles | Sort-Object SID -Unique)
        }

        'Sid' {
            $matchedProfiles = @()

            foreach ($targetSid in $SelectionValues) {
                $match = $normalProfiles | Where-Object { $_.SID -eq $targetSid }

                if ($null -eq $match) {
                    Add-ToolWarning ('No normal Windows profile matched requested SID: {0}' -f $targetSid)
                }
                else {
                    $matchedProfiles += $match
                }
            }

            return @($matchedProfiles | Sort-Object SID -Unique)
        }

        'User' {
            $matchedProfiles = @()

            foreach ($requestedIdentity in $SelectionValues) {
                $normalizedIdentity = $requestedIdentity.Trim()
                $leafIdentity = ($normalizedIdentity -split '\\')[-1]

                $match = @($normalProfiles | Where-Object {
                    $profileLeaf = Split-Path -Path $_.LocalPath -Leaf
                    $profileLeaf -ieq $normalizedIdentity -or
                    $profileLeaf -ieq $leafIdentity
                })

                if (@($match).Count -eq 1) {
                    $matchedProfiles += $match
                }
                elseif (@($match).Count -gt 1) {
                    Add-ToolWarning "Identity '$requestedIdentity' matched multiple local profiles. Use -Sid or -ProfilePath instead."
                }
                else {
                    Add-ToolWarning "Could not map identity '$requestedIdentity' to a unique local profile. Use -Sid, -ProfilePath, or -AllUsers."
                }
            }

            return @($matchedProfiles | Sort-Object SID -Unique)
        }
    }
}

function Remove-FolderIfPresent {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Write-ToolLog "Removing: $Path"

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
    catch {
        Add-ToolWarning "Could not fully remove '$Path'. $($_.Exception.Message)"
    }
}

function Backup-And-RemoveFolder {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    Write-ToolLog "Backing up: $Source -> $Destination"

    try {
        New-Item -ItemType Directory -Path $Destination -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Add-ToolWarning "Could not create backup folder '$Destination'. $($_.Exception.Message)"
        return
    }

    & robocopy.exe `
        $Source `
        $Destination `
        /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NJH /NJS | Out-Null

    $robocopyExitCode = $LASTEXITCODE

    if ($robocopyExitCode -ge 8) {
        Add-ToolWarning "BlueZone backup failed for '$Source'. Robocopy exit code: $robocopyExitCode. Source was retained."
        return
    }

    Remove-FolderIfPresent -Path $Source
}

function Clear-EdgeCacheData {
    param([Parameter(Mandatory)][string]$LocalAppData)

    $edgeRoot = Join-Path $LocalAppData 'Microsoft\Edge\User Data'

    if (-not (Test-Path -LiteralPath $edgeRoot)) {
        Write-ToolLog "Edge user-data folder not found: $edgeRoot"
        return
    }

    Write-ToolLog "Clearing Edge cache folders under: $edgeRoot"

    foreach ($relativePath in @(
        'ShaderCache', 'GrShaderCache', 'GraphiteCache', 'DawnCache',
        'Crashpad\reports'
    )) {
        Remove-FolderIfPresent -Path (Join-Path $edgeRoot $relativePath)
    }

    $edgeProfiles = @()

    foreach ($profileName in @('Default', 'Guest Profile', 'System Profile')) {
        $candidatePath = Join-Path $edgeRoot $profileName
        if (Test-Path -LiteralPath $candidatePath) {
            $edgeProfiles += Get-Item -LiteralPath $candidatePath
        }
    }

    $edgeProfiles += Get-ChildItem `
        -LiteralPath $edgeRoot `
        -Directory `
        -Filter 'Profile *' `
        -ErrorAction SilentlyContinue

    foreach ($edgeProfile in ($edgeProfiles | Sort-Object FullName -Unique)) {
        foreach ($relativePath in @(
            'Cache',
            'Code Cache',
            'GPUCache',
            'DawnCache',
            'Network\Cache',
            'Service Worker\CacheStorage',
            'Service Worker\ScriptCache'
        )) {
            Remove-FolderIfPresent -Path (Join-Path $edgeProfile.FullName $relativePath)
        }
    }
}

function Invoke-ProfileCleanup {
    param([Parameter(Mandatory)][object[]]$Profiles)

    if ($Profiles.Count -eq 0) {
        Add-ToolWarning 'No eligible user profiles were selected for cleanup.'
        return 1
    }

    Write-ToolLog "Eligible profile count: $($Profiles.Count)"

    foreach ($profile in $Profiles) {
        $profilePath = $profile.LocalPath
        $profileFolderName = Split-Path -Path $profilePath -Leaf
        $localAppData = Join-Path $profilePath 'AppData\Local'
        $roamingAppData = Join-Path $profilePath 'AppData\Roaming'
        $documentsPath = Join-Path $profilePath 'Documents'
        $backupPath = Join-Path (Join-Path $script:BackupRoot $profileFolderName) $script:Timestamp

        $startMessage = "CDK/BlueZone profile cleanup started. Profile: '$profilePath'; SID: '$($profile.SID)'; Loaded: '$($profile.Loaded)'."
        Write-ToolLog $startMessage
        Write-ToolEvent -EntryType Information -EventId 4100 -Message $startMessage

        Clear-EdgeCacheData -LocalAppData $localAppData
        Remove-FolderIfPresent -Path (Join-Path $localAppData 'Apps\2.0')
        Remove-FolderIfPresent -Path (Join-Path $localAppData 'assembly\dl3')
        Remove-FolderIfPresent -Path (Join-Path $roamingAppData 'ADP')

        Backup-And-RemoveFolder `
            -Source (Join-Path $roamingAppData 'BlueZone') `
            -Destination (Join-Path $backupPath 'Roaming_BlueZone')

        Backup-And-RemoveFolder `
            -Source (Join-Path $roamingAppData 'BlueZone Web') `
            -Destination (Join-Path $backupPath 'Roaming_BlueZone_Web')

        Backup-And-RemoveFolder `
            -Source (Join-Path $documentsPath 'BlueZone') `
            -Destination (Join-Path $backupPath 'Documents_BlueZone')

        $completionMessage = "CDK/BlueZone profile cleanup completed. Profile: '$profilePath'; SID: '$($profile.SID)'."
        Write-ToolLog $completionMessage
        Write-ToolEvent -EntryType Information -EventId 4101 -Message $completionMessage
    }

    if ($script:HadWarnings) {
        return 1
    }

    return 0
}

function Invoke-MsiUninstall {
    param(
        [Parameter(Mandatory)][string]$ProductCode,
        [Parameter(Mandatory)][string]$ProductName
    )

    Write-ToolLog "MSI uninstall attempt: $ProductName [$ProductCode]"

    try {
        $process = Start-Process `
            -FilePath 'msiexec.exe' `
            -ArgumentList "/x $ProductCode /qn /norestart" `
            -Wait `
            -PassThru `
            -NoNewWindow `
            -ErrorAction Stop

        $exitCode = $process.ExitCode
    }
    catch {
        $exitCode = -1
        Add-ToolWarning "Could not start MSI uninstall for '$ProductName'. $($_.Exception.Message)" 2100
    }

    Write-ToolLog ('MSI exit code for {0}: {1}' -f $ProductName, $exitCode)

    if ($exitCode -notin @(0, 1605, 3010)) {
        Add-ToolWarning "MSI uninstall returned exit code $exitCode for '$ProductName' [$ProductCode]. Review log: $script:LogFile" 2100
    }

    return $exitCode
}

function Invoke-KnownProductUninstalls {
    Write-ToolLog 'Attempting silent uninstall of known BlueZone, ADP, and CDK components.'

    $products = @(
        @{ Code = '{374C62B2-C3F7-4C33-841E-5AD4627ECF9F}'; Name = 'BlueZone VBA 6.2' },
        @{ Code = '{90F50409-6000-11D3-8CFE-0150048383C9}'; Name = 'BlueZone VBA component' },
        @{ Code = '{90F60409-6000-11D3-8CFE-0150048383C9}'; Name = 'BlueZone VBA component' },
        @{ Code = '{38A229CB-4547-478F-B2C4-FB0D336813FD}'; Name = 'SGLW2HCM component' },
        @{ Code = '{359846D6-19CE-480E-9FDF-02359052CEA4}'; Name = 'BlueZone patch' },
        @{ Code = '{E495B22B-232B-4094-90B3-0FD4BC4B7B64}'; Name = 'BlueZone patch' },
        @{ Code = '{49D3D8A3-F983-40B1-B668-2B7B2C4B2154}'; Name = 'BlueZone 6.2' },
        @{ Code = '{383D7832-FC67-4BFA-816E-88B80A0D95ED}'; Name = 'BlueZone VBA 6.1' },
        @{ Code = '{374C61B2-C3F7-4C33-841E-5AD4627ECF9F}'; Name = 'BlueZone VBA 6.1' },
        @{ Code = '{498CDC54-B572-4B23-8E65-2C95DA2F0D08}'; Name = 'BlueZone 6.1' },
        @{ Code = '{5C6ADDC7-067C-4236-B788-2B3F4B6F47A4}'; Name = 'BlueZone Rebrander' },
        @{ Code = '{69EF9BED-A297-4204-90F0-F1CC803AC4FA}'; Name = 'BlueZone VBA 952' },
        @{ Code = '{374C88B2-C3F7-4C33-841E-5AD4627ECF9F}'; Name = 'BlueZone 4.1' },
        @{ Code = '{5DCA09DF-B911-48BB-82B7-89A35A0F49B7}'; Name = 'BlueZone 4.1 update' },
        @{ Code = '{BB3B5869-A650-425E-9985-76CA48A8DDAF}'; Name = 'ADPInit' },
        @{ Code = '{40FDC133-63DC-4B03-B74B-7573CEB2EA9F}'; Name = 'CDKInit' }
    )

    foreach ($product in $products) {
        Invoke-MsiUninstall -ProductCode $product.Code -ProductName $product.Name | Out-Null
    }

    $vbaUninstaller = 'C:\Program Files (x86)\BlueZone VBA\6.2\BzvbaI.exe'

    if (Test-Path -LiteralPath $vbaUninstaller) {
        Write-ToolLog "Running BlueZone VBA executable uninstaller: $vbaUninstaller"

        try {
            $process = Start-Process `
                -FilePath $vbaUninstaller `
                -ArgumentList '/u' `
                -Wait `
                -PassThru `
                -NoNewWindow `
                -ErrorAction Stop

            Write-ToolLog "BlueZone VBA executable uninstaller exit code: $($process.ExitCode)"
        }
        catch {
            Add-ToolWarning "Could not run BlueZone VBA executable uninstaller. $($_.Exception.Message)"
        }
    }
}

function Remove-ProtectedFolder {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-ToolLog "Folder was not found: $Path"
        return
    }

    Write-ToolLog "Removing folder: $Path"

    try {
        & takeown.exe /f $Path /r /d y 2>&1 | Out-Null
        & icacls.exe $Path /grant 'Administrators:(OI)(CI)F' /t /c 2>&1 | Out-Null
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
    catch {
        Add-ToolWarning "Could not fully remove protected folder '$Path'. $($_.Exception.Message)"
    }
}

function Remove-MachineCacheData {
    Write-ToolLog 'Removing machine-wide ADP and CDK Drive cache folders.'

    foreach ($path in @(
        'C:\ProgramData\ADP\websuite',
        'C:\ProgramData\CDK\Drive'
    )) {
        Remove-FolderIfPresent -Path $path
    }
}

function Remove-ResidualProgramFolders {
    Write-ToolLog 'Removing residual BlueZone, ADP, and CDK program folders.'

    foreach ($path in @(
        'C:\Program Files (x86)\ADP\websuite TE',
        'C:\Program Files (x86)\BlueZone',
        'C:\Program Files (x86)\BlueZone VBA',
        'C:\Windows\Downloaded Program Files\6.2',
        'C:\ProgramData\BlueZone',
        'C:\Users\Default\Documents\BlueZone',
        'C:\Users\Public\Documents\BlueZone'
    )) {
        Remove-ProtectedFolder -Path $path
    }
}

function Remove-RegistryKeyIfPresent {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Write-ToolLog "Removing registry key: $Path"

        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
        catch {
            Add-ToolWarning "Could not remove registry key '$Path'. $($_.Exception.Message)"
        }
    }
}

function Remove-RegistryValueIfPresent {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    try {
        $property = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue

        if ($null -ne $property) {
            Write-ToolLog "Removing registry value: $Path\$Name"
            Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
        }
    }
    catch {
        Write-ToolLog "Registry value was not removed: $Path\$Name. $($_.Exception.Message)"
    }
}

function Remove-TargetedRegistryEntries {
    Write-ToolLog 'Removing targeted BlueZone and ADP machine-wide registry entries.'

    Remove-RegistryKeyIfPresent -Path 'HKLM:\SOFTWARE\Wow6432Node\BlueZone'
    Remove-RegistryKeyIfPresent -Path 'HKLM:\SOFTWARE\Wow6432Node\SEAGULL\BlueZone'

    Remove-RegistryValueIfPresent `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'ADPInit'

    foreach ($registryPath in @(
        'HKLM:\SOFTWARE\Classes\fileBBH',
        'HKLM:\SOFTWARE\Classes\fileBBS',
        'HKLM:\SOFTWARE\Classes\fileBZT',
        'HKLM:\SOFTWARE\Classes\fileZLT',
        'HKLM:\SOFTWARE\Classes\fileZVT',
        'HKLM:\SOFTWARE\Classes\BlueZone.FTP.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.iSeriesDisplay.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.iSeriesPrinter.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.MainframeDisplay.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.MainframePrinter.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.SessionManagerLayout.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.TCP/IPPrintServer.1',
        'HKLM:\SOFTWARE\Classes\BlueZone.VTDisplay.1',
        'HKLM:\SOFTWARE\Classes\Bzvba.Vbahost',
        'HKLM:\SOFTWARE\Classes\Bzvba.Vbahost.1',
        'HKLM:\SOFTWARE\Classes\Bzvba.Vbahost.6.2'
    )) {
        Remove-RegistryKeyIfPresent -Path $registryPath
    }

    foreach ($registryPath in @(
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueZone VBA 6.2',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{90F60409-6000-11D3-8CFE-0150048383C9}',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{90F50409-6000-11D3-8CFE-0150048383C9}',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{359846D6-19CE-480E-9FDF-02359052CEA4}',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{374C88B2-C3F7-4C33-841E-5AD4627ECF9F}'
    )) {
        Remove-RegistryKeyIfPresent -Path $registryPath
    }
}

function Unregister-LegacyOcx {
    $ocxFile = 'C:\Windows\Downloaded Program Files\sglw2hcm.ocx'

    if (-not (Test-Path -LiteralPath $ocxFile)) {
        Write-ToolLog 'Legacy sglw2hcm.ocx file was not found.'
        return
    }

    Write-ToolLog "Unregistering legacy OCX file: $ocxFile"

    try {
        Start-Process `
            -FilePath 'regsvr32.exe' `
            -ArgumentList "/u /s `"$ocxFile`"" `
            -Wait `
            -NoNewWindow `
            -ErrorAction Stop

        $destination = Join-Path $env:TEMP ('sglw2hcm_{0}.ocx' -f $script:Timestamp)
        Move-Item -LiteralPath $ocxFile -Destination $destination -Force -ErrorAction Stop
    }
    catch {
        Add-ToolWarning "Could not unregister or move '$ocxFile'. $($_.Exception.Message)"
    }
}

function Invoke-ThoroughMachineCleanup {
    if (-not (Require-Administrator -Operation 'Thorough machine cleanup')) {
        return 5
    }

    Write-ToolLog '===== THOROUGH MACHINE CLEANUP STARTED ====='
    Write-ToolEvent `
        -EntryType Information `
        -EventId 2000 `
        -Message "Thorough CDK/BlueZone machine cleanup started by $script:CurrentAccount."

    Stop-RelatedProcesses
    Remove-MachineCacheData
    Invoke-KnownProductUninstalls
    Remove-ResidualProgramFolders
    Remove-TargetedRegistryEntries
    Unregister-LegacyOcx

    Write-ToolLog '===== THOROUGH MACHINE CLEANUP COMPLETED ====='
    Write-ToolEvent `
        -EntryType Information `
        -EventId 2001 `
        -Message "Thorough CDK/BlueZone machine cleanup completed. No user profile cleanup was performed. Log: $script:LogFile"

    return 0
}

function Get-InteractiveMode {
    Clear-Host

    Write-Host ''
    Write-Host '=================================================================='
    Write-Host '                   CDK Drive / BlueZone Reset Tool'
    Write-Host '=================================================================='
    Write-Host ''

    Write-Host '[1] Basic profile reset' -ForegroundColor Cyan
    Write-Host '    Reset cache and configuration data for the current account.'
    Write-Host '    Does not uninstall CDK Drive, BlueZone, or ADP components.'
    Write-Host ''

    Write-Host '[2] Thorough machine cleanup' -ForegroundColor Yellow
    Write-Host '    Requires Administrator privileges.'
    Write-Host '    Removes machine-wide CDK/BlueZone/ADP components, cache data,'
    Write-Host '    residual folders, and selected registry entries.'
    Write-Host '    Does not alter any user profile.'
    Write-Host ''

    Write-Host '[3] Full user and machine cleanup' -ForegroundColor Magenta
    Write-Host '    Requires Administrator privileges.'
    Write-Host '    Resets the current account profile, then runs machine cleanup.'
    Write-Host '    Use only when the current account is the profile to be reset.'
    Write-Host ''

    Write-Host '[Q] Quit' -ForegroundColor DarkGray
    Write-Host '    Exit without making any changes.'
    Write-Host ''

    do {
        $selection = (Read-Host 'Select an option').Trim().ToUpperInvariant()
    } until ($selection -in @('1', '2', '3', 'Q'))

    switch ($selection) {
        '1' { return 'Basic' }
        '2' { return 'Thorough' }
        '3' { return 'FullUser' }
        'Q' { return 'Quit' }
    }
}

function Get-ProfileSelection {
    if ($AllUsers) {
        return @{ Type = 'AllUsers'; Values = @() }
    }

    if ($ProfilePath) {
        return @{ Type = 'ProfilePath'; Values = $ProfilePath }
    }

    if ($Sid) {
        return @{ Type = 'Sid'; Values = $Sid }
    }

    if ($User) {
        return @{ Type = 'User'; Values = $User }
    }

    return @{ Type = 'Current'; Values = @() }
}

# ============================================================================
# Main execution
# ============================================================================

if ($Help -or $Mode -eq 'Help') {
    Show-ToolHelp
    exit 0
}

if (-not $Mode) {
    $interactiveSelection = Get-InteractiveMode

    if ($interactiveSelection -eq 'Quit') {
        Write-Host ''
        Write-Host 'No action was taken.'
        exit 0
    }

    $Mode = $interactiveSelection
}

$profileSelection = Get-ProfileSelection
$selectionType = $profileSelection.Type
$selectionValues = $profileSelection.Values
$nonCurrentTargeting = $selectionType -ne 'Current'

if ($Mode -eq 'Thorough' -and $nonCurrentTargeting) {
    Write-ToolLog "Target options were ignored because Thorough mode is machine-wide only. Target type received: $selectionType"
    Write-Host ''
    Write-Host 'Note: Target-user options are ignored in Thorough mode.' -ForegroundColor Yellow
    Write-Host 'Thorough mode performs machine-wide cleanup only.'
    Write-Host ''
}

if ($nonCurrentTargeting -and $Mode -ne 'Thorough') {
    if (-not (Require-Administrator -Operation 'Targeted user-profile cleanup')) {
        exit 5
    }
}

switch ($Mode) {
    'Basic' {
        Write-ToolLog '===== BASIC PROFILE RESET STARTED ====='
        Write-ToolLog "Process account: $script:CurrentAccount"
        Write-ToolLog "Target selection: $selectionType"
        Write-ToolEvent `
            -EntryType Information `
            -EventId 1000 `
            -Message "Basic CDK/BlueZone profile reset started. Process account: $script:CurrentAccount. Target mode: $selectionType."

        Stop-RelatedProcesses

        if ($selectionType -eq 'Current') {
            Clear-LegacyInternetExplorerData
        }
        else {
            Write-ToolLog 'Legacy IE cleanup skipped because targeted profile cleanup cannot safely target another user IE profile.'
        }

        $profiles = Resolve-TargetProfiles -SelectionType $selectionType -SelectionValues $selectionValues
        $result = Invoke-ProfileCleanup -Profiles $profiles

        if ($result -ne 0) {
            Write-ToolEvent `
                -EntryType Warning `
                -EventId 1002 `
                -Message "Basic CDK/BlueZone profile reset completed with warnings. Log: $script:LogFile"
        }
        else {
            Write-ToolLog '===== BASIC PROFILE RESET COMPLETED ====='
            Write-ToolEvent `
                -EntryType Information `
                -EventId 1001 `
                -Message "Basic CDK/BlueZone profile reset completed. Target mode: $selectionType. Log: $script:LogFile"
        }

        Write-Host ''
        Write-Host 'Basic profile reset finished.' -ForegroundColor Green
        Write-Host "Log file: $script:LogFile"
        exit $result
    }

    'Thorough' {
        $result = Invoke-ThoroughMachineCleanup

        if ($result -eq 0) {
            Write-Host ''
            Write-Host 'Thorough machine cleanup finished.' -ForegroundColor Green
            Write-Host 'No per-user profiles were changed by this mode.'
            Write-Host "Log file: $script:LogFile"
        }

        exit $result
    }

    'FullUser' {
        if (-not (Require-Administrator -Operation 'Full user and machine cleanup')) {
            exit 5
        }

        Write-ToolLog '===== FULL USER + MACHINE CLEANUP STARTED ====='
        Write-ToolLog "Process account: $script:CurrentAccount"
        Write-ToolLog "Target selection: $selectionType"
        Write-ToolEvent `
            -EntryType Information `
            -EventId 3000 `
            -Message "Full user and machine CDK/BlueZone cleanup started. Process account: $script:CurrentAccount. Target mode: $selectionType."

        Stop-RelatedProcesses

        if ($selectionType -eq 'Current') {
            Clear-LegacyInternetExplorerData
        }
        else {
            Write-ToolLog 'Legacy IE cleanup skipped because targeted profile cleanup cannot safely target another user IE profile.'
        }

        $profiles = Resolve-TargetProfiles -SelectionType $selectionType -SelectionValues $selectionValues
        $profileResult = Invoke-ProfileCleanup -Profiles $profiles
        $machineResult = Invoke-ThoroughMachineCleanup

        if ($profileResult -ne 0 -or $machineResult -ne 0) {
            Write-ToolEvent `
                -EntryType Warning `
                -EventId 3003 `
                -Message "Full user and machine CDK/BlueZone cleanup completed with warnings. Log: $script:LogFile"

            $finalResult = 1
        }
        else {
            Write-ToolLog '===== FULL USER + MACHINE CLEANUP COMPLETED ====='
            Write-ToolEvent `
                -EntryType Information `
                -EventId 3001 `
                -Message "Full user and machine CDK/BlueZone cleanup completed. Target mode: $selectionType. Log: $script:LogFile"

            $finalResult = 0
        }

        Write-Host ''
        Write-Host 'Full user and machine cleanup finished.' -ForegroundColor Green
        Write-Host "Log file: $script:LogFile"
        exit $finalResult
    }

    default {
        Write-Host ''
        Write-Host "ERROR: Unsupported mode '$Mode'." -ForegroundColor Red
        Show-ToolHelp
        exit 2
    }
}
```

---

## Change Control

Before changing this tool:

- Confirm all MSI product codes still apply to your supported BlueZone/CDK/ADP versions.
- Test revisions on representative Entra-joined, AD-joined, and workgroup endpoints as applicable.
- Require review for modifications to profile targeting, backups, file deletion, registry removal, Edge cleanup, or MSI uninstalls.
- Record version, date, author, rationale, and test result in `CHANGELOG.md`.
