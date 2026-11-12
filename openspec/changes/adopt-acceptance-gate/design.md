## Context

`cd.yml` has one `release` job triggered by `workflow_run` (CI green, push, `v*`
tag). It checks out the CI-validated commit, verifies the tag, smoke-tests,
resolves the greeter-core version, builds `dist/greeter-cli-<tag>.tar.gz` plus
`.sha256`, and publishes via `softprops/action-gh-release@v2`.

The shared acceptance suite lives in `greeterhq/greeter-acceptance` and exposes
a reusable workflow `gate.yml`. This change makes it a release gate and
announces released versions to its ledgers. Only `cd.yml`, `ci.yml` (one step),
`bin/check-acceptance-ref`, its spec and docs change. `exe/` and `lib/` do not.

## Goals / Non-Goals

**Goals:** fail-closed release; the tested tarball is the published tarball;
least-privilege tokens per job; a mechanical guard against ref drift.

**Non-goals:** see proposal.

## Decisions

**Job graph.** `package -> gate -> release -> announce`. `release` needs
`[package, gate]`, `announce` needs `[package, release]`. All four carry the
trigger condition implicitly: only `package` has the `if:`; the others are
skipped when a needed job is skipped or fails (default `success()` semantics).
`announce` does not need `gate` directly because `release` already needs it.

**Package job.**
- Keeps the existing steps verbatim (checkout of `head_sha`, tag verify, setup-ruby,
  smoke, core version, package). `permissions: contents: read` (it no longer
  writes).
- Job outputs: `tag` (from the job-level `TAG` env, i.e. `head_branch`) and `sha`
  (`workflow_run.head_sha`, verified equal to the tag commit by the existing step).
  Outputs are set from `env`/context, not from untrusted free text.
- The core version moves into a `package` output (`core_version`) so `release`
  can still render the body. This is a necessary addition beyond `tag`/`sha`.
- `actions/upload-artifact` (pinned to the major used in ci.yml, `@v6`), name
  `cli-tarball`, paths `dist/greeter-cli-<tag>.tar.gz` and `.sha256`,
  `if-no-files-found: error`. Both explicit paths share the parent `dist/`, so
  the artifact holds `greeter-cli-<tag>.tar.gz` and its `.sha256` at its root,
  which is the layout `artifact_file` expects. Verify this at apply time.

**Gate job.** A job with `uses:` (reusable workflow call), `needs: package`,
`permissions: contents: read`, and `with:` `acceptance_ref: v0.2.0`,
`channel: cli`, `candidate_version: ${{ needs.package.outputs.tag }}`,
`candidate_sha: ${{ needs.package.outputs.sha }}`, `artifact_name: cli-tarball`,
`artifact_file`: `greeter-cli-${{ needs.package.outputs.tag }}.tar.gz`.
`uses:` cannot take expressions, so the ref is a literal `@v0.2.0`; that is
exactly what the check script keeps in sync with `acceptance_ref`.

**Release job.** `needs: [package, gate]`, `permissions: contents: write`.
No checkout and no Ruby: it runs `actions/download-artifact` (`cli-tarball`, path
`dist`) then the same `softprops/action-gh-release@v2` step with the same
`files`, `body`, `generate_release_notes` and `fail_on_unmatched_files: true`.
`tag_name` comes from `needs.package.outputs.tag`. Because softprops needs the
tag on the remote and no checkout is present, `target_commitish` is not needed
(the tag already exists).

**Announce job.** `needs: [package, release]`, `permissions: {}`.
1. `actions/create-github-app-token@v3` with `client-id: ${{ vars.DISPATCH_APP_CLIENT_ID }}`,
   `private-key: ${{ secrets.DISPATCH_APP_PRIVATE_KEY }}`, `owner: greeterhq`,
   `repositories: greeter-acceptance` (exactly one repository), placed in this
   job immediately before use.
2. A `run:` step with `env:` `GH_TOKEN: ${{ steps.app.outputs.token }}`,
   `VERSION`, `SHA`, `ENVIRONMENT: ${{ matrix.environment }}`, and no values
   interpolated into the script body. The job has
   `strategy: {fail-fast: false, matrix: {environment: [prod, stage]}}`, so it
   runs once per environment, each run minting its own token, and each calls
   `gh api repos/greeterhq/greeter-acceptance/dispatches -f event_type=channel-released -f 'client_payload[channel]=cli' -f "client_payload[version]=${VERSION}" -f "client_payload[sha]=${SHA}" -f "client_payload[environment]=${ENVIRONMENT}"`.
   `fail-fast: false` keeps a failed prod dispatch from cancelling stage.
   Only `-f` (string) fields are used. No `url`, `base_url`, `target`, `address`.
   The environments are a literal list in the workflow, not input.

