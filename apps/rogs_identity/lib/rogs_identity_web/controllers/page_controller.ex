defmodule RogsIdentityWeb.PageController do
  use RogsIdentityWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
