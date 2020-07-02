defmodule Broadway.UnreadMessageProducerState do
  @moduledoc """
  Memory storage of un-dispatched, as well as dispatched messages as a state
  of the producer.
  """
  require Logger
  alias __MODULE__

  defstruct buffer: %{},
            outstanding: %{},
            pending_demand: 0

  def remove_outstanding(state, article_id) do
    new_outstanding = Map.delete(state.outstanding, article_id)
    %UnreadMessageProducerState{state | outstanding: new_outstanding}
  end

  def add_articles(state, articles) do
    new_buffer =
      articles
      |> Map.new(fn x -> {x.article_id, x} end)
      |> Map.drop(Map.keys(state.outstanding))
      |> Map.merge(state.buffer)

    Logger.debug(
      "Incomming #{length(articles)}, old #{map_size(state.buffer)}, outstanding #{map_size(state.outstanding)} final: #{
        map_size(new_buffer)
      }"
    )

    %UnreadMessageProducerState{state | buffer: new_buffer}
  end

  def add_pending_demand(state, increase) do
    %UnreadMessageProducerState{state | pending_demand: state.pending_demand + increase}
  end

  def split_by_outstanding_demand(state = %UnreadMessageProducerState{pending_demand: pending_demand})
      when pending_demand == 0 do
    {[], state}
  end

  def split_by_demand(state) do
    {events_to_send, remaining_events} =
      state.buffer
      # to split the map by demand, convert it to a list
      |> Map.to_list()
      |> Enum.split(state.pending_demand)

    events_to_send = Map.new(events_to_send)
    new_outstanding = Map.merge(events_to_send, state.outstanding)

    new_buffer = Map.new(remaining_events)
    new_demand = state.pending_demand - map_size(events_to_send)

    # Logger.debug("Split sending out: #{map_size(events_to_send)}, outstanding #{map_size(new_outstanding)} remaining: #{map_size(new_buffer)}")

    {events_to_send,
     %UnreadMessageProducerState{
       buffer: new_buffer,
       pending_demand: new_demand,
       outstanding: new_outstanding
     }}
  end
end
