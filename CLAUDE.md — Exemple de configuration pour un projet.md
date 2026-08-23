# CLAUDE.md

## Project Overview

This repository contains a Garmin Connect IQ application written in Monkey C.

The project should remain compatible with the Garmin Connect IQ SDK configured for this repository.

## Project Structure

- `source/` — Monkey C source files
- `resources/` — application resources, layouts, strings and images
- `manifest.xml` — Connect IQ application manifest
- `monkey.jungle` — Monkey C build configuration
- `bin/` — generated build artifacts
- `tests/` — tests and test utilities, if present

Do not modify generated files in `bin/`.

## Development Environment

Before making changes, verify the available SDK and compiler:

```bash
which monkeyc
env | grep -i connectiq
ls ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks 2>/dev/null
```

If `monkeyc` is not available, do not assume its location. Inspect the installed Connect IQ SDKs first.

## Build

Build the project using the repository's configured build process.

If a direct `monkeyc` command is required, determine the SDK version and compiler path before running it.

Never silently switch to a different SDK version.

After changing Monkey C source code, perform a build when practical.

## Code Style

- Use idiomatic Monkey C.
- Keep functions small and focused.
- Prefer clear names over abbreviated names.
- Avoid unnecessary global state.
- Reuse existing project utilities before introducing new ones.
- Follow the style already established in neighboring files.
- Do not introduce a new dependency unless it is necessary.

## Changes

Before modifying code:

1. Inspect the relevant files.
2. Understand how the existing implementation works.
3. Identify the smallest change that solves the problem.
4. Preserve existing behavior unless the task explicitly requires changing it.

Do not rewrite unrelated code.

Do not perform large refactors while fixing a small bug.

## Error Handling

When an operation can fail, handle the failure explicitly where appropriate.

Do not hide errors merely to make the build succeed.

If the Garmin API has platform-specific limitations, verify the existing implementation and SDK compatibility before changing behavior.

## Testing

After making changes:

1. Build the project.
2. Run the available tests.
3. If tests cannot be run, explain why.
4. Report build or test failures rather than claiming success.

Do not modify tests merely to make them pass unless the requested change requires the tests to change.

## Git

Do not create commits unless explicitly requested.

Do not reset, rebase, force-push, or discard user changes without explicit permission.

Before editing, preserve unrelated working-tree changes.

Keep changes focused on the requested task.

## Dependencies

Do not add dependencies without first checking whether the required functionality can be implemented using the existing project and Garmin Connect IQ APIs.

If a dependency is necessary, explain why before adding it.

## Documentation

Update documentation when behavior, configuration, installation, or public interfaces change.

Do not create documentation for trivial internal changes.

## Communication

When completing a task, summarize:

- What changed
- Which files changed
- What verification was performed
- Any remaining limitations or warnings

Be concise and do not claim that something was tested if it was not actually tested.