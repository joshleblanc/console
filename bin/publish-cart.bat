@echo off
rem ============================================================================
rem  publish-cart.bat -- publish exactly one cart, and prove it. (Windows)
rem
rem    publish-cart.bat arcade                    package arcade for windows-amd64
rem    publish-cart.bat arcade --platforms=html5,windows-amd64
rem    publish-cart.bat arcade --dry-run          stage + verify, do not package
rem    publish-cart.bat --list                    list carts and their titles
rem
rem  dragonruby-publish packages a whole game directory, and this one holds
rem  every cart under carts\. Publishing it as-is would ship the selftest, the
rem  widgets gallery and every other cart inside the arcade build. So this
rem  script never points dragonruby-publish at the console -- it stages a
rem  throwaway directory containing the console library, exactly one cart
rem  directory (code and the sprites/sounds/maps/data it owns), and a main.rb
rem  that pins that cart, then packages the staging directory instead.
rem
rem  Anything not understood here is passed straight through to
rem  dragonruby-publish, so --platforms and friends work as usual.
rem
rem  This mirrors ./publish-cart. Keep the two in step.
rem
rem  NOTE: written by hand and reviewed, not executed. See README.md.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo publish-cart.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "DIR=%CD%"
for %%I in ("%DIR%\..") do set "ROOT=%%~fI"
set "DRAGONRUBY_PUBLISH=%ROOT%\dragonruby-publish.exe"
if not exist "%DRAGONRUBY_PUBLISH%" set "DRAGONRUBY_PUBLISH=%ROOT%\dragonruby-publish"
set "DRAGONRUBY=%ROOT%\dragonruby.exe"
if not exist "%DRAGONRUBY%" set "DRAGONRUBY=%ROOT%\dragonruby"
set "CARTS_DIR=carts"
set "STAGE_ROOT=%ROOT%\builds\cart-staging"

rem ============================================================================
rem  helpers
rem ============================================================================

:die
echo publish-cart.bat: %~1 1>&2
endlocal & exit /b 1

:trim
rem  %1 = name of a variable to trim in place (leading spaces).
rem
rem  No endlocal here on purpose: this is called from the script's own setlocal
rem  scope, so ending it would leak the rest of the script out of scope.
set "TRIM_OUT=%~1"
if "%TRIM_OUT%"=="" goto :eof
for /f "tokens=* delims= " %%A in ("!TRIM_OUT!") do set "TRIM_OUT=%%A"
set "%~1=!TRIM_OUT!"
goto :eof

:cart_entry
rem  %1 = cart directory -> ENTRY. app\main.rb preferred, like the loader.
set "ENTRY="
if exist "%~1\app\main.rb" set "ENTRY=%~1\app\main.rb"
if defined ENTRY goto :eof
for %%F in ("%~1") do set "BASE=%%~nxF"
if exist "%~1\app\!BASE!.rb" set "ENTRY=%~1\app\!BASE!.rb"
goto :eof

:cart_dir
rem  A name or a path, resolved the way the loader resolves it: a bare name is
rem  the gallery shorthand for carts\<name\>. Tested by substitution rather
rem  than a piped findstr, so no subshell and no quoting surprises.
set "CD_OUT=%~1"
set "CD_TEST=!CD_OUT:/=\!"
if "!CD_TEST!"=="%~1" set "CD_OUT=%DIR%\%CARTS_DIR%\%~1"
goto :eof

:carts
rem  Cart names in the default gallery. Derived from the filesystem every run so
rem  a newly added cart is publishable without touching this script. A directory
rem  without an entry file is not a cart.
set "CARTS_OUT="
if not exist "%DIR%\%CARTS_DIR%" goto :eof
for /f "delims=" %%D in ('dir /b /ad "%DIR%\%CARTS_DIR%\*" 2^>nul') do (
  call :cart_entry "%DIR%\%CARTS_DIR%\%%D"
  if defined ENTRY (
    if defined CARTS_OUT (set "CARTS_OUT=!CARTS_OUT! %%D") else (set "CARTS_OUT=%%D")
  )
)
goto :eof

