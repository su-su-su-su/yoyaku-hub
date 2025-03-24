# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Menu do
  let(:stylist) { create(:user, :stylist) }
  let(:customer) { create(:user, :customer) }

  def setup_working_hour(start_time: '09:00', end_time: '17:00')
    create(:working_hour,
      stylist: stylist,
      day_of_week: Date.current.wday,
      start_time: Time.zone.parse(start_time),
      end_time: Time.zone.parse(end_time))
  end

  before do
    working_hour = setup_working_hour
    allow(WorkingHour).to receive(:date_only_for).and_return(working_hour)
    allow(ReservationLimit).to receive(:find_by).and_return(
      instance_double(ReservationLimit, max_reservations: 1)
    )
  end

  describe '定数' do
    it 'has MAX_MENUS_PER_STYLIST constant' do
      expect(described_class::MAX_MENUS_PER_STYLIST).to eq(30)
    end
  end

  describe 'バリデーション' do
    context 'when it has basic validations' do
      it 'is valid with valid attributes' do
        menu = build(:menu)
        expect(menu).to be_valid
      end

      it 'is invalid without a name' do
        menu = build(:menu, name: nil)
        expect(menu).not_to be_valid
        expect(menu.errors[:name]).to include(I18n.t('errors.messages.blank'))
      end

      it 'is invalid without a price' do
        menu = build(:menu, price: nil)
        expect(menu).not_to be_valid
        expect(menu.errors[:price]).to include(I18n.t('errors.messages.blank'))
      end

      it 'is invalid without a duration' do
        menu = build(:menu, duration: nil)
        expect(menu).not_to be_valid
        expect(menu.errors[:duration]).to include(I18n.t('errors.messages.blank'))
      end

      it 'is invalid without a stylist' do
        menu = build(:menu, stylist: nil)
        expect(menu).not_to be_valid
        expect(menu.errors[:stylist]).to include(I18n.t('errors.messages.blank'))
      end

      it 'is valid without a description' do
        menu = build(:menu, :without_description)
        expect(menu).to be_valid
      end

      it 'is valid with different categories' do
        menu_cut = build(:menu, :cut)
        menu_color = build(:menu, :color)
        menu_multi = build(:menu, :multi_category)

        expect(menu_cut).to be_valid
        expect(menu_color).to be_valid
        expect(menu_multi).to be_valid
      end
    end

    context 'when validating price' do
      it 'is invalid with negative price' do
        menu = build(:menu, price: -1000)
        expect(menu).not_to be_valid
        expect(menu.errors[:price]).to include(I18n.t('errors.messages.greater_than_or_equal_to', count: 0))
      end
    end

    context 'when validating duration' do
      it 'is valid with zero duration' do
        menu = build(:menu, duration: 0)
        expect(menu).to be_valid
      end

      it 'is invalid with negative duration' do
        menu = build(:menu, duration: -10)
        expect(menu).not_to be_valid
        expect(menu.errors[:duration]).to include(I18n.t('errors.messages.greater_than_or_equal_to', count: 0))
      end
    end

    context 'when validating name uniqueness' do
      it 'is invalid with duplicate name for the same stylist' do
        create(:menu, stylist: stylist, name: 'カット')
        duplicate_menu = build(:menu, stylist: stylist, name: 'カット')
        expect(duplicate_menu).not_to be_valid
        expect(duplicate_menu.errors[:name]).to include(I18n.t('errors.messages.taken'))
      end

      it 'is valid with the same name for different stylists' do
        stylist2 = create(:user, :stylist)
        create(:menu, stylist: stylist, name: 'カット')
        menu = build(:menu, stylist: stylist2, name: 'カット')
        expect(menu).to be_valid
      end
    end

    context 'when validating menu limit per stylist' do
      it 'is valid when stylist has less than MAX_MENUS_PER_STYLIST menus' do
        create_list(:menu, described_class::MAX_MENUS_PER_STYLIST - 1, stylist: stylist)
        menu = build(:menu, stylist: stylist)
        expect(menu).to be_valid
      end

      it 'is invalid when stylist has MAX_MENUS_PER_STYLIST menus' do
        create_list(:menu, described_class::MAX_MENUS_PER_STYLIST, stylist: stylist)
        menu = build(:menu, stylist: stylist)
        expect(menu).not_to be_valid
        expect(menu.errors[:base]).to include("メニューは最大#{described_class::MAX_MENUS_PER_STYLIST}件までです")
      end
    end
  end

  describe 'アソシエーション' do
    let(:menu) { create(:menu, stylist: stylist) }

    it 'belongs to a stylist' do
      expect(menu.stylist).to eq(stylist)
    end

    it 'has many reservation_menu_selections' do
      reservation = create(:reservation, customer: customer, stylist: stylist,
        start_date_str: Date.current.to_s, start_time_str: '10:00')
      selection = create(:reservation_menu_selection, reservation: reservation, menu: menu)
      expect(menu.reservation_menu_selections).to include(selection)
    end

    it 'has many reservations through reservation_menu_selections' do
      reservation = create(:reservation, customer: customer, stylist: stylist,
        start_date_str: Date.current.to_s, start_time_str: '10:00')
      create(:reservation_menu_selection, reservation: reservation, menu: menu)
      expect(menu.reservations).to include(reservation)
    end
  end

  describe 'スコープ' do
    let(:stylist2) { create(:user, :stylist) }
    let!(:stylist_menu) { create(:menu, stylist: stylist, name: 'メニューA') }
    let!(:other_stylist_menu) { create(:menu, stylist: stylist2, name: 'メニューB') }

    context 'when using by_stylist scope' do
      it 'returns menus for the specified stylist' do
        expect(described_class.by_stylist(stylist)).to include(stylist_menu)
        expect(described_class.by_stylist(stylist)).not_to include(other_stylist_menu)
      end
    end
  end

  describe 'コールバック' do
    context 'when assign_sort_order_if_blank is triggered' do
      it 'assigns sort_order automatically if not specified' do
        menu = create(:menu, stylist: stylist, sort_order: nil)
        expect(menu.sort_order).not_to be_nil
      end

      it 'uses the first available order number' do
        create(:menu, stylist: stylist, sort_order: 1)
        create(:menu, stylist: stylist, sort_order: 3)
        menu = create(:menu, stylist: stylist, sort_order: nil)
        expect(menu.sort_order).to eq(2)
      end
    end

    context 'when shift_others is triggered' do
      it 'shifts other menus when inserting at a lower position' do
        menu1 = create(:menu, stylist: stylist, sort_order: 1)
        menu2 = create(:menu, stylist: stylist, sort_order: 2)
        menu3 = create(:menu, stylist: stylist, sort_order: 3)

        menu3.update(sort_order: 1)

        expect(menu1.reload.sort_order).to eq(2)
        expect(menu2.reload.sort_order).to eq(3)
        expect(menu3.reload.sort_order).to eq(1)
      end

      it 'shifts other menus when inserting at a higher position' do
        menu1 = create(:menu, stylist: stylist, sort_order: 1)
        menu2 = create(:menu, stylist: stylist, sort_order: 2)
        menu3 = create(:menu, stylist: stylist, sort_order: 3)

        menu1.update(sort_order: 3)

        expect(menu1.reload.sort_order).to eq(3)
        expect(menu2.reload.sort_order).to eq(1)
        expect(menu3.reload.sort_order).to eq(2)
      end
    end
  end

  describe 'ソート' do
    before do
      create(:menu, stylist: stylist, name: 'Cメニュー', sort_order: 3)
      create(:menu, stylist: stylist, name: 'Aメニュー', sort_order: 1)
      create(:menu, stylist: stylist, name: 'Bメニュー', sort_order: 2)
    end

    it 'sorts menus by sort_order' do
      sorted_menus = stylist.menus.order(:sort_order)
      expect(sorted_menus.map(&:name)).to eq(%w[Aメニュー Bメニュー Cメニュー])
    end
  end
end
