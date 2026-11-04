#!/usr/bin/env python3
"""Adds what online play needs to a working copy, none of which is kept in the repository:
the Epic plugin's compiled files, the keys, and, for Android, the changes to the Gradle template.

    python3 tools/setup_epic.py path/to/addons/epic-online-services-godot [platforms]

platforms is any of android, ios and linux, separated by commas. The default is android,linux.
The keys come from the environment (EPIC_PRODUCT_ID, EPIC_SANDBOX_ID, EPIC_DEPLOYMENT_ID, EPIC_CLIENT_ID,
EPIC_CLIENT_SECRET) or from keys/epic.env. Run from the project root. For Android, install the build
template first: godot --headless --path . --install-android-build-template --export-release Android build/first.apk"""
import os, shutil, sys

DEST = "addons/epic-online-services-godot"
NAMES = {"PRODUCT_ID": "EPIC_PRODUCT_ID", "SANDBOX_ID": "EPIC_SANDBOX_ID", "DEPLOYMENT_ID": "EPIC_DEPLOYMENT_ID",
         "CLIENT_ID": "EPIC_CLIENT_ID", "CLIENT_SECRET": "EPIC_CLIENT_SECRET"}


def keys():
    values = dict(os.environ)
    if os.path.exists("keys/epic.env"):
        for line in open("keys/epic.env"):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                values.setdefault(k, v)
    return {const: values.get(env, "") for const, env in NAMES.items()}


def copy_plugin(source, platforms):
    os.makedirs(DEST + "/bin", exist_ok=True)
    shutil.copy(source + "/eosg.gdextension", DEST)
    for platform in platforms:
        target = DEST + "/bin/" + platform
        shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(source + "/bin/" + platform, target)
    # Godot should not try to import what is only there to be packaged.
    open(DEST + "/.gitignore", "w").write("*\n")


def write_keys(k):
    if not all(k.values()):
        print("Epic keys are missing: this build will have no online play")
        if os.path.exists("scripts/epic_keys.gd"):
            os.remove("scripts/epic_keys.gd")
        return
    with open("scripts/epic_keys.gd", "w") as f:
        f.write("extends RefCounted\n## Written by tools/setup_epic.py. Not in the repository.\n\n")
        for name, value in k.items():
            f.write('const %s := "%s"\n' % (name, value))


def once(text, marker, old, new, path):
    if marker in text:
        return text
    if old not in text:
        sys.exit("%s has changed: cannot find %r" % (path, old[:50]))
    return text.replace(old, new, 1)


def android(client_id):
    path = "android/build/build.gradle"
    s = open(path).read()
    fragment = 'implementation "androidx.fragment:fragment:$versions.fragmentVersion"\n'
    s = once(s, "eossdk-StaticSTDC", fragment, fragment + """
    // Epic Online Services
    implementation 'androidx.appcompat:appcompat:1.5.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'androidx.security:security-crypto:1.0.0'
    implementation 'androidx.browser:browser:1.4.0'
    implementation 'androidx.webkit:webkit:1.7.0'
    implementation files('../../addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar')

""", path)
    s = once(s, "coreLibraryDesugaring ", fragment, fragment + "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'\n", path)
    s = once(s, "coreLibraryDesugaringEnabled", "compileOptions {\n", "compileOptions {\n        coreLibraryDesugaringEnabled true\n", path)
    s = once(s, "eos_login_protocol_scheme", "missingDimensionStrategy 'products', 'template'\n", """missingDimensionStrategy 'products', 'template'

        resValue("string", "eos_login_protocol_scheme", "eos.%s")
""" % client_id.lower(), path)
    open(path, "w").write(s)
    path = "android/build/src/main/java/com/godot/game/GodotApp.java"
    s = open(path).read()
    s = once(s, "mobile.eossdk.EOSSDK", "import org.godotengine.godot.Godot;\n", "import com.epicgames.mobile.eossdk.EOSSDK;\nimport org.godotengine.godot.Godot;\n", path)
    s = once(s, 'loadLibrary("EOSSDK")', "public class GodotApp extends GodotActivity {\n\tstatic {\n", 'public class GodotApp extends GodotActivity {\n\tstatic {\n\t\tSystem.loadLibrary("EOSSDK");\n', path)
    s = once(s, "EOSSDK.init", "public void onCreate(Bundle savedInstanceState) {\n", "public void onCreate(Bundle savedInstanceState) {\n\t\tEOSSDK.init(this);\n", path)
    open(path, "w").write(s)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    platforms = (sys.argv[2] if len(sys.argv) > 2 else "android,linux").split(",")
    copy_plugin(sys.argv[1].rstrip("/"), platforms)
    k = keys()
    write_keys(k)
    if "android" in platforms and os.path.exists("android/build/build.gradle"):
        android(k["CLIENT_ID"])
    print("Epic set up for", ", ".join(platforms))


if __name__ == "__main__":
    main()
