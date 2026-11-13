# frozen_string_literal: true

@requirement-guest-greeting
Feature: Guest greeting

  @scenario-greets-a-named-guest
  Scenario: Greets a named guest
    When the CLI is invoked with the name "Alice"
    Then the exit code is 0
    And stdout contains "Howdy, Alice!"

  @scenario-normalises-casing-and-whitespace
  Scenario: Normalises casing and whitespace
    When the CLI is invoked with the name "  alice smith  "
    Then the exit code is 0
    And stdout contains "Howdy, Alice Smith!"

  @scenario-rejects-an-empty-or-whitespace-only-name
  Scenario: Rejects an empty or whitespace-only name
    When the CLI is invoked with the name ""
    Then the exit code is 2
    And stderr contains an invalid name message
    And stdout is empty

  @scenario-rejects-a-name-longer-than-64-characters
  Scenario: Rejects a name longer than 64 characters
    When the CLI is invoked with a name that is 65 characters long
    Then the exit code is 2
    And stderr contains a name too long message

  @scenario-rejects-names-containing-control-or-escape-characters
  Scenario: Rejects names containing control or escape characters
    When the CLI is invoked with a name containing an escape sequence
    Then the exit code is 2
    And stderr contains an invalid characters message
