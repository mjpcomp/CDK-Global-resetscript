@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM ============================================================================
REM CDK Drive / BlueZone Reset and Removal Tool
REM ============================================================================
REM
REM Supported Windows environments:
REM   - Microsoft Entra joined / Azure AD joined
REM   - Active Directory domain joined
REM   - Workgroup or local-account computers
REM
REM USAGE:
REM   CDK-BlueZone-Reset.cmd
REM   CDK-BlueZone-Reset.cmd basic
REM   CDK-BlueZone-Reset.cmd thorough
REM   CDK-BlueZone-Reset.cmd full-user
REM   CDK-BlueZone-Reset.cmd --help
REM
REM USER TARGETING OPTIONS:
REM   --profile-path "C:\Users\someprofile"
REM       Targets a known local Windows profile folder. May be repeated.
REM
REM   --sid "S-1-..."
REM       Targets an existing local Windows profile by SID. May be repeated.
REM
REM   --users "identity"
REM       Attempts to resolve one or more user identities to existing local
REM       profiles. Values can include:
REM         user@company.com
REM         AzureAD\user@company.com
REM         DOMAIN\username
REM         COMPUTER\localuser
REM       May be repeated. If resolution is ambiguous, use --sid or
REM       --profile-path instead.
REM
REM   --all-users
REM       Targets every existing non-special local Windows profile. Excludes
REM       Default, Public, SYSTEM, Local Service, Network Service, and other
REM       Windows Special profiles.
REM
REM MODES:
REM   basic
REM       Resets selected user profile(s): Edge caches, IE legacy data for the
REM       current account only, ClickOnce/.NET caches, ADP data, and BlueZone
REM       data after a timestamped backup.
REM
REM   thorough
REM       Administrator-only machine-wide removal. Does not perform user-profile
REM       cleanup, even if target-user options are passed.
REM
REM   full-user
REM       Administrator-only. Runs profile cleanup for selected profile(s),
REM       then runs thorough machine-wide removal.
REM
REM WARNING:
REM   - Targeting profiles other than the current user requires Administrator.
REM   - --all-users can affect all normal local profiles.
REM   - Edge and BlueZone processes are force-closed; unsaved work can be lost.
REM ============================================================================

set "SCRIPT_NAME=%~nx0"
set "MODE="
set "TARGET_KIND=current"
set "TARGET_VALUES="
set "EVENT_LOG=APPLICATION"
set "EVENT_SOURCE=CDKBlueZoneReset"
set "LOG_ROOT=%ProgramData%\CDKBlueZoneReset\Logs"
set "BACKUP_ROOT=%ProgramData%\CDKBlueZoneReset\Backups"

REM Generate a locale-independent timestamp.
for /f %%I in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul') do set "STAMP=%%I"
if not defined STAMP set "STAMP=%DATE:/=-%_%TIME::=-%"
set "STAMP=%STAMP: =0%"

REM Basic mode may run without ProgramData write access.
if not exist "%LOG_ROOT%" md "%LOG_ROOT%" >nul 2>&1
if not exist "%LOG_ROOT%" (
    set "LOG_ROOT=%LocalAppData%\CDKBlueZoneReset\Logs"
    set "BACKUP_ROOT=%LocalAppData%\CDKBlueZoneReset\Backups"
)
if not exist "%LOG_ROOT%" md "%LOG_ROOT%" >nul 2>&1

set "LOG_FILE=%LOG_ROOT%\CDKBlueZoneReset_%STAMP%.log"
set "PS_HELPER=%TEMP%\CDKBlueZoneReset_ProfileCleanup_%RANDOM%_%RANDOM%.ps1"

REM ============================================================================
REM Parse command-line arguments
REM ============================================================================
:ParseArgs

if "%~1"=="" goto :ArgumentsParsed

if /I "%~1"=="basic" (
    set "MODE=basic"
    shift
    goto :ParseArgs
)

if /I "%~1"=="thorough" (
    set "MODE=thorough"
    shift
    goto :ParseArgs
)

if /I "%~1"=="full-user" (
    set "MODE=full-user"
    shift
    goto :ParseArgs
)

if /I "%~1"=="1" (
    set "MODE=basic"
    shift
    goto :ParseArgs
)

if /I "%~1"=="2" (
    set "MODE=thorough"
    shift
    goto :ParseArgs
)

if /I "%~1"=="3" (
    set "MODE=full-user"
    shift
    goto :ParseArgs
)

