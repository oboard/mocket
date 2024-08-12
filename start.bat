@echo off
REM Start the Moon build process for WebAssembly target
moon build --target=wasm

REM Check if the build was successful before proceeding
if %ERRORLEVEL% neq 0 (
    echo Build failed.
    exit /b %ERRORLEVEL%
)

REM Create the target directory for the application if it doesn't exist
if not exist ".\target\app\node" (
    mkdir ".\target\app\node"
)

REM Copy the entire node directory to the target directory
xcopy /E /I ".\src\node" ".\target\app\node"

REM Check if xcopy was successful
if %ERRORLEVEL% neq 0 (
    echo Failed to copy node directory.
    exit /b %ERRORLEVEL%
)

REM Copy the compiled WebAssembly file to the target directory
copy ".\target\wasm\release\build\main\main.wasm" ".\target\app\node\assets\app.wasm"

REM Check if the copy was successful
if %ERRORLEVEL% neq 0 (
    echo Failed to copy WebAssembly file.
    exit /b %ERRORLEVEL%
)

REM Change the current directory to the target application directory
cd /d ".\target\app\node"

REM Install the Node.js dependencies
npm install

REM Check if npm install was successful
if %ERRORLEVEL% neq 0 (
    echo Failed to install Node.js dependencies.
    exit /b %ERRORLEVEL%
)

REM Start the application
npm start

REM Check if npm start was successful
if %ERRORLEVEL% neq 0 (
    echo Failed to start the application.
    exit /b %ERRORLEVEL%
)

REM Exit the batch script
exit /b
