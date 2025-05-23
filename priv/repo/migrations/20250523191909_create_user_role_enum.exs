defmodule Aurora.Repo.Migrations.CreateUserRoleEnum do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE user_role AS ENUM ('viewer', 'creator')"
  end

  def down do
    execute "DROP TYPE user_role"
  end
end