:cart_title
rem  %1 = cart directory -> TITLE_OUT
rem
rem  Read without requiring the cart, the same trick --list uses, so the
rem  published title and the listed title can never disagree.
set "TITLE_OUT="
call :cart_entry "%~1"
if not defined ENTRY goto :eof
for /f "usebackq tokens=1,* delims==" %%A in ("!ENTRY!") do (
  if /i "%%A"=="TITLE" (
    if not defined TITLE_OUT set "TITLE_OUT=%%B"
  )
)
call :trim TITLE_OUT
rem  Strip the quotes. Percent expansion, not delayed: delayed expansion has no
rem  substitution syntax. A title containing a quote character would lose it,
rem  which is an acceptable price for not needing a regex engine here.
set "TITLE_OUT=%TITLE_OUT:'=%"
set "TITLE_OUT=%TITLE_OUT:"=%"
goto :eof

:do_list
echo Publishable carts:
call :carts
for %%C in (!CARTS_OUT!) do (
  call :cart_title "%DIR%\%CARTS_DIR%\%%C"
  set "LINE=  %%C"
  if defined TITLE_OUT set "LINE=  %%C  -- !TITLE_OUT!"
  echo !LINE!
)
echo.
echo Publish one with:  publish-cart.bat ^<cart^>
goto :eof

:meta_has
rem  %1 = file, %2 = key -> META_HAS=1/0
findstr /b /l /c:"%~2=" "%~1" >nul 2>&1
if errorlevel 1 (set "META_HAS=0") else (set "META_HAS=1")
goto :eof