**check-acceptance-ref.** Ruby script (`#!/usr/bin/env ruby`, frozen string
literal), standard library only. Usage: `bin/check-acceptance-ref [workflow]`,
default `.github/workflows/cd.yml`. It parses the YAML with `YAML.safe_load`,
finds jobs whose `uses` starts with
`greeterhq/greeter-acceptance/.github/workflows/gate.yml@`, reads `with.acceptance_ref`,
and:
- exits 0 and prints `ok: gate and acceptance_ref are vX.Y.Z` when equal and semver;
- exits 1 with a message naming the refs when they differ or either is not
  `\Av\d+\.\d+\.\d+\z`;
- exits 1 when no gate job exists or `acceptance_ref` is missing.
CI runs it in the `lint` job, after checkout, with no extra setup.

**Testing.** RSpec runs the script as a subprocess (`Open3`) against three
fixture workflows under `spec/fixtures/acceptance_ref/` (matching, mismatched,
non-semver, plus the fail-closed cases), asserting exit status and stderr.
`spec/workflows/cd_contract_spec.rb` loads the real `cd.yml` with
`YAML.safe_load_file(..., aliases: false)` and has one example group per
workflow scenario, named after it; `CD_WORKFLOW` can point it at another file
to prove an example can fail. `actionlint` (no arguments) must exit 0. Its
bundled metadata for `create-github-app-token@v3` lists `app-id` and not
`client-id`, so `.github/actionlint.yaml` ignores those two messages for
`cd.yml` only; remove it once actionlint knows `client-id`.

## Risks / Trade-offs

- Fail-closed: a gate outage or an unavailable `v0.2.0` blocks releases. Accepted.
- `announce` runs after `release`; if dispatch fails the Release already exists.
  A re-run of only the failed job is the recovery. Accepted (non-goal).
- Sending `prod` and `stage` together means both ledgers learn of a version at
  the same time. As requested.
- Permissions: a caller job's `contents: read` must be enough for `gate.yml`'s
  own jobs; I could not read `gate.yml` from here. Verify at apply time.
- `concurrency` stays at workflow level; a re-run of a failed job reuses the
  same artifact within the run's retention window.

## Security considerations

Reviewed against the proposal, spec and design (the workflow is not yet
written, so these are design-level findings). Severity is my judgement.
Findings marked "task" have a matching item in tasks.md group 4.

**S1 (Medium) Tag value flows into several sinks unvalidated.** `TAG` is
`workflow_run.head_branch`. The existing step only proves it is a tag at the
validated commit; git tag names can contain characters such as `$`, quotes,
spaces and `..`. The value now feeds a job output, a file name, reusable-workflow
inputs and `gh api -f` fields. Env-only passing stops shell injection, but an odd
name can still break paths or confuse the gate and ledgers. Mitigation: in
`package`, reject any tag not matching `^v[0-9]+\.[0-9]+\.[0-9]+$` before
setting outputs. Task 4.1. (This assumes release tags are plain semver; if you
publish pre-release tags like `v1.0.0-rc1`, the pattern needs to allow them.)

**S2 (Medium) No default token permissions at workflow level.** `cd.yml` has no
top-level `permissions:`, so a job added later without its own block would
inherit the repository default, which may be write. Mitigation: top-level
`permissions: {}`, with each job granting only what it needs (`package`
`contents: read`, `gate` `contents: read`, `release` `contents: write`,
`announce` `{}`). Task 4.2.

**S3 (Medium) Release is not re-verified against the tested bytes.** The
artifact flows `package -> gate -> release` and the spec says it is the same
file. Nothing in the job proves it. Mitigation: `release` runs
`sha256sum -c` on the downloaded `.sha256` file before publishing, and
`package` also records the tarball's sha256 as a job output so `release` can
compare the downloaded file against that value (the `.sha256` file travels in
the same artifact, so on its own it would not detect a swapped artifact). Task 4.3.

**S4 (Medium) App token carries the App's full installation permissions.**
`create-github-app-token` scopes repositories but, by default, grants every
permission the App holds on them. `repository_dispatch` needs only
`contents: write` on the target. Mitigation: set `permission-contents: write`
on the mint step, and do not set `skip-token-revoke` so the token is revoked at
job end. This is a hardening addition beyond the stated "owner plus one
repository" rule and does not contradict it. Task 4.4. Also confirm the v3
input is `client-id` (renamed from `app-id`) when writing the step.

**S5 (Low) Token exposure inside the job.** Scope `GH_TOKEN` to the single
dispatch step's `env:`, not the job. No `set -x`, no echo of the token or
payload, no `secrets: inherit` anywhere. The mint step is the first step of
`announce` and the dispatch step the second, with nothing in between. Task 4.4.

**S6 (Medium) Gate reference is a mutable tag.** `@v0.2.0` can be moved by
anyone able to retag `greeter-acceptance`, which would run attacker-chosen
code in a job that holds `contents: read` and, via the artifact, the release
tarball. The requirement fixes the `vX.Y.Z` form and the check script enforces
it, so I am not changing it here. Mitigation outside this repo: protect `v*`
tags in `greeter-acceptance` with a ruleset (no update or delete). Recorded in
the README as a prerequisite (task 4.8). Pinning to a commit SHA would be
stronger; it conflicts with the `vX.Y.Z` rule, so it is an option for you to decide.
The gate call must not pass `secrets:` or `secrets: inherit`. Task 4.5.

