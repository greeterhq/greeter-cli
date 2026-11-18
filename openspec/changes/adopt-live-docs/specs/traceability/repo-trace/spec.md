## ADDED Requirements

### Requirement: Every requirement has a tagged example
Every `### Requirement:` heading under `openspec/specs/**/spec.md` SHALL be
covered by at least one Cucumber scenario or RSpec example tagged with its slug
(`requirement: '<slug>'`, or `@requirement-<slug>` in Cucumber). The slug is the
heading text lowercased, with each run of characters outside `[a-z0-9]`
replaced by `-` and leading and trailing `-` removed. Scenario slugs use the
same rule on `#### Scenario:` headings.

#### Scenario: Untagged requirement fails the trace check
- **WHEN** a requirement heading has no tagged example
- **THEN** `spec/trace_check_spec.rb` fails and names the requirement and its spec file

### Requirement: Tagged examples name a known requirement
An example's requirement slug SHALL match a `### Requirement:` heading.

#### Scenario: Unknown requirement slug fails the trace check
- **WHEN** an example is tagged with a requirement slug that matches no heading
- **THEN** `spec/trace_check_spec.rb` fails and names the slug and the example file

### Requirement: Test runs write a repo-trace
RSpec and Cucumber SHALL both write results to `tmp/repo-trace.json` in schema
`greeterhq.repo-trace.v1`. Whichever run finishes second reads the file and
appends its results. Each result has `requirement`, `scenario`, `status`
(`passed`, `failed`, `pending` or `skipped`), `source` (`rspec` or `cucumber`)
and `location` (`spec/...rb:LINE` or `features/<file>:<line>`).

#### Scenario: RSpec and Cucumber results merge
- **WHEN** RSpec and then Cucumber run in the same checkout
- **THEN** `tmp/repo-trace.json` contains results with `source` `rspec` and results with `source` `cucumber`, under `repo` `greeter-cli`

### Requirement: The trace holds no guest data
The trace SHALL contain only slugs, statuses, locations and run metadata
(`sha`, `recorded_at`, `run_id`). It SHALL NOT contain example descriptions,
scenario names, step text or guest names.

#### Scenario: Trace omits descriptions
- **WHEN** an example whose description contains a guest name is recorded
- **THEN** that description does not appear anywhere in `tmp/repo-trace.json`

### Requirement: CI publishes the trace and notifies greeter-docs
On a push to `main` and on the weekly schedule (`17 6 * * 1`), `ci.yml` SHALL
upload `tmp/repo-trace.json` as artifact `repo-trace` (retention 90 days). Then
a `notify-docs` job SHALL send a `docs-refresh` `repository_dispatch` to
`greeterhq/greeter-docs` with `client_payload[repo]=greeter-cli`. The job SHALL
declare `permissions: {}` and use a token minted by
`actions/create-github-app-token@v3` for owner `greeterhq` and the single
repository `greeter-docs`, passed through `env:`.

#### Scenario: Main push uploads the trace and sends docs-refresh
- **WHEN** CI runs on a push to `main`
- **THEN** the `repo-trace` artifact is uploaded and `notify-docs` sends `docs-refresh` with `client_payload[repo]=greeter-cli`

#### Scenario: Scheduled run does not release
- **WHEN** CI runs on the weekly schedule
- **THEN** the trace is uploaded and `docs-refresh` is sent, and no release is created and `cd.yml` does not run

#### Scenario: Pull requests do not notify
- **WHEN** CI runs on a pull request
- **THEN** the trace is not uploaded and `notify-docs` does not run
