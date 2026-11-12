## ADDED Requirements

### Requirement: Failed acceptance gate blocks release and announcement
The CD workflow SHALL NOT create a GitHub Release and SHALL NOT send any
`channel-released` event when the acceptance gate job does not succeed.

#### Scenario: Gate failure stops the release
- **WHEN** the `gate` job fails for a tagged CLI build
- **THEN** the `release` job does not run, no GitHub Release is created, and the `announce` job does not run

### Requirement: Release is published from the tested tarball
The `release` job SHALL publish the Release assets from the `cli-tarball`
artifact produced by `package` and tested by `gate`, with no rebuild in between,
so the published `.tar.gz` and `.sha256` are byte-identical to what the gate tested.

#### Scenario: Gate passes and release uses the same tarball
- **WHEN** the `gate` job succeeds
- **THEN** the `release` job downloads the `cli-tarball` artifact and attaches `greeter-cli-<tag>.tar.gz` and `greeter-cli-<tag>.tar.gz.sha256` from it, failing if either file is missing

### Requirement: Released versions are announced for prod and stage
After the Release is published, the `announce` job SHALL send one
`channel-released` `repository_dispatch` event to `greeterhq/greeter-acceptance`
for `environment` `prod` and one for `stage`. Each carries `channel=cli`,
`version=<tag>`, `sha=<sha>` and `environment=<env>` as string fields, and no
`url`, `base_url`, `target` or `address`.

#### Scenario: Release is announced to both environments
- **WHEN** the `release` job succeeds
- **THEN** exactly two `channel-released` events are sent, one with `environment=prod` and one with `environment=stage`, each with `channel=cli`, the released tag as `version` and the packaged commit as `sha`

### Requirement: Announce holds only a single-repository App token
The `announce` job SHALL declare `permissions: {}` and SHALL authenticate only
with a GitHub App token minted by `actions/create-github-app-token@v3` for owner
`greeterhq` and the single repository `greeter-acceptance`. The token SHALL be
passed through `env:` and never interpolated into a script.

#### Scenario: Announce has no ambient token rights
- **WHEN** the `announce` job is inspected
- **THEN** it declares empty permissions, mints a token scoped to `greeter-acceptance` only, and passes the token and all event values via `env:`

### Requirement: Gate ref and acceptance_ref must agree
CI SHALL fail when the ref in the gate job's `uses:` line differs from its
`acceptance_ref` input, or when either is not of the form `vX.Y.Z`.

#### Scenario: Matching semver refs pass
- **WHEN** the gate `uses:` ref and `acceptance_ref` are both `v0.2.0`
- **THEN** `bin/check-acceptance-ref` exits 0

#### Scenario: Mismatched refs fail
- **WHEN** the gate `uses:` ref is `v0.2.0` and `acceptance_ref` is `v0.3.0`
- **THEN** `bin/check-acceptance-ref` exits non-zero and names both refs on stderr

#### Scenario: Non-semver ref fails
- **WHEN** either ref is not of the form `vX.Y.Z` (for example `main`)
- **THEN** `bin/check-acceptance-ref` exits non-zero and names the offending ref on stderr
