defmodule BSPL.Adaptor.Worker do
  @moduledoc false

  import String, only: [to_existing_atom: 1, downcase: 1]
  import Ecto.Adapters.SQL, only: [query!: 2]
  import BSPL.Parser
  import BSPL.Adaptor.Schema
  use GenServer

  ## Defining GenServer Callbacks

  @impl GenServer
  def init(module: module, protocol_path: protocol_path, role: role, repo: repo) do
    {protocol_name,
     [
       roles: _,
       params: _,
       messages: messages
     ]} = parse!(protocol_path)

    for msg <- messages, sent_by?(msg, role) or received_by?(msg, role) do
      msg
      |> create_schema!(protocol_name, module)
      |> create_table!(repo)
    end

    {:ok, %{role: role, messages: messages, repo: repo, module: module}}
  end

  @impl GenServer
  def handle_call({:my_messages}, _from, state = %{messages: messages, role: role}) do
    my_messages = messages |> sent_by(role)

    {:reply, my_messages, state}
  end

  @impl GenServer
  def handle_call({:next_messages}, _, state) do
    %{repo: repo, role: role, module: module, messages: all_messages} = state

    {:reply, next_messages(all_messages, role, module, repo), state}
  end

  ## Private Functions

  ## Functions for init/1

  defp create_schema!(msg, protocol_name, module) do
    msg_name = name(msg)
    params = params(msg)
    schema_module = schema(msg, module)

    unless :code.is_loaded(schema_module) do
      contents =
        quote do
          use BSPL.Adaptor.Schema,
            protocol_name: unquote(protocol_name),
            name: unquote(msg_name),
            params: unquote(Macro.escape(params))
        end

      Module.create(schema_module, contents, Macro.Env.location(__ENV__))
    end

    schema_module
  end

  defp create_table!(schema, repo) do
    primary_key = schema |> primary_key()
    timestamps = schema |> timestamps()
    other_fields = (fields(schema) -- primary_key) -- timestamps

    """
    CREATE TABLE IF NOT EXISTS #{table_name(schema)}(
      #{primary_key |> Enum.reduce("", &"#{&1} BIGINT NOT NULL, #{&2}")}
      #{other_fields |> Enum.reduce("", &"#{&1} TEXT NOT NULL, #{&2}")}
      #{timestamps |> Enum.reduce("", &"#{&1} TIMESTAMP NOT NULL DEFAULT NOW(), #{&2}")}
      PRIMARY KEY (#{primary_key |> Enum.map(&to_string/1) |> Enum.join(",")})
    )
    """
    |> String.replace(~r/\s+/, " ")
    |> repo.query!()
  end

  ## Functions for next_messages/0

  defp next_messages(all_messages, role, module, repo) do
    for msg <- all_messages,
        sent_by?(msg, role) and
          params(msg) |> adorned_with(:in) != [] do
      query = select_next_messages(msg, all_messages, role, module)
      result = query!(repo, query)

      cols = result.columns |> Enum.map(&to_existing_atom/1)
      list_of_bindings = result.rows |> Enum.map(&Enum.zip(cols, &1))

      {name(msg), list_of_bindings}
    end
    |> Enum.into(%{})
  end

  @doc """
  Given a `BSPL.Parser.message`, generates an SQL query to select all :in parameters,
  where all :in parameters are NOT NULL and all :out parameters are NULL.

  The results of the query represent valid messages this agent can send, that has not
  been sent before.
  """
  defp select_next_messages(msg, all_msgs, role, module) do
    table_name = table_name(schema(msg, module))
    primary_key = primary_key(schema(msg, module))
    received_schemas = all_msgs |> received_by(role) |> Enum.map(&schema(&1, module))

    # map of the form %{item_id: Schema.Items, price: Schema.Prices}
    field_to_schema_map =
      for param <- msg |> params() |> adorned_with(:in), reduce: %{} do
        acc ->
          field = param |> to_field()
          schema = received_schemas |> Enum.find(&(field in fields(&1)))
          Map.put_new(acc, field, schema)
      end

    select_clause =
      field_to_schema_map
      |> Enum.map(fn {field, schema} -> "#{table_name(schema)}.#{field}" end)
      |> Enum.join(", ")

    relevant_schemas = Map.values(field_to_schema_map) |> Enum.uniq()

    join_on_primary_keys_equal =
      primary_key
      |> Enum.map(&join_on_condition(&1, table_name, relevant_schemas))
      |> Enum.join(" AND ")

    out_params_are_null =
      msg
      |> params()
      |> adorned_with(:out)
      |> Enum.map(fn param -> "#{table_name}.#{name(param)} IS NULL" end)
      |> Enum.join(" AND ")

    """
    SELECT #{select_clause}
    FROM #{inner_joins(relevant_schemas)}
    LEFT JOIN #{table_name} ON #{join_on_primary_keys_equal}
    WHERE #{out_params_are_null}
    """
    |> String.replace(~r/\s+/, " ")
  end

  defp inner_joins(_all_schemas = [h | t]) do
    inner_joins(t, [h], table_name(h))
  end

  defp inner_joins([], _joined_schemas, acc), do: acc

  defp inner_joins([schema | schemas], joined_schemas, acc) do
    primary_key = primary_key(schema)
    table_name = table_name(schema)

    conditions =
      primary_key
      |> Enum.map(&join_on_condition(&1, table_name, joined_schemas))
      |> Enum.join(" AND ")

    sql = " INNER JOIN #{table_name} ON #{conditions} "

    inner_joins(schemas, [schema | joined_schemas], acc <> sql)
  end

  defp join_on_condition(key, table_name, schemas) do
    other_schema = schemas |> Enum.find(&(key in fields(&1)))

    if other_schema == nil,
      do: "TRUE",
      else: "#{table_name}.#{key} = #{table_name(other_schema)}.#{key}"
  end

  ## HELPER FUNCTIONS

  defp schema(msg, module) do
    Module.concat([module, "Schema", name(msg)])
  end

  def to_field(_param = {_, name, _}) do
    name |> downcase() |> to_existing_atom()
  end
end
