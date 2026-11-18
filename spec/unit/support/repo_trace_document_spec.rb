# frozen_string_literal: true

require 'spec_helper'

# RepoTrace::Document holds the validation both writers (RSpec formatter and
# Cucumber writer) go through. Locations come from the test runners and cannot
# be forced to contain '..' through a real run, so the location rules (S8) are
# tested here, at the shared document.
RSpec.describe 'RepoTrace::Document',
               requirement: 'repo-trace-contains-only-slugs-statuses-locations-and-run-metadata',
               scenario: 'writers-refuse-malformed-values' do
  # String keys, so the trace check's text scan doesn't read these values as tags.
  def result(**overrides)
    valid = { 'requirement' => 'greets-a-named-guest', 'scenario' => 'greets-a-named-guest',
              'status' => 'passed', 'source' => 'rspec', 'location' => 'spec/unit/bin/x_spec.rb:12' }
    RepoTrace::Document.result(**valid.transform_keys(&:to_sym), **overrides)
  end

  it 'accepts a nested spec location for rspec' do
    expect(result).to eq('requirement' => 'greets-a-named-guest', 'scenario' => 'greets-a-named-guest',
                         'status' => 'passed', 'source' => 'rspec', 'location' => 'spec/unit/bin/x_spec.rb:12')
  end

  it 'accepts a feature location for cucumber' do
    expect(result(source: 'cucumber', location: 'features/greeting.feature:7')['location'])
      .to eq('features/greeting.feature:7')
  end

  {
    'a .. segment' => ['rspec', 'spec/../etc/x.rb:1'],
    'a . segment' => ['rspec', 'spec/./x.rb:1'],
    'an empty segment' => ['rspec', 'spec//x.rb:1'],
    'a leading slash' => ['rspec', '/spec/x.rb:1'],
    'line 0' => ['rspec', 'spec/x.rb:0'],
    'no line' => ['rspec', 'spec/x.rb'],
    'a feature path for rspec' => ['rspec', 'features/greeting.feature:3'],
    'a spec path for cucumber' => ['cucumber', 'spec/x_spec.rb:3'],
    'a .. segment in a feature path' => ['cucumber', 'features/../x.feature:2']
  }.each do |label, (source, location)|
    it "refuses a location with #{label}, without echoing it", :aggregate_failures do
      expect { result(source: source, location: location) }.to raise_error do |error|
        expect(error.message).to start_with('invalid location')
        expect(error.message).not_to include(location)
      end
    end
  end

  # String keys, so the trace check's text scan doesn't read these bad values as tags.
  {
    'requirement' => 'Alice Smith',
    'scenario' => 'Not_A_Slug',
    'status' => 'broken',
    'source' => 'junit'
  }.each do |field, value|
    it "refuses an invalid #{field}, without echoing it", :aggregate_failures do
      expect { result(field.to_sym => value) }.to raise_error do |error|
        expect(error.message).to start_with("invalid #{field}")
        expect(error.message).not_to include(value)
      end
    end
  end
end
