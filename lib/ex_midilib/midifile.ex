# Ported from https://github.com/rustyio/BashoBanjo/blob/master/apps/midilib/src/midifile.erl
defmodule ExMidilib.Midifile do
  @moduledoc """
  This module reads and writes MIDI files
  """

  use ExMidilib.Constants
  use Bitwise

  # Returns
  # {:seq, {header...}, conductor_track, list_of_tracks}
  # `header` is `{:header, format, division}`
  # `conductor_track` is the first track of a format 1 MIDI file
  # each track including the conductor track is
  # {:track, list_of_events}
  # each event is
  # {:event_name, delta_time, [values...]}
  # where values after `delta_time` are specific to each event type. If the value
  # is a string, then the string appears instead of [values...].
  #FIXME: Typespecs for this!
  def read(path) do
    case :file.open(path, [:read, :binary, :raw]) do
      {:ok, file} ->
        file_pos = look_for_chunk(file, 0, "MThd", :file.pread(file, 0, 4))
        [header, num_tracks] = parse_header(:file.pread(file, file_pos, 10))
        tracks = read_tracks(file, num_tracks, file_pos + 10, [])
        :file.close(file)
        [conductor_track | remaining_tracks] = tracks
        {:seq, header, conductor_track, remaining_tracks}
      error ->
        {path, error}
    end
  end

  # Look for Cookie in file and return file position after Cookie.
  defp look_for_chunk(_file, file_pos, cookie, {:ok, cookie}) do
    file_pos + size(cookie)
  end
  defp look_for_chunk(file, file_pos, cookie, {:ok, _}) do
    # This isn't efficient, because we only advance one character at a time.
    # We should really look for the first char in Cookie and, if found,
    # advance that far.
    look_for_chunk(file, file_pos + 1, cookie, :file.pread(file, file_pos + 1,
                  size(cookie)))

  end

  defp parse_header({:ok, <<_bytes_to_read :: [integer, size(32)], format :: [integer, size(16)],
                     num_tracks :: [integer, size(16)], division :: [integer, size(16)] >>}) do
     [{:header, format, division}, num_tracks]
  end

  defp read_tracks(_file, 0, _file_pos, tracks) do
    :lists.reverse(tracks)
  end
  defp read_tracks(file, num_tracks, file_pos, tracks) do
    # TODO: make this distributed. Would need to scan each track to get start
    # position of next track.
    IO.puts("read_tracks, num_tracks = #{num_tracks}, file_pos = #{file_pos}")
    [track, next_track_file_pos] = read_track(file, file_pos)
    IO.puts("read_tracks, next_track_file_pos = #{next_track_file_pos}")
    read_tracks(file, num_tracks - 1, next_track_file_pos, [track|tracks])
  end

  defp read_track(file, file_pos) do
    track_start = look_for_chunk(file, file_pos, "MTrk", :file.pread(file, file_pos, 4))
    bytes_to_read = parse_track_header(:file.pread(file, track_start, 4))
    IO.puts "reading track, track_start = #{track_start}, bytes_to_read = #{bytes_to_read}"
    IO.puts "next track pos = #{track_start + 4 + bytes_to_read}"
    Process.put(:status, 0)
    Process.put(:chan, -1)
    [{:track, event_list(file, track_start + 4, bytes_to_read, [])},
      track_start + 4 + bytes_to_read]
  end

  defp parse_track_header({:ok, <<bytes_to_read :: [integer, size(32)]>>}) do
    bytes_to_read
  end

  defp event_list(_file, _file_post, 0, events) do
    :lists.reverse(events)
  end
  defp event_list(file, file_pos, bytes_to_read, events) do
    [delta_time, var_len_bytes_used] = read_var_len(:file.pread(file, file_pos, 4))
    {:ok, three_bytes} = :file.pread(file, file_pos + var_len_bytes_used, 3)
    IO.puts("reading event, file_pos = #{inspect file_pos}, bytes_to_read = #{inspect bytes_to_read}, three_bytes = #{inspect three_bytes}")
    [event, event_bytes_read] = read_event(file, file_pos + var_len_bytes_used, delta_time, three_bytes)
    bytes_read = var_len_bytes_used + event_bytes_read
    event_list(file, file_pos + bytes_read, bytes_to_read - bytes_read, [event|events])
  end

  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_off :: size(4), chan :: size(4), note :: size(8), vel :: size(8) >>) do
    IO.puts("off")
    Process.put(:status, @status_nibble_off)
    Process.put(:chan, chan)
    [{:off, delta_time, [chan, note, vel]}, 3]
  end
  # note on, velocity 0 is a note off
  defp read_event(_file, _file_pos, delta_time,
	    <<@status_nibble_on :: size(4), chan :: size(4), note :: size(8), 0 :: size(8)>>) do
    IO.puts "off (using on vel 0)"
    Process.put(:status, @status_nibble_on)
    Process.put(:chan, chan)
    [{:off, delta_time, [chan, note, 64]}, 3]
  end
  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_on :: size(4), chan :: size(4), note :: size(8), vel :: size(8) >>) do
    IO.puts "on"
    Process.put(:status, @status_nibble_on)
    Process.put(:chan, chan)
    [{:on, delta_time, [chan, note, vel]}, 3]
  end
  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_poly_press :: size(4), chan :: size(4), note :: size(8), amount :: size(8)>>) do
    IO.puts "poly press"
    Process.put(:status, @status_nibble_poly_press)
    Process.put(:chan, chan)
    [{:poly_press, delta_time, [chan, note, amount]}, 3]
  end
  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_controller :: size(4), chan :: size(4), controller :: size(8), value :: size(8)>>) do
    IO.puts "controller ch #{chan}, ctrl #{controller}, val #{value}"
    Process.put(:status, @status_nibble_controller)
    Process.put(:chan, chan)
    [{:controller, delta_time, [chan, controller, value]}, 3]
  end
  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_program_change :: size(4), chan :: size(4), program :: size(8), _ :: size(8)>>) do
    IO.puts "prog change"
    Process.put(:status, @status_nibble_program_change)
    Process.put(:chan, chan)
    [{:program, delta_time, [chan, program]}, 2]
  end
  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_channel_pressure :: size(4), chan :: size(4), amount :: size(8), _ :: size(8)>>) do
    IO.puts "chan pressure"
    Process.put(:status, @status_nibble_channel_pressure)
    Process.put(:chan, chan)
    [{:chan_press, delta_time, [chan, amount]}, 2]
  end
  defp read_event(_file, _file_pos, delta_time,
      <<@status_nibble_pitch_bend :: size(4), chan :: size(4), 0 :: size(1), lsb :: size(7), 0 :: size(1), msb :: size(7)>>) do
    IO.puts "pitch bend"
    Process.put(:status, @status_nibble_pitch_bend)
    Process.put(:chan, chan)
    [{:pitch_bend, delta_time, [chan, <<0 :: size(2), msb :: size(7), lsb :: size(7)>>]}, 3]
  end
  defp read_event(_f, _file_pos, delta_time,
      <<@status_meta_event :: size(8), @meta_track_end :: size(8), 0 :: size(8)>>) do
    IO.puts "end of track"
    Process.put(:status, @status_meta_event)
    Process.put(:chan, 0)
    [{:track_end, delta_time, []}, 3]
  end
  defp read_event(file, file_pos, delta_time, <<@status_meta_event :: size(8), type :: size(8), _ :: size(8)>>) do
    IO.puts "meta event"
    Process.put(:status, @status_meta_event)
    Process.put(:chan, 0)
    [length, length_bytes_used] = read_var_len(:file.pread(file, file_pos + 2, 4))
    length_before_data = length_bytes_used + 2
    {:ok, data} = :file.pread(file, file_pos + length_before_data, length)
    total_length = length_before_data + length
    IO.puts "  type = #{inspect type}, var len = #{inspect length}, len before data = #{inspect length_before_data}, total len = #{inspect total_length},\n  data = #{inspect data}"
    case type do
      @meta_seq_num    -> [{:seq_num, delta_time, [data]}, total_length]
      @meta_text       -> [{:text, delta_time, String.to_char_list(data)}, total_length]
      @meta_copyright  -> [{:copyright, delta_time, String.to_char_list(data)}, total_length]
      @meta_seq_name   -> [{:seq_name, delta_time, String.to_char_list(data)}, total_length]
      @meta_instrument -> [{:instrument, delta_time, String.to_char_list(data)}, total_length]
      @meta_lyric      -> [{:lyric, delta_time, String.to_char_list(data)}, total_length]
      @meta_marker     -> [{:marker, delta_time, String.to_char_list(data)}, total_length]
      @meta_cue        -> [{:cue, delta_time, String.to_char_list(data)}, total_length]
      @meta_midi_chan_prefix -> [{:midi_chan_prefix, delta_time, [data]}, total_length]
      @meta_set_tempo  ->
        # Data is microseconds per quarter note, in three bytes
        <<b0 :: size(8), b1 :: size(8), b2 :: size(8) >> = data
        [{:tempo, delta_time, [(b0 <<< 16) + (b1 <<< 8) + b2]}, total_length]
      @meta_smpte      -> [{:smpte, delta_time, [data]}, total_length]
      @meta_time_sig   -> [{:time_signature, delta_time, [data]}, total_length]
      @meta_key_sig    -> [{:key_signature, delta_time, [data]}, total_length]
      @meta_sequencer_specific -> [{:seq_name, delta_time, [data]}, total_length]
      _ ->
        IO.puts "  unknown meta type #{type}"
        [{:unknown_meta, delta_time, [type, data]}, total_length]
    end
  end
  defp read_event(file, file_pos, delta_time, <<@status_sysex :: size(8), _ :: size(16)>>) do
    IO.puts "sysex"
    Process.put(:status, @status_sysex)
    Process.put(:chan, 0)
    [length, length_bytes_used] = read_var_len(:file.pread(file, file_pos + 1, 4))
    {:ok, data} = :file.pread(file, file_pos + length_bytes_used, length)
    [{:sysex, delta_time, [data]}, length_bytes_used + length]
  end
  defp read_event(file, file_pos, delta_time, <<b0 :: size(8), b1 :: size(8), _ :: size(8)>>) when b0 < 128 do
    # Handle running status bytes
    status = Process.get(:status)
    chan = Process.get(:chan)
    IO.puts "running status byte, status = #{status}, chan = #{chan}"
    [event, num_bytes] = read_event(file, file_pos, delta_time, <<status :: size(4), chan :: size(4), b0 :: size(8), b1 :: size(8)>>)
    [event, num_bytes - 1]
  end
  defp read_event(_file, _file_pos, delta_time, <<unknown :: size(8), _ :: size(16)>>) do
    IO.puts "unknown byte #{unknown}"
    Process.put(:status, 0)
    Process.put(:chan, 0)
    #exit("Unknown status byte " ++ Unknown).
    [{:unknown_status, delta_time, [unknown]}, 3]
  end

  defp read_var_len({:ok, <<0 :: size(1), b0 :: size(7), _ :: size(24)>>}) do
    [b0, 1]
  end
  defp read_var_len({:ok, <<1 :: size(1), b0 :: size(7), 0 :: size(1), b1 :: size(7), _ :: size(16)>>}) do
    [(b0 <<< 7) + b1, 2]
  end
  defp read_var_len({:ok, <<1 :: size(1), b0 :: size(7), 1 :: size(1), b1 :: size(7), 0 :: size(1), b2 :: size(7), _ :: size(8)>>}) do
    [(b0 <<< 14) + (b1 <<< 7) + b2, 3];
  end
  defp read_var_len({:ok, <<1 :: size(1), b0 :: size(7), 1 :: size(1), b1 :: size(7), 1 :: size(1), b2 :: size(7), 0 :: size(1), b3 :: size(8)>>}) do
    [(b0 <<< 21) + (b1 <<< 14) + (b2 <<< 7) + b3, 4]
  end
  defp read_var_len({:ok, <<1 :: size(1), b0 :: size(7), 1 :: size(1), b1 :: size(7), 1 :: size(1), b2 :: size(7), 1 :: size(1), b3 :: size(7)>>}) do
    IO.puts "Warning: bad var len format; all 4 bytes have high bit set"
    [(b0 <<< 21) + (b1 <<< 14) + (b2 <<< 7) + b3, 4]
  end

  def write({:seq, header, conductor_track, tracks}, path) do
    l = [header_io_list(header, length(tracks) + 1) |
        :lists.map(fn(t) -> track_io_list(t) end, [conductor_track | tracks])]
    :ok = :file.write_file(path, l)
  end

  defp header_io_list(header, num_tracks) do
    {:header, _, division} = header
    ["MThd",
     0, 0, 0, 6,                  # header chunk size
     0, 1,                        # format,
     (num_tracks >>> 8) &&& 255,  # num tracks
      num_tracks        &&& 255,
     (division >>> 8) &&& 255,   # division
      division        &&& 255]
  end

  defp track_io_list(track) do
    {:track, events} = track
    Process.put(:status, 0)
    Process.put(:chan, 0)
    event_list = :lists.map(fn(e) -> event_io_list(e) end, events)
    chunk_size = chunk_size(event_list)
    ["MTrk",
     (chunk_size >>> 24) &&& 255,
     (chunk_size >>> 16) &&& 255,
     (chunk_size >>>  8) &&& 255,
      chunk_size         &&& 255,
     event_list]
  end

  # Return byte size of L, which is an IO list that contains lists, bytes, and
  # binaries.
  defp chunk_size(l) do
    :lists.foldl(fn(e, acc) -> acc + io_list_element_size(e) end, 0, :lists.flatten(l))
  end
  defp io_list_element_size(e) when is_binary(e), do: size(e)
  defp io_list_element_size(_), do: 1

  defp event_io_list({:off, delta_time, [chan, note, vel]}) do
    running_status = Process.get(:status)
    running_chan = Process.get(:chan)
    if running_chan == chan &&
	     (running_status == @status_nibble_off ||
	     (running_status == @status_nibble_on && vel == 64)) do
	    status = []
	    out_vel = 0
    else
	    status = (@status_nibble_off <<< 4) + chan
	    out_vel = vel
	    Process.put(:status, @status_nibble_off)
	    Process.put(:chan, chan)
    end
    [var_len(delta_time), status, note, out_vel];
  end
  defp event_io_list({:ok, delta_time, [chan, note, vel]}) do
    [var_len(delta_time), running_status(@status_nibble_on, chan), note, vel]
  end
  defp event_io_list({:poly_press, delta_time, [chan, note, amount]}) do
    [var_len(delta_time), running_status(@status_nibble_poly_press, chan), note, amount];
  end
  defp event_io_list({:controller, delta_time, [chan, controller, value]}) do
    [var_len(delta_time), running_status(@status_nibble_controller, chan), controller, value]
  end
  defp event_io_list({:program, delta_time, [chan, program]}) do
    [var_len(delta_time), running_status(@status_nibble_program_change, chan), program]
  end
  defp event_io_list({:chan_press, delta_time, [chan, amount]}) do
    [var_len(delta_time), running_status(@status_nibble_channel_pressure, chan), amount]
  end
  defp event_io_list({:pitch_bend, delta_time, [chan, <<0 :: size(2), msb :: size(7), lsb :: size(7)>>]}) do
    [var_len(delta_time), running_status(@status_nibble_pitch_bend, chan),
     <<0 :: size(1), lsb :: size(7), 0 :: size(1), msb :: size(7)>>]
  end
  defp event_io_list({:track_end, delta_time}) do
    IO.puts("track_end")
    Process.put(:status, @status_meta_event)
    [var_len(delta_time), @status_meta_event, @meta_track_end, 0]
  end
  defp event_io_list({:seq_num, delta_time, [data]}) do
    meta_io_list(delta_time, @meta_seq_num, data)
  end
  defp event_io_list({:text, delta_time, data}) do
    meta_io_list(delta_time, @meta_text, data)
  end
  defp event_io_list({:copyright, delta_time, data}) do
    meta_io_list(delta_time, @meta_copyright, data)
  end
  defp event_io_list({:seq_name, delta_time, data}) do
    Process.put(:status, @status_meta_event)
    meta_io_list(delta_time, @meta_track_end, data)
  end
  defp event_io_list({:instrument, delta_time, data}) do
    meta_io_list(delta_time, @meta_instrument, data)
  end
  defp event_io_list({:lyric, delta_time, data}) do
    meta_io_list(delta_time, @meta_lyric, data)
  end
  defp event_io_list({:marker, delta_time, data}) do
    meta_io_list(delta_time, @meta_marker, data)
  end
  defp event_io_list({:cue, delta_time, data}) do
    meta_io_list(delta_time, @meta_cue, data)
  end
  defp event_io_list({:midi_chan_prefix, delta_time, [data]}) do
    meta_io_list(delta_time, @meta_midi_chan_prefix, data)
  end
  defp event_io_list({:tempo, delta_time, [data]}) do
    IO.puts "tempo, data = #{data}"
    Process.put(:status, @status_meta_event)
    [var_len(delta_time), @status_meta_event, @meta_set_tempo, var_len(3),
      (data >>> 16) &&& 255,
      (data >>>  8) &&& 255,
       data         &&& 255]
  end
  defp event_io_list({:smpte, delta_time, [data]}) do
    meta_io_list(delta_time, @meta_smpte, data)
  end
  defp event_io_list({:time_signature, delta_time, [data]}) do
    meta_io_list(delta_time, @meta_time_sig, data)
  end
  defp event_io_list({:key_signature, delta_time, [data]}) do
    meta_io_list(delta_time, @meta_key_sig, data)
  end
  defp event_io_list({:sequencer_specific, delta_time, [data]}) do
    meta_io_list(delta_time, @meta_sequencer_specific, data)
  end
  defp event_io_list({:unknown_meta, delta_time, [type, data]}) do
    meta_io_list(delta_time, type, data)
  end

  defp meta_io_list(delta_time, type, data) when is_binary(data) do
    IO.puts "meta_io_list (bin) type = #{type}, data = #{data}"
    Process.put(:status, @status_meta_event)
    [var_len(delta_time), @status_meta_event, type, var_len(size(data)), data]
  end
  defp meta_io_list(delta_time, type, data) do
    IO.puts "meta_io_list type = #{type}, data = #{data}"
    Process.put(:status, @status_meta_event)
    [var_len(delta_time), @status_meta_event, type, var_len(length(data)), data]
  end

  defp running_status(high_nibble, chan) do
    running_status = Process.get(:status)
    running_chan = Process.get(:chan)
    if running_status == high_nibble && running_chan == chan do
      IO.puts "running status: status = #{running_status}, chan = #{running_chan}"
      []
    else
      Process.put(:status, high_nibble)
      Process.put(:chan, chan)
      (high_nibble <<< 4) + chan
    end
  end

  defp var_len(i) when i < (1 <<< 7) do
    <<0 :: size(1), i :: size(7)>>
  end
  defp var_len(i) when i < (1 <<< 14) do
    <<1 :: size(1), (i >>> 7) :: size(7), 0 :: size(1), i :: size(7)>>
  end
  defp var_len(i) when i < (1 <<< 21) do
    <<1 :: size(1), (i >>> 14) :: size(7), 1 :: size(1), (i >>> 7) :: size(7), 0 :: size(1), i :: size(7)>>
  end
  defp var_len(i) when i < (1 <<< 28) do
    <<1 :: size(1), (i >>> 21) :: size(7), 1 :: size(1), (i >>> 14) :: size(7), 1 :: size(1), (i >>> 7) :: size(7), 0 :: size(1), i :: size(7)>>
  end
  defp var_len(i) do
    exit("value #{i} is too big for a variable length number")
  end
end
