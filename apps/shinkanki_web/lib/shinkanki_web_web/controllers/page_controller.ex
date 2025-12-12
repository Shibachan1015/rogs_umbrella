defmodule ShinkankiWebWeb.PageController do
  use ShinkankiWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def rulebook(conn, _params) do
    render(conn, :rulebook)
  end

  def talent_cards(conn, _params) do
    render(conn, :talent_cards)
  end

  def cocreation_cards(conn, _params) do
    render(conn, :cocreation_cards)
  end

  def action_cards(conn, _params) do
    render(conn, :action_cards)
  end

  def hitoyo_cards(conn, _params) do
    render(conn, :hitoyo_cards)
  end

  def migaki_cards(conn, _params) do
    render(conn, :migaki_cards)
  end

  def kuukan(conn, _params) do
    render(conn, :kuukan)
  end
end
