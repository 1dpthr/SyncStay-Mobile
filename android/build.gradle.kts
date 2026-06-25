allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter expects APK under project-root/build/app/outputs/flutter-apk/
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.core:core:1.15.0")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.activity:activity:1.9.3")
            force("androidx.browser:browser:1.8.0")
        }
    }
}

rootProject.extra.set("compileSdkVersion", 36)
rootProject.extra.set("minSdkVersion", 21)
rootProject.extra.set("targetSdkVersion", 36)

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
