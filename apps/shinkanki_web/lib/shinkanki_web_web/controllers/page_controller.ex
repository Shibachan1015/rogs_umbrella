defmodule ShinkankiWebWeb.PageController do
  use ShinkankiWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
