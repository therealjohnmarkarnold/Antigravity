import os
import sys

def main():
    print("🔧 Configuring Android Signing...")

    android_dir = "android"
    app_dir = os.path.join(android_dir, "app")
    build_gradle_path = os.path.join(app_dir, "build.gradle")
    key_properties_path = os.path.join(android_dir, "key.properties")

    if not os.path.exists(build_gradle_path):
        print(f"❌ Could not find {build_gradle_path}. Make sure 'flutter create .' has run.")
        sys.exit(1)

    # 1. Create key.properties if missing
    if not os.path.exists(key_properties_path):
        print("📄 Creating key.properties with default values...")
        with open(key_properties_path, "w") as f:
            f.write("storePassword=android\n")
            f.write("keyPassword=android\n")
            f.write("keyAlias=upload\n")
            f.write("storeFile=upload-keystore.jks\n")
        print("⚠️  Created key.properties. Please verify values match your keystore!")
    else:
        print("✅ key.properties exists.")

    # 2. Patch build.gradle
    with open(build_gradle_path, "r") as f:
        content = f.read()

    # Check if already patched
    if "keystoreProperties.load" in content:
        print("✅ build.gradle seems to be already configured for signing.")
        return

    print("📝 Patching build.gradle...")

    # A. Add Properties loading at start
    # We look for "plugins {" or "apply plugin:"? Newer flutter uses "plugins".
    # Safest is to insert before "android {"
    
    properties_block = """
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""
    
    if "def keystoreProperties" not in content:
        if "android {" in content:
            content = content.replace("android {", properties_block + "android {", 1)
        else:
            print("❌ Could not find 'android {' block in build.gradle")
            sys.exit(1)

    # B. Add signingConfigs
    signing_config_block = """
    signingConfigs {
        release {
            keyAlias = keystoreProperties['keyAlias']
            keyPassword = keystoreProperties['keyPassword']
            storeFile = keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword = keystoreProperties['storePassword']
        }
    }
"""
    
    if "signingConfigs {" not in content:
        # Insert inside "android {"
        # We can insert it at the start of android block
        content = content.replace("android {", "android {" + signing_config_block, 1)

    # C. Update buildTypes
    # Look for "signingConfig signingConfigs.debug" and replace/add
    if "signingConfig signingConfigs.debug" in content:
        content = content.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
    elif "buildTypes {" in content:
        print("⚠️  Could not find debug signing config to replace. Ensuring release config uses correct signing...")
        # This is trickier if it's missing, but standard flutter template has it.
        # We'll trust the replacement above covers the standard case.
    
    with open(build_gradle_path, "w") as f:
        f.write(content)
    
    print("✅ build.gradle patched successfully.")

    # 3. Check for Keystore
    keystore_path = os.path.join(app_dir, "upload-keystore.jks")
    if not os.path.exists(keystore_path):
        print(f"⚠️  Keystore file not found at {keystore_path}")
        print("   Run the following to generate one (password: android):")
        print(f"   keytool -genkey -v -keystore {keystore_path} -storepass android -alias upload -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname \"CN=Android Debug,O=Android,C=US\"")

if __name__ == "__main__":
    main()
