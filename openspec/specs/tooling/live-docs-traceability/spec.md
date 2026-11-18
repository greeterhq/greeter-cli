# live-docs-traceability Specification

## Purpose

Keeps greeter-cli's requirements and test results readable by greeter-docs: every requirement has a tagged test, test runs write a greeterhq.repo-trace.v1 trace of only slugs, statuses, locations and run metadata, and CI publishes that trace and notifies greeter-docs on pushes to main and weekly.

## Requirements

### Requirement: Every requirement has a tagged test
Every known `### Requirement:` heading SHALL be covered by at least one RSpec
example tagged `requirement: '<slug>'` or one Cucumber scenario tagged
`@requirement-<slug>`. A slug is the heading text lowercased, with each run of
characters other than a-z and 0-9 replaced by one `-` and `-` trimmed from both
ends. Scenario slugs come the same way from `#### Scenario:` headings. When a
requirement has no tagged test, the suite SHALL fail and name the requirement
and its spec file.

#### Scenario: Slug rule turns headings into slugs
- **WHEN** the slug function is given the headings in the slug table (for example `Greets a named guest`, `Surfaces control/escape characters as an error`, `Announce holds only a single-repository App token`, `"  --Leading and trailing!!  "`, and every real requirement and scenario heading in this repo)
- **THEN** it returns `greets-a-named-guest`, `surfaces-control-escape-characters-as-an-error`, `announce-holds-only-a-single-repository-app-token`, `leading-and-trailing`, and the expected slug for every other row
- Maps to: `spec/unit/support/slug_spec.rb`

#### Scenario: Requirement with no tagged test fails and is named
- **WHEN** the trace check runs against a fixture `spec.md` containing a requirement that no RSpec example or Cucumber scenario is tagged with
- **THEN** it fails with a message naming that requirement's slug and the fixture file
- Maps to: `spec/trace_check_spec.rb`

### Requirement: Tagged tests must match a requirement and scenario
A test whose requirement slug matches no known requirement, or whose scenario
slug is not a scenario of its requirement, SHALL fail the suite, naming the
slug and the test's file. Known headings come from main specs and from the
ADDED and MODIFIED sections of non-archived changes. Tags are read from
`spec/**/*.rb` and `features/**/*.feature`, excluding `spec/fixtures/**`.

#### Scenario: Unknown requirement slug fails and is named
- **WHEN** the trace check runs with an RSpec example, and separately a Cucumber scenario, tagged with the requirement slug `no-such-requirement`
- **THEN** each run fails with a message naming `no-such-requirement` and the test's file and line
- Maps to: `spec/trace_check_spec.rb`

#### Scenario: Scenario slug is matched only within its requirement
- **WHEN** the trace check runs with a test whose scenario slug exists only under a different requirement, and another whose scenario slug equals its own requirement's slug
- **THEN** it fails naming the first test's scenario, requirement and file, and reports no problem for the second
- Maps to: `spec/trace_check_spec.rb`

#### Scenario: Requirements in in-flight changes are known
- **WHEN** a test is tagged with a requirement or scenario found only in an ADDED or MODIFIED section of a change that is not archived, or only in an archived change, or only in a REMOVED or RENAMED section
- **THEN** the first is known and reports no problem, and the others are reported as unknown with the test's file and line
- Maps to: `spec/trace_check_spec.rb`

#### Scenario: Fixture files are not scanned
- **WHEN** the trace check runs on the real repo, where `spec/fixtures/**` contains tags naming unknown requirements
- **THEN** it reports no problem caused by those fixture tags
- Maps to: `spec/trace_check_spec.rb`

### Requirement: Repo trace contains only slugs, statuses, locations and run metadata
The RSpec formatter and the Cucumber writer SHALL each write a
`greeterhq.repo-trace.v1` file with one result per test tagged with both a
requirement and a scenario. Neither SHALL write descriptions, scenario names,
step text, failure messages or any field outside the schema, because those can
contain guest names.

#### Scenario: Formatter writes the v1 document
- **WHEN** a suite with one passing and one failing tagged example is run with the RSpec formatter
- **THEN** the file has `schema` `greeterhq.repo-trace.v1`, `repo` `greeter-cli`, `sha` (`GITHUB_SHA` or `git rev-parse HEAD`), `recorded_at` (UTC ISO 8601), `run_id` (`GITHUB_RUN_ID` or `null`), and two `results` with statuses `passed` and `failed`, `source` `rspec`, and `spec/...rb:LINE` locations
- Maps to: `spec/unit/support/repo_trace_formatter_spec.rb`

#### Scenario: Cucumber writer writes the v1 document
- **WHEN** a fixture feature with one passing and one failing tagged scenario is run with the Cucumber writer
- **THEN** the file has the same top-level fields and two `results` with statuses `passed` and `failed`, `source` `cucumber`, and `features/<file>:<line>` locations pointing at each `Scenario:` line
- Maps to: `spec/unit/support/cucumber_repo_trace_spec.rb`

#### Scenario: Skipped and pending are told apart
- **WHEN** an RSpec example marked `skip` and one marked `pending` are run with the formatter, and a Cucumber scenario with a pending step and one whose steps are skipped are run with the writer
- **THEN** each result has status `skipped` or `pending` to match
- Maps to: `spec/unit/support/repo_trace_formatter_spec.rb`, `spec/unit/support/cucumber_repo_trace_spec.rb`

#### Scenario: Writers refuse malformed values
- **WHEN** a tagged test has a requirement or scenario value that is not a lowercase slug, a location with a `.`, `..` or empty path segment, or the environment supplies a `GITHUB_SHA` that is not 40 hex characters or a `GITHUB_RUN_ID` that is not digits
- **THEN** the writer raises an error naming the field, without echoing the value, and writes no file
- Maps to: `spec/unit/support/repo_trace_formatter_spec.rb`, `spec/unit/support/cucumber_repo_trace_spec.rb`

