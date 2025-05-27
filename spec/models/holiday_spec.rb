# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Holiday do
  let(:stylist) { create(:user, role: :stylist) }

  describe 'associations' do
    let(:holiday) { create(:holiday, stylist: stylist) }

    it 'belongs to a stylist' do
      expect(holiday.stylist).to eq(stylist)
    end
  end
end
