defmodule BSPL.Adaptor.Worker do
  @moduledoc false

  import BSPL.Parser
  import String, only: [to_atom: 1, downcase: 1]
  import Ecto.Adapters.SQL, only: [query!: 2]
  alias BSPL.Adaptor.Schema
  use GenServer

  ## Defining GenServer Callbacks

  @impl GenServer
  def init(opts) do
    [
      module: module_name,
      protocol_path: protocol_path,
      role: role,
      repo: repo
    ] = opts

    {protocol_name,
     [
       roles: _,
       params: _,
       messages: messages
     ]} = parse!(protocol_path)

    messages
    |> Enum.filter(&(sent_by?(&1, role) or received_by?(&1, role)))
    |> Enum.each(fn msg ->
      create_schema!(msg, protocol_name, module_name)
      create_table!(msg, protocol_name, repo)
    end)

    {:ok,
     %{
       protocol_name: protocol_name,
       messages: messages,
       module: module_name,
       role: role,
       repo: repo
     }}
  end

  defp create_schema!(msg, protocol_name, user_module_name) do
    msg_name = name(msg)
    params = params(msg)

    module_name =
      user_module_name
      |> Module.concat("Schema")
      |> Module.concat(msg_name)

    unless :code.is_loaded(module_name) do
      contents =
        quote bind_quoted: [
                protocol_name: protocol_name,
                name: msg_name,
                params: Macro.escape(params)
              ] do
          use BSPL.Adaptor.Schema,
            protocol_name: protocol_name,
            name: name,
            params: params
        end

      Module.create(module_name, contents, Macro.Env.location(__ENV__))
    end

    module_name
  end

  defp create_table!(msg, protocol_name, repo) do
    params = params(msg)

    primary_key =
      params
      |> Enum.filter(&is_key?/1)
      |> Enum.map(&name/1)
      |> Enum.join(",")

    fields =
      params
      |> Enum.map(fn
        {_, name, :key} -> name <> " BIGINT NOT NULL"
        {_, name, :nonkey} -> name <> " TEXT NOT NULL"
      end)
      |> Enum.join(",")

    sql =
      """
      CREATE TABLE IF NOT EXISTS bspl_#{protocol_name}_#{name(msg)}(
        #{fields},
        inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        PRIMARY KEY (#{primary_key})
      )
      """
      |> String.replace(~r/\s+/, " ")

    Ecto.Adapters.SQL.query!(repo, sql)
  end

  @impl GenServer
  def handle_call({:my_messages}, _from, state = %{messages: messages, role: role}) do
    my_messages = messages |> sent_by(role)

    {:reply, my_messages, state}
  end

  @impl GenServer
  def handle_call({:next_messages}, _, state) do
    %{repo: repo, role: role, module: module, messages: msgs} = state

    result =
      msgs
      |> sent_by(role)
      |> Enum.filter(fn msg -> msg |> params() |> adorned_with(:in) |> length() > 0 end)
      |> Enum.map(fn message -> {message, gen_query(message, msgs, role, module)} end)
      |> Enum.map(fn {message, query} -> {message, query!(repo, query)} end)
      |> Enum.filter(fn {_, result} -> result.num_rows > 0 end)
      |> Enum.map(fn {message, result} -> {name(message), result.columns, result.rows} end)
      |> Enum.map(fn {name, cols, rows} -> {name, Enum.map(cols, &String.to_atom/1), rows} end)
      |> Enum.map(fn {name, cols, rows} -> {name, rows |> Enum.map(&Enum.zip(cols, &1))} end)
      |> Enum.into(%{})

    IO.inspect("new")

    {:reply, result, state}
  end

  defp gen_query(msg, all_msgs, role, module) do
    received_msgs = all_msgs |> received_by(role)
    schema_module = Module.concat(module, "Schema")
    msg_schema = Module.concat(schema_module, name(msg))
    table_name = Schema.name(msg_schema)
    primary_key = Schema.primary_key(msg_schema)

    schema_to_params_map =
      msg
      |> params()
      |> adorned_with(:in)
      |> Enum.map(&name/1)
      |> Enum.into(%{}, fn param ->
        {param,
         received_msgs
         |> Enum.find(&contains_param?(&1, param))
         |> name()}
      end)
      |> reverse_map()

    all_schemas =
      [head_schema | other_schemas] =
      Map.keys(schema_to_params_map)
      |> Enum.map(&Module.concat(schema_module, &1))

    select_clause =
      msg
      |> params()
      |> adorned_with(:in)
      |> Enum.map(fn param -> param |> name() |> downcase() |> to_atom() end)
      |> Enum.map(fn field -> {field, all_schemas |> find_first(field) |> Schema.name()} end)
      |> Enum.map(fn {field, table_name} -> "#{table_name}.#{field}" end)
      |> Enum.join(", ")

    join_conditions =
      primary_key
      |> Enum.map(&join_on_condition(&1, table_name, all_schemas))
      |> Enum.join(" AND ")

    where_conditions =
      msg
      |> params()
      |> adorned_with(:out)
      |> Enum.map(&name/1)
      |> Enum.map(fn param -> "#{table_name}.#{param} IS NULL" end)
      |> Enum.join(" AND ")

    "SELECT #{select_clause} " <>
      "FROM #{Schema.name(head_schema)} " <>
      inner_joins(other_schemas, [head_schema]) <>
      "LEFT JOIN #{table_name} ON #{join_conditions} " <>
      "WHERE #{where_conditions}"
  end

  defp inner_joins(schemas, joined_schemas, acc \\ "")
  defp inner_joins([], _joined_schemas, acc), do: acc

  defp inner_joins([schema | schemas], joined_schemas, acc) do
    primary_key = Schema.primary_key(schema)
    table_name = Schema.name(schema)

    conditions =
      primary_key
      |> Enum.map(&join_on_condition(&1, table_name, joined_schemas))
      |> Enum.join(" AND ")

    sql = "INNER JOIN #{table_name} ON #{conditions} "

    inner_joins(schemas, [schema | joined_schemas], acc <> sql)
  end

  defp join_on_condition(key, table_name, schemas) do
    other_table = schemas |> find_first(key)

    case other_table do
      nil -> "TRUE"
      _ -> "#{table_name}.#{key} = #{Schema.name(other_table)}.#{key}"
    end
  end

  defp find_first(schemas, field) do
    schemas |> Enum.find(&(field in Schema.fields(&1)))
  end

  def reverse_map(map, reversed \\ %{})
  def reverse_map(map, reversed) when map_size(map) == 0, do: reversed

  def reverse_map(map, reversed) do
    [key | _] = Map.keys(map)
    {value, map} = Map.pop!(map, key)
    reversed = Map.update(reversed, value, [key], &[key | &1])
    reverse_map(map, reversed)
  end
end
