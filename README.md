# CDK Drive / BlueZone Local Client Reset Script

> **Warning:** This script force-closes applications and permanently deletes local browser data, cached application files, and selected CDK/ADP folders.  
> Run it only with authorization from CDK Global support or your organization’s IT team. Save any open work first.

## Purpose

This batch script resets local CDK Drive, ADP, and BlueZone client data. It is intended to resolve issues caused by damaged caches, outdated downloaded application components, or corrupted user-profile configuration.

## Actions Performed

- Force-closes CDK Drive, BlueZone, and Internet Explorer-related processes.
- Clears Internet Explorer history, cookies, and temporary internet files.
- Deletes ClickOnce and .NET downloaded-assembly caches.
- Deletes local ADP and CDK Drive cached data.
- Renames active BlueZone configuration folders to `.old` backups, allowing the application to create fresh folders at next launch.

## Batch Script

```bat
@echo off
REM ============================================================================
REM CDK Drive / BlueZone Local Client Reset
REM ============================================================================
REM WARNING:
REM - Force-closes specified applications.
REM - Clears Internet Explorer browsing data.
REM - Deletes local caches and selected application-data directories.
REM - Existing *.old BlueZone backup folders are deleted before new backups
REM   are created.
REM ============================================================================


REM ============================================================================
REM 1. Force-close CDK Drive, BlueZone, and browser processes
REM ============================================================================
REM /IM specifies the image/process name.
REM /F forces termination. Unsaved work in these applications may be lost.

taskkill /IM wsstart.exe /F
taskkill /IM wsstart_2.exe /F
taskkill /IM wsstart_4.exe /F
taskkill /IM BZVT.exe /F
taskkill /IM BZVBA.exe /F
taskkill /IM dfsvc.exe /F
taskkill /IM sw9c.exe /F
taskkill /IM iexplore.exe /F


REM ============================================================================
REM 2. Clear Internet Explorer browsing data
REM ============================================================================
REM 255 clears all supported browser-tracking categories.
REM The following two commands additionally target cookies and temporary files.

REM Clear all Internet Explorer browsing history and related data.
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255

REM Clear Internet Explorer cookies.
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2

REM Clear Internet Explorer temporary internet files/cache.
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8


REM ============================================================================
REM 3. Remove local ClickOnce and .NET application caches
REM ============================================================================
REM These folders are rebuilt or repopulated when affected applications launch.

REM Remove the per-user ClickOnce application cache.
RMDIR /S /Q "%LocalAppData%\Apps\2.0"

REM Remove the per-user downloaded .NET assembly cache.
RMDIR /S /Q "%LocalAppData%\assembly\dl3"


REM ============================================================================
REM 4. Remove local ADP data
REM ============================================================================

REM Remove ADP application data stored in the current user's Roaming profile.
RMDIR /S /Q "%AppData%\ADP"


REM ============================================================================
REM 5. Back up current BlueZone user configuration
REM ============================================================================
REM First remove prior *.old backups. These deletions are permanent.
REM Then rename active configuration folders to *.old, allowing BlueZone to
REM create new configuration folders when it next starts.

REM Remove prior BlueZone backups from AppData\Roaming.
RMDIR /S /Q "%AppData%\BlueZone.old"
RMDIR /S /Q "%AppData%\BlueZone Web.old"

REM Remove a prior BlueZone backup from Documents.
RMDIR /S /Q "%UserProfile%\Documents\BlueZone.old"

REM Rename active BlueZone configuration folders in AppData\Roaming.
REN "%AppData%\BlueZone" "BlueZone.old"
REN "%AppData%\BlueZone Web" "BlueZone Web.old"

REM Rename the active BlueZone Documents folder.
REN "%UserProfile%\Documents\BlueZone" "BlueZone.old"


REM ============================================================================
REM 6. Remove machine-wide ADP and CDK Drive cached data
REM ============================================================================
REM These locations may require Administrator privileges, depending on system
REM permissions and endpoint-management policies.

REM Remove ADP WebSuite data.
RMDIR /S /Q "C:\ProgramData\ADP\websuite"

REM Remove CDK Drive local data/cache.
RMDIR /S /Q "C:\ProgramData\CDK\Drive"


REM ============================================================================
REM End of script
REM ============================================================================
echo.
echo CDK Drive / BlueZone local reset is complete.
echo Restart the computer or relaunch the required CDK applications.
pause
```

## Notes

- The script may produce “path not found” or “process not found” messages when an application or folder is already absent. Those messages are generally expected during a cleanup operation.
- The next CDK Drive or BlueZone launch may take longer than normal because application files, settings, or caches may need to be recreated or downloaded.
- If a prior BlueZone profile must be recovered, check the newly created `.old` folders before running this script again.
