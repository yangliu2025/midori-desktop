# Midori 广告拦截器分析

## 📍 核心结论

**"Astian Privacy Tracker & Ad Blocker" 不在 Midori 源码中，但自动安装机制在源码中**

---

## 🔍 发现的证据

### 1. 自动安装机制 (`add-astian-apps.patch`)

位置: `src/browser/components/add-astian-apps.patch`

```javascript
const extensionsToInstall = [
  {
    url: "https://github.com/goastian/astian-privacy-protect/releases/download/v2.0.4/astian-firefox-2.0.4.xpi",
    id: "astian-privacy-protect@astian.org",
    name: "Astian Privacy Protect",
    required: false
  }
];
```

### 2. 欢迎页面推荐 (`welcome.sys.mjs`)

位置: `src/browser/components/welcome/welcome.sys.mjs`

```javascript
{
  id: 'midori-privacy@astian.org',
  url: 'https://github.com/goastian/astian-privacy-protect/releases/download/v2.0.5/astian-firefox-2.0.5.xpi'
}
```

---

## 📦 组件分布

| 组件 | 位置 | 说明 |
|------|------|------|
| **扩展本身** | ❌ 不在源码 | 单独的 GitHub 仓库 `goastian/astian-privacy-protect` |
| **安装机制** | ✅ 在源码 | `src/browser/components/add-astian-apps.patch` |
| **XPI 文件** | ❌ 不在源码 | 首次运行时从 GitHub 下载安装 |

---

## 🎯 工作原理

1. **首次启动 Midori** 时，自动从 GitHub 下载 XPI 文件
2. **静默安装** `Astian Privacy Protect` 扩展
3. **锁定扩展**，防止用户卸载（代码中设置 `permissions = 0`）
4. **固定到工具栏**，显示图标

---

## 🔗 扩展来源

- **GitHub 仓库**: `https://github.com/goastian/astian-privacy-protect`
- **XPI 版本**: v2.0.4 / v2.0.5
- **扩展 ID**: `astian-privacy-protect@astian.org`

---

## 💡 技术细节

### 扩展安装代码

```javascript
async _installExtensionOnFirstRun() {
  // 检查是否已安装
  if (!this._isNewProfile || 
      Services.prefs.getBoolPref("extensions.installedOnFirstRun", false)) {
    return;
  }

  // 从 GitHub 下载并安装
  const extensionsToInstall = [
    {
      url: "https://github.com/goastian/astian-privacy-protect/releases/download/v2.0.4/astian-firefox-2.0.4.xpi",
      id: "astian-privacy-protect@astian.org",
      name: "Astian Privacy Protect",
      required: false
    }
  ];

  for (const extension of extensionsToInstall) {
    await this._installSingleExtension(extension);
  }
}
```

### 扩展锁定机制

```javascript
// 锁定扩展防止卸载
Object.defineProperty(addon, "permissions", {
  get() { return 0; }, // 无权限 = 无法卸载
  configurable: false
});

if (addon.setLocked) {
  addon.setLocked(true);
}
```

### 固定到工具栏

```javascript
_pinExtensionToToolbar(extensionId) {
  const { CustomizableUI } = ChromeUtils.importESModule(
    "resource:///modules/CustomizableUI.sys.mjs"
  );
  
  const widgetId = makeWidgetId(extensionId) + "-browser-action";
  CustomizableUI.addWidgetToArea(widgetId, CustomizableUI.AREA_NAVBAR);
}
```

---

## 📝 总结

**"Astian Privacy Tracker & Ad Blocker"** 是：

- ❌ **不是源码内置** 的广告拦截代码（如 Brave 的内置拦截器）
- ✅ **而是自动安装的第三方扩展**（类似 uBlock Origin 或 AdGuard）
- 📝 源码只包含 **自动下载和安装机制**

### 与其他浏览器的对比

| 浏览器 | 广告拦截实现 | 位置 |
|--------|-------------|------|
| **Brave** | 内置 C++ 代码 | 浏览器核心源码 |
| **Midori** | 自动安装扩展 | GitHub 仓库 + 源码安装机制 |
| **Firefox** | 用户手动安装 | addons.mozilla.org |

### 开发建议

如果你需要修改广告拦截器本身：
- 访问 `https://github.com/goastian/astian-privacy-protect`
- 这是一个独立的扩展项目
- 修改后需要发布新版本 XPI
- 更新 Midori 源码中的下载 URL

---

## 📂 相关文件

- `src/browser/components/add-astian-apps.patch` - 扩展安装补丁
- `src/browser/components/welcome/welcome.sys.mjs` - 欢迎页面扩展推荐
- `src/browser/app/profile/midori-browser.js` - 扩展更新配置
