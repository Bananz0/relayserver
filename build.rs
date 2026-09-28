
extern crate cc;
fn main() {
    println!("cargo:rerun-if-changed=src/c/relay.c");
    println!("cargo:rerun-if-changed=src/c/absdUser.c");
    let target = std::env::var("TARGET").unwrap_or_default();
    let is_ios = target.contains("apple-ios");

    if is_ios {
        println!("cargo:rustc-link-lib=dylib=MobileGestalt");
        println!("cargo:rustc-link-lib=framework=CoreFoundation");

        let mut build = cc::Build::new();
        build.file("src/c/relay.c");
        build.file("src/c/absdUser.c");

        if let Ok(clang) = std::env::var(format!("CC_{}", target.replace('-', "_"))) {
            build.compiler(clang);
        } else if let Ok(clang) = std::env::var("CC") {
            build.compiler(clang);
        } else if target == "armv7s-apple-ios" && std::path::Path::new("/opt/theos/toolchain/linux/iphone/bin/clang").exists() {
            build.compiler("/opt/theos/toolchain/linux/iphone/bin/clang");
        }

        if let Ok(ar) = std::env::var(format!("AR_{}", target.replace('-', "_"))) {
            build.archiver(ar);
        } else if let Ok(ar) = std::env::var("AR") {
            build.archiver(ar);
        } else if target == "armv7s-apple-ios" && std::path::Path::new("/opt/theos/toolchain/linux/iphone/bin/ar").exists() {
            build.archiver("/opt/theos/toolchain/linux/iphone/bin/ar");
        }

        build.compile("relay");
    }
}