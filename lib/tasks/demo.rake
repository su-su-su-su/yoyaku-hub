# frozen_string_literal: true

namespace :demo do
  desc 'Reset demo users data'
  task reset: :environment do
    cleaner = DemoDataCleaner.new
    count = cleaner.reset
    puts "Demo users data has been reset (#{count} users deleted)"
  end

  desc 'Daily cleanup of demo data'
  task daily_cleanup: :environment do
    puts "[#{Time.current}] デモデータの日次クリーンアップを開始します"

    cleaner = DemoDataCleaner.new
    deleted_count = cleaner.perform_cleanup

    puts "[#{Time.current}] デモデータクリーンアップ完了:"
    puts "  - ユーザー: #{deleted_count[:users]}件"
    puts "  - 予約: #{deleted_count[:reservations]}件"
    puts "  - カルテ: #{deleted_count[:chartes]}件"

    Rails.logger.info "Demo cleanup completed: #{deleted_count.inspect}"
  end

  desc 'Cleanup demo data before backup (silent mode)'
  task cleanup_before_backup: :environment do
    cleaner = DemoDataCleaner.new
    count = cleaner.silent_cleanup
    Rails.logger.info "Cleaned up #{count} demo users before backup" if count.positive?
  end
end

# デモデータクリーナークラス
class DemoDataCleaner
  def initialize
    @demo_users = find_demo_users
  end

  def reset
    cleanup_user_data(@demo_users)
    count = @demo_users.count
    @demo_users.destroy_all
    count
  end

  # rubocop:disable Metrics/AbcSize
  def perform_cleanup
    deleted_count = { users: 0, reservations: 0, chartes: 0, accountings: 0 }

    @demo_users.find_each do |user|
      deleted_count[:reservations] += user.reservations.count + user.stylist_reservations.count
      deleted_count[:chartes] += user.stylist_chartes.count + user.customer_chartes.count
      deleted_count[:users] += 1

      # 単一のユーザーを削除
      user.reservations.destroy_all
      user.stylist_reservations.destroy_all
      user.stylist_chartes.destroy_all
      user.customer_chartes.destroy_all
    end

    @demo_users.reload.destroy_all
    deleted_count
  end
  # rubocop:enable Metrics/AbcSize

  def silent_cleanup
    return 0 unless @demo_users.exists?

    count = @demo_users.count
    cleanup_user_data(@demo_users)
    @demo_users.destroy_all
    count
  end

  private

  def find_demo_users
    User.where("email LIKE 'demo_stylist_%@example.com' OR email LIKE 'demo_customer_%@example.com'")
  end

  def cleanup_user_data(users)
    # usersがActiveRecord::Relationか配列かを判定
    if users.respond_to?(:find_each)
      users.find_each do |user|
        user.reservations.destroy_all
        user.stylist_reservations.destroy_all
        user.stylist_chartes.destroy_all
        user.customer_chartes.destroy_all
      end
    else
      # 配列の場合
      users.each do |user|
        user.reservations.destroy_all
        user.stylist_reservations.destroy_all
        user.stylist_chartes.destroy_all
        user.customer_chartes.destroy_all
      end
    end
  end
end
