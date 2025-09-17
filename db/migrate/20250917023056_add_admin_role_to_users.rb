class AddAdminRoleToUsers < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL
      ALTER TABLE users
      ALTER COLUMN role TYPE integer
      USING CASE
        WHEN role = 0 THEN 0
        WHEN role = 1 THEN 1
        ELSE role::integer
      END
    SQL
  end

  def down
    User.where(role: 2).update_all(role: 0)
  end
end
