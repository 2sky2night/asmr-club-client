---
name: asmr-release-prep
description: Prepare the ASMR Club Client for release by managing versioning, tagging, and changelog generation. Use when the user wants to publish a new version or prepare a release.
---

# ASMR Release Preparation

This skill automates the release preparation workflow for the ASMR Club Client Flutter project.

## Workflow

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

## Instructions

- Always verify the current version in `pubspec.yaml` before making changes.
- Ensure `git-cliff` is installed and configured (`cliff.toml` exists).
- If the user doesn't specify a version, suggest incrementing the minor or patch version based on recent commit types (feat -> minor, fix -> patch).

## Example Usage

User: "Prepare a release for version 0.1.0"
Assistant: 
1. Reads `pubspec.yaml` (current: `0.0.1+1`).
2. Updates `pubspec.yaml` to `0.1.0+2`.
3. Runs `git tag v0.1.0` and `git push origin v0.1.0`.
4. Runs `git-cliff -o CHANGELOG.md`.
5. Commits and pushes the updated `pubspec.yaml` and `CHANGELOG.md`.
