---
title: Teaching Claude Code to Test What Breaks
date: 2026-04-17
description: A weekend experiment measuring how much the undercover-claude Claude Code plugin changes test quality. Same prompt, four runs, two models - with and without Undercover.
---

In the [previous post about building gt](https://grodowski.com/2026/03/15/gt-stacked-prs) I mentioned I used [undercover-claude](https://github.com/grodowski/undercover-claude) while building it. I ran the same prompt four times across two models, with and without Undercover, to measure how much it changes. A word of caution: this is a weekend experiment and not a rigorous study, so take the numbers accordingly.

### Undercover

[undercover-claude](https://github.com/grodowski/undercover-claude) is a Claude Code plugin built around the [undercover gem](https://github.com/grodowski/undercover).

```sh
git clone https://github.com/grodowski/undercover-claude
claude --plugin-dir ./undercover-claude
```

The plugin does two things. First, it sets up SimpleCov and undercover at the start of a new project before any tests are written. Second, it enforces a feedback loop: after every test run, Claude runs `bundle exec undercover` to check which changed lines aren't covered, writes tests for the gaps, and repeats until undercover exits 0.

The key detail: undercover checks only the lines in the current diff, not total coverage. The feedback is always scoped to what was just written.

### The prompt

All four runs got the same prompt to build `gt` from scratch, [available in the gt-eval repo](https://github.com/grodowski/gt-eval):

```
Build a Ruby CLI gem called `gt` for managing stacked pull requests (like Graphite).

## Commands to implement in order

1. gt create <name> [-m <msg>] - stage tracked files, commit, create branch, push, open PR
2. gt log (alias gt ls) - print stack from root to tip, highlight current branch
3. gt up / gt down / gt top - navigate the stack (exit 1 if no move possible)
4. gt restack - rebase each child onto its parent tip, force push, update PR descriptions
5. gt sync - pull main, then restack
6. gt modify (alias gt m) - amend HEAD, force push, then restack

## Tech

- Ruby gem with bin/gt entry point
- Use cli-ui ~> 2.7 for output (spinners, colors)
- Tests with Minitest + a GitSandbox helper (tmpdir + bare remote per test)

Work through the commands one at a time. For each: implement, write tests, commit.
Do not move to the next command until the current one is committed.
```

### Setup

Each agent started in a clean directory with reset memory and no shared context between runs. None of them knew about the blind test suite used for scoring. Scoring is done by a blind BDD suite the agent never sees: a tmpdir repo with a bare remote, `gh` stubbed out, `bin/gt` run as an external process. Results are also reviewed qualitatively: code structure, error handling and test depth.

### What the plain runs missed

The starter prompt explicitly asked for tests with a `GitSandbox` helper and required tests to pass before each commit. Uninstructed agents write tests reasonably well on their own. The plain runs produced 36-41 tests each with meaningful assertions, but the skilled agents were pushed past the point where they'd naturally stop.

That stopping point matters. The plain run test files follow a consistent pattern of covering the happy path. There was no friction forcing the agent to test the errors. Opus plain produced the most idiomatic implementation of the four - a typed `Git::Error` exception class, a dedicated `GH` module that checks for `gh` availability and degrades gracefully, clean separation of concerns - and still left the entire GitHub integration untested.

Sonnet plain's rebase conflict implementation is another example: the defensive error path exists but is broken and untested. It swallows the rebase error, then proceeds to force push and reports success after a failed rebase, while corrupting the remote. Skilled implementations did not have this bug.

### What undercover caught

Iterating on the implementation, the Sonnet + Undercover run found gaps 7 times across 20 undercover checks, while Opus + Undercover found gaps 5 times across 15 runs.

The clearest example: after `gt sync`, the fetch-failure path surfaced. Writing a test for it pushed Claude to split `git pull` into separate fetch and merge steps, with fetch failures being non-fatal warnings. That's better design. The coverage requirement surfaced a specification gap that wouldn't have been caught in review.

After implementing `gt create`, undercover flagged the push failure branch and the PR creation path that follows it. Both were unexercised: no test tried to push without a remote. Claude removed the origin remote in a sandbox to trigger the path, then verified the branch was still created. The test documents that `gt create` degrades gracefully without a remote rather than crashing.

The plain runs' tests are mostly integration-style: build a stack, run a command, assert the outcome, while the skill runs add a second layer. Sonnet skill introduced explicit error-path tests via stubbing (e.g. `test_create_fails_when_git_add_fails`, `test_create_fails_when_commit_fails`) and push-failure degradation tests. Opus skill added dedicated `git_test.rb` and `stack_test.rb` files that unit-test internal modules directly. Those are the tests that close the branch coverage gaps in error handling branches.

### Numbers

| | Sonnet 4.6 high | Sonnet 4.6 high + Undercover | Opus 4.6 high | Opus 4.6 high + Undercover |
|---|---|---|---|---|
| Suite passing / 16 | 16 | 16 | 16 | 16 |
| Fix sessions | 3 | 2 | 2 | 2 |
| Duration (incl. fixes) | 0:27 | 0:34 | 0:12 | 0:26 |
| Turns | 221 | 292 | 148 | 245 |
| Input tokens | 10M | 24.9M | 6.4M | 19.3M |
| Output tokens | 80K | 90K | 26K | 41K |
| Lib LOC | 509 | 408 | 474 | 379 |
| Test LOC | 489 | 749 | 468 | 635 |
| Tests written | 36 | 79 | 41 | 69 |
| Test/impl ratio | 0.96 | 1.84 | 0.99 | 1.68 |
| Line coverage | 94% | 100% | 78% | 100% |
| Branch coverage | 75% | 100% | 65% | 100% |
| Undercover runs | 0 | 20 | 0 | 15 |
| Cost | $5.12 | $9.99 | $4.76 | $13.66 |

None of the models passed the blind suite on the first session. Every run needed at least one fix session, included in the totals.

The fix sessions weren't equal either, with plain agents hitting real bugs in the blind BDD suite: incorrect constant loading that was never exercised in tests, and a genuine restack logic error. The skill agents needed fixes too, but only for surface-level output formatting differences.

Both skill variants wrote leaner implementations (408 vs 509 LOC for Sonnet, 379 vs 474 for Opus). The reviewer agent highlighted overly defensive (and unexercised in tests) error handling that the skilled agents removed.

Skill runs cost roughly 2x more. The feedback loop accumulated context across turns, and cache read tokens dominated the total. Sonnet was also subjectively much slower throughout, spending noticeably more time in thinking mode.

One caveat on duration: all agents took the testing sandbox prompt instruction too literally and ran every test against a tmpdir repo with a bare remote. A more sensible unit/integration split would be faster, which likely wouldn't happen with a better prompt.

### Wrap up

All four models landed on a similar code structure, but the skilled runs produced solutions with fewer and less severe bugs, according to the blind suite and the reviewer model.

The plain runs finished at only 65-75% branch coverage. Every future PR that ships like that widens the gap between what the code claims to handle and what's been verified. The skill not only helped steer the LLM to keep coverage high, but also helped it identify bugs and refrain from making redundant additive changes, which models are often eager to do when left on their own.

One thing I keep wondering: current models already know how to test impressively well, and the things we spell out carefully in prompts are often things they already know. The plain runs wrote tests without being told how, nor was that know-how included in the skill. So how much headroom does the skill actually have as models improve? The gap isn't about knowledge but about momentum. The skill is an active constraint, not a hint.

The plugin: [github.com/grodowski/undercover-claude](https://github.com/grodowski/undercover-claude)

The plugin is pending Anthropic review. Once approved, you'll be able to install it with:

```sh
claude plugin install undercover
```

Until then, clone the repo and load it with `--plugin-dir`:

```sh
git clone https://github.com/grodowski/undercover-claude
claude --plugin-dir ./undercover-claude
```

[Undercover CI](https://undercover-ci.com) closes the same loop in CI as a GitHub status on every PR your team ships. Free for public repos, 14-day trial for private ones.

---

*Originally published at [grodowski.com](https://grodowski.com/2026/04/17/claude-code-undercover-skill.html).*
