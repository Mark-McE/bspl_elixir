defmodule BSPL.Adaptor.Reactor do
  defmacro __using__(_opts) do
    quote do
      # Invoke BSPL.Adaptor.Reactor.__before_compile__/1 before the module is compiled
      @before_compile BSPL.Adaptor.Reactor
      # Invoke BSPL.Adaptor.Reactor.__after_compile__/2 after the module is compiled
      @after_compile BSPL.Adaptor.Reactor

      # register the attribute @functions as an empty list
      Module.register_attribute(__MODULE__, :functions, accumulate: true)

      import BSPL.Adaptor.Reactor
    end
  end

  defmacro react(msg_name, do: block) do
    function_name = String.to_atom("react_" <> msg_name)

    quote do
      # Prepend the newly defined function to the list of functions
      @functions {unquote(function_name), __MODULE__}
      def unquote(function_name)(), do: unquote(block)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def _gen_reactor do
        module_name = Module.concat([BSPL, Protocols, Macro.camelize(@name), Reactor])

        contents =
          Enum.map(@functions, fn {function_name, module} ->
            quote do
              def unquote(function_name)(), do: apply(unquote(module), unquote(function_name), [])
            end
          end)

        unless :code.is_loaded(module_name) do
          Module.create(module_name, contents, Macro.Env.location(__ENV__))
        end
      end
    end
  end

  def __after_compile__(env, _bytecode) do
    apply(env.module, :_gen_reactor, [])
  end
end
