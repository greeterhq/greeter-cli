# frozen_string_literal: true

RSpec.describe 'Tag-only fixture' do
  context 'Rejects an empty or whitespace-only name',
          requirement: 'rejects-an-empty-or-whitespace-only-name',
          scenario: 'rejects-an-empty-or-whitespace-only-name' do
    it_behaves_like 'a rejected name', ''
    it_behaves_like 'a rejected name', '   '
  end
end
