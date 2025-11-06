// ===========================
// Project-level build.gradle.kts
// ===========================

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Android Gradle plugin terbaru
        classpath("com.android.tools.build:gradle:8.1.1")

        // Kotlin plugin terbaru stabil (2.1) untuk Firebase & Google Play Services
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")

        // Google Services plugin
        classpath("com.google.gms:google-services:4.3.15")
    }
}

// ===========================
// Repositories global
// ===========================
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ===========================
// Build directory custom (opsional)
// ===========================
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// ===========================
// Task clean
// ===========================
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ===========================
// Plugins (opsional untuk project-level)
// ===========================
plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}
