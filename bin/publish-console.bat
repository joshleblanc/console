@echo off
rem ============================================================================
rem  publish-console.bat -- release this console to the site. (Windows)
rem
rem    publish-console.bat                  package and send what is here now
rem    publish-console.bat --dry-run        build the archive, send nothing
rem    publish-console.bat --help
rem
rem  The counterpart of publish-site.bat: that one sends a cart, this one sends
rem  the console, which becomes a new version carts can be pinned to. It is the
rem  same install the admin upload screen performs, so an archive this produces
rem  is one the site will accept.
rem
rem  A version is permanent. The site refuses to replace one, because a cartridge
rem  pinned to 0.1.0 has to keep running against 0.1.0 forever. So nothing that
rem  describes this machine goes up: no .git, no builds\, no shots\, no
rem  errors\last.txt, no carts, and not the publishing key sitting in this
rem  directory. What does go up is everything a person needs to run a console --
rem  the library, the entry point, every script, the starter art, and a carts\
rem  directory with a README in it. The list is explicit rather than "everything
rem  but", so adding a file to the console is a decision.
rem
rem  Administrators only. The site resolves the key to its owner on every request
rem  and refuses anybody who is not one, so having this script is a convenience
rem  and not a permission.
rem
rem  This mirrors ./bin/publish-console. Keep the two in step.
rem
rem  NOTE: written by hand and reviewed, not executed. See README.md.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo publish-console.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "CREDENTIALS=dragonstation.json"
set "VERSION_FILE=app\console\version.rb"
set "WORK=%~dp0..\builds\tmp\publish-console"

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
echo publish-console.bat: unknown argument '%~1'  ^(try --help^) 1>&2
exit /b 2

:parsed

where curl >nul 2>&1
if errorlevel 1 (
  echo publish-console.bat: needs curl, and this machine has none. 1>&2
  exit /b 1
)

rem --- credentials --------------------------------------------------------
if not exist "!CREDENTIALS!" (
  echo publish-console.bat: no !CREDENTIALS! in this console. 1>&2
  echo publish-console.bat: it comes in the download from the site. 1>&2
  exit /b 2
)

call :json "!CREDENTIALS!" api_key API_KEY
call :json "!CREDENTIALS!" release_url RELEASE_URL

if "!API_KEY!"=="" (
  echo publish-console.bat: !CREDENTIALS! has no api_key. 1>&2
  exit /b 1
)
if "!RELEASE_URL!"=="" (
  echo publish-console.bat: this key cannot release a console version. 1>&2
  echo publish-console.bat: !CREDENTIALS! has no release_url, which the site 1>&2
  echo publish-console.bat: only writes for an administrator. 1>&2
  exit /b 2
)

rem --- the version --------------------------------------------------------
if not exist "!VERSION_FILE!" (
  echo publish-console.bat: no !VERSION_FILE!, so there is no version to release. 1>&2
  exit /b 1
)

set "VER="
for %%P in (MAJOR MINOR PATCH) do (
  call :const "!VERSION_FILE!" %%P NUM_%%P
)
set "VERSION=!NUM_MAJOR!.!NUM_MINOR!.!NUM_PATCH!"
if "!VERSION:~0,1!"=="." set "VERSION=!VERSION:~1!"

echo publish-console: releasing console !VERSION!

rem --- what the archive holds -----------------------------------------------
for %%D in (app\console bin sprites metadata) do (
  if not exist "%%D" (
    echo publish-console.bat: %%D is missing. A version is a whole console, 1>&2
    echo publish-console.bat: not just its library. 1>&2
    exit /b 1
  )
)
for %%F in (app\main.rb carts\README.md sprites) do (
  if not exist "%%F" (
    echo publish-console.bat: %%F is missing. A version is a whole console, 1>&2
    echo publish-console.bat: not just its library. 1>&2
    exit /b 1
  )
)

if exist "!WORK!" rmdir /s /q "!WORK!"
mkdir "!WORK!" 2>nul
if errorlevel 1 (
  echo publish-console.bat: could not create !WORK! 1>&2
  exit /b 1
)

set "ARCHIVE=!WORK!\console-!VERSION!.zip"

rem --- build ---------------------------------------------------------------
echo publish-console: packing console !VERSION!

powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem;" ^
  "$root = (Get-Location).Path;" ^
  "$paths = @('app/main.rb','app/console','bin','sprites','metadata'," ^
  "  'errors/readme.txt','carts/README.md','font.ttf','tiny.ttf'," ^
  "  'README.md','.gitignore','.gitattributes');" ^
  "$junk = @('.DS_Store','__MACOSX','last.txt','dragonstation.json');" ^
  "$z = [IO.Compression.ZipFile]::Open('!ARCHIVE!', 'Create');" ^
  "foreach ($p in $paths) {" ^
  "  $full = Join-Path $root $p;" ^
  "  if (Test-Path -LiteralPath $full -PathType Leaf) {" ^
  "    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $full, $p, 'Optimal') | Out-Null;" ^
  "  } elseif (Test-Path -LiteralPath $full -PathType Container) {" ^
  "    Get-ChildItem -LiteralPath $full -Recurse -File |" ^
  "      Where-Object { $junk -notcontains $_.Name -and $junk -notcontains $_.Directory.Name } |" ^
  "      ForEach-Object {" ^
  "        $rel = $_.FullName.Substring($root.Length + 1).Replace([char]92, '/');" ^
  "        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $_.FullName, $rel, 'Optimal') | Out-Null };" ^
  "  } else { throw ('missing from the console: ' + $p) } };" ^
  "$z.Dispose()" 1>&2
