
extern crate cc;
fn main() {
    println!("cargo:rerun-if-changed=src/c/relay.c");
    println!("cargo:rerun-if-changed=src/c/absdUser.c");
    println!("cargo:rustc-link-lib=dylib=MobileGestalt");
    println!("cargo:rustc-link-lib=framework=CoreFoundation");

    let clang = std::env::var("CC_armv7s_apple_ios")
        .unwrap_or_else(|_| "/opt/theos/toolchain/linux/iphone/bin/clang".to_string());
    let ar = std::env::var("AR_armv7s_apple_ios")
        .unwrap_or_else(|_| "/opt/theos/toolchain/linux/iphone/bin/ar".to_string());

    cc::Build::new()
        .compiler(clang)
        .archiver(ar)
        .file("src/c/relay.c")
        .file("src/c/absdUser.c")
        .compile("relay");
}