if /I "%~1"=="--profile-path" (
    if "%~2"=="" goto :MissingArgumentValue
    set "TARGET_KIND=profile-path"
    set "TARGET_VALUES=%TARGET_VALUES% "%~2""
    shift
    shift
    goto :ParseArgs
)

if /I "%~1"=="--sid" (
    if "%~2"=="" goto :MissingArgumentValue
    set "TARGET_KIND=sid"
    set "TARGET_VALUES=%TARGET_VALUES% "%~2""
    shift
    shift
    goto :ParseArgs
)

if /I "%~1"=="--users" (
    if "%~2"=="" goto :MissingArgumentValue
    set "TARGET_KIND=users"
    set "TARGET_VALUES=%TARGET_VALUES% "%~2""
    shift
    shift
    goto :ParseArgs
)

if /I "%~1"=="--all-users" (
    set "TARGET_KIND=all-users"
    set "TARGET_VALUES="
    shift
    goto :ParseArgs
)

if /I "%~1"=="--help" goto :Usage
if /I "%~1"=="/?" goto :Usage
if /I "%~1"=="-h" goto :Usage

echo.
echo ERROR: Unknown argument: %~1
echo Run "%SCRIPT_NAME% --help" for usage.
exit /b 2

:MissingArgumentValue
echo.
echo ERROR: %~1 requires a value.
echo Run "%SCRIPT_NAME% --help" for usage.
exit /b 2

:ArgumentsParsed

REM ============================================================================
REM Interactive menu only when no mode was passed
REM ============================================================================
if defined MODE goto :ValidateMode

cls
echo.
echo ==========================================================================
echo                     CDK Drive / BlueZone Tool
echo ==========================================================================
echo.
echo  Basic reset - current logged-on account only[1]
echo  Thorough removal - administrator required, machine-wide only[2]
echo  Full-user removal - administrator required[3]
echo [Q] Quit
echo.
choice /C 123Q /N /M "Select an option"

if errorlevel 4 goto :Quit
if errorlevel 3 set "MODE=full-user"
if errorlevel 2 set "MODE=thorough"
if errorlevel 1 set "MODE=basic"

:ValidateMode

REM Thorough intentionally ignores user profile target options.
if /I "%MODE%"=="thorough" goto :ThoroughMode

REM Targeting any profile other than the current process account requires admin.
if /I not "%TARGET_KIND%"=="current" (
    call :RequireAdmin
    if errorlevel 1 (
        call :Log "ERROR: User-profile targeting requested without elevation."
        call :WriteEvent WARNING 4002 "Targeted CDK/BlueZone profile cleanup was requested but not run elevated. User: %USERDOMAIN%\%USERNAME%."

        echo.
        echo ERROR: --profile-path, --sid, --users, and --all-users require
        echo Administrator privileges.
        exit /b 5
    )
)

if /I "%MODE%"=="basic" goto :BasicMode
if /I "%MODE%"=="full-user" goto :FullUserMode

echo.
echo ERROR: No valid mode selected.
exit /b 2

REM ============================================================================
:BasicMode
REM ============================================================================
call :Log "===== BASIC USER-PROFILE RESET STARTED ====="
call :Log "Process account: %USERDOMAIN%\%USERNAME%"
call :Log "Profile targeting mode: %TARGET_KIND%"
call :WriteEvent INFORMATION 1000 "Basic CDK Drive / BlueZone profile reset started. Process account: %USERDOMAIN%\%USERNAME%. Target mode: %TARGET_KIND%."

call :StopApplicationProcesses

REM IE cleanup applies only to the account running this script.
if /I "%TARGET_KIND%"=="current" call :ClearLegacyBrowserData

call :RunProfileCleanup
set "PROFILE_RESULT=%ERRORLEVEL%"

if not "%PROFILE_RESULT%"=="0" (
    call :Log "ERROR: Profile cleanup helper ended with code %PROFILE_RESULT%."
    call :WriteEvent WARNING 1002 "Basic CDK/BlueZone profile reset completed with warnings. See log: %LOG_FILE%"
) else (
    call :Log "===== BASIC USER-PROFILE RESET COMPLETED ====="
    call :WriteEvent INFORMATION 1001 "Basic CDK/BlueZone profile reset completed. Target mode: %TARGET_KIND%. Log: %LOG_FILE%"
)

echo.
echo Basic profile reset finished.
echo Log: %LOG_FILE%
goto :EndInteractive

REM ============================================================================
:ThoroughMode
REM ============================================================================
call :RequireAdmin
if errorlevel 1 (
    call :Log "ERROR: Thorough mode stopped because the script is not elevated."
    call :WriteEvent WARNING 2002 "Thorough BlueZone/CDK machine cleanup was requested but not run elevated. User: %USERDOMAIN%\%USERNAME%."

    echo.
    echo Thorough mode requires Administrator privileges.
    exit /b 5
)

