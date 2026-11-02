---
title: UndercoverCI winter update
date: 2026-11-02
description: Critical paths, view coverage in your checks, and checks on pull requests from forks.
---

Here's what's new in UndercoverCI this winter.

## Neutral mode with critical paths

Many teams run their coverage check as neutral (🟡). Untested changes get flagged, but nothing blocks the merge.

Critical paths let you keep the check neutral and still fail it (🔴) when an untested change lands in the code you care about most. In your [repository settings](/settings), pick "Neutral" and list the paths where untested changes should still fail the build, one glob per line:

```text
app/models/billing/**/*  # billing code
lib/payments/**/*.rb
```

Paths are relative to the repository root, and the [docs](/docs#critical-paths) have more examples.

Warnings in those paths fail the check and show up as failures in the pull request. Everything else stays neutral:

![critical_paths_files](critical_paths_files.png "240")

The check summary counts them and marks each one as critical:

![critical_paths_check](critical_paths_check.png)

## View coverage in your checks

UndercoverCI now runs [undercover 0.9](/blog/undercover-0-9), so your checks also flag untested `if`, `case` and loop blocks in ERB templates. To get them, upgrade the `undercover` gem to 0.9 (it needs SimpleCov 1.0+) and add one line to your test helper: `enable_coverage :branch, :eval`. If your report has no template coverage, the check tells you which templates it skipped. Setup details are in the [docs](/docs#view-coverage).

## Pull requests from forks

Pull requests from forks get coverage checks too, as long as your CI uploads coverage on pull request builds.

When a contributor's fork runs your workflow on its own pushes, the uploader prints a setup notice and the build stays green. UndercoverCI is free for open source, so contributors can install it on their fork too.

## Also new

- Big pull requests: up to 500 warnings are analysed instead of stopping at 51, and every one is annotated in the diff.
- Checks support Ruby 4 and SimpleCov 1.x.

Questions or feedback? Write to me at [jan@undercover-ci.com](mailto:jan@undercover-ci.com).
