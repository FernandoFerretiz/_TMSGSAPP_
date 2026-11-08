import java.util.Base64
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// --dart-define=ENV=staging: otro applicationId y otro nombre para poder instalarlo
// junto con la app de producción. Flutter pasa los dart-defines a Gradle codificados
// en base64 (KEY=VALUE separados por coma).
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String? ?: "")
    .split(",")
    .filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it)) }
    .filter { it.contains("=") }
    .associate { it.substringBefore("=") to it.substringAfter("=") }
val isStagingBuild = dartDefines["ENV"] == "staging"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sultanx.tms"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sultanx.tms"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        resValues = true
    }

    flavorDimensions += "role"
    productFlavors {
        create("operators") {
            dimension = "role"
            resValue("string", "app_name", "SultánX TMS Operadores")
        }
        create("staff") {
            dimension = "role"
            applicationIdSuffix = ".staff"
            resValue("string", "app_name", "SultánX TMS Staff")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            if (isStagingBuild) {
                applicationIdSuffix = ".staging"
                resValue("string", "app_name", "SultánX TMS (Staging)")
            }
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            if (isStagingBuild) {
                applicationIdSuffix = ".staging"
                resValue("string", "app_name", "SultánX TMS (Staging)")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
