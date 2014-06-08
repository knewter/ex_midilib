defmodule ExMidilib.MidiPlayer do
  alias ExMidilib.Midifile
  alias ExMidilib.AuGenerator
  require Record

  Record.defrecordp :on, [:ticks, :controller, :note, :amplitude]
  Record.defrecordp :off, [:ticks, :controller, :note, :amplitude]
  Record.defrecordp :note, [:start, :length, :controller, :note, :amplitude]

  def play(filename) do
    {:ok, notes, ms_per_tick} = read_midi(filename)
    pid = spawn(fn() -> play_notes(notes, ms_per_tick, 0) end)
    {:ok, pid}
  end

  def stop(pid), do: send(pid, :stop)

  def read_midi(filename) do
    {:seq, {:header, _, time}, global_track, tracks} = Midifile.read(filename)
    <<mode :: [integer, size(1)], ticks_per_beat :: [integer, size(15)]>> = <<time :: [integer, size(16)]>>
    if mode == 1, do: ticks_per_beat = 0
    ms_per_tick = calculate_ms_per_tick(ticks_per_beat, global_track)
    notes = transform_tracks([global_track|tracks])
    {:ok, notes, ms_per_tick}
  end

  def calculate_ms_per_tick(ticks_per_beat, {:track, track_info}) do
    {:tempo, _, [micro_sec_per_quarter_note]} = :lists.keyfind(:tempo, 1, track_info)
    (micro_sec_per_quarter_note * (1 / ticks_per_beat)) / 1000
  end

  def transform_tracks(tracks) do
    :lists.sort(:lists.flatten(for x <- tracks, do: transform_track(x)))
  end
  def transform_track({:track, events}) do
    # Filter out old events, calculate absolute times and relative velocities
    events1 = transform_events1(events, 0)
    # Sort by note/time
    events2 = transform_events2(events1)
    # Collapse on/off into notes
    events3 = transform_events3(events2)
    :lists.sort(events3)
  end

  def transform_events1([{on_off, delta_time, [controller, note, velocity]}|rest], ticks) when on_off == :on or on_off == :off do
    new_ticks = ticks + delta_time
    new_event = {on_off, new_ticks, controller, note, velocity/127 * 0.8}
    [new_event|transform_events1(rest, new_ticks)]
  end
  def transform_events1([{:program, _, [9, _]}|_rest], _ticks) do
    # Don't play percussion.
    []
  end
  def transform_events1([_|rest], ticks) do
    transform_events1(rest, ticks)
  end
  def transform_events1([], _), do: []

  def transform_events2(events) do
    sort_fun = fn({_, ticks_a, _, note_a, _}, {_, ticks_b, _, note_b, _}) ->
                   {note_a, ticks_a} < {note_b, ticks_b}
               end
    :lists.sort(sort_fun, events)
  end

  def transform_events3([on,off|rest]) when Record.record?(on, :on) and
                                            Record.record?(off, :off) and
                                            on(on, :note) == off(off, :note) and
                                            on(on, :controller) == off(off, :controller) do
    note = note(
      start: on(on, :ticks),
      length: off(off, :ticks) - on(on, :ticks),
      controller: on(on, :controller),
      note: on(on, :note),
      amplitude: on(on, :amplitude)
    )
    [note|transform_events3(rest)]
  end
  def transform_events3([_|rest]) do
    transform_events3(rest)
  end
  def transform_events3([]), do: []

  def play_notes([note|notes], ms_per_tick, ticks) do
    # Delay the proper amount of ticks...
    case ticks < note(note, :start) do
      true ->
        sleep = :erlang.trunc(ms_per_tick * (note(note, :start) - ticks))
        :timer.sleep(sleep)
      false ->
        :ok
    end

    # Play the next note...
    controller = note(note, :controller)
    midi_note = note(note, :note)
    amplitude = note(note, :amplitude)
    duration = (ms_per_tick * note(note, :length)) / 1000
    play_note(controller, midi_note, amplitude, duration)

    # Check if we have been stopped...
    receive do
      :stop -> :stopped
    after
      0 -> play_notes(notes, ms_per_tick, note(note, :start))
    end
  end
  def play_notes([], _, _), do: :ok

  def play_note(midi_controller, midi_note, amplitude, duration)
                when midi_note >= 0 and midi_note <= 127 and
                     amplitude >= 0 and amplitude <= 1 do
    # Print out the note...
    cond do
      duration < 0.1 -> note = [9834]
      duration < 0.4 -> note = [9833]
      true -> note = [9835]
    end
    offset = :lists.max([(midi_note - 40) * 2, 0])
    string = :lists.flatten([:string.copies(' ', offset), note, '\n'])
    IO.puts string

    # Play the note...
    play_note_actually(:paplay, midi_note, amplitude, duration)
  end
  def play_note(_, _, _, _), do: :ok

  def play_note_actually(method, midi_note, amplitude, duration) do
    # Generate the sound file...
    filename = :lists.flatten(:io_lib.format('./notes/note_~w_~w_~w.au', [midi_note, duration, amplitude]))
    case :filelib.is_regular(filename) do
        true -> :ok
        false ->
          data = AuGenerator.generate(midi_note, amplitude, duration)
          :filelib.ensure_dir(filename)
          :file.write_file(filename, data)
    end
    # Play the sound file
    play_note_actually(method, filename)
  end

  # Generate the sh command to play an audio file.
  def play_note_actually(:afplay, filename) do
    spawn(fn() -> :os.cmd('afplay ' ++ filename) end)
  end
  def play_note_actually(:aplay, filename) do
    spawn(fn() -> :os.cmd('aplay ' ++ filename) end)
  end
  def play_note_actually(:paplay, filename) do
    spawn(fn() -> :os.cmd('paplay ' ++ filename) end)
  end
  def play_note_actually(unknown, _) do
    IO.puts "unknown audio method: #{unknown}"
  end
end
