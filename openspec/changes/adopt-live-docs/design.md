# Design

## Context

greeter-docs reads requirement slugs and test statuses for each repo. The slug
rule, the trace-check rules and the `greeterhq.repo-trace.v1` schema are shared
across greeterHQ repos, and greeter-core's `adopt-live-docs` design is the
reference. This design follows it and adds what greeter-cli needs on top:
Cucumber as a second test source, and `spec`/`bdd` as the two CI jobs that
produce traces.

Current state that matters:
- `features/greeting.feature` has a feature-level `@requirement-guest-greeting`
  (matches no heading) and `@scenario-*` tags. One of them,
  `@scenario-normalises-casing-and-whitespace`, matches no heading.
- `features/support/traceability.rb` writes `tmp/traceability.json` per
  scenario, and `bdd` uploads it as `traceability-report`. Both stay.
- `spec/spec_helper.rb` already requires every file under `spec/support/**`.
  Tooling specs therefore live under `spec/unit/`, not `spec/support/`, so the
  loader never requires a `_spec.rb` file.
- `ci.yml` has `lint` → `spec`, `bdd`, `security`, `perf`, `spec-gate`, no
  top-level `permissions`, and no publish job.
- `cd.yml` fires on every CI completion (`workflow_run`), including scheduled
  ones. Its `package` job runs only when the CI run's event is `push` and its
  head branch starts with `v`, and every later job needs `package`. So a
  scheduled CI run starts a CD run whose jobs are all skipped.

`exe/` and `lib/` do not change.

## Decisions

### Slug helper
`spec/support/repo_trace/slug.rb` defines `RepoTrace::Slug.call(text)`:
`text.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')`. There is no
camel-case splitting. `spec/unit/support/slug_spec.rb` asserts the table below,
plus every real heading. Each expected slug is written out by hand, not
computed with the function under test.

| Heading text | Slug |
|---|---|
| Greets a named guest | greets-a-named-guest |
| Presents normalised casing and whitespace | presents-normalised-casing-and-whitespace |
| Surfaces an empty or whitespace-only name as an error | surfaces-an-empty-or-whitespace-only-name-as-an-error |
| Surfaces an over-long name as an error | surfaces-an-over-long-name-as-an-error |
| Surfaces control/escape characters as an error | surfaces-control-escape-characters-as-an-error |
| Rejects an empty or whitespace-only name | rejects-an-empty-or-whitespace-only-name |
| Rejects a name longer than 64 characters | rejects-a-name-longer-than-64-characters |
| Rejects names containing control or escape characters | rejects-names-containing-control-or-escape-characters |
| Failed acceptance gate blocks release and announcement | failed-acceptance-gate-blocks-release-and-announcement |
| Gate failure stops the release | gate-failure-stops-the-release |
| Release is published from the tested tarball | release-is-published-from-the-tested-tarball |
| Gate passes and release uses the same tarball | gate-passes-and-release-uses-the-same-tarball |
| Released versions are announced for prod and stage | released-versions-are-announced-for-prod-and-stage |
| Release is announced to both environments | release-is-announced-to-both-environments |
| Announce holds only a single-repository App token | announce-holds-only-a-single-repository-app-token |
| Announce has no ambient token rights | announce-has-no-ambient-token-rights |
| Gate ref and acceptance_ref must agree | gate-ref-and-acceptance-ref-must-agree |
| Matching semver refs pass | matching-semver-refs-pass |
| Mismatched refs fail | mismatched-refs-fail |
| Non-semver ref fails | non-semver-ref-fails |
| `"  --Leading and trailing!!  "` | leading-and-trailing |

The `live-docs-traceability` headings in this change are added to the table too.

### Trace check
`spec/support/repo_trace/check.rb` defines
`RepoTrace::Check.call(spec_glob:, change_glob:, example_glob:, feature_glob:, exclude_glob:)`,
which returns problem strings. `spec/trace_check_spec.rb` runs it against the
fixtures, plus one example against the real repo:
`openspec/specs/**/spec.md`, `openspec/changes/**/specs/**/spec.md`,
`spec/**/*.rb`, `features/**/*.feature`, `spec/fixtures/**/*`.

- Headings: `^### Requirement:\s*(.+)$` and `^#### Scenario:\s*(.+)$`. A
  scenario belongs to the requirement above it.
- Change deltas: paths under `changes/archive/` are skipped. Only headings
  inside `## ADDED Requirements` and `## MODIFIED Requirements` count, and
  `## REMOVED` and `## RENAMED` are ignored. A slug in both a main spec and a
  MODIFIED delta combines the scenarios. Delta requirements need a tagged test
  too, so this change's own requirements are enforced before archive.
