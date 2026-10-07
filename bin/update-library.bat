@echo off
rem ============================================================================
rem  update-library.bat -- refresh the console library from a site. (Windows)
rem
rem    update-library.bat                              the site in dragonstation.json
rem    update-library.bat --site=http://127.0.0.1:3000  an explicit site
rem    update-library.bat --dry-run                    report, change nothing
rem    update-library.bat --help
rem
rem  The site vendors the library and already serves every byte of it to any
rem  browser running a cart, so it publishes the same tree as
rem  <site>/console/library.zip with no login. That is what makes an update a
rem  download and an unpack from a terminal, with no session to log in with.
rem
rem  Which site? There is deliberately no canonical production domain baked in
rem  here: the site knows its own address and hands it out in dragonstation.json.
rem  So the address comes from --site when you name one, and from that file
rem  otherwise -- hardcoding a host would mean a checkout silently pointing at
rem  somebody else's site, or at nothing at all.
rem
rem  Only the version decides whether anything happens. The installed version is
rem  read from MAJOR/MINOR/PATCH in app\console\version.rb and the downloaded
rem  copy the same way; a site that is not newer than what is installed changes
rem  nothing.
rem
rem  Everything is unpacked to a scratch directory first and only moved into
rem  place once verified, so a truncated download cannot leave the console with
rem  half a library. The old one is moved aside first and restored if the second
rem  move fails.
rem
rem  This mirrors ./update-library. Keep the two in step.
rem
rem  NOTE: written by hand and reviewed, not executed. See README.md.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo update-library.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "CREDENTIALS=dragonstation.json"
set "VERSION_FILE=app\console\version.rb"
set "WORK=%~dp0..\builds\tmp\update-library"

set "SITE="
set "DRY_RUN=0"

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-h" goto usage
if /i "%~1"=="--dry-run" (
  set "DRY_RUN=1"
  shift
  goto parse
)
if "%~1"=="--site=*" (
  set "SITE=%~1"
  goto site_only
)
if "%~1"=="--site" (
  if "%~2"=="" (
    echo update-library.bat: --site needs a URL, as --site=http://example.com 1>&2
    exit /b 2
  )
  set "SITE=%~2"
  goto parse_next
)
echo update-library.bat: unknown argument '%~1'  ^(try --help^) 1>&2
exit /b 2

:site_only
set "SITE=!SITE:--site=!"
goto parse_next

:parse_next
shift
goto parse

:parsed

rem --- which site ---------------------------------------------------------
if "!SITE!"=="" if exist "!CREDENTIALS!" call :json "!CREDENTIALS!" site_url SITE
if "!SITE!"=="" (
  echo update-library.bat: no site to download from. 1>&2
  echo update-library.bat: pass one, as --site=URL, or download your bundle from 1>&2
  echo update-library.bat: the site and unpack it here -- it carries this file. 1>&2
  goto usage_fail
)

set "LIBRARY_URL=!SITE:/=/!"
if "!LIBRARY_URL:~-1!"=="/" set "LIBRARY_URL=!LIBRARY_URL:~0,-1!"
set "LIBRARY_URL=!LIBRARY_URL!/console/library.zip"

echo update-library: console version check
call :declared_version "!VERSION_FILE!" LOCAL
if errorlevel 1 (
  echo update-library.bat: could not read MAJOR/MINOR/PATCH from !VERSION_FILE! 1>&2
  exit /b 1
)
echo update-library: console !LOCAL! is installed

rem --- scratch ------------------------------------------------------------
if exist "!WORK!" rmdir /s /q "!WORK!"
mkdir "!WORK!" 2>nul
if errorlevel 1 (
  echo update-library.bat: could not create !WORK! 1>&2
  exit /b 1
)

echo update-library: downloading !LIBRARY_URL!
curl -fsSL -o "!WORK!\library.zip" "!LIBRARY_URL!"
if errorlevel 1 (
  echo update-library.bat: could not download !LIBRARY_URL! 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)

rem --- verify before touching anything -------------------------------------
powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
  "$z=[IO.Compression.ZipFile]::OpenRead('!WORK!\library.zip');" ^
  "$names=@($z.Entries | ForEach-Object { $_.FullName });" ^
  "$z.Dispose();" ^
  "if ($names -notcontains 'app/console/core.rb') { throw 'the download has no app/console/core.rb, so it is not the console library' };" ^
  "if ($names -notcontains 'app/console/version.rb') { throw 'the download has no app/console/version.rb' };" ^
  "foreach ($n in $names) { if ($n.StartsWith('/') -or $n -match '(^|/)\.\.(/|$)' -or $n.Contains([char]92)) { throw ('the download has an entry that escapes the console: ' + $n) } }" 1>&2