if errorlevel 1 (
  echo publish-console.bat: packing failed 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)

rem The credential must not have gone up with it. It is sitting in this
rem directory, and a list that forgot it would leak a live key into a public
rem version.
powershell -NoProfile -Command ^
  "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
  "$z=[IO.Compression.ZipFile]::OpenRead('!ARCHIVE!');" ^
  "$hit = @($z.Entries | Where-Object { $_.FullName -eq '!CREDENTIALS!' });" ^
  "$z.Dispose();" ^
  "if ($hit.Count -gt 0) { throw 'the archive contains !CREDENTIALS!. That is a live key; refusing to send it.' }" 1>&2
if errorlevel 1 (
  rmdir /s /q "!WORK!"
  exit /b 1
)

for %%A in ("!ARCHIVE!") do echo publish-console: %%~nxA
echo publish-console: sending to !RELEASE_URL!

if "!DRY_RUN!"=="1" (
  mkdir "%~dp0..\builds" 2>nul
  copy /y "!ARCHIVE!" "%~dp0..\builds\console-!VERSION!.zip" >nul
  echo publish-console: --dry-run, nothing sent
  echo publish-console: it is at %~dp0..\builds\console-!VERSION!.zip
  rmdir /s /q "!WORK!"
  exit /b 0
)

rem --- send ---------------------------------------------------------------
set "RESPONSE=!WORK!\response.txt"
curl -sS -o "!RESPONSE!" -w "%%{http_code}" -X POST "!RELEASE_URL!" ^
  -H "Authorization: Bearer !API_KEY!" ^
  -F "archive=@!ARCHIVE!;filename=console-!VERSION!.zip;type=application/zip" > "!WORK!\status.txt"
set "STATUS="
set /p STATUS=<"!WORK!\status.txt"

if "!STATUS!"=="201" goto created
if "!STATUS!"=="401" goto unauthorized
if "!STATUS!"=="403" goto forbidden
if "!STATUS!"=="422" goto refused
if "!STATUS!"=="400" goto refused

echo publish-console.bat: the site answered !STATUS! 1>&2
type "!RESPONSE!" 1>&2
rmdir /s /q "!WORK!"
exit /b 1

:created
call :json "!RESPONSE!" version GOT_VERSION
call :json "!RESPONSE!" url URL
echo publish-console: console !GOT_VERSION! installed
if not "!URL!"=="" echo publish-console:   !URL!
echo publish-console: it is not the default yet. Make it the default when you
echo publish-console: are ready for new carts to build against it.
rmdir /s /q "!WORK!"
exit /b 0

:unauthorized
echo publish-console.bat: the site refused the key. 1>&2
echo publish-console.bat: keys are replaced every time you download your 1>&2
echo publish-console.bat: bundle, so this one may be one that was retired. 1>&2
rmdir /s /q "!WORK!"
exit /b 1

:forbidden
echo publish-console.bat: that key belongs to an account that is not an 1>&2
echo publish-console.bat: administrator. 1>&2
rmdir /s /q "!WORK!"
exit /b 1

:refused
echo publish-console.bat: the site will not install this as a version. 1>&2
powershell -NoProfile -Command ^
  "(Get-Content -Raw '!RESPONSE!' | ConvertFrom-Json).problems | ForEach-Object { '    ' + $_ }" 1>&2
echo. 1>&2
rmdir /s /q "!WORK!"
exit /b 1

rem --- helpers ------------------------------------------------------------

:json
rem :json <file> <key> <var>  -- one string value out of a JSON file.
set "%~3="
for /f "tokens=2 delims=:," %%A in ('findstr /c:"%~2" "%~1"') do (
  set "VAL=%%A"
)
set "%~3=!VAL:"=!"
goto :eof

:const
rem :const <version.rb> <NAME> <var>  -- one integer constant out of a version
rem file. Tokens rather than a regex, because a version file is small and a
rem regex that nearly matches is worse than one that plainly does not.
set "%~3="
for /f "tokens=2 delims==" %%A in ('findstr /c:"%~2" "%~1"') do (
  for /f "tokens=1" %%B in ("%%A") do set "%~3=%%B"
)
goto :eof

:usage
echo usage: publish-console.bat [--dry-run]
echo        publish-console.bat --help
echo.
echo   --dry-run   build the archive and check the key, send nothing.
echo   --help      this text.
echo.
echo Packages this console and sends it to the site as a new version. Needs an
echo administrator's key in dragonstation.json, and a version in
echo app\console\version.rb that the site has not seen.
exit /b 0