- RSpec tags are found by scanning text, not loaded metadata, using
  `requirement:\s*'([^']+)',\s*scenario:\s*'([^']+)'`. `\s` allows the pair to
  wrap lines, and requirement always comes before scenario.
- Cucumber tags are found by scanning text too. For each `Scenario:` or
  `Scenario Outline:` line, the tags are the tag lines directly above it plus
  any feature-level tags. `@requirement-(\S+)` and `@scenario-(\S+)` must each
  appear exactly once. The location is the `Scenario:` line.
- Requirement slugs match across all spec files. Scenario slugs match only
  within their requirement. A scenario slug equal to its requirement slug is
  valid.
- Problems:
  - `requirement "<slug>" (<spec.md>) has no tagged test`
  - `test tagged requirement "<slug>" (<file>:<line>) matches no requirement heading`
  - `test scenario "<slug>" (<file>:<line>) is not a scenario of requirement "<slug>"`
  - `scenario at <file>:<line> needs exactly one @requirement- and one @scenario- tag`
- Fixtures in `spec/fixtures/trace_check/`:
  - `specs/alpha/spec.md`: covered, uncovered and same-text requirements.
  - `changes/in-flight-change/specs/alpha/spec.md`: ADDED, MODIFIED, REMOVED
    and RENAMED sections.
  - `changes/archive/2026-01-01-archived-change/specs/alpha/spec.md`.
  - `examples/*.rb`: RSpec tag lists that don't end in `_spec.rb`.
  - `features/*.feature`: Cucumber tag lists.
- `perf/greeting_bench.rb` sits outside `spec/` and isn't scanned.

### Shared trace document
`spec/support/repo_trace/document.rb` defines `RepoTrace::Document`, which both
writers use:
- `result(requirement:, scenario:, status:, source:, location:)` validates each
  value.
- `write(path:, results:, env:, clock:, root:)` builds and writes the file.

Validation patterns:
- slug: `\A[a-z0-9]+(-[a-z0-9]+)*\z`
- rspec location: `\Aspec(?:/[\w-][\w.-]*)+\.rb:[1-9]\d*\z`
- cucumber location: `\Afeatures(?:/[\w-][\w.-]*)+\.feature:[1-9]\d*\z`
  (each path segment starts with a word character or `-`, so `.`, `..`,
  empty segments and absolute paths are rejected; see S8)
- sha: `\A[0-9a-f]{40}\z`
- run_id: `\A\d+\z` or nil
- recorded_at: `\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z` (see S9)
- schema: exactly `greeterhq.repo-trace.v1`; repo: exactly `greeter-cli`
- status: one of `passed|failed|pending|skipped`

A violation raises a message starting `invalid <field>`. It never echoes the
value, and no file is written.

Other details:
- `sha` comes from `GITHUB_SHA`, else `git rev-parse HEAD` (run as an argv
  array, no shell).
- `run_id` comes from `GITHUB_RUN_ID`, else `nil`.
- `recorded_at` is `clock.call.utc.iso8601`. The no-`Time.now` rule applies to
  the domain only.
- `repo` is `greeter-cli`.
- Results are de-duplicated on (requirement, scenario, location), keeping the
  worst status (failed, pending, skipped, passed). They are sorted by location,
  then requirement, then scenario.
- Parent directories are created. `tmp/` is already git-ignored.

### RSpec formatter
`spec/support/repo_trace_formatter.rb` defines `RepoTraceFormatter`, registered
for `:example_passed, :example_failed, :example_pending, :dump_summary`. It
records each example that has both `requirement` and `scenario` metadata
(inherited from enclosing groups).
- Status: RSpec reports both skip and pending as `:example_pending`. A truthy
  `metadata[:skip]` maps to `skipped`; otherwise the example is `pending`.
- `location` is `example.location` relative to the repo root.
- It reads only the slug metadata, the status and the location. It never reads
  description, full_description or the exception.
- The output path is `ENV['REPO_TRACE_PATH']`, default
  `tmp/repo-trace-spec.json`.
- `.rspec` gains `--require ./spec/support/repo_trace_formatter`, so
  `--format RepoTraceFormatter` resolves. The formatter writes only when
  selected.
