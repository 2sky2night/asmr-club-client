---
name: asmr-release-prep
description: Prepare the ASMR Club Client for release by managing versioning, tagging, changelog generation, and creating release notes. Use when the user wants to publish a new version, prepare a release, or generate release content from documentation.
---

# ASMR Release Preparation

This skill automates the release preparation workflow for the ASMR Club Client Flutter project and generates formatted release notes.

## Workflow A: Full Release Preparation

1. **Determine the next version**:
   - Ask the user for the target version (e.g., `0.0.2`).
   - Determine the next build number by checking `pubspec.yaml`.

2. **Update `pubspec.yaml`**:
   - Update the `version` field to `target_version+next_build_number`.

3. **Git Tagging**:
   - Create a Git tag: `git tag v{target_version}`.
   - Push the tag: `git push origin v{target_version}`.

4. **Generate Changelog**:
   - Run `git-cliff -o CHANGELOG.md` to generate the update log based on commits since the last tag.

5. **Commit Changes**:
   - Stage changes: `git add .`.
   - Commit with message: `chore: bump version to v{target_version}`.
   - Push code: `git push`.

## Workflow B: Generate Release Notes from Documentation

When the user provides release documentation or asks to generate release content:

1. **Extract key information** from the provided document:
   - Bug fixes (🐛)
   - New features (✨)
   - Improvements (⚡)
   - Breaking changes (💥)
   - Important notes (⚠️)
   - Disclaimers (🔒)
   - Installation instructions (📥)

2. **Format the release notes** using this template:

```markdown
## 📦 Version {version}

### ✨ 新功能
- [List new features]

### ⚡ 优化改进
- [List improvements]

### 🐛 Bug 修复
- [List bug fixes]

### ⚠️ 注意事项
[Important notes about compatibility, known issues, etc.]

### 🔒 免责声明
本软件为个人开发项目,不附带任何明示或暗示的保证。使用本软件过程中如发生任何数据丢失、设备损坏或其他问题,作者不承担任何责任。请用户自行承担使用风险,建议重要数据提前做好备份。

### 📥 安装说明
下载后直接安装即可使用。
```

3. **Output directly in the conversation** - Do NOT create files, just display the formatted release notes.

4. **Ask if user wants to proceed** with full release preparation (Workflow A) after reviewing the generated notes.

## Instructions

- Always verify the current version in `pubspec.yaml` before making changes.
- Ensure `git-cliff` is installed and configured (`cliff.toml` exists).
- If the user doesn't specify a version, suggest incrementing the minor or patch version based on recent commit types (feat -> minor, fix -> patch).
- When generating release notes from documentation, extract and categorize content appropriately.
- Use emoji indicators consistently: 🐛 (bugs), ✨ (features), ⚡ (improvements), 💥 (breaking changes), ⚠️ (warnings), 🔒 (disclaimer), 📥 (installation).
- Always include the standard disclaimer and installation instructions unless explicitly told otherwise.
- Output release notes directly in the conversation - do not create markdown files unless requested.

## Example Usage

### Example 1: Full Release
User: "Prepare a release for version 0.1.0"
Assistant: 
1. Reads `pubspec.yaml` (current: `0.0.1+1`).
2. Updates `pubspec.yaml` to `0.1.0+2`.
3. Runs `git tag v0.1.0` and `git push origin v0.1.0`.
4. Runs `git-cliff -o CHANGELOG.md`.
5. Commits and pushes the updated `pubspec.yaml` and `CHANGELOG.md`.

### Example 2: Generate Release Notes
User: "Generate release notes from this content: 修复了网络图片加载问题,增加了占位图标"
Assistant:
```markdown
## 📦 Version 0.1.0

### 🐛 Bug 修复
- 修复 Release 版本无法加载网络封面图问题(补充 INTERNET 权限)
- 修复封面图加载失败时显示空白的问题(增加占位图标兜底)

### ⚠️ 注意事项
iOS 版本尚在开发中,当前构建可能无法正常运行,建议 Android 用户下载使用

### 🔒 免责声明
本软件为个人开发项目,不附带任何明示或暗示的保证。使用本软件过程中如发生任何数据丢失、设备损坏或其他问题,作者不承担任何责任。请用户自行承担使用风险,建议重要数据提前做好备份。

### 📥 安装说明
下载后直接安装即可使用。
```

Would you like me to proceed with preparing this release?
