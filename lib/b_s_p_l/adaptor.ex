defmodule BSPL.Adaptor do
  @moduledoc """
  Defines the BSPL Adaptor.

  When used, the adaptor expects `:protocol_path`, `:role` and `:repo` as
  options. For example:
      defmodule Labeller.BSPL do
        use BSPL.Adaptor,
          protocol_path: "priv/logistics.bspl",
          role: "Labeller",
          repo: Labeller.Repo
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @protocol_path opts[:protocol_path]
      @role opts[:role]
      @repo opts[:repo]

      use GenServer

      ## Client API

      @doc """
      Starts the adaptor.
      """
      def start_link(opts) do
        opts = [name: __MODULE__] ++ opts

        init_params = [
          module: __MODULE__,
          protocol_path: @protocol_path,
          role: @role,
          repo: @repo
        ]

        GenServer.start_link(BSPL.Adaptor.Worker, init_params, opts)
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
      def next_messages do
        GenServer.call(__MODULE__, {:next_messages_extra})
      end

      def next_messages_min do
        GenServer.call(__MODULE__, {:next_messages})
      end

      def send(address, map) do
        GenServer.call(__MODULE__, {:send, address, map})
      end
    end
  end
end
