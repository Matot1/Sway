#!/bin/bash
set -e

# Usage: ./release.sh <version> <description>
# Example: ./release.sh 0.4.4 "Bug fixes and improvements"

if [ $# -lt 2 ]; then
    echo "Usage: ./release.sh <version> <description>"
    echo "Example: ./release.sh 0.4.4 \"Bug fixes\""
    exit 1
fi

VERSION="$1"
DESCRIPTION="$2"
REPO="Matot1/Sway"
ZIP_NAME="Sway-v${VERSION}.zip"
TAG="v${VERSION}"
APPCAST="appcast.xml"
KEY_FILE=".keys/ed25519_private.b64"

TOKEN=$(security find-internet-password -s github.com -w 2>/dev/null)
if [ -z "$TOKEN" ]; then
    echo "ERROR: no GitHub token in keychain"
    exit 1
fi

echo "==> Building..."
bash build.sh

echo "==> Creating ZIP..."
cd .build/debug
rm -f "/tmp/$ZIP_NAME"
zip -r -y "/tmp/$ZIP_NAME" Sway.app -x "*.DS_Store" > /dev/null
cd ../..

echo "==> Signing..."
SIG=$(swift tools/sign.swift sign "$KEY_FILE" "/tmp/$ZIP_NAME")
SIZE=$(stat -f%z "/tmp/$ZIP_NAME")
echo "    signature: $SIG"
echo "    size: $SIZE"

echo "==> Creating release..."
RELEASE_JSON=$(curl -sL --max-time 30 -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"body\":\"$DESCRIPTION\"}" \
    "https://api.github.com/repos/$REPO/releases")
RELEASE_ID=$(echo "$RELEASE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")

if [ -z "$RELEASE_ID" ]; then
    # Release may already exist (tag created manually); fetch it
    RELEASE_JSON=$(curl -sL --max-time 30 \
        -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO/releases/tags/$TAG")
    RELEASE_ID=$(echo "$RELEASE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")
fi

if [ -z "$RELEASE_ID" ]; then
    echo "ERROR: failed to create/find release"
    echo "$RELEASE_JSON"
    exit 1
fi

echo "==> Uploading asset ($ZIP_NAME, $((SIZE/1024)) KB)..."
python3 - "$TOKEN" "$REPO" "$RELEASE_ID" "$ZIP_NAME" "/tmp/$ZIP_NAME" <<'PYEOF'
import sys, json, urllib.request, uuid

token, repo, release_id, filename, filepath = sys.argv[1:6]
url = f"https://uploads.github.com/repos/{repo}/releases/{release_id}/assets?name={filename}"
boundary = uuid.uuid4().hex

with open(filepath, "rb") as f:
    filedata = f.read()

body = (
    f"--{boundary}\r\n"
    f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
    f"Content-Type: application/zip\r\n\r\n"
).encode() + filedata + f"\r\n--{boundary}--\r\n".encode()

req = urllib.request.Request(url, data=body, method="POST")
req.add_header("Authorization", f"token {token}")
req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
req.add_header("Content-Length", str(len(body)))

try:
    with urllib.request.urlopen(req) as resp:
        d = json.loads(resp.read().decode())
        print("    asset:", d.get("name"))
except urllib.error.HTTPError as e:
    err = e.read().decode()
    if "already_exists" in err or e.code == 422:
        print("    asset already exists, skipping upload")
    else:
        print("    ERROR uploading:", err[:300])
        sys.exit(1)
PYEOF

echo "==> Updating appcast.xml..."
DATE=$(date -R)
python3 - "$APPCAST" "$VERSION" "$DESCRIPTION" "$ZIP_NAME" "$SIG" "$SIZE" "$DATE" "$TAG" "$REPO" <<'PYEOF'
import sys, re

path, version, description, zip_name, sig, size, date, tag, repo = sys.argv[1:10]
download_url = f"https://github.com/{repo}/releases/download/{tag}/{zip_name}"

item = f"""    <item>
      <title>Version {version}</title>
      <pubDate>{date}</pubDate>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <description>{description}</description>
      <enclosure url="{download_url}"
                 sparkle:edSignature="{sig}"
                 length="{size}"
                 type="application/octet-stream"/>
    </item>
"""

try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    content = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Sway</title>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
  </channel>
</rss>
"""

# Insert new item after <language> line
content = re.sub(r'(<language>en</language>\n)', r'\1' + item, content, count=1)
with open(path, "w") as f:
    f.write(content)
print("    appcast.xml updated")
PYEOF

echo "==> Committing appcast.xml..."
git add "$APPCAST"
git commit -m "Update appcast for v${VERSION}" 2>/dev/null || echo "    (nothing to commit)"
git push origin main 2>&1

echo "==> Tagging..."
git tag "$TAG" 2>/dev/null || true
git push origin "$TAG" 2>&1

echo ""
echo "✅ Release $TAG published:"
echo "   https://github.com/$REPO/releases/tag/$TAG"
