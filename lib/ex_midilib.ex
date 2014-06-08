defmodule ExMidilib do
  @microsecs_per_minute 1_000_000 * 60

  def note_names do
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  end

  def note_length(:whole), do: 4.0
  def note_length(:half), do: 2.0
  def note_length(:quarter), do: 1.0
  def note_length(:eighth), do: 0.5
  def note_length('8th'), do: 0.5
  def note_length(:sixteenth), do: 0.25
  def note_length('16th'), do: 0.25
  def note_length(:thirtysecond), do: 0.125
  def note_length('thirty second'), do: 0.125
  def note_length('32nd'), do: 0.125
  def note_length(:sixtyfourth), do: 0.0625
  def note_length('sixty fourth'), do: 0.0625
  def note_length('64th'), do: 0.0625

  # Translates beats per minute to microseconds per quarter note (beat).
  def bpm_to_mpq(bpm), do: @microsecs_per_minute / bpm

  # Translates microseconds per quarter note (beat) to beats per minute.
  # NOTE: There's no way this is right AND the one above is, but it's a port so...
  def mpq_to_bpm(mpq), do: @microsecs_per_minute / mpq

  # Quantize a lists's event's delta times by returning a new list of events
  # where the delta time of each is moved to the nearest multiple of Boundary.
  def quantize({:track, list_of_events}, boundary) do
    quantize(list_of_events, boundary)
  end
  def quantize([], _boundary), do: []
  def quantize(list_of_events, boundary) do
    {new_list_of_events, _} = :lists.mapfoldl(fn(e, beats_from_start) -> quantized_event(e, beats_from_start, boundary) end,
                                              0, list_of_events)
    new_list_of_events
  end

  # Return a tuple containing a quantized copy of Event and the beats from
  # the start of this event before it was quantized.
  def quantized_event(event, beats_from_start, boundary) do
    IO.puts("qe #{inspect event}, #{inspect beats_from_start}, #{inspect boundary}")
    {name, delta_time, values} = event
    diff = div((beats_from_start + delta_time), boundary)
    new_delta_time = if diff >= boundary / 2 do
                       delta_time - diff
                     else
                       delta_time - diff + boundary
                     end
    {{name, new_delta_time, values}, beats_from_start + delta_time}
  end

  # quantized_delta_time(BeatsFromStart, DeltaTime, Boundary) ->
  #     Diff = (BeatsFromStart + DeltaTime) div Boundary,
  #     NewDeltaTime = if
  # 		       Diff >= Boundary / 2 ->
  # 			   DeltaTime - Diff;
  # 		       true ->
  # 			   DeltaTime - Diff + Boundary
  # 		   end.

  # Given a MIDI note number, return the name and octave as a string.
  def note_to_string(num) do
    note = rem(num, 12)
    octave = div(num, 12)
    :lists.concat([:lists.nth(note + 1, note_names()), octave - 1])
  end
end
