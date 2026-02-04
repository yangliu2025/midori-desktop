# Midori Browser 编译指南 - Ubuntu 24.04

基于项目结构和 Firefox/Gecko 构建系统，这里是 **Ubuntu 24.04 本地编译并生成 .deb 的完整流程**。

---

## 重要说明：构建 vs 打包

本项目使用 **Amelia 构建工具**（`@goastian/amelia`）：

- **`npm run build`**：只编译浏览器二进制文件，**不生成任何安装包**（deb/AppImage/Flatpak 都不会自动生成）
- **打包**：编译完成后，需要手动创建 .deb 包（或使用 `npm run package`，但具体行为不明确）
- **本项目 CI 使用 OpenSUSE Build Service**，没有 GitHub Actions 的 deb 打包流程可参考

**因此流程是**：编译（build）→ 手动打包（deb）

---

## 准备环境

### 1. 安装基础依赖

```bash
sudo apt update
sudo apt install -y curl python3 python3-venv python3-pip git
```

### 2. 安装 Node.js 22（按 .nvmrc 要求）

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3. 安装 Rust（按 .rust-toolchain 要求 1.83）

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup install 1.83
```

### 4. 安装 Firefox 构建依赖（Gecko 需要）

```bash
sudo apt install -y build-essential libgtk-3-dev libpulse-dev libasound2-dev \
    libdbus-glib-1-dev libxt-dev libx11-dev libxext-dev libxinerama-dev \
    libxrender-dev libxcomposite-dev libxdamage-dev libxfixes-dev libxrandr-dev \
    libdrm-dev libffi-dev libnss3-dev clang lld yasm
```

---

## 编译步骤（仅生成二进制文件）

```bash
# 1. 进入项目目录
cd /home/justicui/WorkSpace/midori-desktop

# 2. 安装项目依赖（包含 Amelia 构建工具）
npm install

# 3. 初始化（下载 Firefox 引擎、应用补丁、配置）
npm run init

# 4. 构建（使用 release brand）
npm run brand  # 设置为 release 品牌
npm run build

# 构建产物会在 engine/obj-x86_64-pc-linux/dist/bin/ 目录
# 此时只有二进制文件，没有安装包！
```

---

## 打包为 .deb（手动方式，推荐）

编译完成后，执行以下步骤创建 deb 包：

```bash
# 1. 安装打包工具
sudo apt install -y dpkg-dev fakeroot

# 2. 创建打包目录
PKGROOT="$PWD/midori-deb"
mkdir -p "$PKGROOT/opt/midori" "$PKGROOT/DEBIAN"
mkdir -p "$PKGROOT/usr/share/applications"
mkdir -p "$PKGROOT/usr/share/icons/hicolor/256x256/apps"

# 3. 复制构建产物
# 构建产物通常在 engine/obj-*-linux/dist/bin/
cp -r engine/obj-*-linux/dist/bin/* "$PKGROOT/opt/midori/"

# 4. 创建 control 文件
cat > "$PKGROOT/DEBIAN/control" << 'EOF'
Package: midori-browser
Version: 12.0-1
Section: web
Priority: optional
Architecture: amd64
Maintainer: Local Build <local@build>
Depends: libgtk-3-0, libpulse0, libasound2, libdbus-glib-1-2, libxt6
Description: Midori Browser - Lightweight web browser
 Midori is a fast, lightweight, and open-source web browser
 based on Firefox/Gecko engine.
EOF

# 5. 创建 desktop 文件
cat > "$PKGROOT/usr/share/applications/midori.desktop" << 'EOF'
[Desktop Entry]
Name=Midori Browser
Exec=/opt/midori/midori %u
Terminal=false
Type=Application
Icon=midori
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

# 6. 复制图标（如有）
cp src/browser/themes/midori/logo.svg "$PKGROOT/usr/share/icons/hicolor/256x256/apps/midori.svg" 2>/dev/null || true

# 7. 构建 deb 包
fakeroot dpkg-deb --build "$PKGROOT" ./midori-browser_12.0-1_amd64.deb
```

---

## 替代：使用 Amelia 打包（不确定行为）

如果你想尝试使用 Amelia 的自动打包功能（可能生成多种格式）：

```bash
# 编译完成后运行
npm run package

# 注意：
# - 不确定会生成哪些格式（deb/AppImage/Flatpak/其他）
# - 本项目使用 OpenSUSE Build Service 进行官方打包
# - 本地 amelia package 行为未明确文档化
```

**推荐**：使用上面的手动 deb 打包方式，可控且明确。

---

## 验证安装

```bash
# 检查包信息
dpkg-deb -I ./midori-browser_12.0-1_amd64.deb

# 测试安装
sudo dpkg -i ./midori-browser_12.0-1_amd64.deb
# 如有依赖问题，修复：sudo apt --fix-broken install

# 运行测试
/opt/midori/midori --version
```

---

## ⚠️ 注意事项

1. **磁盘空间**：构建过程需要 **30GB+ 磁盘空间**
2. **内存需求**：建议 **8GB+ 内存**，否则可能 OOM
3. **构建时间**：耗时约 1-3 小时（视硬件而定）
4. **构建系统**：该项目使用 Amelia 构建工具（`@goastian/amelia`），不是标准 Gecko 构建系统
5. **打包分离**：`npm run build` 只生成二进制文件，不会自动创建 deb 包

---

## 参考信息

- 项目版本：Firefox 146.0，Midori 12.0
- Node.js 版本：22
- Rust 版本：1.83
- Python 版本：3.11
- CI/CD：OpenSUSE Build Service（非 GitHub Actions）
