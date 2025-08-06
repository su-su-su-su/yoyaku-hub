# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe User do
  describe 'デモユーザー関連のメソッド' do
    let(:demo_customer) do
      create(:user,
        email: 'demo_customer_abc123@example.com',
        role: 'customer',
        family_name: 'デモ',
        given_name: 'カスタマー')
    end

    let(:demo_stylist) do
      create(:user,
        email: 'demo_stylist_abc123@example.com',
        role: 'stylist',
        family_name: 'デモ',
        given_name: 'スタイリスト')
    end

    let(:demo_stylist_different_session) do
      create(:user,
        email: 'demo_stylist_xyz789@example.com',
        role: 'stylist',
        family_name: 'デモ',
        given_name: 'スタイリスト2')
    end

    let(:regular_customer) { create(:user, role: 'customer') }
    let(:regular_stylist) { create(:user, role: 'stylist') }

    describe '#demo_customer?' do
      it 'デモカスタマーの場合trueを返す' do
        expect(demo_customer.demo_customer?).to be true
      end

      it 'デモスタイリストの場合falseを返す' do
        expect(demo_stylist.demo_customer?).to be false
      end

      it '通常のカスタマーの場合falseを返す' do
        expect(regular_customer.demo_customer?).to be false
      end
    end

    describe '#demo_stylist?' do
      it 'デモスタイリストの場合trueを返す' do
        expect(demo_stylist.demo_stylist?).to be true
      end

      it 'デモカスタマーの場合falseを返す' do
        expect(demo_customer.demo_stylist?).to be false
      end

      it '通常のスタイリストの場合falseを返す' do
        expect(regular_stylist.demo_stylist?).to be false
      end
    end

    describe '#demo_user?' do
      it 'デモカスタマーの場合trueを返す' do
        expect(demo_customer.demo_user?).to be true
      end

      it 'デモスタイリストの場合trueを返す' do
        expect(demo_stylist.demo_user?).to be true
      end

      it '通常のカスタマーの場合falseを返す' do
        expect(regular_customer.demo_user?).to be false
      end

      it '通常のスタイリストの場合falseを返す' do
        expect(regular_stylist.demo_user?).to be false
      end
    end

    describe '#demo_session_id' do
      it 'デモカスタマーのセッションIDを返す' do
        expect(demo_customer.demo_session_id).to eq 'abc123'
      end

      it 'デモスタイリストのセッションIDを返す' do
        expect(demo_stylist.demo_session_id).to eq 'abc123'
      end

      it '異なるセッションのデモスタイリストのセッションIDを返す' do
        expect(demo_stylist_different_session.demo_session_id).to eq 'xyz789'
      end

      it '通常のユーザーの場合nilを返す' do
        expect(regular_customer.demo_session_id).to be_nil
      end
    end

    describe '#same_demo_session?' do
      it '同じセッションのデモユーザー同士の場合trueを返す' do
        expect(demo_customer.same_demo_session?(demo_stylist)).to be true
      end

      it '異なるセッションのデモユーザー同士の場合falseを返す' do
        expect(demo_customer.same_demo_session?(demo_stylist_different_session)).to be false
      end

      it 'デモユーザーと通常ユーザーの場合falseを返す' do
        expect(demo_customer.same_demo_session?(regular_stylist)).to be false
      end

      it '通常ユーザー同士の場合falseを返す' do
        expect(regular_customer.same_demo_session?(regular_stylist)).to be false
      end
    end

    describe '.demo_stylists_for_customer' do
      it 'デモカスタマーに対応するデモスタイリストを返す' do
        stylists = described_class.demo_stylists_for_customer(demo_customer)
        expect(stylists).to include(demo_stylist)
        expect(stylists).not_to include(demo_stylist_different_session)
      end

      it '通常のカスタマーの場合空を返す' do
        stylists = described_class.demo_stylists_for_customer(regular_customer)
        expect(stylists).to be_empty
      end

      it 'nilの場合空を返す' do
        stylists = described_class.demo_stylists_for_customer(nil)
        expect(stylists).to be_empty
      end
    end

    describe '#can_book_with_stylist?' do
      # rubocop:disable RSpec/NestedGroups, RSpec/ContextWording
      context 'デモカスタマーの場合' do
        it '同じセッションのデモスタイリストには予約可能' do
          expect(demo_customer.can_book_with_stylist?(demo_stylist)).to be true
        end

        it '異なるセッションのデモスタイリストには予約不可' do
          expect(demo_customer.can_book_with_stylist?(demo_stylist_different_session)).to be false
        end

        it '通常のスタイリストには予約不可' do
          expect(demo_customer.can_book_with_stylist?(regular_stylist)).to be false
        end

        it 'nilの場合予約不可' do
          expect(demo_customer.can_book_with_stylist?(nil)).to be false
        end
      end

      context '通常のカスタマーの場合' do
        it 'どのスタイリストにも予約可能' do
          expect(regular_customer.can_book_with_stylist?(regular_stylist)).to be true
          expect(regular_customer.can_book_with_stylist?(demo_stylist)).to be true
          expect(regular_customer.can_book_with_stylist?(demo_stylist_different_session)).to be true
        end
      end
      # rubocop:enable RSpec/NestedGroups, RSpec/ContextWording
    end
  end
  # rubocop:enable Metrics/BlockLength
end
