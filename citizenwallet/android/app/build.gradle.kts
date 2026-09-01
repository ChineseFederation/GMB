plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.crcfrcn.citizenwallet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // TataConsole本机编译只从中央工作目录打包Rust库，产品仓库不得保留生成的jniLibs。
    System.getenv("TATA_CONSOLE_NATIVE_ANDROID_DIR")?.takeIf { it.isNotBlank() }?.let { nativeDir ->
        sourceSets.getByName("main").jniLibs.setSrcDirs(listOf(nativeDir))
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Google Play 永久应用标识与 Kotlin namespace 保持一致；与旧沙箱不兼容、不迁移。
        applicationId = "com.crcfrcn.citizenwallet"
        // local_auth 3.x 与新 SecureStorage 加固配置统一要求 API ≥ 24。
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // CitizenWallet Android 唯一支持 64 位 ARM；禁止恢复其他 ABI。
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // 所有环境只生成无私钥 Release 候选。正式 JKS 只存在 TataConsole 的
            // Data Protection Keychain，并由原生安全进程在 Touch ID 后通过匿名 stdin 使用。
            signingConfig = null
            // release 不加 keepDebugSymbols：APK 保持精简，也不把内部符号随包发出。
            // 线上崩溃的反解依赖构建时留档的未剥离产物
            // android/app/src/main/jniLibs/arm64-v8a/libcitizenwallet_signer.so
            // （Cargo 侧 strip=false 保证它始终带符号），剥离只发生在打包阶段。
        }
    }

    packaging {
        jniLibs {
            // 第三方插件可能携带非 ARM64 预编译库；打包阶段统一排除，确保 APK
            // 物理上只保留 defaultConfig 声明的 arm64-v8a。
            excludes.addAll(listOf("lib/armeabi*/**", "lib/x86/**", "lib/x86_64/**"))
        }
    }
}

flutter {
    source = "../.."
}
