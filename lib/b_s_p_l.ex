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
    {protocol_name,
     [
       roles: _,
       params: _,
       messages: messages
     ]} = BSPL.Parser.parse!(opts[:protocol_path])

    bspl_adaptor = create_adaptor(protocol_name)

    quote bind_quoted: [
            opts: opts,
            name: protocol_name,
            messages: Macro.escape(messages),
            adaptor: bspl_adaptor
          ] do
      @adaptor adaptor
      @name name
      @messages messages
      @role opts[:role]
      @repo opts[:repo]
      @port opts[:port] || 8591

      use BSPL.Adaptor.Reactor
      use Supervisor

      def start_link(opts) do
        Supervisor.start_link(__MODULE__, :ok, opts)
      end

      @impl true
      def init(:ok) do
        children = [
          {@adaptor,
           [
             name: @name,
             messages: @messages,
             role: @role,
             repo: @repo,
             port: @port
           ]}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end
    end
  end

  defp create_adaptor(protocol_name) do
    module_name = Module.concat([BSPL, Protocols, Macro.camelize(protocol_name)])
    contents = quote do: use(BSPL.Adaptor)

    Module.create(module_name, contents, Macro.Env.location(__ENV__))

    module_name
  end
end
