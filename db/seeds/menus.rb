# frozen_string_literal: true

require 'factory_bot_rails'

menu_data = {
  'st@example.com' => {
    'カット' => { sort_order: 1, price: 5500, duration: 60, description: 'プロのカット', category: ['カット'], is_active: 1 },
    'カラー' => { sort_order: 2, price: 7700, duration: 90, description: 'リッチなカラーリング', category: ['カラー'], is_active: 1 },
    'パーマ' => { sort_order: 3, price: 7700, duration: 90, description: 'しっかりとしたパーマ', category: ['パーマ'], is_active: 0 }
  },
  'st2@example.com' => {
    'カット' => { sort_order: 1, price: 3300, duration: 90, description: '普通のカット', category: ['カット'], is_active: 1 },
    'カラー' => { sort_order: 2, price: 5500, duration: 120, description: '自然なカラー', category: ['カラー'], is_active: 0 },
    'パーマ' => { sort_order: 3, price: 5500, duration: 120, description: 'ナチュラルなパーマ', category: ['パーマ'], is_active: 1 }
  },
  'st3@example.com' => {
    'カット' => { sort_order: 1, price: 11_000, duration: 30, description: 'カリスマのカット', category: ['カット'], is_active: 1 },
    'カラー' => { sort_order: 2, price: 22_000, duration: 60, description: 'エレガントなカラーリング', category: ['カラー'],
               is_active: 1 },
    'パーマ' => { sort_order: 3, price: 22_000, duration: 60, description: 'クリエイティブなパーマ', category: ['パーマ'],
               is_active: 1 },
    '縮毛矯正' => { sort_order: 4, price: 33_000, duration: 120, description: '自然な縮毛矯正', category: %w[縮毛矯正 スペシャル],
                is_active: 1 }
  }
}

menu_data.each do |stylist_email, menus|
  stylist = User.find_by(email: stylist_email)

  menus.each do |menu_name, attrs|
    Menu.create(
      stylist_id: stylist.id,
      sort_order: attrs[:sort_order],
      name: menu_name,
      price: attrs[:price],
      duration: attrs[:duration],
      description: attrs[:description],
      category: attrs[:category],
      is_active: attrs[:is_active]
    )
  end
end
