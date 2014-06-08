# Port of https://raw.githubusercontent.com/rustyio/BashoBanjo/master/apps/midilib/include/midi_consts.hrl
defmodule ExMidilib do
  defmacro __using__(_options) do
    # Channel messages
    @status_nibble_off 0x8
    @status_nibble_on 0x9
    @status_nibble_poly_press 0xA
    @status_nibble_controller 0xB
    @status_nibble_program_change 0xC
    @status_nibble_channel_pressure 0xD
    @status_nibble_pitch_bend 0xE

    # System common messages
    @status_sysex 0xF0
    @status_song_pointer 0xF2
    @status_song_select 0xF3
    @status_tune_request 0xF6
    @status_eox 0xF7

    # System realtime messages
    # MIDI clock (24 per quarter note)
    @status_clock 0xF8
    # Sequence start
    @status_start 0xFA
    # Sequence continue
    @status_continue 0xFB
    # Sequence stop
    @status_stop 0xFc
    # Active sensing (sent every 300 ms when nothing else being sent)
    @status_active_sense 0xFE
    # System reset
    @status_system_reset 0xFF

    # Meta events
    @status_meta_event 0xFF
    @meta_seq_num 0x00
    @meta_text 0x01
    @meta_copyright 0x02
    @meta_seq_name 0x03
    @meta_instrument 0x04
    @meta_lyric 0x05
    @meta_marker 0x06
    @meta_cue 0x07
    @meta_midi_chan_prefix 0x20
    @meta_track_end 0x2F
    @meta_set_temp 0x51
    @meta_smpte 0x54
    @meta_time_sig 0x58
    @meta_key_sig 0x59
    @meta_sequencer_specific 0x7F
  end
end
