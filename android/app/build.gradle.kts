import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val auth0Domain: String = localProperties.getProperty("auth0Domain") ?: "we-buddhist-prod.us.auth0.com"
val auth0Scheme: String = localProperties.getProperty("auth0Scheme") ?: "org.pecha.app"
    
android {
    namespace = "org.pecha.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.pecha.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders.putAll(
            mapOf(
                "auth0Domain" to auth0Domain,
                "auth0Scheme" to auth0Scheme
            )
        )
    }

    signingConfigs {
        fun createSigningConfig(flavor: String) {
            create("${flavor}Release") {
                keyAlias = keystoreProperties["${flavor}.keyAlias"]?.toString()
                keyPassword = keystoreProperties["${flavor}.keyPassword"]?.toString()
                storeFile = keystoreProperties["${flavor}.storeFile"]?.toString()?.let { file(it) }
                storePassword = keystoreProperties["${flavor}.storePassword"]?.toString()
            }
        }

        createSigningConfig("dev")
        createSigningConfig("staging")
        createSigningConfig("prod")
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "org.pecha.app.dev"
            resValue("string", "app_name", "[Dev] WeBuddhist")
            versionNameSuffix = "-dev"
            signingConfig = signingConfigs.getByName("devRelease")
        }

        create("staging") {
            dimension = "environment"
            applicationId = "org.pecha.app.staging"
            resValue("string", "app_name", "[Stage] WeBuddhist")
            versionNameSuffix = "-staging"
            signingConfig = signingConfigs.getByName("stagingRelease")
        }

        create("prod") {
            dimension = "environment"
            applicationId = "org.pecha.app"
            resValue("string", "app_name", "WeBuddhist")
            signingConfig = signingConfigs.getByName("prodRelease")
        }
    }

    buildTypes {
        getByName("release") {
            // Enable ProGuard for release builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
