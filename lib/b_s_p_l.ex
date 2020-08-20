defmodule BSPL do
  @moduledoc """
  Defines the BSPL Supervision tree.

  When used, BSPL expects `:protocol_path`, `:role` and `:repo` as required
  parameters, and can take `:port` as an optional parameter.

  `:protocol_path`: the file path to the BSPL protocol
  `:role`: the BSPL role for this agent
  `:repo`: the `Ecto.Repo` module to store the local state
  `:port`: the port this agent will receive messages on

  For example:
      defmodule Labeller.BSPL do
        use BSPL,
          protocol_path: "priv/logistics.bspl",
          role: "Labeller",
          repo: Labeller.Repo
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @path opts[:protocol_path]
      @role opts[:role]
      @repo opts[:repo]
      @port opts[:port] || 8591

      use Supervisor

      def start_link(opts) do
        Supervisor.start_link(__MODULE__, :ok, opts)
      end

      @impl true
      def init(:ok) do
        adaptor = create_adaptor()

        children = [
          {adaptor, module: __MODULE__, path: @path, role: @role, repo: @repo, port: @port}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      defp create_adaptor do
        module_name = Module.concat(__MODULE__, "Adaptor")
        contents = quote do: use(BSPL.Adaptor)

        Module.create(module_name, contents, Macro.Env.location(__ENV__))

        module_name
      end
    end
  end
end
