from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
manifest = root / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    text = re.sub(r'\s*<uses-permission android:name="android\.permission\.INTERNET"\s*/>', '', text)
    text = text.replace('android:label="offscreen"', 'android:label="Offscreen"')
    manifest.write_text(text, encoding='utf-8')

for candidate in [root / 'android' / 'app' / 'build.gradle.kts', root / 'android' / 'app' / 'build.gradle']:
    if not candidate.exists():
        continue
    text = candidate.read_text(encoding='utf-8')
    if candidate.name.endswith('.kts'):
        text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 26', text)
        text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 35', text)
    else:
        text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 26', text)
        text = re.sub(r'targetSdkVersion\s+flutter\.targetSdkVersion', 'targetSdkVersion 35', text)
    candidate.write_text(text, encoding='utf-8')

print('Android config prepared: minimum SDK 26 and no INTERNET permission.')
