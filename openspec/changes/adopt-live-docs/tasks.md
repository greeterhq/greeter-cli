# Tasks

## 1. Red tests

- [ ] 1.1 `spec/unit/support/slug_spec.rb`: table of heading -> slug examples (case, punctuation runs, `/`, digits, trimming).
- [ ] 1.2 `spec/unit/support/repo_trace_formatter_spec.rb`: schema fields, status mapping, `location`, `sha`/`run_id` from env, merge with existing cucumber results, no description text in output.
- [ ] 1.3 `spec/trace_check_spec.rb` plus fixtures under `spec/fixtures/trace_check/`: uncovered requirement names requirement and file; unknown slug names slug and file; fully covered passes.
- [ ] 1.4 `spec/unit/features/traceability_spec.rb`: Cucumber writer appends `source: cucumber` results with `features/<file>:<line>` and merges with RSpec results.
- [ ] 1.5 `spec/workflows/ci_contract_spec.rb`: schedule cron, `repo-trace` upload with retention 90 on main/schedule only, `notify-docs` needs/if/`permissions: {}`/token inputs/`client_payload[repo]=greeter-cli`, token not interpolated in `run:`, no release on schedule.
- [ ] 1.6 Confirm each new spec fails red for the right reason (NameError or expectation failure).

## 2. Implementation

- [ ] 2.1 Slug module in `spec/support/`.
- [ ] 2.2 `spec/support/repo_trace_formatter.rb`.
- [ ] 2.3 Replace `features/support/traceability.rb` with the merging writer.
- [ ] 2.4 Retag `features/greeting.feature`; remove `@requirement-guest-greeting`.
- [ ] 2.5 Add `requirement:` / `scenario:` metadata to `spec/workflows/cd_contract_spec.rb` and the `bin/check-acceptance-ref` spec for all acceptance-gate scenarios.
- [ ] 2.6 Update `ci.yml`: schedule trigger, formatter, rspec then cucumber, `repo-trace` upload, `notify-docs`.
- [ ] 2.7 Set `DISPATCH_APP_CLIENT_ID` and `DISPATCH_APP_PRIVATE_KEY` and install the App on `greeter-docs` (manual, outside the repo).

## 3. Verify and docs

- [ ] 3.1 `bundle exec rspec`, then `bundle exec cucumber`; inspect `tmp/repo-trace.json` for both sources and no names.
- [ ] 3.2 `bundle exec rubocop`.
- [ ] 3.3 `openspec validate --all --strict`.
- [ ] 3.4 Update README `## Testing` with the trace file and slug rule.
- [ ] 3.5 Prove red in CI first, with the failing run URL in the PR description.
