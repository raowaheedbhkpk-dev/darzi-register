"""Makes Gradle sign the release APK with our own key (instead of re-signing afterwards,
which breaks native-library alignment and makes Android refuse to install)."""
import os
import sys

ks = os.environ["KS_PATH"]
kts = "android/app/build.gradle.kts"
groovy = "android/app/build.gradle"

if os.path.exists(kts):
    path = kts
    block = f'''    signingConfigs {{
        create("darzi") {{
            storeFile = file("{ks}")
            storePassword = System.getenv("KEYSTORE_PASS")
            keyAlias = "darzi"
            keyPassword = System.getenv("KEYSTORE_PASS")
            storeType = "pkcs12"
        }}
    }}

'''
    use_old = 'signingConfig = signingConfigs.getByName("debug")'
    use_new = 'signingConfig = signingConfigs.getByName("darzi")'
else:
    path = groovy
    block = f'''    signingConfigs {{
        darzi {{
            storeFile file("{ks}")
            storePassword System.getenv("KEYSTORE_PASS")
            keyAlias "darzi"
            keyPassword System.getenv("KEYSTORE_PASS")
            storeType "pkcs12"
        }}
    }}

'''
    use_old = "signingConfig signingConfigs.debug"
    use_new = "signingConfig signingConfigs.darzi"

s = open(path).read()
if "buildTypes {" not in s or use_old not in s:
    print("build file shape not recognised:\n" + s)
    sys.exit(1)
s = s.replace("    buildTypes {", block + "    buildTypes {", 1)
s = s.replace(use_old, use_new)
open(path, "w").write(s)
print("Release signing set in", path)
