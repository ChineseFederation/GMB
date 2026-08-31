fn main() {
    let protocol = "../../chatsdk/lib/src/protocol";
    println!("cargo:rerun-if-changed={protocol}/message.proto");
    println!("cargo:rerun-if-changed={protocol}/attachment.proto");
    println!("cargo:rerun-if-changed={protocol}/chat_frame.proto");
    prost_build::Config::new()
        .compile_protos(
            &[
                format!("{protocol}/message.proto"),
                format!("{protocol}/attachment.proto"),
                format!("{protocol}/chat_frame.proto"),
            ],
            &[protocol],
        )
        .expect("compile the canonical chat protocol");
}
