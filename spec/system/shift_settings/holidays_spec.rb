# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylist Holiday Settings' do
  let(:stylist) { create(:user, role: :stylist) }

  before do
    sign_in stylist
  end

  it 'displays the holiday form correctly' do
    visit stylists_shift_settings_path

    expect(page).to have_content('休業日')
    expect(page).to have_content('休業日にしたい曜日にチェックを入れてください')

    form = find('form[action$="/stylists/shift_settings/holidays"]')
    expect(form).to have_field(type: 'checkbox', count: 8)
    expect(form).to have_field(type: 'hidden', name: 'holiday[day_of_weeks][]', with: '', visible: :hidden)
    expect(form).to have_button('設定')
  end

  it 'can set new holidays' do
    visit stylists_shift_settings_path

    form = find('form[action$="/stylists/shift_settings/holidays"]')

    within(form) do
      find('label', text: '月曜日').find('input[type="checkbox"]').check
      find('label', text: '金曜日').find('input[type="checkbox"]').check
      click_on '設定'
    end

    expect(page).to have_content(I18n.t('stylists.shift_settings.holidays.create_success'))

    expect(Holiday).to exist(stylist_id: stylist.id, day_of_week: 1)
    expect(Holiday).to exist(stylist_id: stylist.id, day_of_week: 5)

    visit stylists_shift_settings_path
    form = find('form[action$="/stylists/shift_settings/holidays"]')
    expect(form.find('label', text: '月曜日').find('input[type="checkbox"]')).to be_checked
    expect(form.find('label', text: '金曜日').find('input[type="checkbox"]')).to be_checked
  end

  it 'can update existing holidays' do
    create(:holiday, stylist: stylist, day_of_week: 1)
    create(:holiday, stylist: stylist, day_of_week: 5)

    visit stylists_shift_settings_path

    form = find('form[action$="/stylists/shift_settings/holidays"]')

    expect(form.find('label', text: '月曜日').find('input[type="checkbox"]')).to be_checked
    expect(form.find('label', text: '金曜日').find('input[type="checkbox"]')).to be_checked

    within(form) do
      find('label', text: '月曜日').find('input[type="checkbox"]').uncheck
      find('label', text: '日曜日').find('input[type="checkbox"]').check
      click_on '設定'
    end

    expect(page).to have_content(I18n.t('stylists.shift_settings.holidays.create_success'))

    expect(Holiday).to exist(stylist_id: stylist.id, day_of_week: 0)
    expect(Holiday).not_to exist(stylist_id: stylist.id, day_of_week: 1)
    expect(Holiday).to exist(stylist_id: stylist.id, day_of_week: 5)

    visit stylists_shift_settings_path
    form = find('form[action$="/stylists/shift_settings/holidays"]')
    expect(form.find('label', text: '日曜日').find('input[type="checkbox"]')).to be_checked
    expect(form.find('label', text: '月曜日').find('input[type="checkbox"]')).not_to be_checked
    expect(form.find('label', text: '金曜日').find('input[type="checkbox"]')).to be_checked
  end

  it 'can remove all holidays' do
    create(:holiday, stylist: stylist, day_of_week: 0)
    create(:holiday, stylist: stylist, day_of_week: 6)

    expect(Holiday.where(stylist_id: stylist.id).count).to eq(2)

    visit stylists_shift_settings_path

    form = find('form[action$="/stylists/shift_settings/holidays"]')

    expect(form.find('label', text: '日曜日').find('input[type="checkbox"]')).to be_checked
    expect(form.find('label', text: '土曜日').find('input[type="checkbox"]')).to be_checked

    expect(form).to have_field(type: 'hidden', name: 'holiday[day_of_weeks][]', with: '', visible: :hidden)

    within(form) do
      find('label', text: '日曜日').find('input[type="checkbox"]').uncheck
      find('label', text: '土曜日').find('input[type="checkbox"]').uncheck
      click_on '設定'
    end

    expect(page).to have_content(I18n.t('stylists.shift_settings.holidays.create_success'))

    expect(Holiday.where(stylist_id: stylist.id).count).to eq(0)

    visit stylists_shift_settings_path
    form = find('form[action$="/stylists/shift_settings/holidays"]')
    form.all('input[type="checkbox"]').each do |checkbox|
      expect(checkbox).not_to be_checked
    end
  end

  it 'can set holidays for national holidays' do
    visit stylists_shift_settings_path

    form = find('form[action$="/stylists/shift_settings/holidays"]')

    within(form) do
      find('label', text: '祝祭日').find('input[type="checkbox"]').check
      click_on '設定'
    end

    expect(page).to have_content(I18n.t('stylists.shift_settings.holidays.create_success'))

    expect(Holiday).to exist(stylist_id: stylist.id, day_of_week: 7)

    visit stylists_shift_settings_path
    form = find('form[action$="/stylists/shift_settings/holidays"]')
    expect(form.find('label', text: '祝祭日').find('input[type="checkbox"]')).to be_checked
  end

  describe 'Access restrictions' do
    it 'non-stylist users cannot access the settings page' do
      customer = create(:user, role: :customer)
      sign_in customer

      visit stylists_shift_settings_path

      expect(page).to have_no_current_path stylists_shift_settings_path, ignore_query: true
    end
  end
end
