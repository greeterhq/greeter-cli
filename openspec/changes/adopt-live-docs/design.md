# Design

## Trace file

One file, `tmp/repo-trace.json`, schema `greeterhq.repo-trace.v1`:
`{schema, repo: "greeter-cli", sha, recorded_at, run_id, results: [...]}`.
`sha` is `GITHUB_SHA` or `git rev-parse HEAD`; `run_id` is `GITHUB_RUN_ID` or
null; `recorded_at` is UTC ISO 8601. Each result is
`{requirement, scenario, status, source, location}`. Descriptions are never
written, so a guest name in an example title cannot leak.

Both writers share the merge rule: if the file exists, read it, append their
results, rewrite it. RSpec runs first in CI, so it starts a fresh file when none
exists. A local rerun of RSpec replaces earlier `source: rspec` results rather
than duplicating them; Cucumber does the same for `source: cucumber`.

## Writers

- RSpec: `RepoTraceFormatter`, registered in `spec/support/` (loaded by
  `spec_helper.rb`) and selected with `--format RepoTraceFormatter`. It reads
  `requirement` and `scenario` from example metadata and skips examples without
  both. Status maps `passed`, `failed`, `pending`, `skipped` (RSpec `pending`
  status is `pending`; a skipped example is `skipped`).
- Cucumber: `features/support/traceability.rb` in an `After` hook reads the
  `@requirement-` and `@scenario-` tags and `scenario.location`, and merges at
  exit (`at_exit`) rather than per scenario, to avoid rewriting the file five
  times. It writes only slugs, status and location.

## Slug function

A small pure module used by the trace check and tested by a table of examples
(for instance `Greets a named guest` -> `greets-a-named-guest`;
`Surfaces control/escape characters as an error` ->
`surfaces-control-escape-characters-as-an-error`). It lives under `spec/support/`
because only specs use it; `lib/` is untouched.

## Trace check

`spec/trace_check_spec.rb` globs `openspec/specs/**/spec.md`, extracts
requirement headings, then collects tagged slugs from RSpec metadata (loaded
examples) and `@requirement-` tags in `features/**/*.feature`. It fails naming
the requirement and spec file for an uncovered heading, and the slug and
example file for an unknown slug. The check logic takes the spec root and
feature/example sources as arguments so it can be tested against fixture
`spec.md` files under `spec/fixtures/`.

## Retagging

Scenario headings in `cli-greeter` equal the Cucumber scenario names, except
`Normalises casing and whitespace` against requirement
`Presents normalised casing and whitespace`. Requirement slug comes from the
`### Requirement:` heading, scenario slug from the `#### Scenario:` heading, so
that scenario's tags become `@requirement-presents-normalised-casing-and-whitespace
@scenario-presents-normalised-casing-and-whitespace`. The scenario titles in the
feature file are renamed only if the tag-to-heading match requires it; tags are
what is checked.

## CI

- `spec` job: `bundle exec rspec --format progress --format RepoTraceFormatter`
  (plus existing html output), then cucumber in the same job (replacing the
  separate `bdd` job's trace upload), then `upload-artifact@v6` `repo-trace` with
  `retention-days: 90`, gated by
  `if: github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')`.
- Triggers: add `schedule: cron '17 6 * * 1'`.
- `notify-docs`: `needs` the spec job, same `if`, `permissions: {}`,
  `create-github-app-token@v3` (`client-id: vars.DISPATCH_APP_CLIENT_ID`,
  `private-key: secrets.DISPATCH_APP_PRIVATE_KEY`, `owner: greeterhq`,
  `repositories: greeter-docs`), then `gh api` with the token in `GH_TOKEN` via
  `env:` sending `docs-refresh` and `-f client_payload[repo]=greeter-cli`.
- The scheduled run is not a tag push, so `cd.yml` (which follows tag pushes
  via `workflow_run`) does not run and no release is created. This repo has no
  RubyGems publish job, so that rule is already met.

## Decisions to confirm

- The brief says every requirement in `greeting-core` and `ports` must be
  covered. Those belong to greeter-core. Here the rule applies to the
  requirements in this repo: `cli-greeter` and `acceptance-gate`. This design
  assumes that.
- `ci.yml` currently also builds on tag pushes. `notify-docs` is limited to
  `main` and schedule, so tags never dispatch.
- The existing `traceability-report` artifact (`tmp/traceability.json`) is
  removed with the old writer.
