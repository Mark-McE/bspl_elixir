defmodule BSPL.Adaptor.Schema do
  @moduledoc """
  Defines the Ecto.Schema for a message within a BSPL protocol

  When used, the schema expects `:name` and `:params` as
  options. For example:
      defmodule Labeller.BSPL.Schema.Labelled do
        use BSPL.Adaptor.Schema,
          name: "Labelled",
          protocol_name: "Logistics",
          params: [{:in, "OrderID", :key}, {:in, "address", :nonkey}, {:out, "label", :nonkey}]
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @name opts[:name]
      @params opts[:params]
      @protocol_name opts[:protocol_name]

      use Ecto.Schema
      import String, only: [to_atom: 1, downcase: 1]

      # remove default field `id`
      @primary_key false

      schema "bspl_#{@protocol_name}_#{@name}" |> downcase() do
        @params
        |> Enum.each(fn
          {_, name, :key} ->
            field(name |> downcase() |> to_atom(), :id, primary_key: true)

          {_, name, :nonkey} ->
            field(name |> downcase() |> to_atom(), :string)
        end)

        timestamps()
      end
    end
  end

  def table_name(schema) do
    schema.__schema__(:source)
  end

  def primary_key(schema) do
    schema.__schema__(:primary_key)
  end

  def timestamps(_schema) do
    [:inserted_at, :updated_at]
  end

  def fields(schema) do
    schema.__schema__(:fields)
  end
end
