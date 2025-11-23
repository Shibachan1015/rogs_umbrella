defmodule RogsIdentityTest do
  use RogsIdentity.DataCase

  alias RogsIdentity.AccountsFixtures

  describe "get_user/1" do
    test "returns the user with given id" do
      user = AccountsFixtures.user_fixture()
      assert RogsIdentity.get_user(user.id) == user
    end

    test "returns nil if user does not exist" do
      assert RogsIdentity.get_user(Ecto.UUID.generate()) == nil
    end
  end
end
