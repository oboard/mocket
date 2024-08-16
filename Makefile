.DEFAULT_GOAL = build

# Define target directory and files
TARGET_DIR := ./target/app/node
WASM_TARGET := ./target/wasm/release/build/main/main.wasm
WASM_DEST := $(TARGET_DIR)/assets/app.wasm

# Default target
build: build_wasm copy_files

# Build WebAssembly
build_wasm:
	moon build --target=wasm

# Copy files
copy_files:
	@mkdir -p $(TARGET_DIR)
	@cp -rf ./src/node/ $(TARGET_DIR)/
	@cp $(WASM_TARGET) $(WASM_DEST)

# Start Node.js application
serve: build
	@cd $(TARGET_DIR) && npm install && npm start

# Clean build directory
clean:
	rm -rf ./target/