call :Log "===== THOROUGH MACHINE-WIDE REMOVAL STARTED ====="
call :Log "Running elevated as: %USERDOMAIN%\%USERNAME%"
call :WriteEvent INFORMATION 2000 "Thorough machine-wide BlueZone/CDK removal started by %USERDOMAIN%\%USERNAME%."

REM No user-profile cleanup occurs in this mode.
call :StopApplicationProcesses
call :ClearMachineCaches
call :UninstallKnownProducts
call :RemoveProgramFolders
call :RemoveTargetedRegistryKeys
call :UnregisterLegacyOcx

call :Log "===== THOROUGH MACHINE-WIDE REMOVAL COMPLETED ====="
call :WriteEvent INFORMATION 2001 "Thorough machine-wide BlueZone/CDK removal completed. No user profiles were targeted. Log: %LOG_FILE%"

echo.
echo Thorough machine-wide removal completed.
echo No per-user profile folders were changed.
echo Log: %LOG_FILE%
goto :EndInteractive

REM ============================================================================
:FullUserMode
REM ============================================================================
call :RequireAdmin
if errorlevel 1 (
    call :Log "ERROR: Full-user mode stopped because the script is not elevated."
    call :WriteEvent WARNING 3002 "Full user and machine BlueZone/CDK removal was requested but not run elevated. User: %USERDOMAIN%\%USERNAME%."

    echo.
    echo Full-user mode requires Administrator privileges.
    exit /b 5
)

call :Log "===== FULL USER + MACHINE REMOVAL STARTED ====="
call :Log "Process account: %USERDOMAIN%\%USERNAME%"
call :Log "Profile targeting mode: %TARGET_KIND%"
call :WriteEvent INFORMATION 3000 "Full user and machine BlueZone/CDK removal started. Process account: %USERDOMAIN%\%USERNAME%. Target mode: %TARGET_KIND%."

call :StopApplicationProcesses

REM IE cleanup applies only to the account running the script.
if /I "%TARGET_KIND%"=="current" call :ClearLegacyBrowserData

call :RunProfileCleanup
set "PROFILE_RESULT=%ERRORLEVEL%"

call :ClearMachineCaches
call :UninstallKnownProducts
call :RemoveProgramFolders
call :RemoveTargetedRegistryKeys
call :UnregisterLegacyOcx

if not "%PROFILE_RESULT%"=="0" (
    call :Log "WARNING: Profile helper returned %PROFILE_RESULT%; machine cleanup still completed."
    call :WriteEvent WARNING 3003 "Full user and machine cleanup completed with profile cleanup warnings. Log: %LOG_FILE%"
) else (
    call :Log "===== FULL USER + MACHINE REMOVAL COMPLETED ====="
    call :WriteEvent INFORMATION 3001 "Full user and machine BlueZone/CDK removal completed. Target mode: %TARGET_KIND%. Log: %LOG_FILE%"
)

echo.
echo Full user and machine cleanup finished.
echo Log: %LOG_FILE%
goto :EndInteractive

REM ============================================================================
:StopApplicationProcesses
REM ============================================================================
call :Log "Stopping CDK Drive, BlueZone, IE, Edge, and Edge WebView processes."

for %%P in (
    wsstart.exe
    wsstart_2.exe
    wsstart_4.exe
    BZVT.exe
    BZVBA.exe
    dfsvc.exe
    sw9c.exe
    legaclt.exe
    iexplore.exe
    msedge.exe
    msedgewebview2.exe
) do (
    taskkill /IM "%%P" /F >> "%LOG_FILE%" 2>&1
)

exit /b 0

REM ============================================================================
:ClearLegacyBrowserData
REM ============================================================================
call :Log "Clearing legacy Internet Explorer data for current process account."

REM This only applies to the account executing the script.
REM It is not a Microsoft Edge cleanup mechanism.
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255 >> "%LOG_FILE%" 2>&1

exit /b 0

REM ============================================================================
:RunProfileCleanup
REM ============================================================================
call :Log "Creating and executing multi-profile cleanup helper."
call :CreatePowerShellHelper

