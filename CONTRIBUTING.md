# Contributing

Small, focused contributions are welcome.

1. Describe the problem and expected behavior in an issue or pull request. For UI or permission bugs, include the macOS version, keyboard layout, and reproduction steps.
2. Keep production code under `Sources/CopyKit` and tests under `Tests/CopyKitTests`.
3. Use English for comments, documentation, and interface strings. Prefer clear names and short comments that explain a non-obvious constraint.
4. Keep clipboard and UI mutations on the main actor. Avoid adding persistent clipboard storage, network access, or broad keyboard monitoring without an explicit design discussion.
5. Add or update tests for meaningful behavior changes. Use isolated named pasteboards; never put real private clipboard data in fixtures, screenshots, issues, or logs.
6. Run `./scripts/check.sh` and `./scripts/build-app.sh`. Include the relevant manual checks from the README in the pull request description.

Do not commit build products, signing credentials, or personal settings. By contributing, you agree that your contribution is distributed under this project's MIT license.
