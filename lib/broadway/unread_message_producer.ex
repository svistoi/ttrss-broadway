defmodule Broadway.UnreadMessageProducer do
  @moduledoc """
  Broadway prdocuer that stores messages in memory until a consumer asks for
  them
  """

  use GenStage
  require Logger
  alias Broadway.UnreadMessageProducerState

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    Logger.info("Starting #{__MODULE__}")
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Callbacks
  def init(_opts) do
    state = %UnreadMessageProducerState{}
    {:producer, state, dispatcher: GenStage.DemandDispatcher}
  end

  def handle_cast(
        {:remove_outstanding, %Broadway.Message{} = message},
        %UnreadMessageProducerState{} = state
      ) do
    state
    |> UnreadMessageProducerState.remove_outstanding(message.data.article_id)
    |> dispatch_events()
  end

  def handle_cast({:notify, articles}, %UnreadMessageProducerState{} = state) do
    state
    |> UnreadMessageProducerState.add_articles(articles)
    |> dispatch_events()
  end

  def handle_demand(incoming_demand, %UnreadMessageProducerState{} = state) do
    state
    |> UnreadMessageProducerState.add_pending_demand(incoming_demand)
    |> dispatch_events()
  end

  defp dispatch_events(%UnreadMessageProducerState{} = state) do
    {events_to_send, new_state} =
      state
      |> UnreadMessageProducerState.split_by_demand()

    # Transform to Broadway.Message and set acknowledger to this module
    events_to_send =
      events_to_send
      |> Enum.map(fn {_id, x} ->
        %Broadway.Message{
          data: x,
          metadata: self(),
          acknowledger: {__MODULE__, :ack_id, :ack_data}
        }
      end)

    {:noreply, events_to_send, new_state}
  end

  def ack(:ack_id, successful, failed) do
    successful
    |> Enum.each(&GenServer.cast(&1.metadata, {:remove_outstanding, &1}))

    failed
    |> Enum.each(&GenServer.cast(&1.metadata, {:remove_outstanding, &1}))

    :ok
  end
end
