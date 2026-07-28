// 1. 파일 최상단에 이 블록을 추가하세요
plugins {
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false    
    // [추가] 구글 로그인 서비스 플러그인
    id("com.google.gms.google-services") version "4.4.4" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // 네이버 지도 SDK — com.naver.* 아티팩트만 여기서 찾는다.
        // content 필터가 없으면 Gradle이 io.flutter 같은 무관한 그룹까지 이 저장소에
        // 물어보다가, 저장소가 느리거나 막히면 연결 타임아웃으로 빌드 전체가 실패한다.
        // (실제로 CI에서 io.flutter:*_debug 해석이 여기서 타임아웃 나며 빌드가 깨졌다)
        maven {
            url = uri("https://repository.map.naver.com/archive/maven")
            content { includeGroupByRegex("com\\.naver.*") }
        }
    }
}

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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
