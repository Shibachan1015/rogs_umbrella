defmodule RogsCommWeb.PageController do
  use RogsCommWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