**S7 (Low) Trigger provenance.** Today's guards (`conclusion == success`,
`event == push`, `head_branch` starts with `v`) are sound, since a fork cannot
push tags into this repo's CI. Defence in depth: also require
`github.event.workflow_run.head_repository.full_name == github.repository`.
Task 4.6.

**S8 (Medium) Check script must fail closed.** A guard that silently passes is
worse than none. Required behaviour: `YAML.safe_load` only; exactly one gate job
(zero or several is an error); the `uses:` must be exactly
`greeterhq/greeter-acceptance/.github/workflows/gate.yml@<ref>` (a different
repo or path is an error, not "no gate found"); missing `with` or
`acceptance_ref` is an error; regex anchored with `\A...\z`. The RSpec examples
invoke the script with `Open3` array form, never through a shell. Task 4.7, with
red fixtures in group 1.

**S9 (Low) Job skipping must not be bypassed.** `release` and `announce` rely on
default `success()` semantics. No `if: always()`, `!cancelled()` or `failure()`
conditions may be added to `gate`, `release` or `announce`, otherwise a failed
gate could still publish or announce. Verified by review and `actionlint`. Task 4.9.

**S10 (Low) Artifact lifetime.** The tarball is the public release content, so
exposure is not a concern, but set `retention-days: 7` on `cli-tarball` to limit
stale copies. Artifacts are run-scoped on download-artifact v4+, so another run
cannot supply the file. Task 4.3.

**S11 (Info) Receiver trust and actions pinning.** The `client_payload` values
are strings only and no `url`, `base_url`, `target` or `address` is sent. The
receiving workflow in `greeter-acceptance` must still treat the payload as
untrusted (validate `version` and `sha`, and check the version exists as a
published release). That is outside this repo, so I am only noting it. Actions in
this repo are pinned by major tag, not SHA, as in `ci.yml`; I am keeping that
convention for consistency. Recommend a separate change to pin by SHA.

**Not a finding:** `announce` does not need `gate` directly because `release`
needs it. Each `announce` matrix job mints its own App token for the same
single repository.

## Files changed

- `.github/workflows/cd.yml` (four jobs, hardening, `announce` matrix)
- `.github/workflows/ci.yml` (one step in `lint`: `bin/check-acceptance-ref`)
- `.github/actionlint.yaml` (new; ignores two stale-metadata messages for `cd.yml`)
- `.gitignore` (`/bin/*` plus `!/bin/check-acceptance-ref`; a `/bin/` directory
  ignore cannot be re-included, and nothing in `bin/` was tracked)
- `bin/check-acceptance-ref` (new)
- `spec/unit/bin/check_acceptance_ref_spec.rb`, `spec/fixtures/acceptance_ref/*.yml` (new)
- `spec/workflows/cd_contract_spec.rb` (new)
- `README.md` (release section, acceptance ref bump, prerequisites)
- `openspec/changes/adopt-acceptance-gate/*`

`exe/` and `lib/` are unchanged.

## Traceability decision

Project rules map each OpenSpec scenario to one tagged Cucumber scenario.
`features/` describes what a CLI user observes, and the workflow scenarios only
run on GitHub, so this change adds no Cucumber scenarios. Each scenario is
instead tied to RSpec examples (table below). The four workflow scenarios also
get a live run, because the YAML contract cannot prove GitHub's behaviour.

## Verification

Spec files: `U` = `spec/unit/bin/check_acceptance_ref_spec.rb`,
`C` = `spec/workflows/cd_contract_spec.rb`.

| Requirement / scenario | Spec example that checks it | Live run |
|---|---|---|
| Gate failure stops the release | `C` "Gate failure stops the release" (needs chain; no `always()`, `failure()` or `cancelled()`) | <refused run URL v0.1.4> |
| Gate passes and release uses the same tarball | `C` "Gate passes and release uses the same tarball" (download `cli-tarball`, `sha256sum -c` before publish, same files as uploaded) | <passing run URL v0.1.3> |
| Release is announced to both environments | `C` "Release is announced to both environments" (matrix exactly `[prod, stage]`, `channel-released`, `channel=cli`, `-f` only) | <passing run URL v0.1.3> |
| Announce holds only a single-repository App token | `C` "Announce has no ambient token rights" (`permissions: {}`, minted token only, `repositories: greeter-acceptance`, no `${{ }}` in scripts) | <passing run URL v0.1.3> |
| Matching semver refs pass | `U` "when the gate ref and acceptance_ref match"; `C` "Matching semver refs pass" (real file) | not applicable |
| Mismatched refs fail | `U` "when the gate ref differs from acceptance_ref" | not applicable |
| Non-semver ref fails | `U` "when the gate ref is not vX.Y.Z", "when acceptance_ref is not vX.Y.Z" | not applicable |
| S8 fail-closed (no gate, two gates, wrong repo, missing input) | `U` the four matching contexts | not applicable |

The live-run placeholders are replaced after merge, before archive.
