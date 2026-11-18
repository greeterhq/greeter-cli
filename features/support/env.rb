# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# Runs the real exe/greeter as a subprocess so the features observe what a CLI
# user observes: exit status, stdout and stderr. Argv form, no shell involved.
module GreeterWorld
  EXE_PATH = File.expand_path('../../exe/greeter', __dir__)

  def invoke_cli(raw_name)
    @stdout, @stderr, status = Open3.capture3(RbConfig.ruby, EXE_PATH, raw_name)
    @exit_code = status.exitstatus
  end

  attr_reader :stdout, :stderr

  def exit_code
    @exit_code
  end
end

World(GreeterWorld)
