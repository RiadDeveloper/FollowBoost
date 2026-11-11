pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

// This VM's Gradle downloads stall on .module files fetched directly from
// Maven Central through the egress MITM proxy (Java read timeout), while
// the local caching proxy on 127.0.0.1:18080 serves the same files fine
// (it downloads them with curl). The Flutter plugin loader puts
// google()/mavenCentral() first in the repository chain, so a stalled
// Maven Central request aborts resolution before the local proxy is ever
// tried. Declaring the local proxy here puts it first for this project.
// PREFER_SETTINGS: ignore the project repositories the Flutter plugin
// adds (google()/mavenCentral()/flutter.io) and use only the settings
// repositories below. Gradle's Java HTTP client stalls on direct downloads
// from Maven Central through the egress MITM proxy, while the local caching
// proxy on 127.0.0.1:18080 (which mirrors Central + Google + flutter.io
// via curl) serves the same artifacts fine.
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri("http://127.0.0.1:18080/maven2") }
        maven { url = uri("http://127.0.0.1:18080/m2") }
    }
}

include(":app")
