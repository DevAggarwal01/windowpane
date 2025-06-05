defmodule Aurora.Accounts.GlobalUID do
  import Ecto.Query
  alias Aurora.Repo
  alias Aurora.Accounts.User
  alias Aurora.Creators.Creator
  alias Aurora.Administration.Admin

  def uid_taken?(uid) do
    Enum.any?([
      Repo.exists?(from u in User, where: u.uid == ^uid),
      Repo.exists?(from c in Creator, where: c.uid == ^uid),
      Repo.exists?(from a in Admin, where: a.uid == ^uid)
    ])
  end

  def generate_unique_uid do
    uid = Ecto.UUID.generate()
    if uid_taken?(uid), do: generate_unique_uid(), else: uid
  end
end