- `spec/unit/support/repo_trace_formatter_spec.rb` runs fixture example files
  (`spec/fixtures/repo_trace/*.rb`: statuses, privacy, malformed tag) in a
  subprocess:
  `rspec --options /dev/null --require <formatter> --format RepoTraceFormatter <fixture>`,
  with `REPO_TRACE_PATH` in a temp dir.

### Cucumber writer
New file `features/support/repo_trace.rb`, which requires the shared document.
- An `After` hook collects results for scenarios that have both tags. It reads
  `scenario.source_tag_names` and `scenario.location`, never `scenario.name`
  or step text.
- `AfterAll` writes the file.
- Status: `passed` and `failed` map directly. `pending` and `undefined` map to
  `pending`, and `skipped` maps to `skipped`.
- The output path is `REPO_TRACE_PATH`, default `tmp/repo-trace-bdd.json`.
- Each writer defaults to its own file, so a local `rspec` then `cucumber` run
  never clobbers the other's file. `bin/merge-repo-trace` combines them.
- `features/support/traceability.rb` is not touched.
- `spec/unit/support/cucumber_repo_trace_spec.rb` runs
  `cucumber --require features/support/repo_trace.rb --require <fixture steps> <fixture feature>`
  in a subprocess. The fixture is under `spec/fixtures/repo_trace_cucumber/`,
  outside `features/`, so the main run never loads it.

### Merge script
`bin/merge-repo-trace OUT IN_A IN_B` uses only the stdlib (`json`, `time`) and
starts with `# frozen_string_literal: true`. It requires the shared document
for validation. `spec/unit/bin/merge_repo_trace_spec.rb` runs it as a
subprocess, the way CI calls it.
- It fails with exit 1 and a message on stderr, writing nothing, when:
  - `schema`, `repo`, `sha` or `run_id` differ (`null` equals only `null`).
    The message is `<field> differs`.
  - An input is outside the v1 shape. The message names the file and the field
    or key. The location pattern must match the result's `source`. The
    top-level values are validated too: `schema`, `repo`, `sha`, `run_id` and
    `recorded_at` must each match their pattern from the shared document, not
    only agree with the other input (S9).
  - A (requirement, scenario, location) triple is in both inputs. The message
    names the requirement and location.
- Otherwise it writes the shared top-level fields, the later `recorded_at`,
  and all results sorted as above.
- It parses with `JSON.parse`, never `JSON.load`.

### CI (`ci.yml`)
- `on:` gains `schedule: - cron: '17 6 * * 1'`.
- Top-level `permissions: contents: read` is added (see Decisions).
- The gate shared by `trace` and `notify-docs` is
  `github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')`.
- `spec` runs
  `bundle exec rspec --format progress --format html --out coverage/rspec.html --format RepoTraceFormatter`
  with step `env: REPO_TRACE_PATH: tmp/repo-trace-spec.json`. It then uploads
  `repo-trace-spec` with `retention-days: 1` and `if-no-files-found: error`.
  The upload uses the default success condition. The SimpleCov upload is
  unchanged.
- `bdd` runs `bundle exec cucumber --format progress` with
  `REPO_TRACE_PATH: tmp/repo-trace-bdd.json` and uploads `repo-trace-bdd` the
  same way. The `traceability-report` upload stays exactly as it is.
- `trace`:
  - `needs: [spec, bdd]`, `if: <gate>`, `permissions: {contents: read}`.
  - Steps: checkout with `persist-credentials: false`, then `ruby/setup-ruby`
    without bundler-cache (stdlib only).
  - Two `actions/download-artifact` steps by name, each into its own directory,
    with no `run-id` and no `merge-multiple`.
  - Then `bin/merge-repo-trace tmp/repo-trace.json <spec file> <bdd file>`,
    then upload `repo-trace` with `retention-days: 90` and
    `if-no-files-found: error`.
- `notify-docs`:
  - `needs: trace`, `if: <gate>`, `permissions: {}`.
  - `actions/create-github-app-token@v3` with
    `client-id: ${{ vars.DISPATCH_APP_CLIENT_ID }}`,
    `private-key: ${{ secrets.DISPATCH_APP_PRIVATE_KEY }}`, `owner: greeterhq`,
    `repositories: greeter-docs` and `permission-contents: write`, and no
    `skip-token-revoke` (S10). The mint is the step directly before the
    dispatch step.
  - Then
    `gh api repos/greeterhq/greeter-docs/dispatches -f event_type=docs-refresh -f client_payload[repo]=greeter-cli`,
    with `GH_TOKEN` from the step output in `env:`.
  - There is no fallback when credentials are missing.
