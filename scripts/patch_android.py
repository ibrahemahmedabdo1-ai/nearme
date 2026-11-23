#!/usr/bin/env python3
"""Idempotent patch of the Flutter-generated Android project. Prints WARN for any pattern it cannot find so you can apply it by hand."""
import re, sys, pathlib
gradle, app_id, label, app = sys.argv[1:5]
p = pathlib.Path(gradle); s = p.read_text(); kts = gradle.endswith(".kts")
def sub(pattern, repl, text, what):
    new, n = re.subn(pattern, repl, text, count=1)
    if n == 0: print(f"WARN: could not patch {what} in {gradle}; set it manually (see docs/ANDROID_SIGNING.md)")
    return new
s = sub(r"compileSdk(Version)?\s*=?\s*[^\n]+", "compileSdk = 36", s, "compileSdk")
s = sub(r"targetSdk(Version)?\s*=?\s*[^\n]+", "targetSdk = 36", s, "targetSdk")
s = sub(r"minSdk(Version)?\s*=?\s*[^\n]+", "minSdk = 26", s, "minSdk")
s = sub(r'applicationId\s*=?\s*"[^"]+"', f'applicationId = "{app_id}"', s, "applicationId")
if "key.properties" not in s:
    header = '''import java.util.Properties
import java.io.FileInputStream
val keystoreProps = Properties().apply { val f = rootProject.file("key.properties"); if (f.exists()) load(FileInputStream(f)) }
''' if kts else ""
    signing = '''
    signingConfigs {
        create("release") {
            if (keystoreProps.getProperty("storeFile") != null) {
                storeFile = file(keystoreProps.getProperty("storeFile")); storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias"); keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }
''' if kts else ""
    if kts:
        s = header + s
        s = s.replace("android {", "android {" + signing, 1)
        s = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("release")\n            isMinifyEnabled = true\n            isShrinkResources = true\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', s)
    else:
        print("WARN: Groovy gradle detected; add signing manually per docs/ANDROID_SIGNING.md")
# Keep debug APK builds lean; native symbol bundles are configured only for signed release builds.
p.write_text(s)
base = p.parent.parent  # android/app -> android
(p.parent / "proguard-rules.pro").write_text("-keep class io.flutter.** { *; }\n-dontwarn com.google.android.play.core.**\n")
man = p.parent / "src/main/AndroidManifest.xml"
if man.exists():
    m = man.read_text()
    m = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', m, count=1)
    if "android:allowBackup" not in m: m = m.replace("<application", '<application android:allowBackup="false"', 1)
    perms = ['<uses-permission android:name="android.permission.INTERNET"/>']
    if app == "customer":
        perms += ['<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>', '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>', '<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>']
    for perm in perms:
        if perm not in m: m = m.replace("<application", perm + "\n    <application", 1)
    if app == "customer" and "com.google.android.gms.ads.APPLICATION_ID" not in m:
        m = m.replace("</application>", '    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-3940256099942544~3347511713"/>  <!-- Google TEST app id: replace with YOUR AdMob app id before release -->\n    </application>', 1)
    man.write_text(m)
# FLAG_SECURE (screenshot/screen-recording protection) for customer app
if app == "customer":
    for f in (p.parent / "src/main").rglob("MainActivity.kt"):
        t = f.read_text()
        if "FLAG_SECURE" not in t:
            t = t.replace("import io.flutter.embedding.android.FlutterActivity", "import android.os.Bundle\nimport android.view.WindowManager\nimport io.flutter.embedding.android.FlutterActivity")
            t = re.sub(r"class MainActivity\s*:\s*FlutterActivity\(\)\s*\{?\s*\}?", "class MainActivity : FlutterActivity() {\n    override fun onCreate(savedInstanceState: Bundle?) {\n        super.onCreate(savedInstanceState)\n        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)\n    }\n}", t)
            f.write_text(t)
print(f"patched {app}")
