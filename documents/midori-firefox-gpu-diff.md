# Midori vs Firefox GPU 进程差异分析

## 问题描述
在 VMware Workstation + Ubuntu 24.04 环境中：
- **Midori v11.6** (X11 模式): `about:process` 显示 GPU 进程
- **Firefox** (X11 模式): `about:process` **不显示** GPU 进程

## 🔍 核心原因：Fastfox.js 的 GPU 配置

Midori 使用了 **Fastfox.js** 配置（来自 Betterfox 项目），其中包含 GPU 相关的优化设置：

```javascript
// Fastfox.js 中的关键 GPU 配置（v11.6）
//user_pref("layers.gpu-process.enabled", true);        // 默认 WINDOWS，但可能被强制
//user_pref("layers.gpu-process.force-enabled", true);  // 强制执行
//user_pref("layers.mlgpu.enabled", true);             // LINUX
```

## ⚙️ 差异分析

### Midori v11.6 可能启用的设置
1. **强制 GPU 进程**:
   ```javascript
   user_pref("layers.gpu-process.force-enabled", true);
   // 即使 VMware 虚拟显卡也能强制启用 GPU 进程
   ```

2. **软件 Webrender 回退**:
   ```javascript
   user_pref("gfx.webrender.software", true);
   // 使用 CPU 渲染但显示 GPU 进程
   ```

3. **MLGPU 启用** (Linux):
   ```javascript
   user_pref("layers.mlgpu.enabled", true);
   ```

### Firefox 默认行为
- Firefox 检测到 VMware 虚拟显卡时会**自动禁用 GPU 进程**（安全考虑）
- `about:process` 页面不显示 GPU 进程，因为硬件加速被禁用

## 🧪 验证方法

在 Firefox 中尝试设置这些 prefs：

```bash
# 在 Firefox 地址栏输入 about:config，然后设置：
layers.gpu-process.force-enabled = true
layers.gpu-process.enabled = true
```

然后重启 Firefox，检查 `about:process` 是否显示 GPU 进程。

## 💡 根本原因总结

| 浏览器 | GPU 进程显示 | 原因 |
|--------|-------------|------|
| **Midori v11.6** | ✅ 有 | 强制启用 GPU 进程，即使在 VMware 中 |
| **Firefox** | ❌ 无 | 自动检测 VMware 虚拟显卡，安全禁用 |

**注意**: 虽然 Midori 显示 GPU 进程，但在 VMware 中它可能使用的是 **软件渲染**（Webrender Software），而不是真正的硬件加速。这只是一种"显示上的 GPU 进程"，实际性能可能并不更好。

## 📋 在 Firefox 中启用 GPU 进程

如果你想在 Firefox 中启用 GPU 进程（VMware 中）：

```javascript
// about:config 设置
user_pref("layers.gpu-process.enabled", true);
user_pref("layers.gpu-process.force-enabled", true);
user_pref("gfx.webrender.software", true);  // 如果硬件不支持
```

**警告**: 实际渲染性能可能不会有显著提升，因为 VMware 的虚拟显卡能力有限。

## 🔧 相关配置文件位置

- `/src/browser/app/profile/Fastfox.js` - Midori 性能优化配置
- `/src/browser/app/profile/Securefox.js` - Midori 安全配置

这些文件来自 Betterfox 项目，包含大量性能调优参数。
