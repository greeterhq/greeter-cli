@requirement-guest-greeting
Feature: Tag-only fixture

  @scenario-old-name
  Scenario: Greets a named guest
    When the CLI is invoked with the name "Alice"
    Then the exit code is 0
