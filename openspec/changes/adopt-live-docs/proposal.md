# Proposal

## Why

greeter-docs needs to read greeter-cli's requirements and the latest test
results. Today the Cucumber tags do not match the OpenSpec headings
(`@requirement-guest-greeting` matches nothing), RSpec examples carry no
requirement metadata, and `features/support/traceability.rb` writes a private
`tmp/traceability.json` in a shape nothing else reads. Nothing checks that every
requirement has a test.

## What Changes

- Slug rule shared by all greeterHQ repos: lowercase the heading text, replace
  each run of non `[a-z0-9]` with `-`, trim `-`.
- Retag `features/greeting.feature` with `@requirement-<slug> @scenario-<slug>`
  per scenario; remove the feature-level `@requirement-guest-greeting`.
- Add `spec/support/repo_trace_formatter.rb`, an RSpec formatter writing
  `tmp/repo-trace.json` (schema `greeterhq.repo-trace.v1`, no descriptions).
- Replace `features/support/traceability.rb` with a writer that appends Cucumber
  results (`source: cucumber`, `location: features/<file>:<line>`) to the same
  file; whichever run is second merges into it.
- Tag `spec/workflows/cd_contract_spec.rb` and the `bin/check-acceptance-ref`
  spec with `requirement:` / `scenario:` metadata, since the acceptance-gate
  requirements are verified by RSpec.
- Add `spec/trace_check_spec.rb`, parsing `openspec/specs/**/spec.md` directly
  (no Node, no OpenSpec CLI) and failing on untagged requirements or unknown
  slugs.
- `ci.yml`: run rspec with the formatter on every push and PR, then cucumber;
  on push to `main` and a weekly schedule upload `repo-trace` and run
  `notify-docs`.
- `exe/` and `lib/` do NOT change.

## Capabilities

### New Capabilities

- `traceability/repo-trace`: slug rule, trace check, trace file, CI publication.

### Modified Capabilities

None. Existing `cli-greeter` and `acceptance-gate` requirements keep their text.

## Impact

- Files: `features/greeting.feature`, `features/support/traceability.rb`,
  `spec/support/repo_trace_formatter.rb`, `spec/trace_check_spec.rb`,
  `spec/workflows/cd_contract_spec.rb`, the `bin/check-acceptance-ref` spec,
  `spec/unit/**` slug and formatter specs, `.github/workflows/ci.yml`.
- Requires repo variable `DISPATCH_APP_CLIENT_ID` and secret
  `DISPATCH_APP_PRIVATE_KEY`, with the App installed on `greeter-docs`.
- Overlaps the in-progress `run-features-against-exe`, which also edits
  `features/`. Apply that change first, or rebase.

## Non-goals

- No change to CLI behaviour, `exe/`, `lib/` or `greeter-core`.
- No change to existing requirement text or the acceptance gate.
- No change to `cd.yml`.
- No greeter-docs changes.
- No unit-level tagging beyond what covers a requirement.
