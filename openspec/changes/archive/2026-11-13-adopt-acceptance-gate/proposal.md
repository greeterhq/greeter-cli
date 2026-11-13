## Why

Today `cd.yml` publishes a GitHub Release as soon as CI is green. The shared
acceptance suite in `greeterhq/greeter-acceptance` (which drives this CLI as a
black box) does not gate that release, and the acceptance ledgers are never told
a new CLI version exists. A CLI build that breaks shared behaviour can ship, and
the ledgers cannot track what shipped.

## What Changes

- Split the single `release` job in `.github/workflows/cd.yml` into four jobs:
  - `package`: everything `release` does today up to the tarball and `.sha256`
    (tag verify, smoke test, core version, package), then uploads both files as
    the `cli-tarball` artifact. Outputs `tag` and `sha`. Same `if:` as today.
  - `gate`: `needs: package`; calls
    `greeterhq/greeter-acceptance/.github/workflows/gate.yml@v0.2.0` with
    `acceptance_ref: v0.2.0`, `channel: cli`, `candidate_version` = tag,
    `candidate_sha` = sha, `artifact_name: cli-tarball`,
    `artifact_file: greeter-cli-<tag>.tar.gz`. `permissions: contents: read`.
  - `release`: `needs: [package, gate]`; downloads `cli-tarball` and publishes
    the GitHub Release exactly as today. `contents: write` only here.
  - `announce`: `needs: [package, release]`; `permissions: {}`. Mints a
    single-repository GitHub App token and sends two `channel-released`
    `repository_dispatch` events (`environment` `prod` and `stage`) to
    `greeterhq/greeter-acceptance`.
- Add `bin/check-acceptance-ref`, which fails when the ref on the gate `uses:`
  line differs from the `acceptance_ref` input, or when either is not `vX.Y.Z`.
  Run it from `ci.yml` (lint job).
- RSpec coverage for the script using fixture workflow files (matching,
  mismatched, non-semver).
- Docs: update the `cd.yml` header comment and the README release section.

## Capabilities

### New Capabilities
- `acceptance-gate`: release gating on the shared acceptance suite, release
  from the gated tarball, announcement of released versions, and the gate-ref
  consistency check.

### Modified Capabilities
None. `cli-greeter` is unchanged.

## Impact

- Files changed: `.github/workflows/cd.yml`, `.github/workflows/ci.yml` (one
  step), new `bin/check-acceptance-ref`, new RSpec example and fixtures under
  `spec/`, `README.md`.
- `exe/` and `lib/` do NOT change. The CLI contract is untouched.
- No change to `greeter-core`.
- New repository configuration required before the first gated release:
  `vars.DISPATCH_APP_CLIENT_ID`, `secrets.DISPATCH_APP_PRIVATE_KEY`, and a
  GitHub App installed on `greeterhq/greeter-acceptance` that may send
  `repository_dispatch`.
- Releases now depend on `greeter-acceptance@v0.2.0` being reachable and
  passing; a gate outage blocks releases (intended fail-closed behaviour).

## Non-goals

- No changes to CLI behaviour, `exe/`, `lib/`, or `greeter-core`.
- No changes to what is packaged in the tarball or to the Release body and notes.
- No re-implementation of acceptance scenarios here; they live in
  `greeter-acceptance`.
- No automation for bumping the acceptance ref; it is edited by hand in both
  places and the check script keeps them in sync.
- No handling of `channel-released` receipt on the acceptance side.
- No retry or rollback of a Release if `announce` fails after `release`.