- `trace` needs both test jobs to succeed, so a red `spec` or `bdd` publishes
  nothing.
- The scheduled run creates no release. `ci.yml` has no release or publish
  job, and `cd.yml`'s `package` guard skips every CD job on a non-push event.
  Nothing in `cd.yml` changes, and `ci_contract_spec` asserts the guard.
- `spec/workflows/ci_contract_spec.rb` parses both workflows with
  `YAML.safe_load_file` (`"on"` is quoted, so it loads as a string key). It
  also runs the `spec` job's rspec command with `--dry-run` and expects at
  least one example, which proves `--format RepoTraceFormatter` resolves.

### Tagging existing tests
Only tags change. In `.rb` files, `requirement:` / `scenario:` are added to
`describe`/`context` lines. In the feature file, only tag lines change. Tests
that verify no scenario stay untagged.

| File | Test | Requirement / scenario |
|---|---|---|
| `features/greeting.feature` | Greets a named guest | greets-a-named-guest / greets-a-named-guest |
| | Normalises casing and whitespace | presents-normalised-casing-and-whitespace / presents-normalised-casing-and-whitespace |
| | Rejects an empty or whitespace-only name | surfaces-an-empty-or-whitespace-only-name-as-an-error / rejects-an-empty-or-whitespace-only-name |
| | Rejects a name longer than 64 characters | surfaces-an-over-long-name-as-an-error / rejects-a-name-longer-than-64-characters |
| | Rejects names containing control or escape characters | surfaces-control-escape-characters-as-an-error / rejects-names-containing-control-or-escape-characters |
| `spec/workflows/cd_contract_spec.rb` | `describe 'Gate failure stops the release'` | failed-acceptance-gate-blocks-release-and-announcement / gate-failure-stops-the-release |
| | `describe 'Gate passes and release uses the same tarball'` | release-is-published-from-the-tested-tarball / gate-passes-and-release-uses-the-same-tarball |
| | `describe 'Release is announced to both environments'` | released-versions-are-announced-for-prod-and-stage / release-is-announced-to-both-environments |
| | `describe 'Announce has no ambient token rights'` | announce-holds-only-a-single-repository-app-token / announce-has-no-ambient-token-rights |
| | `describe 'Matching semver refs pass'` | gate-ref-and-acceptance-ref-must-agree / matching-semver-refs-pass |
| `spec/unit/bin/check_acceptance_ref_spec.rb` | context "match and are vX.Y.Z" | gate-ref-and-acceptance-ref-must-agree / matching-semver-refs-pass |
| | context "gate ref differs" | gate-ref-and-acceptance-ref-must-agree / mismatched-refs-fail |
| | contexts "gate ref is not vX.Y.Z", "acceptance_ref is not vX.Y.Z" | gate-ref-and-acceptance-ref-must-agree / non-semver-ref-fails |

Notes on the table:
- In the `.feature` file, the `@requirement-guest-greeting` line is deleted,
  and `@scenario-normalises-casing-and-whitespace` becomes
  `@scenario-presents-normalised-casing-and-whitespace`. Scenario names stay
  as they are, because renaming one would fail the tag-only check.
- `exists and is executable` and the four fail-closed contexts in
  `check_acceptance_ref_spec.rb` verify no OpenSpec scenario and stay untagged.

### Tag-only check
`spec/support/repo_trace/tag_only_diff.rb` defines
`RepoTrace::TagOnlyDiff.call(path:, before:, after:)`. It returns problem
strings naming `path`, and an empty list when the edit is allowed. Both texts
are normalised the same way and then compared.

For `.rb` files, normalisation does this:
1. Remove each tagged context wrapper. That is a
   `context '<text>', requirement: '...', scenario: '...' do` opener (which may
   wrap lines), only when its body is `it_behaves_like` lines, plus the `end`
   at the same indentation.
2. Remove `, requirement: '...'` and `, scenario: '...'`.
3. Remove all whitespace.

For `.feature` files, normalisation does this:
1. Remove every `@requirement-\S+` and `@scenario-\S+` token.
2. Remove all whitespace.

Any remaining difference is a problem. `spec/unit/support/tag_only_diff_spec.rb`
covers these cases, with fixtures as `before`/`after` pairs in
`spec/fixtures/tag_only/<case>/`:
- tags added: allowed
- assertion changed: fails
- wrapper around `it_behaves_like`: allowed
- wrapper that also changes an inner line: fails
- feature tag lines changed or removed: allowed
- feature step or scenario name changed: fails

