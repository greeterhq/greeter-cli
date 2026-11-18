# Proposal

## Why

The Cucumber features that map to the `cli-greeter` scenarios never run the
CLI. `features/support/env.rb` calls the domain in-process and sets its own
exit code when it catches `InvalidGuestName`. So the rule "invalid name exits
2" lives in two places, `exe/greeter` and the test harness, and the features
only check the harness copy. When the acceptance gate was proven by making
`exe/greeter` exit 9, every greeter-cli test stayed green. Only the shared
acceptance suite noticed.

The features are this repo's evidence for its OpenSpec scenarios. They should
observe what a CLI user observes: the real process, its exit code, stdout and
stderr.

## What Changes

- The Cucumber harness runs the real `exe/greeter` as a subprocess for every
  scenario and captures its exit status, stdout and stderr. It no longer
  builds the domain, presenter or clock itself.
- Step definitions keep their wording; they read the captured process result.
- `features/greeting.feature`, its tags and the traceability report are
  unchanged, so the scenario-to-feature mapping stays one to one.
- The stderr steps check for the CLI's `Error:` prefix, not just "not empty",
  since they now see the real message.
- `exe/` and `lib/` do NOT change. This is a test-harness change only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The `cli-greeter` requirements and scenarios describe the right
behaviour already; this change makes the features verify them against the
shipped executable. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- Files: `features/support/env.rb`, `features/step_definitions/greeting_steps.rb`,
  `README.md` (`## Testing` section).
- Cucumber gets slower: one Ruby process per scenario (five today, well under
  a few seconds in total).
- Cucumber no longer exercises code through `lib/` directly; coverage is
  unchanged because SimpleCov only measures RSpec.
- No change to CI job layout, `cd.yml`, or the acceptance gate.

## Non-goals

- No change to CLI behaviour, `exe/`, `lib/`, or `greeter-core`.
- No new or changed OpenSpec requirements or scenarios.
- No running of the features against a packaged tarball; the acceptance gate
  already does that.
- No removal of `spec/unit/exe/invalid_name_spec.rb` or `version_flag_spec.rb`
  (see design.md).
- No change to the shared acceptance suite in `greeter-acceptance`.
