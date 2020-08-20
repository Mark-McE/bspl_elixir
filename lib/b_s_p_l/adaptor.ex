defmodule BSPL.Adaptor do
  @moduledoc """
  Client API for the BSPL adaptor
  """

  defmacro __using__(_opts) do
    quote do
      @doc """
      Defines how to supervise a process running this module
      """
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @doc """
      Starts the adaptor
      """
      def start_link(opts) do
        GenServer.start_link(BSPL.Adaptor.Worker, opts, name: __MODULE__)
      end

      @doc """
      Determines all messages from the protocol in which this agent is defined as the sender
      """
      def my_messages do
        GenServer.call(__MODULE__, {:my_messages})
      end

      @doc """
      Determines all messages this agent can send and hasn't sent yet
      `:any` used to represent data that this agent can set
      """
      def enabled_messages do
        GenServer.call(__MODULE__, {:enabled_messages})
      end

      @doc """
      Blocks until a message is received
      """
      def receive do
        GenServer.call(__MODULE__, {:receive})
      end

      @doc """
      Sends a message to the given address
      """
      def send(address, message) do
        GenServer.call(__MODULE__, {:send, address, message})
      end
    end
  end
end
