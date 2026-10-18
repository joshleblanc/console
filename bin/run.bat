@echo off
rem ============================================================================
rem  run.bat -- run a cart on the console (Windows).
rem
rem    run.bat                       boot the default cart
rem    run.bat carts\hello           boot a cart by path
rem    run.bat hello                 ...or by name (shorthand for carts\hello)
rem    run.bat --cart hello          the explicit switch form
rem    run.bat --list                list available carts
rem    run.bat --hud                 start with the debug overlay on
rem
rem  A cart is identified by a path to its cart directory, and a bare name is
rem  shorthand for carts\<name>. Any cart directory works -- games\space,
rem  demos\space, carts\space -- as long as it sits inside this console, because
rem  DragonRuby resolves asset paths relative to the game directory.
rem
rem  The positional form is translated here rather than handled in the runtime.
rem  DragonRuby parses argv by splitting on ' --', so a bare argument before the
rem  first switch gets folded into the game directory it thinks you asked for,
rem  and '--cart=x' arrives as one symbol key named "cart=x". Rewriting both into
rem  the '--cart x' form keeps the ergonomics and never reaches the engine as
rem  anything it cannot parse.
rem
rem  This mirrors ./run exactly. Keep the two in step.
rem ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if errorlevel 1 (
  echo run.bat: could not enter %~dp0.. 1>&2
  exit /b 1
)

set "GAMEDIR=%CD%"
set "DRAGONRUBY=%CD%\..\dragonruby.exe"
if not exist "%DRAGONRUBY%" set "DRAGONRUBY=%CD%\..\dragonruby"
if not exist "%DRAGONRUBY%" (
  echo run.bat: cannot find dragonruby next to the console 1>&2
  echo          expected %CD%\..\dragonruby.exe 1>&2
  exit /b 1
)

set "CART="
set "REST="
set "HAVE_SWITCH=0"

rem -- Collect every argument once. A bare argument is shorthand for --cart;
rem an explicit --cart wins, so `run.bat --cart foo foo` is left as the author
rem meant it rather than being doubled up.
:collect
if "%~1"=="" goto collected
set "A=%~1"
set "HEAD=!A:~0,1!"
if "%HEAD%"=="-" goto keep
rem -- The FIRST bare argument is the cart. Every LATER bare argument is the
rem -- VALUE of the switch before it, and must be carried through: dropping it
rem -- turns `--ticks 90` into a bare `--ticks`, which the engine reads as
rem -- "run forever" rather than "run 90 frames".
if defined CART (
  set "REST=!REST! !A!"
) else (
  set "CART=!A!"
)
goto next

:keep
if /i "!A!"=="--cart" set "HAVE_SWITCH=1"
rem -- --cart=value  ->  --cart value, because the engine cannot parse the '=' form.
rem --
rem -- No inner quotes when accumulating REST. cmd's set "v=..." strips only the
rem -- OUTERMOST quotes, so a nested " would survive into the value as a literal
rem -- character. REST is then splatted unquoted on the launch line, and the
rem -- engine receives an argument like "--ticks" with the quotes still attached
rem -- and silently ignores it -- which looks exactly like "the switch was
rem -- dropped". Quotes here buy nothing, because the engine re-splits argv anyway.
if /i "!A:~0,7!"=="--cart=" (
  set "REST=!REST! --cart !A:~7!"
  goto next
)
set "REST=!REST! !A!"

:next
shift
goto collect

:collected
if not defined CART goto launch_plain
if not "%HAVE_SWITCH%"=="0" goto launch_plain
"%DRAGONRUBY%" "%GAMEDIR%" --cart "!CART!" !REST!
goto done

:launch_plain
rem -- HAVE_SWITCH means an explicit --cart was given, but its VALUE arrives as
rem -- the next bare argument and lands in CART, so CART still has to be emitted
rem -- here. Without this, `--cart carts\foo` reaches the engine as a bare
rem -- `--cart` and the console silently falls back to another cart.
if defined CART (
  "%DRAGONRUBY%" "%GAMEDIR%" --cart "!CART!" !REST!
) else (
  "%DRAGONRUBY%" "%GAMEDIR%" !REST!
)

:done
endlocal & exit /b %ERRORLEVEL%
