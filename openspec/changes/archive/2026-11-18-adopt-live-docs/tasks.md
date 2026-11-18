# Tasks

## 1. Red tests

The maintainer runs `tests-open` before this group and `tests-close` after 1.12.

- [x] 1.1 Write `spec/unit/support/slug_spec.rb` with the design's slug table and every real requirement and scenario heading, using hand-written slugs. Tag it `requirement: 'every-requirement-has-a-tagged-test', scenario: 'slug-rule-turns-headings-into-slugs'`.
- [x] 1.2 Write `spec/trace_check_spec.rb` and fixtures under `spec/fixtures/trace_check/`: `specs/`, `changes/in-flight-change/`, `changes/archive/2026-01-01-archived-change/`, `examples/*.rb` and `features/*.feature`. Cover the untagged requirement, unknown slugs in both RSpec and Cucumber, a scenario slug under another requirement, a same-text scenario, in-flight versus archived and REMOVED/RENAMED headings, and fixture exclusion, plus one example on the real repo. Tag each example with its `live-docs-traceability` scenario.
- [x] 1.3 Write `spec/unit/support/repo_trace_formatter_spec.rb` and fixtures under `spec/fixtures/repo_trace/` covering the v1 document, skipped versus pending, malformed values and description privacy.
- [x] 1.4 Write `spec/unit/support/cucumber_repo_trace_spec.rb` and fixtures under `spec/fixtures/repo_trace_cucumber/` covering the v1 document with `source: cucumber`, `Scenario:` line locations, pending versus skipped, malformed tags, and no scenario names or step text in the output.
- [x] 1.5 Write `spec/unit/bin/merge_repo_trace_spec.rb`, which runs `bin/merge-repo-trace` as a subprocess. Cover the merge, each mismatched field including `run_id` null versus non-null, shape errors per source, and a duplicated result.
- [x] 1.6 Write `spec/workflows/ci_contract_spec.rb` with one example per CI scenario, the `--dry-run` check of the `spec` rspec command, the `cd.yml` `package` guard, and an example checking that top-level `permissions` is exactly `{contents: read}` and that no job's `permissions` grants `write`.
- [x] 1.7 Write `spec/unit/support/tag_only_diff_spec.rb` and before/after pairs in `spec/fixtures/tag_only/` for each case in the design.
- [x] 1.8 Add the tags only, with no other edits, to `features/greeting.feature`, `spec/workflows/cd_contract_spec.rb` and `spec/unit/bin/check_acceptance_ref_spec.rb`, following the design's mapping table. Remove `@requirement-guest-greeting`.
- [x] 1.9 (S8) In the formatter, Cucumber writer and merge specs, add cases where a location containing `..`, `.`, an empty segment, a leading `/` or line `0` is rejected (writer raises `invalid location` and writes nothing, merge exits non-zero naming the file and `location`). Add one case where a valid nested path such as `spec/unit/bin/x_spec.rb:12` is accepted.
- [x] 1.10 (S9) In `spec/unit/bin/merge_repo_trace_spec.rb`, add cases where both inputs carry the same malformed `sha`, `run_id` or `recorded_at`, or the same wrong `schema` or `repo`. Each must exit non-zero naming that field and write no output. In the formatter and Cucumber writer specs, assert `recorded_at` matches `\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z`.
- [x] 1.11 (S10) In `spec/workflows/ci_contract_spec.rb`, add examples for the `notify-docs` mint step. It sets `permission-contents: write` and no other `permission-*` input, it has no `skip-token-revoke`, it is the step directly before the `gh api` dispatch step, and `notify-docs` declares no `outputs`.
- [x] 1.12 Run `bundle exec rspec` and confirm each new spec is red for the right reason (NameError, a missing file or an expectation failure, not a syntax error). Commit as `test(adopt-live-docs): red`.

## 2. Implementation

The maintainer runs `tests-open` before apply and `tests-close` after it.

