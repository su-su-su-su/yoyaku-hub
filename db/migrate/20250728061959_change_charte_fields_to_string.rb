class ChangeCharteFieldsToString < ActiveRecord::Migration[7.2]
  def up
    change_column :chartes, :treatment_memo, :string
    change_column :chartes, :remarks, :string
  end

  def down
    change_column :chartes, :treatment_memo, :text
    change_column :chartes, :remarks, :text
  end
end