#### Scenario: Writers omit descriptions
- **WHEN** a tagged RSpec example whose description contains `Alice Smith`, and a tagged Cucumber scenario whose name and step text contain `Alice Smith`, are recorded
- **THEN** neither written file contains `Alice Smith`, and each result has exactly the keys `requirement`, `scenario`, `status`, `source`, `location`
- Maps to: `spec/unit/support/repo_trace_formatter_spec.rb`, `spec/unit/support/cucumber_repo_trace_spec.rb`

### Requirement: Per-job traces merge into one trace
`bin/merge-repo-trace` SHALL merge the `spec` and `bdd` trace files into one
`greeterhq.repo-trace.v1` file that contains every result from both. It SHALL
fail and write nothing when the inputs differ in `schema`, `repo`, `sha` or
`run_id`, or when the same result appears in both.

#### Scenario: Merge combines both traces
- **WHEN** an RSpec trace and a Cucumber trace with the same schema, repo, sha and run_id and disjoint results are merged
- **THEN** the output has the same schema, repo, sha and `run_id`, the later of the two `recorded_at` values, and all results from both files
- Maps to: `spec/unit/bin/merge_repo_trace_spec.rb`

#### Scenario: Merge rejects mismatched inputs
- **WHEN** the two files differ in `schema`, `repo`, `sha` or `run_id` (including one `null` and one non-null `run_id`)
- **THEN** the merge exits non-zero with a message naming the differing field and writes no output file
- Maps to: `spec/unit/bin/merge_repo_trace_spec.rb`

#### Scenario: Merge rejects inputs outside the v1 shape
- **WHEN** an input has an unknown top-level key, a `schema` other than `greeterhq.repo-trace.v1`, a `repo` other than `greeter-cli`, a `sha`, `run_id` or `recorded_at` that does not match its pattern (even when both inputs agree), a result with an extra key, a `status` outside `passed|failed|pending|skipped`, a `source` other than `rspec` or `cucumber`, or a requirement, scenario or location that does not match its pattern for that source
- **THEN** the merge exits non-zero naming the file and field and writes no output file
- Maps to: `spec/unit/bin/merge_repo_trace_spec.rb`

#### Scenario: Merge rejects a duplicated result
- **WHEN** the same requirement, scenario and location appear in both files
- **THEN** the merge exits non-zero with a message naming that requirement and location and writes no output file
- Maps to: `spec/unit/bin/merge_repo_trace_spec.rb`

### Requirement: CI publishes the trace on main and weekly
CI SHALL run RSpec with the formatter in `spec` and Cucumber with the writer in
`bdd` on every push and pull request. Each job SHALL upload its own trace. Only
on push to `main` and on the weekly schedule SHALL CI merge and upload the
trace as artifact `repo-trace` and send `repository_dispatch` `docs-refresh` to
`greeterhq/greeter-docs`. A failed `spec` or `bdd` job SHALL publish no trace
and send no dispatch. The scheduled run SHALL NOT create a release.

#### Scenario: Spec and bdd upload their own traces
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** `spec` runs rspec with `--format RepoTraceFormatter` and `REPO_TRACE_PATH=tmp/repo-trace-spec.json` and uploads `repo-trace-spec`, and `bdd` runs cucumber with `REPO_TRACE_PATH=tmp/repo-trace-bdd.json` and uploads `repo-trace-bdd`, each with `retention-days: 1` and `if-no-files-found: error`, and the `traceability-report` upload of `tmp/traceability.json` is unchanged
- Maps to: `spec/workflows/ci_contract_spec.rb`

#### Scenario: Trace job merges and uploads on main and schedule
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** the schedule is `17 6 * * 1`, and `trace` has `needs: [spec, bdd]`, `permissions: {contents: read}`, the gate `github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')`, runs `bin/merge-repo-trace`, and uploads `repo-trace` with `retention-days: 90`
- Maps to: `spec/workflows/ci_contract_spec.rb`

#### Scenario: Notify-docs dispatches docs-refresh
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** `notify-docs` has `needs: trace`, `permissions: {}`, the same gate, a token from `actions/create-github-app-token@v3` (client-id `vars.DISPATCH_APP_CLIENT_ID`, private-key `secrets.DISPATCH_APP_PRIVATE_KEY`, owner `greeterhq`, repositories `greeter-docs`), and a `docs-refresh` dispatch with `client_payload[repo]=greeter-cli`
- Maps to: `spec/workflows/ci_contract_spec.rb`

#### Scenario: Workflow credentials are least-privilege
- **WHEN** `.github/workflows/ci.yml` is parsed
- **THEN** the top-level `permissions` is exactly `{contents: read}`, no job's `permissions` grants `write`, `notify-docs` has `permissions: {}`, the mint step requests only `permission-contents: write`, does not set `skip-token-revoke` and is directly before the dispatch step, the app token reaches `gh` only as `GH_TOKEN` in `env`, no `run:` step of `trace` or `notify-docs` contains a `${{` expression, the `trace` checkout sets `persist-credentials: false`, and the `trace` download steps set neither `run-id` nor `merge-multiple`
- Maps to: `spec/workflows/ci_contract_spec.rb`

#### Scenario: Scheduled run creates no release
- **WHEN** `.github/workflows/ci.yml` and `.github/workflows/cd.yml` are parsed
- **THEN** the `trace` and `notify-docs` gate excludes `pull_request` and tag pushes, `ci.yml` has no publish or release job, and the `cd.yml` `package` job, which every other CD job needs, runs only when the triggering CI run's event is `push` and its head branch starts with `v`
- Maps to: `spec/workflows/ci_contract_spec.rb`
