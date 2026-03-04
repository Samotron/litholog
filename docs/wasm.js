const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export class LithologWasm {
    constructor(instance) {
        this.instance = instance;
        this.exports = instance.exports;
    }

    static async init(wasmUrl = "./litholog.wasm") {
        const { instance } = await WebAssembly.instantiateStreaming(fetch(wasmUrl), {});
        return new LithologWasm(instance);
    }

    readString(ptr, len) {
        if (!ptr || !len) return "";
        const bytes = new Uint8Array(this.exports.memory.buffer, ptr, len);
        return textDecoder.decode(bytes);
    }

    withInputString(value) {
        const encoded = textEncoder.encode(value);
        const ptr = this.exports.litholog_wasm_alloc(encoded.length);
        if (!ptr) throw new Error("WASM allocation failed");
        new Uint8Array(this.exports.memory.buffer, ptr, encoded.length).set(encoded);
        return {
            ptr,
            len: encoded.length,
            free: () => this.exports.litholog_wasm_free(ptr, encoded.length),
        };
    }

    parse(description) {
        const input = this.withInputString(description);
        try {
            const rc = this.exports.litholog_wasm_parse(input.ptr, input.len);
            if (rc !== 0) {
                const err = this.readString(
                    this.exports.litholog_wasm_error_ptr(),
                    this.exports.litholog_wasm_error_len(),
                );
                throw new Error(err || "Parse failed");
            }
            const json = this.readString(
                this.exports.litholog_wasm_result_ptr(),
                this.exports.litholog_wasm_result_len(),
            );
            return JSON.parse(json);
        } finally {
            input.free();
        }
    }
}
