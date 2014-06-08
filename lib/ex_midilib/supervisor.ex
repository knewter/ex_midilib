defmodule ExMidilib.Supervisor do
  use Supervisor.Behaviour

  def start_link() do
    :supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    supervise [], strategy: :one_for_one
  end
end
