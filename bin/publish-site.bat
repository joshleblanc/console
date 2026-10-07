@echo off
rem ============================================================================
rem  publish-site.bat -- send a cart to a Dragonstation site. (Windows)
rem
rem    publish-site.bat arcade                    send carts\arcade
rem    publish-site.bat carts\hello               a path, as run takes one
rem    publish-site.bat arcade --title=My Game    set the title
rem    publish-site.bat arcade --dry-run          build and check, send nothing
rem    publish-site.bat --list                    list carts that could be sent
rem
rem  Where a cart goes is one POST, and this script is that POST: the archive
rem  goes up as multipart/form-data under `archive`, with the API key from
rem  dragonstation.json in an Authorization header. The site runs it through
rem  exactly the same ingest the browser form does, so the refusals are the
rem  form's, and they arrive here as a list to read.
rem
rem  It lands as a *draft* under your account. Nothing goes public because a
rem  script ran.
rem
rem  The key is replaced by every personal download from the site, so a console
rem  unpacked a while ago can hold one the site has retired. That arrives as a
rem  401, and the bottom half of this script says what to do about it.
rem
rem  This mirrors ./publish-site. Keep the two in step.
rem
rem  NOTE: written by hand and reviewed, not executed. See README.md.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo publish-site.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "CREDENTIALS=dragonstation.json"
set "CARTS_DIR=carts"
set "WORK=%~dp0..\builds\tmp\publish-site"

set "CART="
set "TITLE="
set "DRY_RUN=0"
set "WANT_LIST=0"

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-h" goto usage
if /i "%~1"=="--list" (
  set "WANT_LIST=1"
  shift
  goto parse
)
if /i "%~1"=="--dry-run" (
  set "DRY_RUN=1"
  shift
  goto parse
)
if "%~1"=="--title=*" (
  set "TITLE=%~1"
  goto title_only
)
if "%~1"=="--title" (
  if "%~2"=="" (
    echo publish-site.bat: --title needs a value 1>&2
    exit /b 2
  )
  set "TITLE=%~2"
  shift
  shift
  goto parse
)
if "%~1"=="" goto parsed
echo %~1 | findstr /r "^-" >nul && (
  echo publish-site.bat: unknown argument '%~1'  ^(try --help^) 1>&2
  exit /b 2
)
if not "!CART!"=="" (
  echo publish-site.bat: one cart at a time; '!CART!' and '%~1' were both named 1>&2
  exit /b 2
)
set "CART=%~1"
shift
goto parse

:title_only
set "TITLE=!TITLE:--title=!"
shift
goto parse

:parsed

if "!WANT_LIST!"=="1" goto list

if "!CART!"=="" (
  call :usage
  echo publish-site.bat: name a cart to send 1>&2
  exit /b 2
)

rem A bare name is shorthand for carts\<name^>, the same translation run does.
set "CART_DIR=!CART!"
echo !CART! | findstr /r "^[a-zA-Z0-9_-]*$" >nul && set "CART_DIR=carts\!CART!"

if not exist "!CART_DIR!\" (
  echo publish-site.bat: no such cart: !CART_DIR! 1>&2
  exit /b 1
)
for %%A in ("!CART_DIR!") do set "CART_NAME=%%~nxA"

rem The entry file is what makes a directory a cart.
if not exist "!CART_DIR!\app\!CART_NAME!.rb" (
  echo publish-site.bat: !CART_DIR! has no app\!CART_NAME!.rb, so it is not a cart this can send. 1>&2
  exit /b 1
)

rem --- credentials --------------------------------------------------------
if not exist "!CREDENTIALS!" (
  echo publish-site.bat: no !CREDENTIALS! in this console. 1>&2
  echo publish-site.bat: it comes in the download from the site -- sign in there and 1>&2
  echo publish-site.bat: unpack the bundle over this directory. 1>&2
  exit /b 2
)

call :json "!CREDENTIALS!" api_key API_KEY
call :json "!CREDENTIALS!" publish_url PUBLISH_URL

if "!API_KEY!"=="" (
  echo publish-site.bat: !CREDENTIALS! has no api_key. 1>&2
  exit /b 1
)
if "!PUBLISH_URL!"=="" (
  echo publish-site.bat: !CREDENTIALS! has no publish_url. It is written by the site. 1>&2
  exit /b 1
)

rem --- scratch ------------------------------------------------------------
if exist "!WORK!" rmdir /s /q "!WORK!"
mkdir "!WORK!" 2>nul
if errorlevel 1 (
  echo publish-site.bat: could not create !WORK! 1>&2
  exit /b 1
)

set "ARCHIVE=!WORK!\!CART_NAME!.zip"

