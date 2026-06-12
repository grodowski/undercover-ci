---
title: 4 ways to steer your agents towards better tests with Undercover CI
date: 2026-06-11
description: Feedback loops for agentic coding were a hot topic at latest RubyConf in Vienna. UndercoverCI shares recipes to help your team ship diffs without testing gaps.
---

My highlight for the month of May was RubyConf Austria! Combining a full time role, work on undercover, social life and training adds up to... me being a rare guest on programming conferences. But what an event this was, hats off to Muhamed, Hans and team, as well as all speakers and performing musicians for pulling this off.

![panel_haus_der_musik](rubyconf_vie_panel.jpeg)

<p class="post-caption">Hans Schnedlitz, Armin Ronacher, Chad Fowler, Obie Fernandez and José Valim discussing the future of coding.</p>

The main theme, including a large portion of the hallway track, was the paradigm shift we're experiencing with agentic coding: what it means for Ruby, for our craft and the tools we use. The conclusion among speakers, panelists and participants was that while agents are improving constantly, our role and responsibility shifts to being the gatekeepers of what gets accepted and owning the code changes landing in production every day. In exactly that spirit, I'd like to walk you through my daily-driver test coverage tooling.

## But does it work?

In my previous post "Teaching Claude Code to Test What Breaks" I ran a contrived experiment to check whether a test coverage harness with `undercover` will have any effects on the code produced by Opus and Sonnet models. Agents were prompted to implement a sample but complex-enough CLI app. All were asked to supply tests, but only half followed the workflow of writing tests *and* reviewing their coverage prescibed by the `/coverage` skill.

**TLDR: the feedback loop produced fewer LOC overall, overly defensive and redundant blocks were removed (good) and there were fewer and more surface level bugs. Check out the [original writeup](https://undercover-ci.com/blog/claude-code-experiment) for more details.**

Of course there is a cost: more time, tokens and turns. I think it's a worthy investment, because Claude Code, being trained to complete the given task, may as well say "good enough" to tests with < 75% branch coverage. In fact, I've just finished iterating on a PR stack today at `$main_job`, where a similar feedback loop was employed in a GPT 5.5 `pi` agent. Here is how it could work for your team.

## 1. Pre-commit coverage check

The baseline `undercover` local check: do any methods in my feature branch diff require additional tests?

```bash
undercover --compare origin/main --format json
undercover: ✅ No coverage is missing in latest changes
Undercover finished in 0.0974s
```

A more condensed and agent-friendly option: `--format json`, recently added in `undercover v0.8.5`.

```bash
undercover -c master --simplecov coverage/undercover_coverage.json --format json
{
  "warnings": [],
  "summary": {
    "total_warnings": 0,
    "files_affected": 0
  }
}
Undercover finished in 0.0798s
```

A failure with 1 warnings:

```
undercover -c master --simplecov coverage/coverage.json --format json
{
  "warnings": [
    {
      "node": "email_subject",
      "type": "instance method",
      "file": "app/mailers/user_mailer.rb",
      "first_line": 12,
      "last_line": 20,
      "coverage": 0.8,
      "uncovered_lines": [
        16
      ],
      "uncovered_branches": [
        {
          "line": 16,
          "block": 0,
          "branch": 1,
          "description": "then"
        }
      ]
    }
  ],
  "summary": {
    "total_warnings": 1,
    "files_affected": 1
  }
}
```

Your coding agent will know what to do with this data.

## 2. AGENTS.md

A step further would be to instruct our coding buddy to check for coverage on their own, when necessary, without intervention and get back to us with results that meet our standards.

Here's a compact `AGENTS.md` snippet that I use daily. Assumes you have SimpleCov and Undercover set up.

```text
# AGENTS.md
Run `undercover -c origin/main --format json` after a successful test run to check test coverage of your changes.
Create new or update existing tests if any methods were flagged by `undercover`, until sufficient coverage is reported.
```

In my experience agents based on newer models figure out on their own how to filter specs and run just the right subset of files to meet the `undercover` guard.

## 3. Claude Code `/coverage` skill

The above feedback loop is available to the `/coverage` skill, which has some more capabilities. Besides making the agent loop between implementation and testing reviews, it will run coverage and tests more selectively (via `--include-files`) and debate and suggest skipping certain tests via `:nocov:`.

A few ways you can run it:

```text
/coverage set up coverage for this Rails app
```

Adds `simplecov` and `undercover` to the Gemfile, wires `SimpleCov::Formatter::Undercover` and creates `.undercover` with `-c origin/main`. Local agent permissions will be updated so the loop runs without prompts too.

```text
/coverage keep changes covered as we go
```

Run undercover after each change with the correct args and fills gaps.

```text
/coverage check the coverage feedback on this PR and fix it
```

Pulls the coverage check's annotations, adds the missing tests and verifies locally.

Go check out the [undercover-claude readme](https://github.com/grodowski/undercover-claude) for setup instructions and more details.

## 4. PR feedback with UndercoverCI

Finally, if you work in a team, I would recommend having a fast feedback loop like one of the above, as well as a CI step that reviews every pull requests and enforces a common quality bar for everyone.

One way to achieve it is to set up GitHub Checks powered by UndercoverCI. Every warning will be delivered as a check annotation, right in the diff, alongside a summary of all changed classes, blocks and methods, decorated with coverage data.

While reading these is a timely conversation starter for you and your reviewers to decide if the testing quality and meets your standards, the agents can take over smoothly as well. The below prompt is all you need, given your agent can access an authorized `gh` CLI.

```text
Address undercover feedback from https://github.com/grodowski/undercover-ci/pull/809
```

This gets us from:

![cov_output_with_warning](coverage_agent_fail.png)

To:

![cov_output_with_pass](coverage_agent_pass.png)

✨

There's a final plot twist and caveat here. I wanted to use the Claude for Slack app and ask `@Claude` to address coverage feedback in the above PR. Unfortunately, it didn't go smoothly. The GitHub MCP accessible to Claude for Slack trim down Check API responses and don't include annotations and summaries, resulting in the agent guessing.

Why wasn't this an issue for the local agent? It could read check annotations and summaries with a direct `gh api` call.

So stay tuned, maybe Claude or the GitHub MCP will change soon, or I will add a dedicated MCP for UndercoverCI to expose check results to agents: let me know if you would be interested to use it.

Thank you for reading! Would you like to implement a similar feeback loop at your engineering organization? Feel free to reach out at [jan@undercover-ci.com](mailto:jan@undercover-ci.com).