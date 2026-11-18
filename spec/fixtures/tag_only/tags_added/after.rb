# frozen_string_literal: true

RSpec.describe 'Tag-only fixture' do
  describe 'Some scenario',
           requirement: 'some-requirement',
           scenario: 'some-scenario' do
    it 'checks a thing' do
      expect(1).to eq(1)
    end
  end

  it 'checks another thing', requirement: 'some-requirement', scenario: 'another-scenario' do
    expect(2).to eq(2)
  end
end
