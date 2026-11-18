# frozen_string_literal: true

When('the CLI is invoked with the name {string}') do |raw_name|
  invoke_cli(raw_name)
end

When('the CLI is invoked with a name that is 65 characters long') do
  invoke_cli('a' * 65)
end

# Gherkin 27 does not resolve \e in string literals; the ESC byte is
# constructed here in Ruby so the real control character reaches the CLI.
When('the CLI is invoked with a name containing an escape sequence') do
  invoke_cli("\e[31m")
end

Then('the exit code is {int}') do |expected|
  expect(exit_code).to eq(expected)
end

Then('stdout contains {string}') do |expected|
  expect(stdout).to include(expected)
end

Then('stdout is empty') do
  expect(stdout).to be_empty
end

def expect_single_line_error
  expect(stderr).to start_with('Error: ')
  expect(stderr.lines.size).to eq(1)
end

Then('stderr contains an invalid name message') do
  expect_single_line_error
end

Then('stderr contains a name too long message') do
  expect_single_line_error
end

Then('stderr contains an invalid characters message') do
  expect_single_line_error
end
