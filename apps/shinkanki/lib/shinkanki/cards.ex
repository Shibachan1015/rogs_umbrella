defmodule Shinkanki.Cards do
  @moduledoc """
  The Cards context.
  Provides CRUD operations for action cards, event cards, and talent cards.
  Editing is allowed, creation is allowed, deletion is NOT allowed.
  """

  import Ecto.Query, warn: false
  alias Shinkanki.Repo
  alias Shinkanki.CardCache
  alias Shinkanki.Games.{ActionCard, EventCard, TalentCard}

  # ============================================================
  # Action Cards
  # ============================================================

  def list_action_cards do
    ActionCard
    |> order_by([c], asc: c.category, asc: c.name)
    |> Repo.all()
  end

  def get_action_card(id) do
    Repo.get(ActionCard, id)
  end

  def get_action_card!(id) do
    Repo.get!(ActionCard, id)
  end

  def create_action_card(attrs \\ %{}) do
    result =
      %ActionCard{}
      |> ActionCard.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, _card} -> CardCache.reload()
      _ -> :ok
    end

    result
  end

  def update_action_card(%ActionCard{} = card, attrs) do
    result =
      card
      |> ActionCard.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, _card} -> CardCache.reload()
      _ -> :ok
    end

    result
  end

  def change_action_card(%ActionCard{} = card, attrs \\ %{}) do
    ActionCard.changeset(card, attrs)
  end

  # ============================================================
  # Event Cards (Hitoyo)
  # ============================================================

  def list_event_cards do
    EventCard
    |> order_by([c], asc: c.type, asc: c.name)
    |> Repo.all()
  end

  def get_event_card(id) do
    Repo.get(EventCard, id)
  end

  def get_event_card!(id) do
    Repo.get!(EventCard, id)
  end

  def create_event_card(attrs \\ %{}) do
    result =
      %EventCard{}
      |> EventCard.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, _card} -> CardCache.reload()
      _ -> :ok
    end

    result
  end

  def update_event_card(%EventCard{} = card, attrs) do
    result =
      card
      |> EventCard.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, _card} -> CardCache.reload()
      _ -> :ok
    end

    result
  end

  def change_event_card(%EventCard{} = card, attrs \\ %{}) do
    EventCard.changeset(card, attrs)
  end

  # ============================================================
  # Talent Cards
  # ============================================================

  def list_talent_cards do
    TalentCard
    |> order_by([c], asc: c.category, asc: c.name)
    |> Repo.all()
  end

  def get_talent_card(id) do
    Repo.get(TalentCard, id)
  end

  def get_talent_card!(id) do
    Repo.get!(TalentCard, id)
  end

  def create_talent_card(attrs \\ %{}) do
    result =
      %TalentCard{}
      |> TalentCard.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, _card} -> CardCache.reload()
      _ -> :ok
    end

    result
  end

  def update_talent_card(%TalentCard{} = card, attrs) do
    result =
      card
      |> TalentCard.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, _card} -> CardCache.reload()
      _ -> :ok
    end

    result
  end

  def change_talent_card(%TalentCard{} = card, attrs \\ %{}) do
    TalentCard.changeset(card, attrs)
  end
end
