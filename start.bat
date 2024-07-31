@echo off
REM Start the Moon build process for WebAssembly target
moon build --target=wasm

REM Create the target directory for the application
mkdir ./target/app/node

REM Copy the entire node directory to the target directory
xcopy /E /I ./node ./target/app/node

REM Copy the compiled WebAssembly file to the target directory
copy ./target/wasm/release/build/main/main.wasm ./target/app/node/assets/app.wasm

REM Change the current directory to the target application directory
cd ./target/app/node

REM Install the Node.js dependencies
npm install

REM Start the application
npm start

REM Exit the batch script
exit