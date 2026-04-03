---
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion, Grep, Glob
description: Publish intl_ai to pub.dev — bumps version, generates changelog, tags, pushes, and publishes
---

# Publish Skill

End-to-end release flow for `intl_ai`: detect changes since last tag, suggest a semver bump, draft a changelog, update files, commit, tag, push, and publish to pub.dev.

## Step 1 — Gather context

Run these in parallel:
- `git tag --sort=-v:refname | head -1` → last tag (e.g. `v0.2.0`)
- Read `pubspec.yaml` → current version
- `git log <last-tag>..HEAD --merges --format="%s"` → merged PR subjects

Extract PR numbers from subjects matching `Merge pull request #(\d+)`.

For each PR number, run `gh pr view <N> --json number,title,body,headRefName` to get:
- `title` — PR title
- `body` — PR description (contains "resolves #M" / "closes #M" / "fixes #M")
- `headRefName` — branch name (e.g. `feat/my-feature`, `fix/bug`)

For each issue number M found in PR bodies, run `gh issue view <M> --json title,number` to get the issue title.

## Step 2 — Classify and suggest version bump

Classify each PR by its branch prefix:
- `feat/` → **minor**
- `fix/` → **patch**
- `docs/`, `chore/` → **patch**
- Branch contains `breaking` OR PR body contains `BREAKING CHANGE` OR PR has label `breaking change` → **major**

Apply the highest classification across all PRs:
- Any **major** → bump major, reset minor and patch to 0
- Any **minor** (no major) → bump minor, reset patch to 0
- Only **patch** → bump patch

Present the suggestion and ask:

> I found N PRs since `<last-tag>`. Based on the changes (list feat/fix/breaking breakdown), I suggest bumping to **X.Y.Z**. What version should I use?

Use `AskUserQuestion` with the suggestion pre-filled. Accept the user's answer as the final version.

## Step 3 — Draft changelog

Format using Flutter-style flat bullets. Each entry links to the GitHub issue (preferred) or PR if no issue was found.

Issue link format: `[#M](https://github.com/krolmic/intl_ai/issues/M)`
PR link format: `[#N](https://github.com/krolmic/intl_ai/pull/N)`

Use the **issue title** as the description (not the PR title), trimmed to be concise. If no issue was found for a PR, use the PR title.

```
## [X.Y.Z]

- [#M](https://github.com/krolmic/intl_ai/issues/M) Issue title here.
- [#M2](https://github.com/krolmic/intl_ai/issues/M2) Another issue title.
```

Rules:
- One bullet per issue number. If a PR resolves multiple issues, create a bullet for each.
- Skip PRs that only have `docs/` or `chore/` branches AND no issue reference (e.g. pure README edits). Include them if they have an issue number.
- Order: breaking changes first, then added features, then fixes — but no subsection headers.
- End each bullet with a period.

Present the draft to the user via `AskUserQuestion`:

> Here's the changelog draft for `[X.Y.Z]`:
>
> ```
> ## [X.Y.Z]
>
> - [#M] ...
> ```
>
> Does this look good, or would you like to edit it? (Reply "ok" to proceed, or paste your edited version.)

If the user pastes edits, use their version verbatim.

## Step 4 — Apply changes

**Update `pubspec.yaml`**: Replace the `version:` line with the new version.

**Update `CHANGELOG.md`**: Prepend the new section after the `# Changelog` heading, with a blank line separating it from the previous section.

Read both files first before editing.

## Step 5 — Commit and tag

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: prepare release v<version>"
git tag v<version>
```

## Step 6 — Push (ask first)

Ask via `AskUserQuestion`:

> Ready to push. This will run:
> ```
> git push origin main
> git push origin v<version>
> ```
> Proceed?

If confirmed, run both commands.

## Step 7 — Publish (ask first)

Ask via `AskUserQuestion`:

> Ready to publish to pub.dev. This will run:
> ```
> fvm dart pub publish
> ```
> Proceed?

If confirmed, run `fvm dart pub publish`. Report the output to the user.
