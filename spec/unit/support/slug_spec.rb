# frozen_string_literal: true

require 'spec_helper'

# Every slug below is written out by hand. None is computed with the function
# under test, so a wrong rule cannot agree with itself.
SLUG_SAMPLES = {
  '  --Leading and trailing!!  ' => 'leading-and-trailing',
  'Base Clock#now raises NotImplementedError' => 'base-clock-now-raises-notimplementederror',
  'Equal names agree across ==, eql?, hash, and uniq' => 'equal-names-agree-across-eql-hash-and-uniq',
  'Completes #greet in under 5 ms at p99' => 'completes-greet-in-under-5-ms-at-p99',
  'GreetingPresenter port declares an unimplemented #present' =>
    'greetingpresenter-port-declares-an-unimplemented-present'
}.freeze

SLUG_REAL_HEADINGS = {
  # greeting/cli-greeter
  'Greets a named guest' => 'greets-a-named-guest',
  'Presents normalised casing and whitespace' => 'presents-normalised-casing-and-whitespace',
  'Surfaces an empty or whitespace-only name as an error' =>
    'surfaces-an-empty-or-whitespace-only-name-as-an-error',
  'Surfaces an over-long name as an error' => 'surfaces-an-over-long-name-as-an-error',
  'Surfaces control/escape characters as an error' => 'surfaces-control-escape-characters-as-an-error',
  'Rejects an empty or whitespace-only name' => 'rejects-an-empty-or-whitespace-only-name',
  'Rejects a name longer than 64 characters' => 'rejects-a-name-longer-than-64-characters',
  'Rejects names containing control or escape characters' =>
    'rejects-names-containing-control-or-escape-characters',
  # release/acceptance-gate
  'Failed acceptance gate blocks release and announcement' =>
    'failed-acceptance-gate-blocks-release-and-announcement',
  'Gate failure stops the release' => 'gate-failure-stops-the-release',
  'Release is published from the tested tarball' => 'release-is-published-from-the-tested-tarball',
  'Gate passes and release uses the same tarball' => 'gate-passes-and-release-uses-the-same-tarball',
  'Released versions are announced for prod and stage' => 'released-versions-are-announced-for-prod-and-stage',
  'Release is announced to both environments' => 'release-is-announced-to-both-environments',
  'Announce holds only a single-repository App token' => 'announce-holds-only-a-single-repository-app-token',
  'Announce has no ambient token rights' => 'announce-has-no-ambient-token-rights',
  'Gate ref and acceptance_ref must agree' => 'gate-ref-and-acceptance-ref-must-agree',
  'Matching semver refs pass' => 'matching-semver-refs-pass',
  'Mismatched refs fail' => 'mismatched-refs-fail',
  'Non-semver ref fails' => 'non-semver-ref-fails',
  # tooling/live-docs-traceability (adopt-live-docs)
  'Every requirement has a tagged test' => 'every-requirement-has-a-tagged-test',
  'Slug rule turns headings into slugs' => 'slug-rule-turns-headings-into-slugs',
  'Requirement with no tagged test fails and is named' => 'requirement-with-no-tagged-test-fails-and-is-named',
  'Tagged tests must match a requirement and scenario' => 'tagged-tests-must-match-a-requirement-and-scenario',
  'Unknown requirement slug fails and is named' => 'unknown-requirement-slug-fails-and-is-named',
  'Scenario slug is matched only within its requirement' => 'scenario-slug-is-matched-only-within-its-requirement',
  'Requirements in in-flight changes are known' => 'requirements-in-in-flight-changes-are-known',
  'Fixture files are not scanned' => 'fixture-files-are-not-scanned',
  'Repo trace contains only slugs, statuses, locations and run metadata' =>
    'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
  'Formatter writes the v1 document' => 'formatter-writes-the-v1-document',
  'Cucumber writer writes the v1 document' => 'cucumber-writer-writes-the-v1-document',
  'Skipped and pending are told apart' => 'skipped-and-pending-are-told-apart',
  'Writers refuse malformed values' => 'writers-refuse-malformed-values',
  'Writers omit descriptions' => 'writers-omit-descriptions',
  'Per-job traces merge into one trace' => 'per-job-traces-merge-into-one-trace',
  'Merge combines both traces' => 'merge-combines-both-traces',
  'Merge rejects mismatched inputs' => 'merge-rejects-mismatched-inputs',
  'Merge rejects inputs outside the v1 shape' => 'merge-rejects-inputs-outside-the-v1-shape',
  'Merge rejects a duplicated result' => 'merge-rejects-a-duplicated-result',
  'CI publishes the trace on main and weekly' => 'ci-publishes-the-trace-on-main-and-weekly',
  'Spec and bdd upload their own traces' => 'spec-and-bdd-upload-their-own-traces',
  'Trace job merges and uploads on main and schedule' => 'trace-job-merges-and-uploads-on-main-and-schedule',
  'Notify-docs dispatches docs-refresh' => 'notify-docs-dispatches-docs-refresh',
  'Workflow credentials are least-privilege' => 'workflow-credentials-are-least-privilege',
  'Scheduled run creates no release' => 'scheduled-run-creates-no-release'
}.freeze

RSpec.describe 'RepoTrace::Slug',
               requirement: 'every-requirement-has-a-tagged-test',
               scenario: 'slug-rule-turns-headings-into-slugs' do
  SLUG_SAMPLES.merge(SLUG_REAL_HEADINGS).each do |heading, slug|
    it "turns #{heading.inspect} into #{slug}" do
      expect(RepoTrace::Slug.call(heading)).to eq(slug)
    end
  end

  it 'has a row for every requirement and scenario heading in the repo' do
    repo_root = File.expand_path('../../..', __dir__)
    files = Dir[File.join(repo_root, 'openspec/specs/**/spec.md')] +
            Dir[File.join(repo_root, 'openspec/changes/*/specs/**/spec.md')]
    headings = files.flat_map do |file|
      File.read(file).scan(/^\#{3,4} (?:Requirement|Scenario):\s*(.+?)\s*$/).flatten
    end
    expect(headings.uniq - SLUG_REAL_HEADINGS.keys).to be_empty
  end
end
