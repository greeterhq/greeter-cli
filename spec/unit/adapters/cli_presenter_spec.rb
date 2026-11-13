# frozen_string_literal: true

require 'stringio'
require 'greeter/core'
require 'greeter/adapters/cli_presenter'

RSpec.describe Greeter::Adapters::CliPresenter do
  let(:output)    { StringIO.new }
  let(:presenter) { described_class.new(output: output) }

  def build_greeting(name:, time: Time.utc(2024, 6, 1, 9, 0, 0))
    Greeter::Core::Domain::Greeting.new(
      guest_name: Greeter::Core::Domain::GuestName.new(name),
      greeted_at: time
    )
  end

  # Scenario: Greets a named guest
  it "writes 'Howdy, Alice!' to the injected IO" do
    presenter.present(build_greeting(name: 'Alice'))
    expect(output.string).to eq("Howdy, Alice!\n")
  end

  # Scenario: Normalises casing and whitespace
  it 'uses the display value from GuestName, reflecting normalised casing' do
    presenter.present(build_greeting(name: '  alice smith  '))
    expect(output.string).to eq("Howdy, Alice Smith!\n")
  end
end