- [x] 2.1 Add `spec/support/repo_trace/slug.rb` and `spec/support/repo_trace/check.rb`. Verify: the slug and trace-check specs pass.
- [x] 2.2 Add `spec/support/repo_trace/document.rb`, plus `spec/support/repo_trace_formatter.rb` and the `.rspec` `--require` line. Verify: the formatter spec passes.
- [x] 2.3 Add `features/support/repo_trace.rb` and leave `features/support/traceability.rb` unchanged (`git diff --exit-code main -- features/support/traceability.rb`). Verify: the Cucumber writer spec passes.
- [x] 2.4 Add `bin/merge-repo-trace` (executable, stdlib only). Verify: the merge spec passes.
- [x] 2.5 Add `spec/support/repo_trace/tag_only_diff.rb`. Verify: the tag-only spec passes.
- [x] 2.6 Update `ci.yml` with top-level `permissions: contents: read`, the schedule, the `spec` and `bdd` trace env and uploads, the `trace` job and the `notify-docs` job. Keep `traceability-report`. Verify: `ci_contract_spec` passes.
- [x] 2.7 Add the file-scoped `.rubocop.yml` exclusions. Refresh the `.talismanrc` checksums for flagged code and workflow files. The spec-artifact entries under `openspec/changes/adopt-live-docs/` were already refreshed before the spec commit.
- [x] 2.8 (S8) Use the tightened location patterns in `spec/support/repo_trace/document.rb`. The formatter, the Cucumber writer and `bin/merge-repo-trace` all validate through it. Verify: the 1.9 cases pass.
- [x] 2.9 (S9) In `bin/merge-repo-trace`, validate each input's `schema`, `repo`, `sha`, `run_id` and `recorded_at` before comparing the two inputs. Have the writers emit `recorded_at` as `YYYY-MM-DDTHH:MM:SSZ`. Verify: the 1.10 cases pass.
- [x] 2.10 (S10) In `ci.yml`, set `permission-contents: write` on the `notify-docs` mint step, place it directly before the dispatch step, and don't set `skip-token-revoke`. Verify: the 1.11 examples pass.
- [x] 2.11 Manual, outside the repo: set `DISPATCH_APP_CLIENT_ID` and `DISPATCH_APP_PRIVATE_KEY`, and install the App on `greeter-docs` with Contents write.

## 3. Verify and docs

- [x] 3.1 Run `bundle exec rspec`, `bundle exec cucumber` and `bin/merge-repo-trace tmp/repo-trace.json tmp/repo-trace-spec.json tmp/repo-trace-bdd.json`. Confirm both sources appear, all 15 requirements are covered, and `grep -c Alice tmp/repo-trace*.json` is 0.
- [x] 3.2 Run the tag-only check against `main` for `features/greeting.feature`, `spec/workflows/cd_contract_spec.rb` and `spec/unit/bin/check_acceptance_ref_spec.rb`. All must report no problems.
- [x] 3.3 Run `bundle exec rubocop` with no offenses.
- [x] 3.4 Run `openspec validate --all --strict` and confirm it passes.
- [x] 3.5 Update `README.md` `## Testing` with the trace files, the merge command and the slug rule.
- [x] 3.6 Scope the repo rules as described in the design's Decisions. In `AGENTS.md` ("OpenSpec ↔ Cucumber traceability") and `openspec/config.yaml` (`context` and `rules.specs`), say that the Cucumber-mapping and CLI-observable rules apply to `greeting/cli-greeter`, and that `release/` and `tooling/` capabilities are verified by RSpec examples tagged `requirement:`/`scenario:`. Verify: `git diff` on both files shows only those lines.
- [x] 3.7 Prove red in CI first, and put the failing run's URL in the PR description. Done after the merge of #17, so the URL is on the archive PR instead. Red run: https://github.com/greeterhq/greeter-cli/actions/runs/44385659170 (branch `red/adopt-live-docs`, commit `9ec2f66`: red tests `aacffeb` plus the `.rubocop.yml` exclusions only). Linting, Functional Tests, Security Test, Performance Test and OpenSpec passed; Unit Test failed with `212 examples, 150 failures`, `uninitialized constant RepoTrace`. Green run on `main`: https://github.com/greeterhq/greeter-cli/actions/runs/44380667909 (all 8 jobs, including Repo trace and Notify greeter-docs).