The check runs during apply (task 3.2) against `main` for each existing file
edited. New files are not compared.

Known limit: whitespace is removed everywhere, including inside string
literals. The edited lines are few enough to review by eye.

### RuboCop
`.rubocop.yml` gains file-scoped exclusions only, each with a comment:
- `RSpec/SpecFilePathSuffix` for `spec/fixtures/**/*`
- `RSpec/DescribeClass` for the tooling specs and `spec/workflows/ci_contract_spec.rb`
- `RSpec/ExampleLength` and `RSpec/MultipleMemoizedHelpers` for the tooling specs
- `RSpec/IdenticalEqualityAssertion` and `RSpec/ExpectActual` for
  `spec/fixtures/repo_trace/*.rb`
- `RSpec/ContextWording` for `spec/fixtures/tag_only/**/*`

The exact list is confirmed when RuboCop runs.

## Security considerations

| # | Finding | Resolution |
|---|---|---|
| S1 | Trace values are rendered by greeter-docs. Tags and the env-supplied sha and run_id are free text. | Both writers and the merge script validate every value against fixed patterns and write nothing on a violation. Error messages never echo values. |
| S2 | The app token could carry every permission the App has on greeter-docs. | Scope it to `owner: greeterhq` and `repositories: greeter-docs`, and request `permission-contents: write` only. |
| S3 | Expressions interpolated into `run:` are the usual workflow injection route. | `trace` and `notify-docs` have no `${{` in `run:`, which `ci_contract_spec` asserts. The token is passed as `GH_TOKEN` via `env:`. |
| S4 | `trace` runs repo code on `main`. | Use `persist-credentials: false` and `permissions: {contents: read}`. |
| S4a | Without top-level `permissions`, existing jobs get the repository default token, which may be write-all. | Add top-level `permissions: contents: read`. `ci_contract_spec` asserts that exact value and that no job requests `write`. |
| S5 | Artifacts must come from the same run. | Download by name only, with no `run-id` and no `merge-multiple`. |
| S6 | PRs and forks. | The gate excludes `pull_request`, and fork PRs get no secrets. |
| S7 | `create-github-app-token@v3` is referenced by tag. | Kept as requested. SHA pinning belongs to `add-dependency-scanning`. |

### Security review findings

This review covered the formatter, the Cucumber writer, the shared document,
the merge script, the trace check, the tag-only check, the `ci.yml` changes and
the dispatch to greeter-docs. There are three trust boundaries:
- PR code, which is untrusted and gets no secrets, versus `main` and the
  schedule, which hold the App key.
- The published `repo-trace` artifact, which greeter-docs reads and renders.
- The `docs-refresh` payload, which greeter-docs reads.

| # | Finding | Severity | Resolution | Code? |
|---|---|---|---|---|
| S8 | The location patterns `spec/[\w./-]+\.rb` and `features/[\w./-]+\.feature` accept `..` segments, such as `spec/../../etc/x.rb:1`. If greeter-docs builds a link or file path from `location`, a crafted tag file or writer bug could point it outside the repo. | Medium | Tighten both patterns so every segment starts with `[\w-]`, which rejects `.`, `..`, empty segments and leading `/`, and require a line number of 1 or more. Apply the same patterns in the writers and the merge. | Yes: tasks 1.9, 2.8 |
| S9 | The merge checks that `schema`, `repo`, `sha` and `run_id` agree between its two inputs, but not that they are well-formed. It also copies `recorded_at` without checking it. Two inputs with the same malformed value, such as free text in `sha` or `recorded_at`, would be published. S1 claims the merge validates every value, and that claim doesn't yet hold. | Medium | The merge validates `schema == greeterhq.repo-trace.v1`, `repo == greeter-cli`, `sha` (40 hex), `run_id` (digits or null) and `recorded_at` (`YYYY-MM-DDTHH:MM:SSZ`) in each input before comparing them. The writers emit `recorded_at` in exactly that form. | Yes: tasks 1.10, 2.9 |
| S10 | S2 says the App token requests only `permission-contents: write`, but no task sets it and no test checks it. Without it, the token gets every permission the App holds on greeter-docs. Nothing yet stops `skip-token-revoke`, which would leave the token valid after the job, or a later step reordering that puts other steps between mint and use, against the rule to mint just before use. | Medium | Set `permission-contents: write` on the mint step. `ci_contract_spec` asserts that it is the only `permission-*` input, that `skip-token-revoke` is absent, that the mint step comes directly before the dispatch step in `notify-docs`, and that the minted token isn't referenced in any other job. | Yes: tasks 1.11, 2.10 |
| S11 | The tag-only check runs by hand (task 3.2), not in CI. Another edit to an existing test could slip through unnoticed. | Low | Accepted for this change. Edits to existing tests are limited to three files and get reviewed in the PR. Making it a CI check is a possible follow-up. | No |
| S12 | The "no guest data" guarantee covers `repo-trace` only. The unchanged `traceability-report` writes Cucumber scenario names, and `simplecov-report` (`coverage/rspec.html`) writes RSpec descriptions. Both are artifacts any reader of the repo can download. Today neither contains real guest data, because test names use fixed sample names. | Info | No change, since you decided `traceability-report` stays as it is. Tests must keep using sample names only. | No |
| S13 | The existing jobs check out with the default `persist-credentials: true` and then run PR code. With top-level `contents: read` (S4a), the persisted token can only read. | Info | No change. Top-level `contents: read` already limits what the persisted token can do. | No |
| S14 | Consumer side. greeter-docs receives `client_payload[repo]` and the trace from another repo. | Info | Out of scope here. The greeter-docs change that consumes `docs-refresh` should allowlist repo names, never use payload or trace values in paths or shell commands, validate the v1 schema, and cap file size and result count. | No (greeter-docs) |
| S15 | `spec-gate` runs `npm install --global @fission-ai/openspec` unpinned, and it will now also run in the weekly scheduled build. The job holds only a `contents: read` token and no secrets. | Low | Existing behaviour. Pinning belongs to `add-dependency-scanning`. | No |

