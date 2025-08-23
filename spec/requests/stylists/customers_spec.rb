# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Customers' do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:stylist) { create(:user, role: :stylist) }
  let(:yamada_customer) do
    create(:user, role: :customer,
      family_name: '山田', given_name: '太郎',
      family_name_kana: 'ヤマダ', given_name_kana: 'タロウ')
  end
  let(:sato_customer) do
    create(:user, role: :customer,
      family_name: '佐藤', given_name: '花子',
      family_name_kana: 'サトウ', given_name_kana: 'ハナコ')
  end
  let(:unrelated_customer) do
    create(:user, role: :customer,
      family_name: '田中', given_name: '次郎',
      family_name_kana: 'タナカ', given_name_kana: 'ジロウ')
  end
  let(:other_stylist) { create(:user, role: :stylist) }
  let(:menu) { create(:menu, stylist: stylist) }
  let(:other_menu) { create(:menu, stylist: other_stylist) }

  before do
    sign_in stylist

    [stylist, other_stylist].each do |s|
      create(:working_hour,
        stylist: s,
        target_date: Date.current,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('18:00'))

      start_slot_index = (Time.zone.parse('09:00').hour * 2)
      end_slot_index = (Time.zone.parse('18:00').hour * 2)

      (start_slot_index...end_slot_index).each do |slot_idx|
        create(:reservation_limit,
          stylist: s,
          target_date: Date.current,
          time_slot: slot_idx,
          max_reservations: 1)
      end
    end

    create(:reservation, customer: yamada_customer, stylist: stylist, status: :paid,
      menu_ids: [menu.id], start_date_str: Date.current.to_s, start_time_str: '10:00')
    create(:reservation, customer: sato_customer, stylist: stylist, status: :paid,
      menu_ids: [menu.id], start_date_str: Date.current.to_s, start_time_str: '11:00')

    create(:reservation, customer: unrelated_customer, stylist: other_stylist, status: :paid,
      menu_ids: [other_menu.id], start_date_str: Date.current.to_s, start_time_str: '10:00')
  end

  describe 'GET /stylists/customers' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'when user is authenticated as stylist' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'returns successful response' do
        get stylists_customers_path
        expect(response).to have_http_status(:ok)
      end

      it 'displays all customers for the stylist' do
        get stylists_customers_path
        expect(response.body).to include('山田 太郎')
        expect(response.body).to include('佐藤 花子')
        expect(response.body).to include('ヤマダ タロウ')
        expect(response.body).to include('サトウ ハナコ')
      end

      it 'does not display other stylists customers' do
        get stylists_customers_path
        expect(response.body).not_to include('田中 次郎')
        expect(response.body).not_to include('タナカ ジロウ')
      end

      it 'displays customer count' do
        get stylists_customers_path
        expect(response.body).to include('2件の顧客が見つかりました')
      end
    end

    context 'when searching with query parameter' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'filters customers by family name' do
        get stylists_customers_path, params: { query: '山田' }
        expect(response.body).to include('山田 太郎')
        expect(response.body).not_to include('佐藤 花子')
      end

      it 'filters customers by given name' do
        get stylists_customers_path, params: { query: '花子' }
        expect(response.body).to include('佐藤 花子')
        expect(response.body).not_to include('山田 太郎')
      end

      it 'filters customers by family name kana' do
        get stylists_customers_path, params: { query: 'ヤマダ' }
        expect(response.body).to include('山田 太郎')
        expect(response.body).not_to include('佐藤 花子')
      end

      it 'filters customers by given name kana' do
        get stylists_customers_path, params: { query: 'ハナコ' }
        expect(response.body).to include('佐藤 花子')
        expect(response.body).not_to include('山田 太郎')
      end

      it 'filters customers by partial match' do
        get stylists_customers_path, params: { query: '田' }
        expect(response.body).to include('山田 太郎')
        expect(response.body).not_to include('佐藤 花子')
      end

      it 'shows appropriate message when no results found' do
        get stylists_customers_path, params: { query: '存在しない名前' }
        expect(response.body).to include('「存在しない名前」に一致する顧客が見つかりませんでした')
      end

      it 'escapes HTML in search query for security' do
        malicious_query = '<script>alert("XSS")</script>'
        get stylists_customers_path, params: { query: malicious_query }
        expect(response.body).to include('&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;')
        expect(response.body).not_to include('<script>alert("XSS")</script>')
      end
    end

    context 'when no customers exist' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before do
        Reservation.destroy_all
      end

      it 'shows empty state message' do
        get stylists_customers_path
        expect(response.body).to include('まだ担当している顧客がいません')
        expect(response.body).to include('お客様からの予約をお待ちください')
      end
    end

    context 'when user is not authenticated' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before { sign_out stylist }

      it 'redirects to sign in page' do
        get stylists_customers_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is authenticated as customer' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:customer) { create(:user, role: :customer) }

      before do
        sign_out stylist
        sign_in customer
      end

      it 'redirects or denies access' do
        get stylists_customers_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /stylists/customers/:id' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'when viewing customer details' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'returns successful response' do
        get stylists_customer_path(yamada_customer)
        expect(response).to have_http_status(:ok)
      end

      it 'displays customer information' do
        get stylists_customer_path(yamada_customer)
        expect(response.body).to include('山田 太郎')
        expect(response.body).to include('ヤマダ タロウ')
      end

      it 'displays visit information' do
        get stylists_customer_path(yamada_customer)
        expect(response.body).to include('来店情報')
        expect(response.body).to include('来店回数')
      end
    end

    context 'when trying to view other stylists customer' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'returns not found response' do
        get stylists_customer_path(unrelated_customer)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when customer does not exist' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'returns not found response' do
        get stylists_customer_path(999_999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'Security' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:non_stylist) { create(:user, role: :customer) }

    describe 'XSS Protection' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'prevents XSS in search query' do
        malicious_query = '<script>alert("XSS")</script>'
        get stylists_customers_path, params: { query: malicious_query }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('<script>alert("XSS")</script>')
        expect(response.body).to include(CGI.escapeHTML(malicious_query))
      end

      it 'sanitizes malicious HTML in search results' do
        get stylists_customers_path, params: { query: '<img src=x onerror=alert(1)>' }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('<img src=x onerror=alert(1)>')
      end
    end

    describe 'SQL Injection Protection' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'prevents SQL injection in search query' do
        malicious_query = "'; DROP TABLE users; --"
        expect do
          get stylists_customers_path, params: { query: malicious_query }
        end.not_to raise_error

        expect(response).to have_http_status(:ok)
        expect(User.count).to be > 0
      end

      it 'handles single quotes safely' do
        query_with_quotes = "O'Reilly"
        expect do
          get stylists_customers_path, params: { query: query_with_quotes }
        end.not_to raise_error

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Access Control' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'prevents access by non-authenticated users' do
        sign_out stylist
        get stylists_customers_path

        expect(response).to redirect_to(new_user_session_path)
      end

      it 'prevents access by customers' do
        sign_out stylist
        sign_in non_stylist
        get stylists_customers_path

        expect(response).to redirect_to(root_path)
      end

      it 'prevents access to other stylists customers in show action' do
        # Create a customer that belongs to another stylist
        unrelated_customer = create(:user, role: :customer)
        get stylists_customer_path(unrelated_customer)
        expect(response).to have_http_status(:not_found)
      end

      it 'allows access to own customers' do
        get stylists_customer_path(yamada_customer)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Parameter Validation' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'handles empty search parameters' do
        get stylists_customers_path, params: { query: '' }
        expect(response).to have_http_status(:ok)
      end

      it 'handles nil search parameters' do
        get stylists_customers_path, params: { query: nil }
        expect(response).to have_http_status(:ok)
      end

      it 'handles very long search queries' do
        long_query = 'a' * 1000
        get stylists_customers_path, params: { query: long_query }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