REM TARGET_VALUES contains individually quoted values, including paths/spaces.
if /I "%TARGET_KIND%"=="current" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_HELPER%" ^
        -TargetKind "current" ^
        -BackupRoot "%BACKUP_ROOT%" ^
        -LogFile "%LOG_FILE%" ^
        -EventSource "%EVENT_SOURCE%" ^
        -Stamp "%STAMP%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_HELPER%" ^
        -TargetKind "%TARGET_KIND%" ^
        -Targets %TARGET_VALUES% ^
        -BackupRoot "%BACKUP_ROOT%" ^
        -LogFile "%LOG_FILE%" ^
        -EventSource "%EVENT_SOURCE%" ^
        -Stamp "%STAMP%"
)

set "PROFILE_RESULT=%ERRORLEVEL%"

if exist "%PS_HELPER%" del /q "%PS_HELPER%" >> "%LOG_FILE%" 2>&1

exit /b %PROFILE_RESULT%

REM ============================================================================
:CreatePowerShellHelper
REM ============================================================================
(
echo param(
echo     [Parameter(Mandatory=$true)][ValidateSet('current','profile-path','sid','users','all-users')][string]$TargetKind,
echo     [string[]]$Targets,
echo     [Parameter(Mandatory=$true)][string]$BackupRoot,
echo     [Parameter(Mandatory=$true)][string]$LogFile,
echo     [Parameter(Mandatory=$true)][string]$EventSource,
echo     [Parameter(Mandatory=$true)][string]$Stamp
echo ^)
echo $ErrorActionPreference = 'Continue'
echo $script:HadWarnings = $false
echo
echo function Write-ToolLog {
echo     param([string]$Message)
echo     $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
echo     Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
echo ^}
echo
echo function Write-ToolEvent {
echo     param(
echo         [ValidateSet('INFORMATION','WARNING','ERROR')][string]$Type,
echo         [int]$Id,
echo         [string]$Message
echo     ^)
echo     ^& eventcreate.exe /l APPLICATION /so $EventSource /t $Type /id $Id /d $Message 2^>^&1 ^| Out-Null
echo ^}
echo
echo function Mark-Warning {
echo     param([string]$Message)
echo     $script:HadWarnings = $true
echo     Write-ToolLog "WARNING: $Message"
echo     Write-ToolEvent -Type WARNING -Id 4102 -Message $Message
echo ^}
echo
echo function Remove-FolderIfPresent {
echo     param([string]$Path)
echo     if (Test-Path -LiteralPath $Path) {
echo         Write-ToolLog "Removing: $Path"
echo         try {
echo             Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
echo         } catch {
echo             Mark-Warning "Could not fully remove '$Path'. $($_.Exception.Message)"
echo         }
echo     }
echo ^}
echo
echo function Copy-And-Remove {
echo     param(
echo         [string]$Source,
echo         [string]$Destination
echo     ^)
echo     if (-not (Test-Path -LiteralPath $Source)) { return }
echo
echo     Write-ToolLog "Backing up: $Source -^> $Destination"
echo     New-Item -ItemType Directory -Path $Destination -Force ^| Out-Null
echo
echo     ^& robocopy.exe $Source $Destination /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NJH /NJS ^| Out-Null
echo     $rc = $LASTEXITCODE
echo
echo     REM Robocopy exit codes 0-7 are non-failure results; 8+ means failure.
echo     if ($rc -ge 8) {
echo         Mark-Warning "Backup failed for '$Source' with Robocopy exit code $rc. Source was retained."
echo         return
echo     }
echo
echo     Remove-FolderIfPresent -Path $Source
echo ^}
echo
echo function Clear-EdgeCaches {
echo     param([string]$LocalAppData)
echo
echo     $edgeRoot = Join-Path $LocalAppData 'Microsoft\Edge\User Data'
echo     if (-not (Test-Path -LiteralPath $edgeRoot)) {
echo         Write-ToolLog "Edge user-data folder not found: $edgeRoot"
echo         return
echo     }
echo
echo     Write-ToolLog "Clearing Edge cache folders under: $edgeRoot"
echo
echo     foreach ($relative in @(
echo         'ShaderCache',
echo         'GrShaderCache',
echo         'GraphiteCache',
echo         'DawnCache',
echo         'Crashpad\reports'
echo     )) {
echo         Remove-FolderIfPresent -Path (Join-Path $edgeRoot $relative)
echo     }
echo
echo     $edgeProfiles = @()
echo     foreach ($name in @('Default','Guest Profile','System Profile')) {
echo         $candidate = Join-Path $edgeRoot $name
echo         if (Test-Path -LiteralPath $candidate) { $edgeProfiles += Get-Item -LiteralPath $candidate }
echo     }
echo     $edgeProfiles += Get-ChildItem -LiteralPath $edgeRoot -Directory -Filter 'Profile *' -ErrorAction SilentlyContinue
echo
echo     foreach ($edgeProfile in ($edgeProfiles ^| Sort-Object FullName -Unique)) {
echo         foreach ($relative in @(
echo             'Cache',
echo             'Code Cache',
echo             'GPUCache',
echo             'DawnCache',
echo             'Network\Cache',
echo             'Service Worker\CacheStorage',
echo             'Service Worker\ScriptCache'
echo         )) {
echo             Remove-FolderIfPresent -Path (Join-Path $edgeProfile.FullName $relative)
echo         }
echo     }
echo ^}
echo
echo function Get-NormalProfiles {
echo     Get-CimInstance -ClassName Win32_UserProfile ^| Where-Object {
echo         -not $_.Special -and
echo         $_.SID -and
echo         $_.LocalPath -and
echo         (Test-Path -LiteralPath $_.LocalPath)
echo     }
echo ^}
echo
echo function Get-CurrentProfile {
echo     $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
echo     Get-NormalProfiles ^| Where-Object { $_.SID -eq $sid } ^| Select-Object -First 1
echo ^}
echo
echo function Resolve-TargetProfiles {
echo     $normalProfiles = @(Get-NormalProfiles)
echo
echo     switch ($TargetKind) {
echo         'current' {
echo             $current = Get-CurrentProfile
echo             if ($null -eq $current) {
echo                 Mark-Warning "Could not resolve a normal local profile for the current process account."
echo                 return @()
echo             }
echo             return @($current)
echo         }
echo
echo         'all-users' {
echo             return $normalProfiles
echo         }
echo
echo         'profile-path' {
echo             $results = @()
echo             foreach ($target in $Targets) {
echo                 $expanded = [Environment]::ExpandEnvironmentVariables($target)
echo                 $match = $normalProfiles ^| Where-Object {
echo                     $_.LocalPath.TrimEnd('\') -ieq $expanded.TrimEnd('\')
echo                 }
echo                 if ($null -eq $match) {
echo                     Mark-Warning "No normal existing Windows profile matched path: $target"
echo                 } else {
echo                     $results += $match
echo                 }
echo             }
echo             return @($results ^| Sort-Object SID -Unique)
echo         }
echo
echo         'sid' {
echo             $results = @()
echo             foreach ($target in $Targets) {
echo                 $match = $normalProfiles ^| Where-Object { $_.SID -eq $target }
echo                 if ($null -eq $match) {
echo                     Mark-Warning "No normal existing Windows profile matched SID: $target"
echo                 } else {
echo                     $results += $match
echo                 }
echo             }
echo             return @($results ^| Sort-Object SID -Unique)
echo         }
echo
echo         'users' {
echo             $results = @()
echo             foreach ($target in $Targets) {
echo                 $normalized = $target.Trim()
echo                 $leaf = ($normalized -split '\\')[-1]
echo
echo                 REM User identities cannot always be mapped offline to a SID.
echo                 REM Match only known local profile folder leaves and warn rather
echo                 REM than guessing when there is no unique match.
echo                 $match = $normalProfiles ^| Where-Object {
echo                     (Split-Path -Path $_.LocalPath -Leaf) -ieq $normalized -or
echo                     (Split-Path -Path $_.LocalPath -Leaf) -ieq $leaf
echo                 }
echo
echo                 if (@($match).Count -eq 1) {
echo                     $results += $match
echo                 } elseif (@($match).Count -gt 1) {
echo                     Mark-Warning "Identity '$target' matched multiple local profiles. Use --sid or --profile-path instead."
echo                 } else {
echo                     Mark-Warning "Could not map identity '$target' to a unique local profile. Use --sid, --profile-path, or --all-users."
echo                 }
echo             }
echo             return @($results ^| Sort-Object SID -Unique)
echo         }
echo     }
echo ^}
echo
echo $profiles = @(Resolve-TargetProfiles)
echo
echo if ($profiles.Count -eq 0) {
echo     Mark-Warning "No eligible user profiles were selected for cleanup."
echo     exit 1
echo ^}
echo
echo Write-ToolLog "Eligible profile count: $($profiles.Count)"
echo
echo foreach ($profile in $profiles) {
echo     $profilePath = $profile.LocalPath
echo     $profileLeaf = Split-Path -Path $profilePath -Leaf
echo     $localAppData = Join-Path $profilePath 'AppData\Local'
echo     $roamingAppData = Join-Path $profilePath 'AppData\Roaming'
echo     $documentsPath = Join-Path $profilePath 'Documents'
echo     $backupPath = Join-Path $BackupRoot (Join-Path $profileLeaf $Stamp)
echo
echo     Write-ToolLog "Processing profile: Path='$profilePath'; SID='$($profile.SID)'; Loaded='$($profile.Loaded)'"
echo     Write-ToolEvent -Type INFORMATION -Id 4100 -Message "CDK/BlueZone cleanup started for profile '$profilePath' (SID $($profile.SID))."
echo
echo     Clear-EdgeCaches -LocalAppData $localAppData
echo     Remove-FolderIfPresent -Path (Join-Path $localAppData 'Apps\2.0')
echo     Remove-FolderIfPresent -Path (Join-Path $localAppData 'assembly\dl3')
echo     Remove-FolderIfPresent -Path (Join-Path $roamingAppData 'ADP')
echo
echo     Copy-And-Remove -Source (Join-Path $roamingAppData 'BlueZone') -Destination (Join-Path $backupPath 'Roaming_BlueZone')
echo     Copy-And-Remove -Source (Join-Path $roamingAppData 'BlueZone Web') -Destination (Join-Path $backupPath 'Roaming_BlueZone_Web')
echo     Copy-And-Remove -Source (Join-Path $documentsPath 'BlueZone') -Destination (Join-Path $backupPath 'Documents_BlueZone')
echo
echo     Write-ToolLog "Completed profile: $profilePath"
echo     Write-ToolEvent -Type INFORMATION -Id 4101 -Message "CDK/BlueZone cleanup completed for profile '$profilePath' (SID $($profile.SID))."
echo ^}
echo
echo if ($script:HadWarnings) { exit 1 }
echo exit 0
) > "%PS_HELPER%"

exit /b 0

REM ============================================================================
:ClearMachineCaches
REM ============================================================================
call :Log "Clearing machine-wide ADP/CDK cache locations."

rd /s /q "C:\ProgramData\ADP\websuite" >> "%LOG_FILE%" 2>&1
rd /s /q "C:\ProgramData\CDK\Drive" >> "%LOG_FILE%" 2>&1

exit /b 0

REM ============================================================================
:UninstallKnownProducts
REM ============================================================================
call :Log "Attempting silent uninstall of known BlueZone/ADP components."

call :UninstallMsi "{374C62B2-C3F7-4C33-841E-5AD4627ECF9F}" "BlueZone VBA 6.2"
call :UninstallMsi "{90F50409-6000-11D3-8CFE-0150048383C9}" "BlueZone VBA component"
call :UninstallMsi "{90F60409-6000-11D3-8CFE-0150048383C9}" "BlueZone VBA component"
call :UninstallMsi "{38A229CB-4547-478F-B2C4-FB0D336813FD}" "SGLW2HCM component"
call :UninstallMsi "{359846D6-19CE-480E-9FDF-02359052CEA4}" "BlueZone patch"
call :UninstallMsi "{E495B22B-232B-4094-90B3-0FD4BC4B7B64}" "BlueZone patch"
call :UninstallMsi "{49D3D8A3-F983-40B1-B668-2B7B2C4B2154}" "BlueZone 6.2"
call :UninstallMsi "{383D7832-FC67-4BFA-816E-88B80A0D95ED}" "BlueZone VBA 6.1"
call :UninstallMsi "{374C61B2-C3F7-4C33-841E-5AD4627ECF9F}" "BlueZone VBA 6.1"
call :UninstallMsi "{498CDC54-B572-4B23-8E65-2C95DA2F0D08}" "BlueZone 6.1"
call :UninstallMsi "{5C6ADDC7-067C-4236-B788-2B3F4B6F47A4}" "BlueZone Rebrander"
call :UninstallMsi "{69EF9BED-A297-4204-90F0-F1CC803AC4FA}" "BlueZone VBA 952"
call :UninstallMsi "{374C88B2-C3F7-4C33-841E-5AD4627ECF9F}" "BlueZone 4.1"
call :UninstallMsi "{5DCA09DF-B911-48BB-82B7-89A35A0F49B7}" "BlueZone 4.1 update"
call :UninstallMsi "{BB3B5869-A650-425E-9985-76CA48A8DDAF}" "ADPInit"
call :UninstallMsi "{40FDC133-63DC-4B03-B74B-7573CEB2EA9F}" "CDKInit"

if exist "C:\Program Files (x86)\BlueZone VBA\6.2\BzvbaI.exe" (
    call :Log "Running BlueZone VBA executable uninstaller."
    start "" /wait "C:\Program Files (x86)\BlueZone VBA\6.2\BzvbaI.exe" /u >> "%LOG_FILE%" 2>&1
    call :Log "BlueZone VBA executable uninstaller exit code: %ERRORLEVEL%"
)

exit /b 0

REM ============================================================================
:UninstallMsi
REM ============================================================================
set "PRODUCT_CODE=%~1"
set "PRODUCT_NAME=%~2"

call :Log "Uninstall attempt: %PRODUCT_NAME% [%PRODUCT_CODE%]"

REM /x = uninstall; /qn = silent; /norestart = do not reboot automatically.
start "" /wait msiexec.exe /x %PRODUCT_CODE% /qn /norestart >> "%LOG_FILE%" 2>&1

set "MSI_RESULT=%ERRORLEVEL%"
call :Log "MSI exit code for %PRODUCT_NAME%: %MSI_RESULT%"

REM Expected outcomes:
REM   0    success
REM   1605 product is not installed
REM   3010 success; restart needed
if not "%MSI_RESULT%"=="0" if not "%MSI_RESULT%"=="1605" if not "%MSI_RESULT%"=="3010" (
    call :WriteEvent WARNING 2100 "MSI uninstall returned exit code %MSI_RESULT% for %PRODUCT_NAME% [%PRODUCT_CODE%]. Log: %LOG_FILE%"
)

exit /b 0

REM ============================================================================
:RemoveProgramFolders
REM ============================================================================
call :Log "Removing residual BlueZone/ADP program folders."

call :RemoveFolder "C:\Program Files (x86)\ADP\websuite TE"
call :RemoveFolder "C:\Program Files (x86)\BlueZone"
call :RemoveFolder "C:\Program Files (x86)\BlueZone VBA"
call :RemoveFolder "C:\Windows\Downloaded Program Files\6.2"
call :RemoveFolder "C:\ProgramData\BlueZone"
call :RemoveFolder "C:\Users\Default\Documents\BlueZone"
call :RemoveFolder "C:\Users\Public\Documents\BlueZone"

exit /b 0

REM ============================================================================
:RemoveFolder
REM ============================================================================
set "TARGET_FOLDER=%~1"

if not exist "%TARGET_FOLDER%" (
    call :Log "Folder not present: %TARGET_FOLDER%"
    exit /b 0
)

call :Log "Removing folder: %TARGET_FOLDER%"
takeown /f "%TARGET_FOLDER%" /r /d y >> "%LOG_FILE%" 2>&1
icacls "%TARGET_FOLDER%" /grant Administrators:F /t /c >> "%LOG_FILE%" 2>&1
attrib -r -s -h "%TARGET_FOLDER%" /s /d >> "%LOG_FILE%" 2>&1
rd /s /q "%TARGET_FOLDER%" >> "%LOG_FILE%" 2>&1

exit /b 0

REM ============================================================================
:RemoveTargetedRegistryKeys
REM ============================================================================
call :Log "Removing targeted machine-wide BlueZone/ADP registry keys."

REM Thorough/full-user mode does not delete HKCU keys for the admin account.
reg delete "HKLM\SOFTWARE\Wow6432Node\BlueZone" /f >> "%LOG_FILE%" 2>&1
reg delete "HKLM\SOFTWARE\Wow6432Node\SEAGULL\BlueZone" /f >> "%LOG_FILE%" 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ADPInit" /f >> "%LOG_FILE%" 2>&1

for %%K in (
    "HKLM\SOFTWARE\Classes\fileBBH"
    "HKLM\SOFTWARE\Classes\fileBBS"
    "HKLM\SOFTWARE\Classes\fileBZT"
    "HKLM\SOFTWARE\Classes\fileZLT"
    "HKLM\SOFTWARE\Classes\fileZVT"
    "HKLM\SOFTWARE\Classes\BlueZone.FTP.1"
    "HKLM\SOFTWARE\Classes\BlueZone.iSeriesDisplay.1"
    "HKLM\SOFTWARE\Classes\BlueZone.iSeriesPrinter.1"
    "HKLM\SOFTWARE\Classes\BlueZone.MainframeDisplay.1"
    "HKLM\SOFTWARE\Classes\BlueZone.MainframePrinter.1"
    "HKLM\SOFTWARE\Classes\BlueZone.SessionManagerLayout.1"
    "HKLM\SOFTWARE\Classes\BlueZone.TCP/IPPrintServer.1"
    "HKLM\SOFTWARE\Classes\BlueZone.VTDisplay.1"
    "HKLM\SOFTWARE\Classes\Bzvba.Vbahost"
    "HKLM\SOFTWARE\Classes\Bzvba.Vbahost.1"
    "HKLM\SOFTWARE\Classes\Bzvba.Vbahost.6.2"
) do (
    reg delete %%~K /f >> "%LOG_FILE%" 2>&1
)

REM Do not manually delete generic MSI Products/Components/UserData records.
for %%K in (
    "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\BlueZone VBA 6.2"
    "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{90F60409-6000-11D3-8CFE-0150048383C9}"
    "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{90F50409-6000-11D3-8CFE-0150048383C9}"
    "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{359846D6-19CE-480E-9FDF-02359052CEA4}"
    "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{374C88B2-C3F7-4C33-841E-5AD4627ECF9F}"
) do (
    reg delete %%~K /f >> "%LOG_FILE%" 2>&1
)

exit /b 0

REM ============================================================================
:UnregisterLegacyOcx
REM ============================================================================
set "OCX_FILE=C:\Windows\Downloaded Program Files\sglw2hcm.ocx"

if exist "%OCX_FILE%" (
    call :Log "Unregistering legacy OCX: %OCX_FILE%"
    regsvr32.exe /u /s "%OCX_FILE%" >> "%LOG_FILE%" 2>&1
    move /y "%OCX_FILE%" "%TEMP%\sglw2hcm_%STAMP%.ocx" >> "%LOG_FILE%" 2>&1
) else (
    call :Log "Legacy OCX not present."
)

exit /b 0

REM ============================================================================
:RequireAdmin
REM ============================================================================
net session >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

REM ============================================================================
:WriteEvent
REM ============================================================================
REM Event Viewer:
REM Windows Logs > Application
REM Event source: CDKBlueZoneReset

set "EVENT_TYPE=%~1"
set "EVENT_ID=%~2"
set "EVENT_MESSAGE=%~3"

eventcreate.exe ^
    /l "%EVENT_LOG%" ^
    /so "%EVENT_SOURCE%" ^
    /t "%EVENT_TYPE%" ^
    /id %EVENT_ID% ^
    /d "%EVENT_MESSAGE%" >> "%LOG_FILE%" 2>&1

exit /b 0

REM ============================================================================
:Log
REM ============================================================================
>> "%LOG_FILE%" echo [%DATE% %TIME%] %~1
exit /b 0

REM ============================================================================
:Usage
REM ============================================================================
echo.
echo ==========================================================================
echo CDK Drive / BlueZone Reset and Removal Tool - Help
echo ==========================================================================
echo.
echo SYNTAX
echo   %SCRIPT_NAME% [basic ^| thorough ^| full-user] [target options]
echo.
echo MODES
echo   basic
echo       Resets user profile data only.
echo.
echo   thorough
echo       Administrator-only machine-wide BlueZone/CDK removal.
echo       It does not touch user profile data.
echo.
echo   full-user
echo       Administrator-only profile cleanup plus machine-wide removal.
echo.
echo TARGET OPTIONS
echo   No target option
echo       Targets only the profile of the account running this script.
echo.
echo   --profile-path "C:\Users\ProfileName"
echo       Targets an existing profile by exact local profile path.
echo.
echo   --sid "S-1-..."
echo       Targets an existing profile by Windows SID.
echo.
echo   --users "identity"
echo       Best-effort identity lookup. If it cannot identify one unique local
echo       profile, use --sid, --profile-path, or --all-users.
echo.
echo   --all-users
echo       Targets every existing non-special local Windows profile.
echo.
echo EXAMPLES
echo   %SCRIPT_NAME% basic
echo   %SCRIPT_NAME% basic --profile-path "C:\Users\janes"
echo   %SCRIPT_NAME% basic --sid "S-1-12-1-123456789-123456789-123456789-123456789"
echo   %SCRIPT_NAME% basic --users "jane.smith@contoso.com"
echo   %SCRIPT_NAME% basic --all-users
echo   %SCRIPT_NAME% full-user --all-users
echo   %SCRIPT_NAME% thorough
echo.
echo REQUIREMENTS AND WARNINGS
echo   - Targeting other users or all users requires Administrator privileges.
echo   - Quote profile paths and identities that contain spaces.
echo   - --all-users can affect every normal user profile on the device.
echo   - CDK/BlueZone/Edge processes are force-closed; unsaved work can be lost.
echo   - Detailed logs and Event Viewer summary records are created.
echo.
exit /b 0

REM ============================================================================
:Quit
REM ============================================================================
echo.
echo No action was taken.
exit /b 0

REM ============================================================================
:EndInteractive
REM ============================================================================
REM Do not pause during scripted deployment.
if not "%~1"=="" exit /b 0

echo.
pause
exit /b 0
