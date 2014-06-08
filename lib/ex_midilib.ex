defmodule ExMidilib do
  use Application.Behaviour

  def start(_start_type, _start_args) do
    ExMidilib.Supervisor.start_link
  end
end
