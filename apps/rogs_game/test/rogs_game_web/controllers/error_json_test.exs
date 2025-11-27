defmodule RogsGameWeb.ErrorJSONTest do
  use RogsGameWeb.ConnCase, async: true

  test "renders 404" do
    assert RogsGameWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert RogsGameWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
