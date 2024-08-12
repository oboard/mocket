!/bin/bash

moon build --target=wasm
mkdir -p ./target/app/node
cp -rf ./src/node/ ./target/app/node/
cp ./target/wasm/release/build/main/main.wasm ./target/app/node/assets/app.wasm
cd ./target/app/node/
npm install
npm start