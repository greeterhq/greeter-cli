# Project conventions

## Architecture: Hexagonal (three layers only)

Domain and ports live in the **`greeter-core`** gem (`Greeter::Core::Domain`,
`Greeter::Core::Ports`). This app (`greeter-cli`) owns the adapters that wire
the core to real I/O.

| Layer | Location | Rules |
|---|---|---|
| Domain | `greeter-core` gem (`Greeter::Core::Domain`) | Pure Ruby, zero gems, zero I/O, no AWS, no `Time.now` |
| Ports | `greeter-core` gem (`Greeter::Core::Ports`) | Abstract interfaces (driving + driven); unimplemented methods raise `NotImplementedError` |
| Adapters | `lib/greeter/adapters` | All I/O: CLI, HTTP/Lambda, DynamoDB |

Test doubles (`FakeClock`, `FixedClock`) ship in the gem under
`Greeter::Core::Testing` and are loaded with `require 'greeter/core/testing'`.

## Dependency rule

Dependencies point **inward only**. Adapters depend on `greeter-core`; the core
never references adapters.

## Dependency injection

All collaborators are injected via constructor keyword arguments. No globals, no singletons, no `require` of adapter files from domain files.

## TDD

Write the failing RSpec example before the implementation, in the same commit.

## OpenSpec ↔ Cucumber traceability

This app's OpenSpec covers CLI-observable behaviour (arguments, exit codes,
stdout/stderr). Every OpenSpec scenario maps to exactly one Cucumber scenario,
tagged with the requirement name.

Name-validation and domain rules are owned by `greeter-core`'s OpenSpec (mapped
there to RSpec examples). This app references those rules where the CLI surfaces
them (e.g. exit 2 + stderr for an invalid name) rather than re-specifying them,
so there is a single source of truth per rule. Where the app implements a
gem-defined port (e.g. `CliPresenter` satisfies `Greeter::Core::Ports::GreetingPresenter`),
a spec proves the adapter satisfies that contract.

## Toolchain

- Ruby 3.3.x
- `# frozen_string_literal: true` on every file
- RuboCop clean (no offenses)
