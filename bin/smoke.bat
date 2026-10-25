@echo off
rem ============================================================================
rem  smoke.bat -- boot every cart headlessly and report which ones raise.
rem                 (Windows)
rem
rem    smoke.bat
rem    smoke.bat 600
rem
rem  This is the cheapest way to catch "I edited the library and now one of the
rem  carts is broken". Exits non-zero if any cart raised an exception.
rem
rem  On a headless box (CI, a container, WSL) wrap it in xvfb-run, exactly as
rem  with ./smoke.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo smoke.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "GAMEDIR=%CD%"
set "DRAGONRUBY=%CD%\..\dragonruby.exe"
if not exist "%DRAGONRUBY%" set "DRAGONRUBY=%CD%\..\dragonruby"
if not exist "%DRAGONRUBY%" (
  echo smoke.bat: cannot find dragonruby next to the console 1>&2
  exit /b 1
)

set "TICKS=300"
if not "%~1"=="" set "TICKS=%~1"

set "LOG=%TEMP%\smoke.log"
if not exist "%TEMP%" set "LOG=%CD%\smoke.log"

rem  Cart directories in both galleries: your own in carts\ and the samples
rem  that ship in samples\. A directory without an entry file is not a cart,
rem  the same rule Console::CartLoader#available applies.
rem
rem  Paths, not names: a cart of yours can share a name with a sample, and
rem  both have to be booted. The path is spelled with forward slashes, which
rem  is what the console reads.
set "CARTS="
call :collect carts
call :collect samples

if not defined CARTS (
  echo smoke: no carts found in carts\ or samples\ 1>&2
  endlocal & exit /b 1
)

set "FAILED="
for %%C in (!CARTS!) do call :boot "%%C"

if defined FAILED (
  echo.
  echo smoke: FAILED:!FAILED!
  endlocal & exit /b 1
)

echo.
echo smoke: all carts booted cleanly
endlocal & exit /b 0

rem ============================================================================
rem  helpers
rem ============================================================================

:has_entry
set "HASE="
if exist "%~1\app\main.rb" set "HASE=1"
if defined HASE goto :eof
if exist "%~1\app\%~2.rb" set "HASE=1"
goto :eof

rem  Collect the carts in one gallery. %%D is the directory name, so the entry
rem  file can be named after it.
:collect
set "GALLERY=%~1"
for /f "delims=" %%D in ('dir /b /ad "%GALLERY%\*" 2^>nul') do (
  call :has_entry "%GALLERY%\%%D" "%%D"
  if defined HASE (
    set "CARTPATH=%GALLERY%/%%D"
    if defined CARTS (set "CARTS=!CARTS! !CARTPATH!") else (set "CARTS=!CARTPATH!")
  )
)
goto :eof

:boot
rem  Each cart's whole output goes to the log, so a failure can show the
rem  complete trace rather than a couple of grepped lines.
rem  %~1 is a cart path (carts\mine or samples\arcade).
"%DRAGONRUBY%" "%GAMEDIR%" --cart "%~1" --ticks "%TICKS%" >"%LOG%" 2>&1
for %%A in ("%LOG%") do if %%~zA==0 if exist "%DRLOG%" type "%DRLOG%" >"%LOG%"

findstr /i /l /c:"EXCEPTION" "%LOG%" >nul 2>&1
if errorlevel 1 (
  echo ok    %~1  ^(%TICKS% frames^)
  goto :eof
)

echo FAIL  %~1
type "%LOG%"
set "FAILED=!FAILED! %~1"
goto :eof