if errorlevel 1 (
  rmdir /s /q "!WORK!"
  exit /b 1
)

powershell -NoProfile -Command ^
  "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
  "[IO.Compression.ZipFile]::ExtractToDirectory('!WORK!\library.zip','!WORK!')" 1>&2
if errorlevel 1 (
  echo update-library.bat: could not unpack the download 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)

call :declared_version "!WORK!\!VERSION_FILE!" REMOTE
if errorlevel 1 (
  echo update-library.bat: could not read the downloaded version 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)

rem --- decide -------------------------------------------------------------
call :version_cmp "!REMOTE!" "!LOCAL!" CMP
if !CMP! LEQ 0 (
  if !CMP! EQU 0 (
    echo update-library: the site serves !REMOTE!, which is what is installed.
  ) else (
    echo update-library: the site serves !REMOTE!, older than the installed !LOCAL!.
  )
  echo update-library: nothing to do; this console is at !LOCAL!
  rmdir /s /q "!WORK!"
  exit /b 0
)

echo update-library: the site serves !REMOTE!; this console has !LOCAL!

if "!DRY_RUN!"=="1" (
  echo update-library: --dry-run, !LOCAL! still installed
  rmdir /s /q "!WORK!"
  exit /b 0
)

rem --- install ------------------------------------------------------------
rem The old library is moved aside first, so it is recoverable until the new
rem one is in, and restored if the second move fails.
move "app\console" "!WORK!\previous-app-console" >nul
if errorlevel 1 (
  echo update-library.bat: could not move the installed library aside; nothing changed 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)
move "!WORK!\app\console" "app\console" >nul
if errorlevel 1 (
  move "!WORK!\previous-app-console" "app\console" >nul
  echo update-library.bat: could not install the downloaded library; the installed one was restored 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)

rem The fonts the library serves alongside itself. Only the ones this version
rem ships are touched.
set "FONTS="
for %%F in (font.ttf tiny.ttf) do (
  if exist "!WORK!\%%F" (
    move /y "!WORK!\%%F" "%%F" >nul
    set "FONTS=!FONTS! %%F"
  )
)

echo update-library: replaced app\console and!FONTS!
echo update-library: console !LOCAL! -^> !REMOTE!
echo update-library: run run-test.bat to prove the new library boots
rmdir /s /q "!WORK!"
exit /b 0

rem --- helpers ------------------------------------------------------------

:json
rem :json <file> <key> <var>  -- one string value out of a JSON file.
for /f "tokens=2 delims=:," %%A in ('findstr /c:"%~2" "%~1"') do (
  set "VAL=%%A"
)
set "%~3=!VAL:"=!"
goto :eof

:declared_version
rem :declared_version <version.rb> <var>  -- MAJOR.MINOR.PATCH from a version file.
set "%~2="
if not exist "%~1" exit /b 1
set "VER="
for %%P in (MAJOR MINOR PATCH) do (
  if "!VER!"=="" set "VER=0"
  for /f "tokens=2 delims==" %%A in ('findstr /r /c:"^ *%%P *= *[0-9][0-9]*$" "%~1"') do (
    set "VER=!VER!.%%A"
  )
)
set "%~2=!VER:.=!"
goto :eof

:version_cmp
rem :version_cmp <a> <b> <var>  -- -1 older, 0 same, 1 newer. Field by field,
rem because string comparison reads 0.10.0 as older than 0.9.0.
set "%~3=0"
for %%F in (1 2 3) do (
  if "!%~3!"=="0" (
    call :field "%~1" %%F A
    call :field "%~2" %%F B
    if !A! LSS !B! set "%~3=-1"
    if !A! GTR !B! set "%~3=1"
  )
)
goto :eof

:field
set "VAL="
for /f "tokens=1-3 delims=." %%A in ("%~1") do (
  if "%%A"=="%~2" set "VAL=%%B"
)
goto :eof

:usage
echo usage: update-library.bat [--site=URL] [--dry-run]
echo        update-library.bat --help
echo.
echo   --site=URL  the Dragonstation to download from. Defaults to site_url in
echo               dragonstation.json, which is how a checkout knows its site.
echo   --dry-run   report the version, change nothing.
echo.
echo Downloads ^<site^>/console/library.zip (public, no login^) and replaces this
echo console's app\console^ plus the library's fonts with the copy the site
echo serves. Nothing changes when the site's version is not newer.
exit /b 0

:usage_fail
call :usage
exit /b 2