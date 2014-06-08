# ported from https://github.com/rustyio/BashoBanjo/blob/master/apps/riak_music/src/riak_music_vnode.erl#L128
defmodule ExMidilib.AuGenerator do
  @sample_rate 16_000
  @channels 2

  def generate(midi_note, amplitude, duration) do
    frequency = 261 * :math.pow(2, (midi_note - 60)/12.0)
    num_samples = trunc(@sample_rate * duration)
    t = (:math.pi * 2 * frequency) / @sample_rate

    # Generate the raw PCM data
    f = fn(x) ->
      # Apply a simple fade in and out of the note to make
      # it sound less harsh
      cond do
        (x < num_samples * 0.1) ->
          scale = (x / (num_samples * 0.1))
        (x > num_samples * 0.8) ->
          scale = (1 - (x - num_samples * 0.8) / (num_samples * 0.2))
        true ->
          scale = 1
      end
      value = :erlang.trunc(32767 * amplitude * scale * :math.sin(t * x))
      for _ <- :lists.seq(1, @channels), do: <<value :: [big, signed, integer, size(16)]>>
    end
    pre_data = for x <- :lists.seq(1, num_samples), do: f.(x)
    data = iodata_to_binary(pre_data)
    size = size(data)

    # From
    <<
      ".snd",                                        # Magic number
      0024 :: [unsigned, integer, size(32)],         # Data offset
      size :: [unsigned, integer, size(32)],         # Data size
      0003 :: [unsigned, integer, size(32)],         # 16-bit linear PCM
      @sample_rate :: [unsigned, integer, size(32)], # 8000 sample rate
      @channels :: [unsigned, integer, size(32)],    # two channels
      data :: binary
    >>
  end
end
