# frozen_string_literal: true

RSpec.describe 'Tag-only fixture' do
  it_behaves_like 'a rejected name', ''
  it_behaves_like 'a rejected name', '   '
end
