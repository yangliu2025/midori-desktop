#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "==> 清理旧的打包文件"
rm -rf midori-deb midori-browser_*.deb

echo "==> 创建打包目录结构"
PKGROOT="$PWD/midori-deb"
mkdir -p "$PKGROOT/opt/midori" "$PKGROOT/DEBIAN"
mkdir -p "$PKGROOT/usr/share/applications"
mkdir -p "$PKGROOT/usr/share/icons/hicolor/256x256/apps"

echo "==> 复制构建产物（解析符号链接）"
# 使用 rsync 复制并解析符号链接，排除损坏的链接
rsync -aL --copy-unsafe-links engine/obj-x86_64-pc-linux-gnu/dist/bin/ "$PKGROOT/opt/midori/" 2>/dev/null || true

# 如果rsync失败，使用tar备选方案
if [ ! -f "$PKGROOT/opt/midori/midori" ]; then
    echo "==> rsync失败，使用tar复制..."
    tar -C engine/obj-x86_64-pc-linux-gnu/dist/bin -cf - . | tar -C "$PKGROOT/opt/midori" -xf -
    # 删除所有损坏的符号链接
    find "$PKGROOT/opt/midori" -type l ! -exec test -e {} \; -delete
fi

echo "==> 创建 control 文件"
cat > "$PKGROOT/DEBIAN/control" << 'EOF'
Package: midori-browser
Version: 12.0-1
Section: web
Priority: optional
Architecture: amd64
Maintainer: Local Build <local@build>
Depends: libgtk-3-0, libpulse0, libasound2, libdbus-glib-1-2, libxt6, libnss3, libxrandr2, libx11-6
Description: Midori Browser - Lightweight web browser
 Midori is a fast, lightweight, and open-source web browser
 based on Firefox/Gecko engine.
EOF

echo "==> 创建 desktop 文件"
cat > "$PKGROOT/usr/share/applications/midori.desktop" << 'EOF'
[Desktop Entry]
Name=Midori Browser
Comment=Browse the World Wide Web
Exec=/opt/midori/midori %u
Terminal=false
Type=Application
Icon=midori
StartupWMClass=Midori
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

echo "==> 复制图标"
cp configs/branding/release/logo256.png "$PKGROOT/usr/share/icons/hicolor/256x256/apps/midori.png"

echo "==> 设置权限"
chmod 755 "$PKGROOT/opt/midori/midori"
chmod 755 "$PKGROOT/opt/midori/midori-bin"

echo "==> 构建 deb 包"
fakeroot dpkg-deb --build "$PKGROOT" ./midori-browser_12.0-1_amd64.deb

echo "==> 完成！"
ls -lh midori-browser_12.0-1_amd64.deb
dpkg-deb -I ./midori-browser_12.0-1_amd64.deb