## Risks / trade-offs

- A regex scan can be fooled by tag text inside a comment or string. This is
  accepted because the scan is simple and needs no Node or CLI, and fixtures
  are excluded from it.
- Adding tags may push `describe` lines over RuboCop's line length. Wrapping is
  allowed, because the tag-only check ignores whitespace.
- `notify-docs` fails until the credentials and the App installation exist.
- This change makes `bdd` a required input of `trace`. A flaky Cucumber run on
  `main` skips that week's or that push's publication.

## Decisions

- **Scheduled CD runs are accepted.** A scheduled CI run starts a CD run
  through `workflow_run`, and the `package` guard skips every job unless a
  `v*` tag was pushed. A skipped CD run in the Actions list each week is fine.
  `cd.yml` does not change, and `ci_contract_spec` asserts the guard.
- **Top-level `permissions: contents: read` in `ci.yml`.** No existing job needs
  more, because they only check out, set up Ruby, cache and upload artifacts.
  `trace` declares `contents: read`, and `notify-docs` keeps `permissions: {}`
  and uses only the minted App token. `ci_contract_spec` gets an example that
  checks two things: top-level `permissions` is exactly `{contents: read}`,
  and no job's `permissions` contains `write`.
- **Repo rules are scoped by capability.** Two rules apply to
  `greeting/cli-greeter` only: "every OpenSpec scenario maps to exactly one
  Cucumber scenario" and "CLI-observable behaviour only". The `release/` and
  `tooling/` capabilities (`acceptance-gate`, `live-docs-traceability`)
  describe pipeline and tooling behaviour and are verified by RSpec examples
  tagged `requirement:`/`scenario:`. Files edited:
  - `AGENTS.md`, section "OpenSpec ↔ Cucumber traceability": the first
    paragraph is scoped, and a sentence about `release/` and `tooling/` is
    added.
  - `openspec/config.yaml`: the `context` line about Cucumber mapping and the
    `rules.specs` line "Scenarios assert only what a user of the CLI can
    observe" are scoped to `greeting/cli-greeter`, and a line about `release/`
    and `tooling/` is added.
  Every other line of both files stays unchanged (`git diff` shows only those
  lines).
- **Default trace file names are accepted.** Each writer defaults to its own
  file, `tmp/repo-trace-spec.json` and `tmp/repo-trace-bdd.json`.
- **Talisman.** The spec-artifact entries in `.talismanrc` are refreshed
  before the spec commit. The entry for the deleted
  `specs/traceability/repo-trace/spec.md` is removed, and entries are added or
  refreshed only for flagged files under `openspec/changes/adopt-live-docs/`.
  The code and workflow entries are refreshed after apply (task 2.7).
- **Test edits.** The maintainer runs `tests-open` before the red-test step
  and before apply, and runs `tests-close` after each.

## Assumptions

- Duplicate results inside one writer collapse to the worst status.
- The merge keeps the later `recorded_at`.
