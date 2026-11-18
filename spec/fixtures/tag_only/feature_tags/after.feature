Feature: Tag-only fixture

  @requirement-greets-a-named-guest @scenario-greets-a-named-guest
  Scenario: Greets a named guest
    When the CLI is invoked with the name "Alice"
    Then the exit code is 0
