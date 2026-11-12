# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'bin/check-acceptance-ref' do
  # rubocop:enable RSpec/DescribeClass
  let(:repo_root) { File.expand_path('../../..', __dir__) }
  let(:script)    { File.join(repo_root, 'bin', 'check-acceptance-ref') }
  let(:fixtures)  { File.join(repo_root, 'spec', 'fixtures', 'acceptance_ref') }

  # Runs the script without a shell (argv form) against a fixture workflow.
  def run_check(fixture)
    Open3.capture3(RbConfig.ruby, script, File.join(fixtures, fixture))
  end

  it 'exists and is executable' do
    expect(File.executable?(script)).to be(true)
  end

  context 'when the gate ref and acceptance_ref match and are vX.Y.Z' do
    it 'exits 0' do
      _out, _err, status = run_check('matching.yml')
      expect(status.exitstatus).to eq(0)
    end

    it 'writes nothing to stderr' do
      _out, err, = run_check('matching.yml')
      expect(err).to be_empty
    end
  end

  context 'when the gate ref differs from acceptance_ref' do
    it 'exits non-zero' do
      _out, _err, status = run_check('mismatched.yml')
      expect(status).not_to be_success
    end

    it 'names both refs on stderr' do
      _out, err, = run_check('mismatched.yml')
      expect(err).to include('v0.2.0').and include('v0.3.0')
    end
  end

  context 'when the gate ref is not vX.Y.Z' do
    it 'exits non-zero' do
      _out, _err, status = run_check('non_semver_ref.yml')
      expect(status).not_to be_success
    end

    it 'names the offending ref on stderr' do
      _out, err, = run_check('non_semver_ref.yml')
      expect(err).to include('main')
    end
  end

  context 'when acceptance_ref is not vX.Y.Z' do
    it 'exits non-zero' do
      _out, _err, status = run_check('non_semver_input.yml')
      expect(status).not_to be_success
    end

    it 'names the offending ref on stderr' do
      _out, err, = run_check('non_semver_input.yml')
      expect(err).to include('v0.2').and include('acceptance_ref')
    end
  end

  # Fail-closed behaviour (security finding S8).
  context 'when there is no gate job' do
    it 'exits non-zero and says no gate job was found' do
      _out, err, status = run_check('no_gate.yml')
      expect([status.success?, err]).to match([false, /no gate job/i])
    end
  end

  context 'when there is more than one gate job' do
    it 'exits non-zero and says exactly one is allowed' do
      _out, err, status = run_check('two_gates.yml')
      expect([status.success?, err]).to match([false, /exactly one gate job/i])
    end
  end

  context 'when the gate job uses a different repository' do
    it 'exits non-zero and names the unexpected uses value' do
      _out, err, status = run_check('wrong_repo.yml')
      expect([status.success?, err]).to match([false, %r{someoneelse/other}])
    end
  end

  context 'when the gate job has no acceptance_ref input' do
    it 'exits non-zero and says acceptance_ref is missing' do
      _out, err, status = run_check('missing_with.yml')
      expect([status.success?, err]).to match([false, /acceptance_ref.*missing|missing.*acceptance_ref/i])
    end
  end
end
