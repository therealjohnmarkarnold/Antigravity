import os
import urllib.request
import ssl

# Map internal names to ISO 3166-1 alpha-2 codes
flags_map = {
    'usa': 'us',
    'canada': 'ca',
    'uk': 'gb',
    'france': 'fr',
    'germany': 'de',
    'japan': 'jp',
    'italy': 'it',
    'brazil': 'br',
    'india': 'in',
    'australia': 'au',
    'china': 'cn',
    'spain': 'es',
    'mexico': 'mx',
    'south_korea': 'kr',
    'argentina': 'ar'
}

base_dir = "assets/flags"
if not os.path.exists(base_dir):
    os.makedirs(base_dir)

print(f"Downloading {len(flags_map)} flags to {base_dir} using urllib...")

# Create a context that ignores SSL verification errors slightly safer for quick scripts if certs are missing locally
# though ideally we want validation, this environment might be restrictive.
# For now, let's try default context first, if it fails we can make it more permissive.
# Actually, let's just use default urlopen.

for name, code in flags_map.items():
    url = f"https://flagcdn.com/w320/{code}.png"
    file_path = os.path.join(base_dir, f"{name}.png")
    
    try:
        print(f"Downloading {name}...", end=" ")
        with urllib.request.urlopen(url) as response, open(file_path, 'wb') as out_file:
            data = response.read()
            out_file.write(data)
        print("✅")
    except Exception as e:
        print(f"❌ Error: {e}")

print("Asset download complete.")
