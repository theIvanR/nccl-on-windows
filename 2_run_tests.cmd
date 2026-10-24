
@echo off
setlocal

REM Initialize Visual Studio build environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
if errorlevel 1 (
    echo Failed to initialize Visual Studio environment!
    exit /b 1
)

REM Paths relative to this script
set "SCRIPT_DIR=%~dp0"
set "LIB_DIR=%SCRIPT_DIR%nccl_all_arch"
set "EXE=%SCRIPT_DIR%nccl_smoke_test.exe"

REM Build
echo [1/3] Building smoke test...
nvcc -arch=sm_35 -I"%LIB_DIR%" "%SCRIPT_DIR%nccl_smoke_test.cu" -o "%EXE%"

if errorlevel 1 (
    echo Build failed!
    set "RESULT=1"
    goto cleanup
)

REM Test
echo.
echo [2/3] Running smoke test...

REM Make NCCL DLL discoverable
set "PATH=%LIB_DIR%;%PATH%"

"%EXE%"
set "RESULT=%ERRORLEVEL%"

REM Cleanup
:cleanup
echo.
echo [3/3] Cleaning generated files...

del /q "%EXE%" 2>nul
del /q "%SCRIPT_DIR%nccl_smoke_test.exp" 2>nul
del /q "%SCRIPT_DIR%nccl_smoke_test.lib" 2>nul

if not "%RESULT%"=="0" (
    echo Smoke test failed with exit code %RESULT%.
    exit /b %RESULT%
)

echo Smoke test passed!
exit /b 0
