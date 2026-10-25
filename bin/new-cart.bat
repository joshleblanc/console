@echo off
rem ============================================================================
rem  new-cart.bat -- scaffold a new cart (Windows).
rem
rem    new-cart.bat <name>
rem    new-cart.bat --no-git <name>   skip the git repo
rem
rem  Creates carts\<name>\ with an app\main.rb skeleton and the empty asset
rem  directories the console looks for: sprites, sounds, maps and data, then
rem  makes the cart its own git repo with an initial commit -- carts\ is yours
rem  to version separately. The name becomes the cart directory and -- run
rem  through the same camel-case rule Console::Str.camel applies -- the class
rem  the entry file defines, so it must be a bare directory name: letters,
rem  digits, '-' and '_', starting with a letter.
rem
rem  This mirrors ./new-cart exactly. Keep the two in step.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo new-cart.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "NO_GIT=0"
set "GIT_DONE=0"
set "NAME="
:args
if "%~1"=="" goto args_done
if /i "%~1"=="-h" goto usage_ok
if /i "%~1"=="--help" goto usage_ok
if /i "%~1"=="--no-git" (
  set "NO_GIT=1"
  shift
  goto args
)
set "A=%~1"
if "!A:~0,1!"=="-" (
  echo new-cart.bat: unknown option: !A! 1>&2
  exit /b 1
)
if defined NAME (
  echo new-cart.bat: expected exactly one name 1>&2
  echo usage: new-cart.bat [--no-git] ^<name^> 1>&2
  exit /b 1
)
set "NAME=%~1"
shift
goto args
:args_done
if not defined NAME goto usage_err

rem  findstr's character ranges collate by locale rather than codepoint, so a
rem  [a-z] style class can match characters it should not. Spell the classes
rem  out instead.
echo(!NAME!| findstr /r /x "[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ][abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-]*" >nul
if errorlevel 1 (
  echo new-cart.bat: '!NAME!' is not a valid cart name 1>&2
  echo                letters, digits, '-' and '_', starting with a letter 1>&2
  exit /b 1
)

if exist "carts\!NAME!" (
  echo new-cart.bat: carts\!NAME! already exists 1>&2
  exit /b 1
)

if exist "samples\!NAME!" (
  echo new-cart.bat: warning: carts\!NAME! will shadow the '!NAME!' sample in the gallery 1>&2
)

rem  The class the loader expects is Console::Str.camel(name): split on '-'
rem  and '_', uppercase the first character of each part, join.
rem  app/console/str.rb.
set "CLASS="
set "UP=1"
set "REST=!NAME!"
:camel
if not defined REST goto camel_done
set "C=!REST:~0,1!"
set "REST=!REST:~1!"
if "!C!"=="-" (set "UP=1") else if "!C!"=="_" (set "UP=1") else (
  if "!UP!"=="1" (
    for %%U in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if /i "!C!"=="%%U" set "C=%%U"
    set "UP=0"
  )
  set "CLASS=!CLASS!!C!"
)
goto camel
:camel_done

set "CART=carts\!NAME!"
mkdir "!CART!\app" "!CART!\sprites" "!CART!\sounds" "!CART!\maps" "!CART!\data" 2>nul
if errorlevel 1 (
  echo new-cart.bat: could not create !CART! 1>&2
  exit /b 1
)

rem  echo writes CRLF line endings, so the generated main.rb is CRLF where the
rem  sh twin's is LF. mruby reads either.
set "MAIN=!CART!\app\main.rb"
>"!MAIN!" echo # Cart: !NAME!
>>"!MAIN!" echo #
>>"!MAIN!" echo #   ./bin/run !NAME!
>>"!MAIN!" echo #
>>"!MAIN!" echo # See "The cart contract" in the console README. Every hook is optional.
>>"!MAIN!" echo TITLE = '!NAME!'
>>"!MAIN!" echo.
>>"!MAIN!" echo class !CLASS!
>>"!MAIN!" echo   # Optional: short names for assets. Anything under this cart's own sprites/
>>"!MAIN!" echo   # is already reachable by name without this.
>>"!MAIN!" echo   def self.assets
>>"!MAIN!" echo     {}
>>"!MAIN!" echo   end
>>"!MAIN!" echo.
>>"!MAIN!" echo   # Called once, when the console boots.
>>"!MAIN!" echo   def setup
>>"!MAIN!" echo   end
>>"!MAIN!" echo.
>>"!MAIN!" echo   # Called every frame, unless the cart registers scenes.
>>"!MAIN!" echo   def update
>>"!MAIN!" echo   end
>>"!MAIN!" echo.
>>"!MAIN!" echo   # Called every frame, always last.
>>"!MAIN!" echo   def render
>>"!MAIN!" echo     draw.text TITLE, place: { x: 0.5, y: 0.5, anchor_x: 0.5, anchor_y: 0.5 },
>>"!MAIN!" echo               size_px: 40, color: :accent
>>"!MAIN!" echo   end
>>"!MAIN!" echo end

rem  Each cart is its own repository: carts\ is git-ignored by the console, so
rem  a nested repo is the way a cart gets versioned. The ignore and attributes
rem  files only exist when the repo does.
if "!NO_GIT!"=="1" goto git_done
where git >nul 2>&1
if errorlevel 1 (
  echo new-cart.bat: warning: git not found; skipped git init 1>&2
  goto git_done
)

set "GITIGNORE=!CART!\.gitignore"
>"!GITIGNORE!" echo .DS_Store
>>"!GITIGNORE!" echo Thumbs.db

set "GITATTR=!CART!\.gitattributes"
>"!GITATTR!" echo *.rb text eol=lf
>>"!GITATTR!" echo *.md text eol=lf
>>"!GITATTR!" echo *.json text eol=lf
>>"!GITATTR!" echo *.ldtk text eol=lf
>>"!GITATTR!" echo *.png binary
>>"!GITATTR!" echo *.ogg binary
>>"!GITATTR!" echo *.wav binary
>>"!GITATTR!" echo *.ttf binary

git -C "!CART!" init -q
if errorlevel 1 (
  echo new-cart.bat: warning: git init failed in !CART! 1>&2
  goto git_done
)
git -C "!CART!" add -A
git -C "!CART!" commit -q -m "Scaffold !NAME! cart"
if errorlevel 1 (
  echo new-cart.bat: warning: repo initialized but the initial commit failed ^(set user.name and user.email, then commit in !CART!^) 1>&2
  goto git_done
)
set "GIT_DONE=1"
:git_done

echo created !CART!
echo   !CART!\app\main.rb
echo   !CART!\sprites\
echo   !CART!\sounds\
echo   !CART!\maps\
echo   !CART!\data\
if exist "!CART!\.gitignore" (
  echo   !CART!\.gitignore
  echo   !CART!\.gitattributes
)
echo.
if "!GIT_DONE!"=="1" echo initialized git repo with initial commit
echo next: bin\run.bat !NAME!
endlocal & exit /b 0

:usage_ok
echo usage: new-cart.bat [--no-git] ^<name^>
echo.
echo   creates carts\^<name^>\ with an app\main.rb skeleton and empty
echo   sprites\, sounds\, maps\ and data\ directories, then makes it a
echo   git repo with an initial commit. --no-git skips the repo.
endlocal & exit /b 0

:usage_err
echo usage: new-cart.bat [--no-git] ^<name^> 1>&2
endlocal & exit /b 1
