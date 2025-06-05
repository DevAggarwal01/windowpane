defmodule Aurora.Repo.Migrations.AddUid do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    alter table(:users) do
      add :uid, :uuid
    end

    alter table(:creators) do
      add :uid, :uuid
    end

    alter table(:admins) do
      add :uid, :uuid
    end

    create unique_index(:users, [:uid])
    create unique_index(:creators, [:uid])
    create unique_index(:admins, [:uid])

    execute("UPDATE users SET uid = gen_random_uuid() WHERE uid IS NULL")
    execute("UPDATE creators SET uid = gen_random_uuid() WHERE uid IS NULL")
    execute("UPDATE admins SET uid = gen_random_uuid() WHERE uid IS NULL")

    alter table(:users) do
      modify :uid, :uuid, null: false
    end

    alter table(:creators) do
      modify :uid, :uuid, null: false
    end

    alter table(:admins) do
      modify :uid, :uuid, null: false
    end
  end
end
