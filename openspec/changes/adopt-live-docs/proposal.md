# Proposal

## Why

greeter-docs needs to read greeter-cli's requirements and the latest test
results. Today the Cucumber tags do not match the OpenSpec headings
(`@requirement-guest-greeting` matches no heading), RSpec examples carry no
requirement metadata, and nothing checks that every requirement has a test.
greeter-core is adopting the same `live-docs-traceability` capability; this
change applies the shared rules here, where tests are both Cucumber and RSpec.

## What Changes

- Shared slug rule: lowercase the heading text, replace each run of characters
  other than `a-z0-9` with one `-`, trim `-` from both ends.
- Coverage:
  - `cli-greeter` (5 requirements) is covered by Cucumber. Each scenario in
    `features/greeting.feature` gets `@requirement-<slug> @scenario-<slug>`;
    the feature-level `@requirement-guest-greeting` is removed.
  - `acceptance-gate` (5 requirements) is covered by RSpec. Examples in
    `spec/workflows/cd_contract_spec.rb` and
    `spec/unit/bin/check_acceptance_ref_spec.rb` get `requirement:` /
    `scenario:` metadata.
  - The new `live-docs-traceability` requirements are covered by the new RSpec
    tooling specs.
- Trace writers, one file per CI job, schema `greeterhq.repo-trace.v1`, holding
  only slugs, statuses, locations and run metadata:
  - RSpec: `spec/support/repo_trace_formatter.rb` (`source: rspec`).
  - Cucumber: new `features/support/repo_trace.rb` (`source: cucumber`,
    `location: features/<file>:<line>`).
  - The existing `features/support/traceability.rb` and its
    `traceability-report` artifact stay unchanged.
- `bin/merge-repo-trace` merges the two job traces into one, failing on any
  mismatch or duplicate.
- `spec/trace_check_spec.rb` parses OpenSpec markdown directly (no Node, no
  OpenSpec CLI). It reads main specs and the ADDED/MODIFIED sections of
  non-archived changes. It scans `spec/**/*.rb` and `features/**/*.feature`,
  skipping `spec/fixtures/**`. It fails on an untagged requirement, an unknown
  requirement slug, or a scenario slug that isn't one of its requirement's
  scenarios.
- A tag-only check proves that edits to existing spec and feature files only
  add or change tags.
- `ci.yml`:
  - `spec` writes `tmp/repo-trace-spec.json` and `bdd` writes
    `tmp/repo-trace-bdd.json`. Each uploads its file (retention 1 day).
  - A new `trace` job merges the two and uploads `repo-trace` (retention 90
    days).
  - `notify-docs` sends `docs-refresh` to greeter-docs.
  - `trace` and `notify-docs` run only on push to `main` and the weekly
    schedule `17 6 * * 1`.
- `exe/` and `lib/` do NOT change.

## Capabilities

### New Capabilities

- `tooling/live-docs-traceability`: slug rule, trace check, trace writers,
  merge, CI publication. Same capability name as greeter-core's.

### Modified Capabilities

None. `cli-greeter` and `acceptance-gate` keep their requirement and scenario
text.

## Impact

- Existing files edited (tags only, enforced by the tag-only check):
  `features/greeting.feature`, `spec/workflows/cd_contract_spec.rb`,
  `spec/unit/bin/check_acceptance_ref_spec.rb`.
- Other edited files: `.github/workflows/ci.yml` (including top-level
  `permissions: contents: read`), `.rspec`, `.rubocop.yml` (file-scoped
  exclusions), `.talismanrc` (checksums), `README.md` (`## Testing`), and
  `AGENTS.md` and `openspec/config.yaml` (traceability rules scoped by
  capability).
- New files: `spec/support/` (slug, trace check, tag-only diff, trace document,
  formatter), `features/support/repo_trace.rb`, `bin/merge-repo-trace`, the
  tooling specs, and fixtures under `spec/fixtures/`.
- Requires repo variable `DISPATCH_APP_CLIENT_ID` and secret
  `DISPATCH_APP_PRIVATE_KEY`, with the App installed on `greeter-docs`.
- Applying this change edits files under `spec/` and `features/`. That needs
  the same explicit exception as `run-features-against-exe`.

## Non-goals

- No change to CLI behaviour, `exe/`, `lib/` or `greeter-core`.
- No change to existing requirement or scenario text.
- No change to `cd.yml` or the acceptance gate.
- No change to `features/support/traceability.rb` or `tmp/traceability.json`.
- `perf/greeting_bench.rb` is not RSpec, no requirement depends on it, and it
  stays out of the trace.
- No greeter-docs changes.
- No tags on tests that verify no scenario.
