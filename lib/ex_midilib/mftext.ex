defmodule ExMidilib.Mftext do
  def seq_to_text(seq) do
    seq_to_text(seq, false)
  end
  def seq_to_text(seq, show_chan_events) do
    {:seq, _, tracks} = seq
    :lists.map(fn(t) -> track_to_text(t, show_chan_events) end, tracks)
    :ok
  end

  def track_to_text(track) do
    track_to_text(track, false)
  end
  def track_to_text(track, show_chan_events) do
    IO.puts "track start"
    {:track, events} = track
    :lists.map(fn(e) -> event_to_text(e, show_chan_events) end, events)
    :ok
  end

  def event_to_text(event) do
    event_to_text(event, false)
  end
  def event_to_text(event, show_chan_events) do
    {name, _} = event
    is_chan_event = :lists.any(fn(x) -> x == name end,
                      [:off, :ok, :poly_press, :controller, :program,
                       :chan_press, :pitch_bend])
    if show_chan_events or !is_chan_event do
      IO.inspect event
    end
  end
end
