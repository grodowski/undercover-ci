---
title: Teaching Claude Code to Test What Breaks
date: 2026-04-17
description: A weekend experiment measuring how much the undercover-claude Claude Code plugin changes test quality. Same prompt, four runs, two models, with and without Undercover.
---

We built the same Ruby CLI four times with Claude Code, with two models with and without a coverage skill, and scored every run against a test suite the agent never saw. A word of caution: this is a weekend experiment and not a rigorous study, so take the numbers accordingly.

The CLI is `gt`, a tool for managing stacked pull requests (think Graphite). Stacked PRs let you split a large change into a chain of smaller, reviewable branches that rebase onto each other. `gt` automates the branching, rebasing, and PR management from the command line. Six commands, a git sandbox for testing, GitHub API integration: real enough to stress-test an agent without becoming a research project.

### The evaluation

Scoring is done by a blind BDD suite the agents never saw. It runs in a fresh tmpdir repo with a bare remote, `gh` stubbed out, and `bin/gt` invoked as an external process. The agent writes its own tests during implementation, but those tests don't determine the score.

After scoring, an LLM reviewer assessed each implementation: code structure, separation of concerns, error handling depth, and test quality.

### Undercover

[undercover-claude](https://github.com/grodowski/undercover-claude) is a Claude Code plugin built around the [undercover gem](https://github.com/grodowski/undercover).

The plugin does two things. First, it sets up SimpleCov and undercover at the start of a new project before any tests are written. Second, it enforces a feedback loop: after getting to a successful test run, Claude runs `bundle exec undercover` to check which changed lines aren't covered, writes tests for the gaps, and repeat until undercover exits 0.

The key detail: undercover checks only the lines in the current diff, not the total coverage. The feedback is always scoped to what was just written.

### The prompt

All four runs got the same prompt to build `gt` from scratch, available for you to read in the [gt-eval repo](https://github.com/grodowski/gt-eval), alongside the actual result builds, the scoring test suite and all helper scripts.

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

### What the plain runs missed

The starter prompt explicitly asked for tests with a `GitSandbox` helper and required tests to pass before each commit. Uninstructed agents wrote tests reasonably well on their own. The plain runs produced 36-41 test cases each with meaningful assertions, but the skilled agents were pushed past the point where they'd naturally stop.

That stopping point matters. The plain run test files follow a consistent pattern of covering the happy path. There was no friction forcing the agent to test the errors. Opus plain produced the most idiomatic implementation of the four (according to the reviewer), with typed `Git::Error` exceptions, a dedicated `GH` module that degrades gracefully when the `gh` executable isn't available, and clean separation of concerns. Yet, it still left the entire GitHub integration untested.

Sonnet plain's rebase conflict implementation is another example: the defensive error path exists but is broken and untested. It swallows the rebase error, then proceeds to force push and reports success after a failed rebase, while corrupting the remote. Skilled implementations did not have this bug.

### What undercover caught

Iterating on the implementation, the Sonnet + Undercover run found gaps 7 times across 20 undercover checks, while Opus + Undercover found gaps 5 times across 15 runs.

Running `undercover` surfaced a failure path in `gt sync` and pushed Claude to split `git pull` into separate fetch and merge steps, with fetch failures becoming non-fatal warnings. The coverage requirement surfaced a specification gap.

After implementing `gt create`, undercover flagged the push failure code branch and the PR creation path that follows it. Both were unexercised: no test tried to push without a remote. Claude removed the origin remote in the sandbox to trigger the failure path and verified the local branch was still created. A new test documents that `gt create` degrades gracefully without a remote rather than crashing.

Finally, the plain runs' tests are mostly integration-style: build a stack, run a command, assert the outcome, while the skill runs add a second layer. Sonnet skill introduced explicit error-path tests via stubbing (e.g. `test_create_fails_when_git_add_fails`, `test_create_fails_when_commit_fails`) and push-failure degradation tests. Opus skill added dedicated `git_test.rb` and `stack_test.rb` files that unit-test internal modules directly. Those are the tests that close the branch coverage gaps in error handling.

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

None of the models passed the blind suite initially. Every run needed at least one fix session, included in the totals.

The fix sessions weren't equal either. One plain agent had a naming clash between its own `CLI` class and `::CLI` module from the `cli-ui` gem, never caught by its own tests. One also failed to handle more than one `gt` stack branching out from root. One silently corrupted the remote on a failed restack. The skill agents needed fixes too, but only for surface-level output formatting differences, like a different kind of unicode arrow being used.

Both skill variants wrote leaner implementations (408 vs 509 LOC for Sonnet, 379 vs 474 for Opus). The qualitative review flagged overly defensive (and unexercised in tests) error handling that the skilled agents didn't have.

Skill runs cost roughly 2x more as they accumulated context across turns. Sonnet was also subjectively much slower throughout, spending noticeably more time in thinking mode.

One caveat on duration: all agents took the testing sandbox instruction too literally and way too many tests against a tmpdir repo with a bare remote, while a more sensible unit/integration split would be faster. This could be improved with a better prompt.

### Wrap up

All four models landed on a similar code structure, but the skilled runs produced solutions with fewer and less severe bugs, per both the blind suite and our qualitative review.

The plain runs finished at only 65-75% branch coverage, which would compound over time and widen the gap between what the code claims to handle and what's been verified in a real world project shipping new PRs continuously. The skill not only helped steer the LLM to keep coverage of changes high, but also helped it identify real issues and refrain from making redundant additive changes, which models are often eager to do when left on their own.

One thing I keep wondering: current models already know how to test impressively well, and the things we spell out carefully in prompts are often things they already know. The plain runs wrote tests without being told how, nor was that know-how included in the skill. So how much headroom does the skill actually have as models improve? While this isn't a knowledge gap, the LLM agents produce better code with active constraints.

---

The plugin is [github.com/grodowski/undercover-claude](https://github.com/grodowski/undercover-claude). It's pending Anthropic review. Once approved: `claude plugin install undercover`. Until then:

```sh
git clone https://github.com/grodowski/undercover-claude
claude --plugin-dir ./undercover-claude
```

[Undercover CI](https://undercover-ci.com) closes the same loop in CI as a GitHub status on every PR your team ships. Free for public repos, 14-day trial for private ones.

---

*Originally published at [grodowski.com](https://grodowski.com/2026/04/17/claude-code-undercover-skill.html).*
