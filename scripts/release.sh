#!/bin/bash
set -euo pipefail

# Usage: ./scripts/release.sh 1.0.0

VERSION="${1:?Usage: ./scripts/release.sh <version>}"
TEAM_ID="W33JZPPPFN"
SIGNING_IDENTITY="Developer ID Application: Sabotage Media, LLC ($TEAM_ID)"
APPLE_ID="josh@sabotagemedia.com"
BUNDLE_ID="com.joshpigford.Chops"

if ! command -v create-dmg &>/dev/null; then
  echo "❌ create-dmg not found. Install with: brew install create-dmg"
  exit 1
fi

create_chops_dmg() {
  rm -f build/Chops.dmg
  create-dmg \
    --volname "Chops" \
    --volicon "build/export/Chops.app/Contents/Resources/AppIcon.icns" \
    --background "scripts/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 790 480 \
    --icon-size 128 \
    --icon "Chops.app" 195 220 \
    --app-drop-link 595 220 \
    --hide-extension "Chops.app" \
    --no-internet-enable \
    build/Chops.dmg \
    build/export/Chops.app \
    || test $? -eq 2
}

echo "🔨 Building Chops v$VERSION..."

# Generate Xcode project
xcodegen generate

# Clean build
rm -rf build
mkdir -p build

# Archive
xcodebuild -project Chops.xcodeproj \
  -scheme Chops \
  -configuration Release \
  -archivePath build/Chops.xcarchive \
  archive \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION"

# Export
sed "s/\${APPLE_TEAM_ID}/$TEAM_ID/g" ExportOptions.plist > build/ExportOptions.plist
xcodebuild -exportArchive \
  -archivePath build/Chops.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export

echo "📦 Creating DMG..."
create_chops_dmg

echo "🔏 Notarizing..."
xcrun notarytool submit build/Chops.dmg \
  --keychain-profile "AC_PASSWORD" \
  --wait

echo "📎 Stapling..."
xcrun stapler staple build/export/Chops.app
create_chops_dmg
xcrun stapler staple build/Chops.dmg || echo "⚠️  DMG staple failed (normal — CDN propagation delay). App inside is stapled."

echo "🏷️  Tagging v$VERSION..."
git tag "v$VERSION"
git push --tags

echo "📡 Generating Sparkle appcast..."
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData/Chops-*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 0 2>/dev/null | head -1)
SIGNATURE=$("$SPARKLE_BIN/sign_update" build/Chops.dmg 2>&1)
ED_SIG=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

cat > build/appcast.xml << APPCAST
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
  <channel>
    <title>Chops</title>
    <item>
      <title>Version $VERSION</title>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <pubDate>$PUB_DATE</pubDate>
      <enclosure
        url="https://github.com/Shpigford/chops/releases/download/v$VERSION/Chops.dmg"
        sparkle:edSignature="$ED_SIG"
        length="$LENGTH"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
APPCAST

echo "📡 Updating site appcast..."
cp build/appcast.xml site/public/appcast.xml
git add site/public/appcast.xml
git commit -m "chore: update appcast for v$VERSION" || true
git push

echo "🚀 Creating GitHub Release..."
gh release create "v$VERSION" build/Chops.dmg \
  --title "Chops v$VERSION" \
  --generate-notes

echo "✅ Done! Release: https://github.com/Shpigford/chops/releases/tag/v$VERSION"
