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

  describe "get_display_name/1" do
    test "returns user name if set" do
      user = AccountsFixtures.user_fixture(%{name: "John Doe"})
      assert RogsIdentity.get_display_name(user.id) == "John Doe"
    end

    test "returns email if name is not set" do
      user = AccountsFixtures.user_fixture(%{name: nil})
      assert RogsIdentity.get_display_name(user.id) == user.email
    end

    test "returns email if name is empty string" do
      user = AccountsFixtures.user_fixture(%{name: ""})
      assert RogsIdentity.get_display_name(user.id) == user.email
    end

    test "returns Anonymous if user does not exist" do
      assert RogsIdentity.get_display_name(Ecto.UUID.generate()) == "Anonymous"
    end
  end
end
