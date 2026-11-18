# frozen_string_literal: true

Feature: Guest greeting

  @requirement-greets-a-named-guest @scenario-greets-a-named-guest
  Scenario: Greets a named guest
    When the CLI is invoked with the name "Alice"
    Then the exit code is 0
    And stdout contains "Hello, Alice!"

  @requirement-presents-normalised-casing-and-whitespace @scenario-presents-normalised-casing-and-whitespace
  Scenario: Normalises casing and whitespace
    When the CLI is invoked with the name "  alice smith  "
    Then the exit code is 0
    And stdout contains "Hello, Alice Smith!"

  @requirement-surfaces-an-empty-or-whitespace-only-name-as-an-error @scenario-rejects-an-empty-or-whitespace-only-name
  Scenario: Rejects an empty or whitespace-only name
    When the CLI is invoked with the name ""
    Then the exit code is 2
    And stderr contains an invalid name message
    And stdout is empty

  @requirement-surfaces-an-over-long-name-as-an-error @scenario-rejects-a-name-longer-than-64-characters
  Scenario: Rejects a name longer than 64 characters
    When the CLI is invoked with a name that is 65 characters long
    Then the exit code is 2
    And stderr contains a name too long message

  @requirement-surfaces-control-escape-characters-as-an-error @scenario-rejects-names-containing-control-or-escape-characters
  Scenario: Rejects names containing control or escape characters
    When the CLI is invoked with a name containing an escape sequence
    Then the exit code is 2
    And stderr contains an invalid characters message
