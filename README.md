# BSPL

Parser and network adaptor for the Blindingly Simple Protocol Language.

## Installation

The package can be installed by adding `bspl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bspl, git: "https://github.com/mark-mce/bspl_elixir.git"}
  ]
end
```

## Usage

BSPL requires a database connection to log messages sent and received, to use the adaptor you must pass a connection to your database as an `Ecto.Repo` module.  
The adaptor can be added to the supervision tree of your application by defining a module which uses it.
```elixir
defmodule MyAgent.Repo do
  use Ecto.Repo,
    otp_app: :my_agent,
    adapter: Ecto.Adapters.Postgres
end
```
```elixir
defmodule MyAgent.BSPL do
  use BSPL.Adaptor,
    protocol_path: "priv/protocol.bspl",
    role: "Buyer",
    repo: MyAgent.Repo
end
```
```elixir
defmodule MyAgent.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyAgent.Repo,
      MyAgent.BSPL
    ]
    opts = [strategy: :one_for_one, name: MyAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

