---
name: flutter-code-review
description: Review Flutter code for quality, security, and project standards compliance. Checks naming conventions, resource management, privacy constraints, and state management patterns. Use when reviewing pull requests, examining code changes, or when the user asks for a Flutter code review in the ASMR Club Client project.
---

# Flutter Code Review

## Context
This skill applies to the ASMR Club Client project. Before reviewing, read the project context from `Agents.md` to understand:
- Privacy-first scanning logic (`rootPath` validation)
- State management with `provider`
- Audio playback via `just_audio`
- Path normalization requirements for Android

## Instructions
When reviewing Flutter code, follow these steps:

1. **Get Changes**: Use `git diff` to identify changes in `.dart` files.
2. **Static Analysis**:
   - Check naming conventions (camelCase for variables/functions, PascalCase for classes, `_privateLeadingUnderscore` for private members).
   - Identify hardcoded strings/colors and suggest extracting them to constants or themes.
   - Verify proper `await` usage and error handling (`try-catch` with specific exception types).
   - Ensure widgets use `const` constructors where possible for performance.
3. **Security & Performance**:
   - Ensure listeners/streams are cancelled in `dispose()` methods.
   - Verify file scanning logic respects `rootPath` constraints (privacy compliance).
   - Avoid heavy operations inside `build()` methods (use `compute()` for expensive calculations).
   - Check for unnecessary rebuilds (consider `Selector` or `Consumer` optimization).
4. **Project Standards**:
   - Confirm use of `provider` for state management (not `setState` for complex state).
   - Verify `just_audio` integration follows existing patterns in `PlayerProvider`.
   - Check for `_normalizePath` usage when handling Android file paths.
   - Ensure database operations use `DatabaseService` singleton.
5. **Flutter-Specific Checks**:
   - Widget tree depth is reasonable (< 10 levels).
   - `ListView`/`GridView` use `itemBuilder` pattern (not building all items at once).
   - Async operations handle loading/error states in UI.

## Checklist
- [ ] Naming follows Dart style guide (camelCase/PascalCase/private underscore)?
- [ ] No unhandled exceptions or empty catch blocks?
- [ ] UI components are modularized and reusable?
- [ ] Privacy guidelines followed (rootPath validation in scanning logic)?
- [ ] No unnecessary dependencies added?
- [ ] Resource cleanup in dispose() methods?
- [ ] Const constructors used where possible?
- [ ] Async operations handle loading/error states?

## Output Format
Provide feedback using this structure:

### 📄 File: `path/to/file.dart`
**✅ Pros**
- Briefly mention good practices.

**⚠️ Issues**
- Point out bugs, performance risks, or security concerns.

**💡 Suggestions**
- Provide specific code snippets or refactoring advice.
