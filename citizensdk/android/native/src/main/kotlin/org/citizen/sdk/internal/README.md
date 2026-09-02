# Private Android host boundary

This package is not public API. It owns exact request routing, verified assets,
separate no-backup SQLite stores, generation-scoped hardware KEKs and JNI. Raw
Core handles and Rust direct secret buffers must never escape this package.

