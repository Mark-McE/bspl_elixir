defmodule BSPL.Parser do
  @moduledoc false

  @type role :: String.t()
  @type adornment :: :in | :out | nil
  @type parameter :: {adornment, String.t(), :key | :nonkey}
  @type message :: {String.t(), String.t(), String.t(), [parameter]}
  @type protocol :: {String.t(), [roles: [role], params: [parameter], messages: [message]]}

  @doc """
  Parse a BSPL protocol and return a parse tree.
  """
  @spec parse(Path.t()) :: {:ok, protocol} | {:error, term}
  def parse(filename) do
    case File.read(filename) do
      {:ok, contents} ->
        case contents
             |> String.to_charlist()
             |> :bspl_lexer.string() do
          {:ok, tokens, _end_line} -> :bspl_parser.parse(tokens)
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as as parse/1 but will raise on error and returns only parse_tree
  """
  @spec parse!(Path.t()) :: protocol
  def parse!(filename) do
    {:ok, tokens, _end_line} =
      File.read!(filename)
      |> String.to_charlist()
      |> :bspl_lexer.string()

    {:ok, parse_tree} = :bspl_parser.parse(tokens)
    parse_tree
  end

  ## helper functions for using the parse tree

  @spec name(protocol | message | parameter) :: String.t()
  def name({name, [roles: _, params: _, messages: _]}), do: name
  def name({_, _, name, _}), do: name
  def name({_, name, _}), do: name

  @spec params(protocol | message) :: [parameter]
  def params({_, [roles: _, params: params, messages: _]}), do: params
  def params({_, _, _, params}), do: params

  @spec roles(protocol) :: [role]
  def roles({_, [roles: roles, params: _, messages: _]}), do: roles

  @spec messages(protocol) :: [message]
  def messages({_, [roles: _, params: _, messages: messages]}), do: messages

  @spec sender(message) :: role
  def sender({sender, _, _, _}), do: sender

  @spec receiver(message) :: role
  def receiver({_, receiver, _, _}), do: receiver

  @spec adorn(parameter) :: adornment
  def adorn({adorn, _, _}), do: adorn

  @spec sent_by?(message, role) :: boolean
  def sent_by?(msg, sender), do: sender(msg) == sender

  @spec sent_by([message], role) :: [message]
  def sent_by(msgs, sender), do: msgs |> Enum.filter(&sent_by?(&1, sender))

  @spec received_by?(message, role) :: boolean
  def received_by?(msg, receiver), do: receiver(msg) == receiver

  @spec received_by([message], role) :: [message]
  def received_by(msgs, receiver), do: msgs |> Enum.filter(&received_by?(&1, receiver))

  @spec contains_param?(message, parameter | String.t()) :: boolean
  def contains_param?(msg, {_, name, _}), do: contains_param?(msg, name)

  def contains_param?({_, _, _, params}, param_name) do
    params |> Enum.any?(fn {_, name, _} -> name == param_name end)
  end

  @spec adorned_with?(parameter, adornment) :: boolean
  def adorned_with?(param, adornment), do: match?({^adornment, _, _}, param)

  @spec adorned_with([parameter], adornment) :: [parameter]
  def adorned_with(params, adornment), do: params |> Enum.filter(&adorned_with?(&1, adornment))

  @spec is_key?(parameter) :: boolean
  def is_key?({_, _, :key}), do: true
  def is_key?({_, _, :nonkey}), do: false
end
