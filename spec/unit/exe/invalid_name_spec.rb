# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# The exit code and stderr for an invalid name are decided in the executable
# itself (it rescues InvalidGuestName and exits 2), so they are exercised by
# running the real exe/greeter as a subprocess. The Cucumber features drive the
# domain in-process and would not notice if exe/greeter exited with anything else.
RSpec.describe 'exe/greeter with an invalid name', :aggregate_failures do
  let(:exe) { File.expand_path('../../../exe/greeter', __dir__) }

  def run(*args)
    Open3.capture3(RbConfig.ruby, exe, *args)
  end

  it 'exits 2 with a message on stderr and nothing on stdout for an empty name' do
    stdout, stderr, status = run('')

    expect(status.exitstatus).to eq(2)
    expect(stderr).not_to be_empty
    expect(stdout).to be_empty
  end
end
