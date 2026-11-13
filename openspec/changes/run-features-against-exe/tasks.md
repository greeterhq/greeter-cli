# Tasks

## 1. Red tests

- [ ] 1.1 Rewrite `features/support/env.rb` so `invoke_cli` runs `exe/greeter` with `Open3.capture3(RbConfig.ruby, exe, raw_name)` and stores stdout, stderr and the exit status; remove the in-process service, presenter and clock. Verify: `bundle exec cucumber` runs all 5 scenarios
- [ ] 1.2 Update `features/step_definitions/greeting_steps.rb` to read the captured process result, keeping every step's wording; the three stderr steps check for the `Error: ` prefix on a single line. Verify: `features/greeting.feature` is unchanged (`git diff --exit-code features/greeting.feature`)
- [ ] 1.3 Prove the features now observe the shipped CLI: temporarily change `exit 2` to `exit 9` in `exe/greeter`, run `bundle exec cucumber`, and confirm the three rejection scenarios fail on the exit-code step; restore `exe/greeter` (`git diff --exit-code exe/`). Record the failing output in the PR description

## 2. Confirm unchanged behaviour

- [ ] 2.1 Run `bundle exec cucumber` against the unmodified `exe/greeter`: 5 scenarios pass. Verify `tmp/traceability.json` still lists the same 5 scenarios with the same `@requirement-*` and `@scenario-*` tags
- [ ] 2.2 Confirm `exe/` and `lib/` are unchanged (`git diff --exit-code origin/main -- exe lib`)

## 3. Verify and docs

- [ ] 3.1 Update the `## Testing` section of `README.md` so the `bundle exec cucumber` line says the features run the real `exe/greeter` as a subprocess. Verify by reading the section
- [ ] 3.2 Run `bundle exec rspec`, `bundle exec cucumber`, `bundle exec rubocop` and `openspec validate --all --strict`; all pass
