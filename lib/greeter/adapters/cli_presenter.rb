# frozen_string_literal: true

require 'greeter/core/ports/greeting_presenter'

module Greeter
  module Adapters
    class CliPresenter < Greeter::Core::Ports::GreetingPresenter
      def initialize(output: $stdout) # rubocop:disable Lint/MissingSuper
        @output = output
      end

      def present(greeting)
        @output.puts("Howdy, #{greeting.guest_name.display}!")
      end
    end
  end
end
