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
UPLOAD_URL="https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$ZIP_NAME"
RESPONSE=$(curl -sL --max-time 300 -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Content-Type: application/zip" \
    --data-binary @"/tmp/$ZIP_NAME" \
    "$UPLOAD_URL")
ASSET_NAME=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name', ''))" 2>/dev/null || echo "")
if [ -z "$ASSET_NAME" ]; then
    if echo "$RESPONSE" | grep -q "already_exists"; then
        echo "    asset already exists, skipping upload"
    else
        echo "    ERROR uploading: ${RESPONSE:0:300}"
        exit 1
    fi
else
    echo "    asset: $ASSET_NAME"
fi

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
if ! git diff --cached --quiet; then
    TREE=$(git write-tree)
    PARENT=$(git rev-parse HEAD)
    NEW=$(git commit-tree "$TREE" -p "$PARENT" -m "Update appcast for v${VERSION}")
    git reset --soft "$NEW"
fi
git push origin main 2>&1

echo "==> Tagging..."
git tag "$TAG" 2>/dev/null || true
if git push origin "$TAG" 2>&1 | grep -q "rejected"; then
    echo "    tag $TAG already exists on remote (created via API), skipping"
fi

echo ""
echo "✅ Release $TAG published:"
echo "   https://github.com/$REPO/releases/tag/$TAG"
