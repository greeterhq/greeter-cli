# Design

## Context

See proposal.md for why. Current state:

- `features/support/env.rb` defines `invoke_cli(raw_name)`. It builds
  `GreetingService` with a `FixedClock` and a `CliPresenter` writing to a
  `StringIO`, sets `@exit_code = 0`, and on `InvalidGuestName` sets
  `@exit_code = 2` and writes the message to a `StringIO` for stderr.
- `exe/greeter` is the composition root. It uses `SystemClock`, prints to
  `$stdout`, and on `InvalidGuestName` writes `Error: <message>` to stderr and
  exits 2. That is the behaviour users and the acceptance gate see.
- `spec/unit/exe/version_flag_spec.rb` and `spec/unit/exe/invalid_name_spec.rb`
  already run `exe/greeter` with `Open3.capture3(RbConfig.ruby, exe, *args)`.
- CI runs features with `bundle exec cucumber`, so the child process inherits
  the bundle environment and can load `greeter-core`.

## Goals / Non-Goals

**Goals:**
- One source of truth for exit codes and stream output: `exe/greeter`.
- A broken exit code, stream or greeting in `exe/greeter` fails a feature.

**Non-Goals:**
- Making the features channel-neutral or reusing the acceptance suite's drivers.
- Faster features; a few seconds is acceptable.

## Decisions

**Run the executable the same way the exe specs do.** `invoke_cli` calls
`Open3.capture3(RbConfig.ruby, exe_path, raw_name)` with argv form, so no shell
is involved and names with spaces or escape bytes reach the CLI unchanged. It
stores stdout, stderr and the exit status. `RbConfig.ruby` pins the same Ruby
that runs Cucumber; the inherited bundle environment supplies the gems.
Alternative considered: running `bundle exec exe/greeter` per scenario. It adds
a Bundler boot to every scenario and duplicates what the inherited environment
already gives. Alternative considered: `load`ing `exe/greeter` in-process with
captured `$stdout`/`$stderr` and a rescued `SystemExit`. It is faster but keeps
global-state swapping in the harness and still would not prove the real
process exit code.

**Keep step wording and the feature file unchanged.** Only the World module
and the step bodies change. Tags, scenario names and the traceability hook stay
as they are, so the OpenSpec-to-Cucumber mapping is untouched.

**Tighten the stderr steps to the `Error:` prefix.** In-process, the harness
wrote the bare message, so the steps could only check "not empty". The real
CLI prefixes `Error: `. The steps check that prefix and that stderr is a single
line. They do not match greeter-core's wording, which greeter-core owns.

**Drop the in-process collaborators from the harness.** `env.rb` no longer
requires `greeter/core`, `greeter/core/testing` or the adapters. The features
then fail if `exe/greeter` cannot boot, which is the point.

**Keep the exe RSpec examples.** `spec/unit/exe/*` give fast feedback in the
RSpec run and count toward the same CI gate. Removing them is a separate
decision for the maintainer, not part of this change.

**Time.** The CLI uses `SystemClock`, but the presented greeting does not
include the time today, so no clock injection is needed. If the presenter ever
prints time, the scenario must assert on a pattern, not an exact string.

## Risks / Trade-offs

- [A child process cannot receive a NUL byte in argv] → No current scenario
  uses one. Control characters other than NUL (e.g. ESC) pass through argv.
  If a NUL scenario is added later, it has to be tested in greeter-core or
  RSpec, not through the CLI.
- [The child inherits `RUBYOPT`/`BUNDLE_GEMFILE` from Cucumber] → That is how
  it finds its gems; outside `bundle exec`, the features fail to load
  `greeter-core`, which surfaces as a clear error rather than a false pass.
- [Slower features] → One process per scenario; five scenarios today.
- [A future scenario needs a deterministic clock] → Out of scope; it would need
  a CLI-level way to set the clock, which is a CLI behaviour change.

## Migration Plan

Single PR. Rollback is reverting the two feature support files.
