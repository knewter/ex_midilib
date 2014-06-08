# ExMidilib

This is a port of midilib from inside the BashoBanjo to Elixir.  I learned after
finishing it that it was written by Jim Menard.  His original is
[here](https://github.com/jimm/erlang-midilib)

He also ported it to Elixir, I learned later, and his has tests (which are
obviously a good thing).  His version can be found
[here](https://github.com/jimm/elixir/tree/master/midifile).

To see the midi file reading working, from inside `iex -S mix`:

```elixir
ExMidilib.Midifile.read('midi/mario.mid')
```

It can also generate .au files of a given midi note, intensity, and duration.
This was ported from the BashoBanjo vnode lib.  You can use it like so:

```elixir
ExMidilib.AuGenerator.generate(120, 0.5, 1)
```

To hear it play a midifile it's read (by reading the midi data, generating PCM
files on the fly, and piping those into paplay), run this:

```elixir
ExMidilib.MidiPlayer.play('midi/mario.mid')
```
