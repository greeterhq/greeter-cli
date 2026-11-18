# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'shellwords'
require 'tmpdir'
require 'yaml'

# Contract checks on .github/workflows/ci.yml for publishing the repo trace,
# one group per CI scenario of the live-docs-traceability capability.
# These read the YAML; the behaviour itself is proven by a live run.
# CI_WORKFLOW / CD_WORKFLOW point the spec at other files (to prove it can fail).
# rubocop:disable RSpec/DescribeClass
RSpec.describe 'ci.yml contract' do
  # rubocop:enable RSpec/DescribeClass
  let(:gate) do
    "github.event_name == 'schedule' || (github.event_name == 'push' && github.ref == 'refs/heads/main')"
  end
  let(:repo_root) { File.expand_path('../..', __dir__) }
  let(:workflow) { YAML.safe_load_file(ci_path, aliases: false) }
  let(:jobs) { workflow.fetch('jobs') }
  let(:cd_jobs) { YAML.safe_load_file(cd_path, aliases: false).fetch('jobs') }

  def ci_path
    ENV.fetch('CI_WORKFLOW', File.join(repo_root, '.github', 'workflows', 'ci.yml'))
  end

  def cd_path
    ENV.fetch('CD_WORKFLOW', File.join(repo_root, '.github', 'workflows', 'cd.yml'))
  end

  def job_steps(name)
    jobs.fetch(name)['steps'] || []
  end

  def step_matches?(step, uses:, run:, artifact:)
    [uses.nil? || step['uses'].to_s.start_with?(uses),
     run.nil? || step['run'].to_s.include?(run),
     artifact.nil? || step.dig('with', 'name') == artifact].all?
  end

  def find_step(name, uses: nil, run: nil, artifact: nil)
    job_steps(name).find { |step| step_matches?(step, uses: uses, run: run, artifact: artifact) } || {}
  end

  # The rspec arguments of a `bundle exec rspec ...` line, with any --out path
  # redirected so the dry run never overwrites the real HTML report.
  def dry_run_args(run, html_path)
    args = Shellwords.split(run).drop_while { |word| word != 'rspec' }.drop(1)
    args.each_with_index.map { |arg, index| index.positive? && args[index - 1] == '--out' ? html_path : arg }
  end

  def upload(name, artifact)
    find_step(name, uses: 'actions/upload-artifact', artifact: artifact)
  end

  def step_env(name, step)
    (jobs.fetch(name)['env'] || {}).merge(step['env'] || {})
  end

  def condition(name)
    jobs.fetch(name)['if'].to_s.strip
  end

  def needs_of(name, from: jobs)
    Array(from.fetch(name)['needs'])
  end

  describe 'per-job traces',
           requirement: 'ci-publishes-the-trace-on-main-and-weekly',
           scenario: 'spec-and-bdd-upload-their-own-traces' do
    {
      'spec' => ['rspec', 'tmp/repo-trace-spec.json', 'repo-trace-spec'],
      'bdd' => ['cucumber', 'tmp/repo-trace-bdd.json', 'repo-trace-bdd']
    }.each do |job, (tool, path, artifact)|
      it "runs #{tool} in #{job} with REPO_TRACE_PATH=#{path}" do
        step = find_step(job, run: "bundle exec #{tool}")
        expect(step_env(job, step)['REPO_TRACE_PATH']).to eq(path)
      end

      it "uploads #{artifact} from #{job} for one day, failing if the file is missing" do
        expect(upload(job, artifact)['with'])
          .to include('path' => path, 'retention-days' => 1, 'if-no-files-found' => 'error')
      end
    end

    it 'selects RepoTraceFormatter in the spec job' do
      expect(find_step('spec', run: 'bundle exec rspec')['run']).to include('--format RepoTraceFormatter')
    end

    it 'keeps the traceability-report upload of tmp/traceability.json unchanged', :aggregate_failures do
      step = upload('bdd', 'traceability-report')
      expect(step['if']).to eq('always()')
      expect(step['with']).to eq('name' => 'traceability-report', 'path' => 'tmp/traceability.json',
                                 'retention-days' => 14)
    end

    it 'runs the spec job rspec command with a formatter that resolves and selects examples', :aggregate_failures do
      Dir.mktmpdir('ci-dry-run') do |dir|
        args = dry_run_args(find_step('spec', run: 'bundle exec rspec')['run'].to_s, File.join(dir, 'rspec.html'))
        expect(args.each_cons(2)).to include(%w[--format RepoTraceFormatter])
        out, err, = Open3.capture3({ 'REPO_TRACE_PATH' => File.join(dir, 'trace.json') },
                                   RbConfig.ruby, Gem.bin_path('rspec-core', 'rspec'), *args, '--dry-run',
                                   chdir: repo_root)
        expect(out[/(\d+) examples?/, 1].to_i).to be_positive
        expect(out + err).not_to match(/No examples found|RepoTraceFormatter/)
      end
    end
  end

  describe 'trace job',
           requirement: 'ci-publishes-the-trace-on-main-and-weekly',
           scenario: 'trace-job-merges-and-uploads-on-main-and-schedule' do
    it 'runs weekly at 17 6 * * 1' do
      expect(workflow.fetch('on').fetch('schedule')).to include('cron' => '17 6 * * 1')
    end

    it 'needs spec and bdd, reads contents only and runs on main pushes and the schedule only', :aggregate_failures do
      expect(needs_of('trace')).to match_array(%w[spec bdd])
      expect(jobs.fetch('trace')['permissions']).to eq('contents' => 'read')
      expect(condition('trace')).to eq(gate)
    end

    it 'merges with bin/merge-repo-trace and uploads repo-trace for 90 days', :aggregate_failures do
      expect(find_step('trace', run: 'bin/merge-repo-trace')).not_to be_empty
      expect(upload('trace', 'repo-trace')['with'])
        .to include('path' => 'tmp/repo-trace.json', 'retention-days' => 90, 'if-no-files-found' => 'error')
    end
  end

  describe 'notify-docs',
           requirement: 'ci-publishes-the-trace-on-main-and-weekly',
           scenario: 'notify-docs-dispatches-docs-refresh' do
    let(:mint) { find_step('notify-docs', uses: 'actions/create-github-app-token@v3') }
    let(:dispatch) { find_step('notify-docs', run: 'gh api') }

    it 'needs trace, has no token rights and uses the same gate', :aggregate_failures do
      expect(needs_of('notify-docs')).to eq(['trace'])
      expect(jobs.fetch('notify-docs')['permissions']).to eq({})
      expect(condition('notify-docs')).to eq(gate)
    end

    it 'mints an App token for greeterhq/greeter-docs only' do
      expect(mint['with']).to include('client-id' => '${{ vars.DISPATCH_APP_CLIENT_ID }}',
                                      'private-key' => '${{ secrets.DISPATCH_APP_PRIVATE_KEY }}',
                                      'owner' => 'greeterhq', 'repositories' => 'greeter-docs')
    end

    it 'sends docs-refresh to greeter-docs with client_payload[repo]=greeter-cli' do
      expect(dispatch['run']).to include('repos/greeterhq/greeter-docs/dispatches', 'event_type=docs-refresh',
                                         'client_payload[repo]=greeter-cli')
    end
  end

  describe 'credentials',
           requirement: 'ci-publishes-the-trace-on-main-and-weekly',
           scenario: 'workflow-credentials-are-least-privilege' do
    let(:mint) { find_step('notify-docs', uses: 'actions/create-github-app-token@v3') }
    let(:dispatch) { find_step('notify-docs', run: 'gh api') }

    it 'sets top-level permissions to exactly contents: read' do
      expect(workflow['permissions']).to eq('contents' => 'read')
    end

    it 'grants write in no job' do
      grants = jobs.values.flat_map { |job| (job['permissions'] || {}).values }
      expect(grants).not_to include('write')
    end

    it 'requests only permission-contents: write and never skips token revocation', :aggregate_failures do
      expect(mint['with'].keys.grep(/\Apermission-/)).to eq(['permission-contents'])
      expect(mint['with']['permission-contents']).to eq('write')
      expect(mint['with']).not_to include('skip-token-revoke')
    end

    it 'mints the token in the step directly before the dispatch and exposes it to no other job', :aggregate_failures do
      steps = job_steps('notify-docs')
      expect(steps.index(dispatch)).to eq(steps.index(mint) + 1)
      expect(jobs.fetch('notify-docs')).not_to include('outputs')
    end

    it 'passes the minted token to gh only as GH_TOKEN in env' do
      expect(dispatch['env']).to eq('GH_TOKEN' => "${{ steps.#{mint['id']}.outputs.token }}")
    end

    it 'interpolates no expression into a run: script of trace or notify-docs' do
      scripts = %w[trace notify-docs].flat_map { |name| job_steps(name).map { |step| step['run'].to_s } }
      expect(scripts.grep(/\$\{\{/)).to be_empty
    end

    it 'checks out without persisted credentials in trace' do
      expect(find_step('trace', uses: 'actions/checkout')['with']).to include('persist-credentials' => false)
    end

    it 'downloads artifacts by name from this run only, each into its own directory', :aggregate_failures do
      downloads = job_steps('trace').select { |step| step['uses'].to_s.start_with?('actions/download-artifact') }
      expect(downloads.map { |step| step.dig('with', 'name') }).to match_array(%w[repo-trace-spec repo-trace-bdd])
      expect(downloads.flat_map { |step| step['with'].keys }).not_to include('run-id', 'merge-multiple')
      expect(downloads.map { |step| step.dig('with', 'path') }.uniq.size).to eq(2)
    end
  end

  describe 'scheduled runs',
           requirement: 'ci-publishes-the-trace-on-main-and-weekly',
           scenario: 'scheduled-run-creates-no-release' do
    it 'gates trace and notify-docs away from pull requests and tag pushes', :aggregate_failures do
      expect(gate).not_to include('pull_request')
      %w[trace notify-docs].each { |name| expect(condition(name)).to eq(gate) }
    end

    it 'has no publish or release job and no release step in ci.yml', :aggregate_failures do
      expect(jobs.keys.grep(/publish|release/)).to be_empty
      uses = jobs.values.flat_map { |job| (job['steps'] || []).map { |step| step['uses'].to_s } }
      runs = jobs.values.flat_map { |job| (job['steps'] || []).map { |step| step['run'].to_s } }
      expect(uses.grep(/action-gh-release/)).to be_empty
      expect(runs.grep(/gem push|gh release/)).to be_empty
    end

    it 'runs the cd.yml package job only for a pushed v* tag', :aggregate_failures do
      guard = cd_jobs.fetch('package')['if'].to_s
      expect(guard).to include("github.event.workflow_run.event == 'push'")
      expect(guard).to include("startsWith(github.event.workflow_run.head_branch, 'v')")
    end

    it 'makes every other cd.yml job depend on package' do
      reaches_package = lambda do |name, seen = []|
        needs = needs_of(name, from: cd_jobs)
        needs.include?('package') || (needs - seen).any? { |need| reaches_package.call(need, seen + [name]) }
      end
      expect(cd_jobs.keys - ['package']).to all(satisfy { |name| reaches_package.call(name) })
    end
  end
end
