@echo off
rem ============================================================================
rem  run-test.bat -- run the console self test and exit non-zero on failure.
rem                   (Windows)
rem
rem    run-test.bat
rem    run-test.bat --ticks 120
rem
rem  Tests execute inside the real DragonRuby runtime, so a pass means the
rem  library works against the actual renderer and the actual mruby build.
rem
rem  The verdict is taken from the output, not the process exit code, which is
rem  what ./run-test does: DragonRuby reports a quit code of its own choosing and
rem  the machine-readable line is the authoritative answer.
rem ============================================================================
setlocal

cd /d "%~dp0.."
if errorlevel 1 (
  echo run-test.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "GAMEDIR=%CD%"
set "DRAGONRUBY=%CD%\..\dragonruby.exe"
if not exist "%DRAGONRUBY%" set "DRAGONRUBY=%CD%\..\dragonruby"
if not exist "%DRAGONRUBY%" (
  echo run-test.bat: cannot find dragonruby next to the console 1>&2
  echo               expected %CD%\..\dragonruby.exe 1>&2
  exit /b 1
)

set "LOG=%TEMP%\run-test.log"
if not exist "%TEMP%" set "LOG=%CD%\run-test.log"
if exist "%LOG%" del /q "%LOG%"

rem  dragonruby.exe is a GUI program on Windows, so its stdout is not inherited
rem  and the redirect below captures nothing. The engine mirrors the same
rem  output into ..\logs\console.log; that is cleared first (so a stale log can
rem  never report a pass) and read when the redirect came back empty.
set "DRLOG=%CD%\..\logs\console.log"
if exist "%DRLOG%" del /q "%DRLOG%" >nul 2>&1

"%DRAGONRUBY%" "%GAMEDIR%" --selftest %* >"%LOG%" 2>&1

for %%A in ("%LOG%") do if %%~zA==0 if exist "%DRLOG%" type "%DRLOG%" >"%LOG%"

type "%LOG%"

findstr /i /l /c:"CONSOLE_TEST_STATUS=PASS" "%LOG%" >nul 2>&1
if not errorlevel 1 (
  del /q "%LOG%" >nul 2>&1
  endlocal & exit /b 0
)

echo.
echo run-test.bat: FAILED (no CONSOLE_TEST_STATUS=PASS in the output above)
del /q "%LOG%" >nul 2>&1
endlocal & exit /b 1
