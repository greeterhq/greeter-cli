# frozen_string_literal: true

require 'spec_helper'

# RepoTrace::TagOnlyDiff compares an existing test file before and after
# tagging. Only requirement/scenario tags, tagged context wrappers around
# it_behaves_like lines, feature tag lines and whitespace may change. Each case
# is a before/after pair under spec/fixtures/tag_only/<case>/. The `path:`
# argument is the file's repo path; its extension picks .rb or .feature rules.
# Design-only check (no OpenSpec scenario), so these examples are untagged.
RSpec.describe 'RepoTrace::TagOnlyDiff' do
  let(:fixtures) { File.expand_path('../../fixtures/tag_only', __dir__) }

  def diff(kase, path)
    ext = File.extname(path)
    RepoTrace::TagOnlyDiff.call(path: path,
                                before: File.read(File.join(fixtures, kase, "before#{ext}")),
                                after: File.read(File.join(fixtures, kase, "after#{ext}")))
  end

  {
    'tags_added' => 'spec/unit/example_spec.rb',
    'wrapper_added' => 'spec/unit/example_spec.rb',
    'feature_tags' => 'features/greeting.feature'
  }.each do |kase, path|
    it "allows #{kase.tr('_', ' ')}" do
      expect(diff(kase, path)).to eq([])
    end
  end

  {
    'assertion_changed' => 'spec/unit/example_spec.rb',
    'metadata_added' => 'spec/unit/example_spec.rb',
    'wrapper_changes_inner' => 'spec/unit/example_spec.rb',
    'feature_step_changed' => 'features/greeting.feature',
    'feature_name_changed' => 'features/greeting.feature'
  }.each do |kase, path|
    it "reports #{kase.tr('_', ' ')}, naming the file" do
      expect(diff(kase, path)).to include(a_string_including(path))
    end
  end

  it 'reports nothing when the file is unchanged' do
    text = File.read(File.join(fixtures, 'tags_added', 'before.rb'))
    expect(RepoTrace::TagOnlyDiff.call(path: 'spec/unit/example_spec.rb', before: text, after: text)).to eq([])
  end
end
