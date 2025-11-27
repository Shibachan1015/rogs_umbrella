defmodule RogsGameWeb.PageController do
  use RogsGameWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