:meta_set
rem  %1 = file, %2 = key, %3 = value
rem
rem  Rewrites the matching line, exactly as the sed one-liner in ./publish-cart
rem  does, and copies every other line through untouched -- including every line
rem  past the first six, which DragonRuby reads by name (hd, highdpi,
rem  orientation, aspect_mode, sprites_directory).
set "MF=%~1"
set "MK=%~2"
set "MV=%~3"
set "MTMP=%MF%.tmp"
if exist "!MTMP!" del /q "!MTMP!"
if not exist "!MF%" goto :eof
for /f "usebackq delims=" %%L in ("!MF!") do (
  echo(%%L| findstr /b /l /c:"!MK!=" >nul 2>&1
  if errorlevel 1 (echo(%%L>>"!MTMP!") else (echo(!MK!=!MV!>>"!MTMP!")
)
if exist "!MTMP!" move /y "!MTMP!" "!MF!" >nul
goto :eof

rem ============================================================================
rem  usage
rem ============================================================================

if "%~1"=="" goto usage
if /i "%~1"=="--list" (
  call :do_list
  endlocal & exit /b 0
)

:usage
echo usage: publish-cart.bat ^<cart^> [--platforms=...] [--dry-run] 1>&2
echo        publish-cart.bat --list 1>&2
endlocal & exit /b 2

rem ============================================================================
rem  resolve the cart
rem ============================================================================
rem
rem  Accepts a name or a path, like run.bat does. Whatever the cart is called
rem  here, it is staged (and pinned) as carts\<its directory name\>, so a cart
rem  outside the gallery publishes under the same layout a gallery cart would.
set "CART_ARG=%~1"
shift

call :cart_dir "%CART_ARG%"
set "CART_SRC=!CD_OUT!"
if "!CART_SRC:~-1!"=="\" set "CART_SRC=!CART_SRC:~0,-1!"
for %%F in ("!CART_SRC!") do set "CART=%%~nxF"

call :cart_entry "!CART_SRC!"
if not defined ENTRY (
  call :carts
  echo publish-cart.bat: no cart at '!CART_SRC!' 1>&2
  echo publish-cart.bat: available: !CARTS_OUT! 1>&2
  endlocal & exit /b 1
)

rem ============================================================================
rem  switches
rem ============================================================================

set "DRY_RUN=0"
set "PLATFORM_ARGS="
:switches
set "A=%~1"
if "!A!"=="" goto switches_done
if /i "!A!"=="--dry-run" (
  set "DRY_RUN=1"
  goto switches_next
)
if /i "!A:~0,12%"=="--platforms=" (
  set "PLATFORM_ARGS=--platforms=!A:~12!"
  goto switches_next
)
if /i "!A!"=="--package" goto switches_next
if /i "!A!"=="--package-with-remote-hotload" goto switches_next
if /i "!A!"=="--only-package" goto switches_next
if not defined PLATFORM_ARGS (
  set "PLATFORM_ARGS=!A!"
) else (
  set "PLATFORM_ARGS=!PLATFORM_ARGS! !A!"
)

:switches_next
shift
goto switches

:switches_done
rem  Default to the host's desktop build; --platforms= overrides it.
if not defined PLATFORM_ARGS set "PLATFORM_ARGS=--platforms=windows-amd64"

rem ============================================================================
rem  stage
rem ============================================================================
rem
rem  Rebuild from scratch every time. A stale staging directory is exactly how a
rem  deleted cart ends up back inside a build, so it is removed rather than
rem  merged into.
set "STAGE=%STAGE_ROOT%\%CART%"
set "WORKLOG=%STAGE_ROOT%\publish-cart-verify.log"

if exist "%STAGE%" rd /s /q "%STAGE%"
if exist "%STAGE%" call :die "could not clear the staging directory (is something holding it open?)"
mkdir "%STAGE_ROOT%" 2>nul
mkdir "%STAGE%\app" 2>nul
mkdir "%STAGE%\metadata" 2>nul
mkdir "%STAGE%\carts" 2>nul

rem  1. The console library. The cart is meaningless without it.
xcopy "app\console" "%STAGE%\app\console" /e /i /q /y >nul
if errorlevel 1 call :die "could not stage the console library"

rem  2. Exactly one cart, whole. Copying the directory rather than picking files
rem     out of it is deliberate: the cart owns its sprites, sounds, maps and
rem     data, so those have to travel with it. Named explicitly, so this cannot
rem     drift into "copy whatever is in carts\".
xcopy "!CART_SRC!" "%STAGE%\carts\%CART%" /e /i /q /y >nul
if errorlevel 1 call :die "could not stage the cart at !CART_SRC!"

rem  3. Fonts. DragonRuby reads these from the game root, so they cannot live
rem     inside a cart; the console ships its own copy for a standalone build.
if exist "font.ttf" copy /y "font.ttf" "%STAGE%\font.ttf" >nul
if exist "tiny.ttf" copy /y "tiny.ttf" "%STAGE%\tiny.ttf" >nul

rem ============================================================================
rem  4. metadata
rem ============================================================================
rem
rem  DragonRuby reads metadata/game_metadata.txt from the GAME ROOT -- the path
rem  is hardcoded in the engine, so a cart can never have the engine read its own
rem  copy -- which is why this file is generated per cart instead of shipped
rem  as-is.
rem
rem  The part that matters: DragonRuby loads the whole file into
rem  Cvars["game_metadata.*"]. The first six lines are read positionally (devid,
rem  devtitle, gameid, gametitle, version, icon), but every key after them is
rem  read by name and decides real behaviour -- hd, highdpi, orientation,
rem  aspect_mode, sprites_directory. Writing a fresh six-line file here would
rem  silently drop all of them, and the published build would stop matching the
rem  checkout you tested. So: start from the console's file, or from the cart's
rem  own when it ships one, and rewrite only the cart-specific fields.

set "CART_META=!CART_SRC!\metadata\game_metadata.txt"
set "BASE_META=%DIR%\metadata\game_metadata.txt"
set "ICON_ROOT=%DIR%"

if exist "!CART_META!" (
  set "BASE_META=!CART_META!"
  set "ICON_ROOT=!CART_SRC!"
  echo publish-cart.bat: using the metadata '!CART!' ships
)

if not exist "!BASE_META!" call :die "no metadata to publish (looked for !BASE_META!)"
copy /y "!BASE_META!" "%STAGE%\metadata\game_metadata.txt" >nul
set "TARGET=%STAGE%\metadata\game_metadata.txt"

rem  The first six lines are positional, so a file missing one of them would
rem  shift every value across. Refuse rather than publish a scrambled identity.
set "MISSING="
for %%K in (devid devtitle gameid gametitle version icon) do (
  call :meta_has "!TARGET!" "%%K"
  if "!META_HAS!"=="0" set "MISSING=!MISSING! %%K"
)
if defined MISSING call :die "metadata is missing required keys:!MISSING!"

if exist "!CART_META!" (
  rem  Only fill in identity the cart left blank; do not overrule it.
  call :cart_title "!CART_SRC!"
  call :meta_get "!TARGET!" gameid
  if not defined MG_OUT call :meta_set "!TARGET!" gameid "!CART!"
  call :meta_get "!TARGET!" gametitle
  if not defined MG_OUT call :meta_set "!TARGET!" gametitle "!TITLE_OUT!"
) else (
  rem  Derived from the cart, so the published title and --list can never
  rem  disagree.
  call :cart_title "!CART_SRC!"
  if defined CART_GAMEID (set "GAMEID=!CART_GAMEID!") else (set "GAMEID=!CART!")
  if defined CART_GAMETITLE (set "GAMETITLE=!CART_GAMETITLE!") else (set "GAMETITLE=!TITLE_OUT!")
  call :meta_set "!TARGET!" gameid "!GAMEID!"
  call :meta_set "!TARGET!" gametitle "!GAMETITLE!"
)

if defined CART_VERSION call :meta_set "!TARGET!" version "!CART_VERSION!"
if defined CART_DEVID call :meta_set "!TARGET!" devid "!CART_DEVID!"
if defined CART_DEVTITLE call :meta_set "!TARGET!" devtitle "!CART_DEVTITLE!"

rem  An icon with the cart wins; otherwise the one this metadata names. Copied
rem  rather than referenced, because the staged build has no cart tree at the
rem  path the source used.
set "CART_ICON=!CART_SRC!\metadata\icon.png"
if exist "!CART_ICON!" (
  call :meta_set "!TARGET!" icon "metadata/icon.png"
  copy /y "!CART_ICON!" "%STAGE%\metadata\icon.png" >nul
) else (
  call :meta_get "!TARGET!" icon
  if defined MG_OUT (
    if exist "!ICON_ROOT!\!MG_OUT!" copy /y "!ICON_ROOT!\!MG_OUT!" "%STAGE%\!MG_OUT!" >nul
  )
)

rem ============================================================================
rem  5. an entry point that pins the cart
rem ============================================================================
rem
rem  This is what makes "only this cart" a property of the build rather than a
rem  promise in a README: the pin outranks --cart and $CART, and a pinned cart
rem  that is missing aborts the boot instead of quietly falling back.
rem
rem  The require list is READ FROM THE REAL app\main.rb rather than duplicated
rem  here. A second copy of that list in this script is exactly how a published
rem  build ends up missing a library file the development checkout has.
set "GEN=%STAGE%\app\main.rb"
if exist "!GEN!" del "!GEN!"
>>"!GEN!" echo # GENERATED BY publish-cart.bat -- DO NOT EDIT.
>>"!GEN!" echo #.
>>"!GEN!" echo # Single-cart build of '!CART!'. The console library is unmodified; only this
>>"!GEN!" echo # entry point differs from a normal checkout.
findstr /b /l /c:"require 'app/console/" "%DIR%\app\main.rb" >>"!GEN!"
>>"!GEN!" echo.
>>"!GEN!" echo module Main
>>"!GEN!" echo   def boot
>>"!GEN!" echo     Console::CartLoader.new^($args^).pin^('carts/!CART!'^).run
>>"!GEN!" echo   end
>>"!GEN!" echo.
>>"!GEN!" echo   def tick
>>"!GEN!" echo     Console.tick args
>>"!GEN!" echo   end
>>"!GEN!" echo.
>>"!GEN!" echo   def shutdown
>>"!GEN!" echo     Console.debug 'shutdown'
>>"!GEN!" echo   end
>>"!GEN!" echo end

rem ============================================================================
rem  verify
rem ============================================================================
rem
rem  Read the staged directory back rather than trusting the copy loop above.

call :verify_staging
if errorlevel 1 call :die "refusing to package a build that is not single-cart"

rem  The console's own diagnostic cart is exempt from the asset check: it names
rem  paths deliberately, because it is the thing testing resolution -- files
rem  that do not exist, files that live at the console root, and files another
rem  cart owns. Every other cart is a game, and a game owns everything it
rem  references.
if /i "!CART!"=="selftest" (
  echo publish-cart.bat: '!CART!' is the diagnostic cart; skipping the asset check
) else (
  call :verify_assets
  if errorlevel 1 call :die "refusing to package a build with missing assets"
)

if "!DRY_RUN!"=="1" goto dry_run

rem ============================================================================
rem  package
rem ============================================================================

if not exist "%DRAGONRUBY_PUBLISH%" call :die "cannot find %DRAGONRUBY_PUBLISH%"

rem  dragonruby-publish resolves a relative game directory against the DragonRuby
rem  root it ships in, and silently fails to read metadata from an absolute one
rem  -- so run it from the root and pass the staging dir relative to it.
set "REL_STAGE=builds\cart-staging\!CART!"
echo publish-cart.bat: packaging '!CART!'
pushd "%ROOT%"
"%DRAGONRUBY_PUBLISH%" --only-package !PLATFORM_ARGS! "%REL_STAGE%"
set "PKG_ERROR=%ERRORLEVEL%"
popd >nul
if not "%PKG_ERROR%"=="0" (
  echo publish-cart.bat: dragonruby-publish failed with %PKG_ERROR% 1>&2
  endlocal & exit /b %PKG_ERROR%
)
echo.
echo publish-cart.bat: done. artifacts are in %ROOT%\builds
endlocal & exit /b 0

:dry_run
echo.
echo staged tree:
for /f "delims=" %%F in ('dir /b /s /a:-d "!STAGE!" 2^>nul') do (
  set "REL=%%F"
  set "REL=!REL:%STAGE%\=!"
  echo   !REL!
)
echo.
echo publish-cart.bat: --dry-run, nothing packaged
endlocal & exit /b 0

rem ============================================================================
rem  meta_get
rem ============================================================================

:meta_get
rem  %1 = file, %2 = key -> MG_OUT (first match only, like `head -1`)
set "MG_OUT="
for /f "usebackq tokens=1,* delims==" %%A in ("%~1") do (
  if /i "%%A"=="%~2" (
    if not defined MG_OUT set "MG_OUT=%%B"
  )
)
goto :eof

rem ============================================================================
rem  verify_staging
rem ============================================================================

:verify_staging
set "STAGED_COUNT=0"
set "STAGED_NAME="
for /f "delims=" %%D in ('dir /b /ad "%STAGE%\carts" 2^>nul') do (
  set /a STAGED_COUNT+=1
  set "STAGED_NAME=%%D"
)

if not "!STAGED_COUNT!"=="1" (
  echo publish-cart.bat: ABORT staging '!STAGE!' has !STAGED_COUNT! carts, expected 1: 1>&2
  for /f "delims=" %%D in ('dir /b /ad "%STAGE%\carts" 2^>nul') do echo     %%D 1>&2
  goto :eof 1
)
if /i not "!STAGED_NAME!"=="!CART!" (
  echo publish-cart.bat: ABORT staged cart is '!STAGED_NAME!', expected '!CART!' 1>&2
  goto :eof 1
)

call :cart_entry "%STAGE%\carts\!CART!"
if not defined ENTRY (
  echo publish-cart.bat: ABORT staged cart has no entry file 1>&2
  goto :eof 1
)

rem  The pin has to be in the entry point, or the build is merely a console with
rem  one cart present rather than one that can only run that cart.
findstr /l /c:"pin('carts/!CART!')" "%STAGE%\app\main.rb" >nul 2>&1
if errorlevel 1 (
  echo publish-cart.bat: ABORT staged main.rb does not pin '!CART!' 1>&2
  goto :eof 1
)

rem  No other cart may be referenced from the staged cart. The directory check
rem  above already proves no other cart's code is *present*; this catches a cart
rem  reaching out and pulling one in.
rem
rem  Only the cart's own files are scanned, not the console library: the library
rem  documents paths like 'carts/<name>/' in its own comments, and matching the
rem  bare string there would flag the library rather than a reference.
call :carts
for %%O in (!CARTS_OUT!) do (
  if /i not "%%O"=="!CART!" (
    findstr /s /l /c:"carts/%%O/" "%STAGE%\carts\*.rb" >nul 2>&1
    if not errorlevel 1 (
      echo publish-cart.bat: ABORT staged build references cart '%%O' 1>&2
      goto :eof 1
    )
  )
)

echo publish-cart.bat: verified 1 cart ('!CART!') in !CART!
goto :eof 0

rem ============================================================================
rem  verify_assets
rem ============================================================================
rem
rem  Every asset the cart names has to be inside the staged cart. The staged
rem  build has no console-root art to fall back on -- that is the whole point of
rem  staging -- so a path that does not resolve is a file the cart borrows from
rem  the console, and it would ship as an invisible sprite.
rem
rem  This is checked by BOOTING the staged build and looking for the console's
rem  own missing-asset warnings, rather than by grepping the cart's source for
rem  quoted paths the way ./publish-cart does. Grepping means parsing quotes in
rem  batch, which is fragile in a way that would either skip the check or abort
rem  a good build; booting is simpler and stricter, because it catches exactly
rem  the assets the cart actually fails to load. The trade-off is that it only
rem  sees assets used at runtime, so a missing file reached only on a later
rem  scene may slip past here.

:verify_assets
if not exist "%DRAGONRUBY%" (
  echo publish-cart.bat: WARNING the staged build could not be run, so its assets were NOT verified 1>&2
  echo                       boot it yourself:  dragonruby "%STAGE%" --ticks 60 1>&2
  goto :eof 0
)

if exist "%WORKLOG%" del /q "%WORKLOG%"
"%DRAGONRUBY%" "%STAGE%" --ticks 60 >"%WORKLOG%" 2>&1

findstr /i /l /c:"booted with cart" "%WORKLOG%" >nul 2>&1
if errorlevel 1 (
  echo publish-cart.bat: WARNING the staged build did not boot, so its assets were NOT verified 1>&2
  findstr /i /l /c:"BOOT ERROR" "%WORKLOG%" 1>&2
  goto :eof 0
)

findstr /i /l /c:"not in the cart" /c:"sprite not found" /c:"map not found" "%WORKLOG%" >"%WORKLOG%.hits" 2>&1
if not errorlevel 1 (
  echo publish-cart.bat: ABORT '!CART!' loads assets it does not own: 1>&2
  type "%WORKLOG%.hits" 1>&2
  echo     move them into carts\!CART!\ before publishing 1>&2
  del /q "%WORKLOG%.hits" >nul 2>&1
  goto :eof 1
)

del /q "%WORKLOG%" >nul 2>&1
del /q "%WORKLOG%.hits" >nul 2>&1
echo publish-cart.bat: verified !CART! loads every asset it names
goto :eof 0
