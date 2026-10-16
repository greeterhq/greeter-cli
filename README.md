# greeter-cli

[![CI](https://github.com/greeterhq/greeter-cli/actions/workflows/ci.yml/badge.svg)](https://github.com/greeterhq/greeter-cli/actions/workflows/ci.yml)

A hexagonal CLI greeter. This is the application layer: it owns the driven
adapters (`CliPresenter`, `SystemClock`) and the composition root
(`exe/greeter`), and depends on the [`greeter-core`](https://rubygems.org/gems/greeter-core)
gem for the pure domain and ports (`Greeter::Core::Domain`, `Greeter::Core::Ports`).

## Requirements

- Ruby 3.3.5
- Bundler

## Setup (from source)

```bash
bundle install
bundle exec ruby exe/greeter "Alice"   # => Hello, Alice!
bundle exec ruby exe/greeter --version # => greeter-cli 0.1.0 (greeter-core 0.1.2)
```

## Running a release build

Tagged releases publish a versioned distribution tarball to
[GitHub Releases](https://github.com/greeterhq/greeter-cli/releases). Each
release attaches two assets:

- `greeter-cli-<tag>.tar.gz` — the runnable distribution (`exe/`, `lib/`,
  `Gemfile`, `Gemfile.lock`, `README.md`, `LICENSE`)
- `greeter-cli-<tag>.tar.gz.sha256` — a checksum for integrity verification

`greeter` is a Ruby CLI, not a compiled binary: `exe/greeter` loads the
`greeter-core` gem and the app's adapters at runtime. So a release is a
self-contained snapshot you unpack and run with Bundler — **Ruby 3.3.5 and
Bundler are still required** on the target machine.

### Download, verify, and run

Replace `v0.1.0` with the release tag you want.

```bash
# 1. Download both assets (via gh, or from the Releases page)
gh release download v0.1.0 --repo greeterhq/greeter-cli

# 2. Verify integrity, then unpack
shasum -a 256 -c greeter-cli-v0.1.0.tar.gz.sha256
tar -xzf greeter-cli-v0.1.0.tar.gz
cd greeter-cli-v0.1.0

# 3. Install the pinned dependencies and run
bundle install
bundle exec exe/greeter "Alice"     # => Hello, Alice!
bundle exec exe/greeter --version   # prints the CLI + greeter-core versions
```

`bundle install` resolves against the bundled `Gemfile.lock`, so you get the
exact `greeter-core` version this release was built and tested against. Run
`--version` to confirm the pairing.

To run the CLI without typing `bundle exec` each time, install the bundle and
invoke through the binstub, or add a shell alias, e.g.:

```bash
alias greeter='bundle exec ruby /path/to/greeter-cli-v0.1.0/exe/greeter'
```

## Referencing the greeter-core gem

This app depends on `greeter-core`. Pick the source that matches your workflow
and put **one** of the following in the `Gemfile`, then run `bundle install`.

### RubyGems (default — released versions)

Use the published gem. This is what the committed `Gemfile` uses.

```ruby
gem 'greeter-core', '~> 0.1'
```

`~> 0.1` is a pessimistic constraint: it allows `0.1.x` and later `0.x` releases
while the API stabilises, and `Gemfile.lock` pins the exact resolved version.
Upgrade deliberately with:

```bash
bundle update greeter-core
```

### GitHub (unreleased commits / a branch or tag)

Track the gem's repository directly — useful for testing changes that are merged
but not yet published to RubyGems.

```ruby
# Follow the default branch:
gem 'greeter-core', git: 'https://github.com/greeterhq/greeter-core.git', branch: 'main'

# …or pin to a tag or commit for reproducibility:
gem 'greeter-core', git: 'https://github.com/greeterhq/greeter-core.git', tag: 'v0.1.2'
gem 'greeter-core', git: 'https://github.com/greeterhq/greeter-core.git', ref: 'e6b039c'
```

With a `git:` source, `bundle update greeter-core` re-resolves against the branch
(or leaves a pinned `tag`/`ref` fixed). Bundler records the resolved commit SHA
in `Gemfile.lock`.

### Local path (developing the gem alongside this app)

Point at a local clone so edits in the gem are picked up immediately, with no
publish or push step. Assumes the gem is checked out as a sibling directory.

```ruby
gem 'greeter-core', path: '../greeter-core'
```

Prefer this only for local development — do not commit a `path:` source, since
the path won't exist on CI or another machine. To keep `git:`/RubyGems in the
committed `Gemfile` while overriding to a local checkout on your machine only:

```bash
bundle config set --local local.greeter-core ../greeter-core
```

This requires a `git:` source in the `Gemfile` (Bundler maps the local override
onto it) and leaves the committed `Gemfile` unchanged. Remove it with:

```bash
bundle config unset --local local.greeter-core
```

## Testing

```bash
bundle exec rspec        # unit + security specs
bundle exec cucumber     # CLI behaviour scenarios
bundle exec rubocop      # lint
```

## Architecture

Hexagonal. Dependencies point inward only; adapters depend on `greeter-core`,
and the core never references adapters.

| Layer | Location | Namespace |
|---|---|---|
| Domain | `greeter-core` gem | `Greeter::Core::Domain` |
| Ports | `greeter-core` gem | `Greeter::Core::Ports` |
| Adapters | `lib/greeter/adapters` | `Greeter::Adapters` |

Test doubles (`FakeClock`, `FixedClock`) ship in the gem under
`Greeter::Core::Testing` and load with `require 'greeter/core/testing'`.

## Cutting a release (maintainers)

Releases are produced by the `release` job in `.github/workflows/ci.yml`. It runs
**only** on version tags and **only** if every other CI job passes, then packages
the tarball and creates the GitHub Release.

1. Bump `Greeter::Cli::VERSION` in `lib/greeter/cli/version.rb` to match the tag
   you intend to push (the tag drives the asset name; the constant drives what
   `--version` prints — keep them in step).
2. Commit and push to `main`; confirm the CI run is fully green.
3. Tag with a **`v` prefix** and push the tag:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

The tag must start with `v` (e.g. `v0.1.0`). The workflow triggers on
`tags: ["v*"]` and the release job guards on `refs/tags/v`, so a bare `0.1.0`
tag is ignored and produces no release. The resulting assets are named from the
tag (`greeter-cli-v0.1.0.tar.gz`).

See `AGENTS.md` for full project conventions and `openspec/` for the
specification of CLI-observable behaviour.
