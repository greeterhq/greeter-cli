## 1. Red tests

- [x] 1.1 Add fixture workflows `spec/fixtures/acceptance_ref/matching.yml`, `mismatched.yml`, `non_semver.yml` (each a minimal workflow with a `gate` job using `greeterhq/greeter-acceptance/.github/workflows/gate.yml@<ref>` and `with.acceptance_ref`)
- [x] 1.2 Add `spec/unit/check_acceptance_ref_spec.rb` running `bin/check-acceptance-ref <fixture>` via `Open3`: matching exits 0; mismatched exits non-zero naming both refs on stderr; non-semver exits non-zero naming the ref
- [x] 1.3 Add red fixtures and examples for S8: no gate job, two gate jobs, `uses:` pointing at a different repo or path, gate job missing `with`/`acceptance_ref`; each must exit non-zero
- [x] 1.4 Run `bundle exec rspec spec/unit/check_acceptance_ref_spec.rb` and confirm it is red for the right reason (script missing / expectation failure, not a syntax error)

## 2. check-acceptance-ref

- [x] 2.1 Create `bin/check-acceptance-ref` (executable, `# frozen_string_literal: true`, stdlib only) per design; make the examples green
- [x] 2.2 Add a step to the `lint` job in `.github/workflows/ci.yml` running `bin/check-acceptance-ref`
- [x] 2.3 `bundle exec rubocop` clean for the script and spec

## 3. Split cd.yml

- [x] 3.1 `package` job: existing steps, outputs `tag`, `sha` (and `core_version`), upload `cli-tarball` with `if-no-files-found: error`, same `if:`, `contents: read`
- [x] 3.2 `gate` job: reusable-workflow call to `gate.yml@v0.2.0` with the specified inputs, `permissions: contents: read`
- [x] 3.3 `release` job: `needs: [package, gate]`, download `cli-tarball`, same softprops step, `contents: write` only here
- [x] 3.4 `announce` job: `permissions: {}`, `create-github-app-token@v3` (owner `greeterhq`, repositories `greeter-acceptance`), `gh api` dispatch for `prod` and `stage` with `-f` fields only and values via `env:`
- [x] 3.5 Add `.github/actionlint.yaml` (ignores the two stale-metadata messages for `create-github-app-token@v3` in `cd.yml`, with a removal comment) and run `actionlint` with no arguments; it exits 0
- [x] 3.6 Confirm `gate.yml@v0.2.0` input names and the permissions it needs match the caller job
- [x] 3.7 Confirm `bin/check-acceptance-ref` passes on the real `cd.yml`

## 4. Security hardening (see design.md "Security considerations")

- [x] 4.1 S1: in `package`, fail unless `TAG` matches `^v[0-9]+\.[0-9]+\.[0-9]+$` before any output is set (confirm pre-release tags are not used)
- [x] 4.2 S2: add top-level `permissions: {}` to `cd.yml`; each job declares its own minimum
- [x] 4.3 S3/S10: `package` outputs the tarball sha256; `release` runs `sha256sum -c` on the downloaded `.sha256` and compares the tarball hash to the output before publishing; upload with `retention-days: 7`
- [x] 4.4 S4/S5: mint step sets `permission-contents: write` and leaves token revocation on; `GH_TOKEN` is set in the dispatch step's `env:` only; no `set -x` or token echo
- [x] 4.5 S6: gate call passes no `secrets:` / `secrets: inherit`
- [x] 4.6 S7: add `head_repository.full_name == github.repository` to the `package` `if:`, keeping the existing conditions
- [x] 4.7 S8: harden `bin/check-acceptance-ref` (exactly one gate job, exact `uses:` repo and path, missing `with`/`acceptance_ref` is an error, anchored regex, `YAML.safe_load`); matching red fixtures and examples are in group 1
- [x] 4.8 S6: document in the README that `v*` tags in `greeter-acceptance` must be protected by a ruleset
- [x] 4.9 S9: confirm no `always()`, `!cancelled()` or `failure()` on `gate`, `release` or `announce`; confirm no `${{ }}` appears inside any `run:` body in `announce`

## 5. Verify and docs

- [x] 5.1 Update the `cd.yml` header comment (job graph, gate, announce)
- [x] 5.2 Update the README release section (gate, release from tested tarball, announcement, how to bump the acceptance ref)
- [x] 5.3 Document required repo config: `vars.DISPATCH_APP_CLIENT_ID`, `secrets.DISPATCH_APP_PRIVATE_KEY`
- [x] 5.4 Run `bundle exec rspec`, `bundle exec cucumber`, `bundle exec rubocop`, `openspec validate --all --strict`
- [x] 5.5 Traceability: no Cucumber scenarios. Add `spec/workflows/cd_contract_spec.rb` (one example group per workflow scenario, named after it) and the design.md "Verification" table mapping each scenario to its spec example, with `<passing run URL v0.1.3>` and `<refused run URL v0.1.4>` live-run placeholders to be filled after merge, before archive. Run URLs stay out of the PR description; the PR description mentions the `core_version` output and the `vX.Y.Z`-only tag check
