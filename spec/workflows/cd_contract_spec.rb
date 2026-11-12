# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

# Contract checks on .github/workflows/cd.yml, one example per workflow
# scenario in openspec/changes/adopt-acceptance-gate/specs/release/acceptance-gate/spec.md.
# These read the YAML only; the behaviour itself is proven by a live run.
# CD_WORKFLOW points the spec at another file (used to prove the examples can fail).
# rubocop:disable RSpec/DescribeClass
RSpec.describe 'cd.yml contract' do
  # rubocop:enable RSpec/DescribeClass
  let(:workflow) { YAML.safe_load_file(workflow_path, aliases: false) }
  let(:jobs) { workflow.fetch('jobs') }

  def workflow_path
    ENV.fetch('CD_WORKFLOW', File.expand_path('../../.github/workflows/cd.yml', __dir__))
  end

  def needs_of(name)
    Array(jobs.fetch(name)['needs'])
  end

  def job_steps(name)
    jobs.fetch(name)['steps'] || []
  end

  def step_matches?(step, uses: nil, run: nil)
    (uses.nil? || step['uses'].to_s.start_with?(uses)) && (run.nil? || step['run'].to_s.include?(run))
  end

  def find_step(name, **match)
    job_steps(name).find { |step| step_matches?(step, **match) }
  end

  def step_positions(name, *matchers)
    matchers.map { |match| job_steps(name).index { |step| step_matches?(step, **match) } }
  end

  def conditions(name)
    [jobs.fetch(name)['if'], *job_steps(name).map { |step| step['if'] }].compact.map(&:to_s)
  end

  def file_list(value)
    value.to_s.lines.map(&:strip).reject(&:empty?)
  end

  def expressions(name)
    jobs.fetch(name).to_yaml.scan(/\$\{\{.*?\}\}/).uniq
  end

  describe 'Gate failure stops the release' do
    it 'makes release and announce depend on the gate chain', :aggregate_failures do
      expect(needs_of('release')).to include('package', 'gate')
      expect(needs_of('announce')).to include('release')
    end

    it 'never overrides the default success() condition' do
      overrides = %w[gate release announce].flat_map { |name| conditions(name) }
      expect(overrides.grep(/always\(\)|failure\(\)|cancelled\(\)/)).to be_empty
    end
  end

  describe 'Gate passes and release uses the same tarball' do
    let(:release_steps) do
      step_positions('release', { uses: 'actions/download-artifact' }, { run: 'sha256sum -c' },
                     { uses: 'softprops/action-gh-release' })
    end

    it 'downloads cli-tarball, verifies the .sha256, then publishes, in that order', :aggregate_failures do
      expect(find_step('release', uses: 'actions/download-artifact')['with']['name']).to eq('cli-tarball')
      expect(release_steps).not_to include(nil)
      expect(release_steps).to eq(release_steps.compact.sort)
    end

    it 'publishes exactly the files package uploaded', :aggregate_failures do
      uploaded = find_step('package', uses: 'actions/upload-artifact')['with']
      published = find_step('release', uses: 'softprops/action-gh-release')['with']['files']
      expect(uploaded['name']).to eq('cli-tarball')
      expect(file_list(published)).to eq(file_list(uploaded['path']))
    end
  end

  describe 'Release is announced to both environments' do
    let(:dispatch) { find_step('announce', run: 'gh api') }

    it 'fans out over exactly prod and stage', :aggregate_failures do
      expect(jobs.fetch('announce').dig('strategy', 'matrix', 'environment')).to eq(%w[prod stage])
      expect(dispatch['env']['ENVIRONMENT']).to eq('${{ matrix.environment }}')
    end

    it 'sends channel-released for the cli channel', :aggregate_failures do
      expect(dispatch['run']).to include('event_type=channel-released', 'client_payload[channel]=cli')
      expect(dispatch['run']).to include('client_payload[environment]=')
    end

    it 'sends string fields only and no target-like fields' do
      expect(dispatch['run']).not_to match(/(^|\s)-F\s|\[(url|base_url|target|address)\]/)
    end
  end

  describe 'Announce has no ambient token rights' do
    let(:mint) { find_step('announce', uses: 'actions/create-github-app-token@v3') }

    it 'declares empty permissions', :aggregate_failures do
      expect(jobs.fetch('announce')['permissions']).to eq({})
      expect(workflow['permissions']).to eq({})
    end

    it 'mints a token for the one repository greeter-acceptance', :aggregate_failures do
      expect(mint['with']).to include('owner' => 'greeterhq', 'repositories' => 'greeter-acceptance')
      expect(mint['with']).not_to include('skip-token-revoke')
    end

    it 'uses the minted token as its only credential', :aggregate_failures do
      allowed = ['${{ secrets.DISPATCH_APP_PRIVATE_KEY }}', "${{ steps.#{mint['id']}.outputs.token }}"]
      expect(find_step('announce', run: 'gh api')['env']['GH_TOKEN']).to eq(allowed.last)
      expect(expressions('announce').grep(/secrets\.|token/i) - allowed).to be_empty
    end

    it 'never interpolates expressions into a script body' do
      expect(job_steps('announce').map { |step| step['run'].to_s }.grep(/\$\{\{/)).to be_empty
    end
  end

  describe 'Matching semver refs pass' do
    let(:gate) { jobs.fetch('gate') }
    let(:uses_ref) do
      gate['uses'][%r{\Agreeterhq/greeter-acceptance/\.github/workflows/gate\.yml@(v\d+\.\d+\.\d+)\z}, 1]
    end

    it 'calls gate.yml at a vX.Y.Z equal to acceptance_ref', :aggregate_failures do
      expect(uses_ref).not_to be_nil
      expect(gate['with']['acceptance_ref']).to eq(uses_ref)
    end
  end
end