rem --- build --------------------------------------------------------------
echo publish-site: packing !CART_DIR!

rem The archive is the cart directory itself, which the site accepts as well as
rem an archive containing one. The two names a desktop adds without being asked
rem are excluded by name rather than by a dot rule: a cart is allowed to have
rem files beginning with a dot.
powershell -NoProfile -Command ^
  "Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem;" ^
  "$root = (Resolve-Path '!CART_DIR!').Path;" ^
  "$base = Split-Path $root -Parent;" ^
  "$z = [IO.Compression.ZipFile]::Open('!ARCHIVE!', 'Create');" ^
  "Get-ChildItem -LiteralPath $root -Recurse -File |" ^
  "  Where-Object { $_.Name -ne '.DS_Store' -and $_.FullName -notmatch '__MACOSX' } |" ^
  "  ForEach-Object {" ^
  "    $rel = $_.FullName.Substring($base.Length + 1).Replace([char]92, '/');" ^
  "    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $_.FullName, $rel, 'Optimal') | Out-Null };" ^
  "$z.Dispose()" 1>&2
if errorlevel 1 (
  echo publish-site.bat: packing failed for !CART_DIR! 1>&2
  rmdir /s /q "!WORK!"
  exit /b 1
)

echo publish-site: !CART_NAME!.zip sent to !PUBLISH_URL!

if "!DRY_RUN!"=="1" (
  mkdir "%~dp0..\builds" 2>nul
  copy /y "!ARCHIVE!" "%~dp0..\builds\!CART_NAME!.zip" >nul
  echo publish-site: --dry-run, nothing sent
  echo publish-site: the archive it would have sent is at %~dp0..\builds\!CART_NAME!.zip
  rmdir /s /q "!WORK!"
  exit /b 0
)

rem --- send ---------------------------------------------------------------
set "RESPONSE=!WORK!\response.txt"
set "TITLE_ARG="
if not "!TITLE!"=="" set "TITLE_ARG=-F title=!TITLE!"

curl -sS -o "!RESPONSE!" -w "%%{http_code}" -X POST "!PUBLISH_URL!" ^
  -H "Authorization: Bearer !API_KEY!" ^
  -F "archive=@!ARCHIVE!;filename=!CART_NAME!.zip;type=application/zip" ^
  !TITLE_ARG! > "!WORK!\status.txt"
set "STATUS="
set /p STATUS=<"!WORK!\status.txt"

if "!STATUS!"=="201" goto created
if "!STATUS!"=="401" goto unauthorized
if "!STATUS!"=="422" goto refused
if "!STATUS!"=="400" goto refused
if "!STATUS!"=="503" goto unavailable

echo publish-site.bat: the site answered !STATUS! 1>&2
type "!RESPONSE!" 1>&2
rmdir /s /q "!WORK!"
exit /b 1

:created
call :json "!RESPONSE!" url URL
echo publish-site: !CART_NAME! arrived as a draft
if not "!URL!"=="" echo publish-site:   !URL!
echo publish-site: it is a draft under your account. Play it, then publish it there.
rmdir /s /q "!WORK!"
exit /b 0

:unauthorized
echo publish-site.bat: the site refused the key. 1>&2
echo publish-site.bat: keys are replaced every time you download your bundle, so 1>&2
echo publish-site.bat: the one in !CREDENTIALS! may be one that was retired. 1>&2
echo publish-site.bat: download the bundle again and unpack it over this console. 1>&2
rmdir /s /q "!WORK!"
exit /b 1

:refused
echo publish-site.bat: the site will not run !CART_NAME! as it stands. 1>&2
powershell -NoProfile -Command ^
  "(Get-Content -Raw '!RESPONSE!' | ConvertFrom-Json).problems | ForEach-Object { '    ' + $_ }" 1>&2
echo. 1>&2
rmdir /s /q "!WORK!"
exit /b 1

:unavailable
echo publish-site.bat: the site has no console library to pin a cart to. 1>&2
type "!RESPONSE!" 1>&2
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

:list
echo publish-site: carts that could be sent:
for /d %%D in ("!CARTS_DIR!\*") do (
  if exist "%%D\app\%%~nxD.rb" echo   %%~nxD
)
exit /b 0

:usage
echo usage: publish-site.bat ^<cart^> [--title=^<title^>] [--dry-run]
echo        publish-site.bat --list
echo        publish-site.bat --help
echo.
echo   ^<cart^>       a cart name ^(arcade^) or a path to one ^(carts\arcade^).
echo   --title=     the title to publish under.
echo   --dry-run    build the archive and check the key, send nothing.
echo   --list       list the carts this could send.
echo.
echo Needs dragonstation.json in the console root, from the download on the site.
exit /b 0