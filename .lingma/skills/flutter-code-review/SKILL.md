---
name: flutter-code-review
description: Review Flutter code changes for quality, security, and adherence to project standards. Use when reviewing pull requests, checking code before commit, or when the user asks for a Flutter code review.
---

# Flutter Code Review

## Instructions
When reviewing Flutter code, follow these steps:

1. **Get Changes**: Use `git diff` to identify changes in `.dart` files.
2. **Static Analysis**:
   - Check naming conventions (camelCase for variables/functions, PascalCase for classes).
   - Identify hardcoded strings/colors and suggest extracting them to constants or themes.
   - Verify proper `await` usage and error handling (`try-catch`).
3. **Security & Performance**:
   - Ensure listeners are cancelled in `dispose`.
   - Verify file scanning logic respects `rootPath` constraints (privacy).
   - Avoid heavy operations inside `build` methods.
4. **Project Standards**:
   - Confirm use of `provider` for state management and `just_audio` for playback.
   - Check for `_normalizePath` usage in Android path handling.

## Checklist
- [ ] Naming follows Dart style guide?
- [ ] No unhandled exceptions or empty catch blocks?
- [ ] UI components are modularized?
- [ ] Privacy guidelines followed?
- [ ] No unnecessary dependencies?

## Output Format
Provide feedback using this structure:

### 📄 File: `path/to/file.dart`
**✅ Pros**
- Briefly mention good practices.

**⚠️ Issues**
- Point out bugs, performance risks, or security concerns.

**💡 Suggestions**
- Provide specific code snippets or refactoring advice.
