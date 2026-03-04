import { readFile } from "node:fs/promises";

const wasmPath = process.argv[2] || "zig-out/bin/litholog-wasm.wasm";
const source = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(source, {});
const e = instance.exports;

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const input = encoder.encode("Firm CLAY");
const ptr = e.litholog_wasm_alloc(input.length);
new Uint8Array(e.memory.buffer, ptr, input.length).set(input);

const rc = e.litholog_wasm_parse(ptr, input.length);
e.litholog_wasm_free(ptr, input.length);
if (rc !== 0) {
    const err = decoder.decode(new Uint8Array(e.memory.buffer, e.litholog_wasm_error_ptr(), e.litholog_wasm_error_len()));
    throw new Error(`WASM parse failed: ${err}`);
}

const out = decoder.decode(new Uint8Array(e.memory.buffer, e.litholog_wasm_result_ptr(), e.litholog_wasm_result_len()));
const parsed = JSON.parse(out);
if (!parsed.material_type) {
    throw new Error("WASM smoke test failed: material_type missing");
}

console.log("WASM smoke test passed");
