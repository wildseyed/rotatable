I have written an emulator for NORNS and I wanted someone to tell me if I have any gaps.

https://github.com/wildseyed/rotatable

Fetched: GitHub - wildseyed/rotatable
This is a very thorough emulation. I checked your README against the tutorial transcript; I haven't read the Lua itself, so anything below that depends on actual behavior is a question, not a verdict. Most of the transcript is covered, including things like tempo-synced loop entry, effect envelopes, sub-oscillators with detune and transpose, and polyphonic sequencing. Your random sequencer's "automatic solos" goes beyond what the transcript shows. The gaps are mostly in the loop player, the sampler, and a few performance details.

Clear gaps against the transcript

Loop player behavior is different. In the original, a loop object in loop mode holds four loops per face, and rotation switches between them while they stay in sync. Rotation only changes playback speed in one-shot mode. Yours maps rotation to playback rate in both modes and seems to hold one file per object. Switching among four synced loops by rotation is one of the Reactable's signature performance moves, so this is probably your biggest functional gap. Cube faces don't translate to norns, but four slots per loop object, with a face or bank selector in config, would.
Sampler banks and drum kits. The original sampler loads a program from a bank. In drum mode, each note triggers a different sound. Yours is one WAV pitched melodically, with drum mode meaning one-shot, which is why your KIT-808 preset needs three samplers. A multi-sample program (a folder of WAVs mapped to notes) would let one sampler plus one sequencer play a whole kit.
Drawing custom waveforms. The oscillator lets you draw a waveform with your finger. That's a real gap, though a hard one with encoders. A small wavetable editor (E2 picks a point, E3 sets its height, on 16 or 32 points) would work.
External tempo sync. The original syncs its tempo over MIDI with Ableton Live or Traktor. You have your own rot_tempo param. If that isn't tied to the norns clock system, you're missing MIDI clock, and also Ableton Link and crow, which norns gives you almost for free. I'd make the tempo object read and write params:get("clock_tempo") and run your 32nd-note clock off clock.sync.
Starting an object silent. Touching the surface before placing a generator or effect sets its initial level to zero, which avoids a loud entrance mid-performance. An easy equivalent is holding K1 while you press K3 to place.
Locking a slider. Dragging the slider dot outward locks its value. It's low priority on encoders, but it matters if an LFO or MIDI can override a value you want frozen.
Pitch display on generators. The original shows the current note and octave next to each generator. Your status line may already do this; if not, it's a useful addition.
Showing the signal on connections. The original draws the actual waveform along audio lines and the actual data values along control lines. Your marching dashes and dots show direction but not content. A tiny scope drawn along the line would be a very Reactable touch, even at 128×64.
Things to check in the code

Does tonality snap the main oscillator pitch? The README says tonality constrains sequencer notes, improvisation, and sampler and sub-oscillator pitches. The transcript says it constrains what oscillators and samplers play, which includes rotating an oscillator by hand.
Can one controller drive several targets through hardlinks? In the original, once a controller is hardlinked, you repeat the gesture to link it to more objects, so one sequencer can drive a generator and a filter at the same time. Your README describes pinning one specific target.
Does rotating the sampler trigger a note? In the original, every rotation triggers a new note. Your rotation maps to pitch, which may or may not retrigger.
What does rotation control on the reverb subtype? On the original, rotating the reverb selects room size, not delay time.
Which way does a generator connect? Your rule is that a generator connects to the nearest effect in range. If that effect is farther from the center than the generator, audio would flow outward. Effects-to-effects can also form loops when two effects are about the same distance from the center. Make sure there's a tie-breaker and a guard against cycles.
Safe to skip on norns: calibration, the tangible hardware and camera tracking, and background color or image. Save and load living in your patch-slot ring instead of the song-settings object is a sensible adaptation.

Beyond the transcript, your 16-step sequencer and 12-note tonality map neatly onto a monome grid, if you ever want an optional grid layer. If you point me at specific files in lib/, I can check the questions above in the actual code.

Do you want to give the code a look?

Yes, I'll clone it and go through the code.

Ran 7 commands
I cloned it and read through world.lua, audio.lua, tonality.lua, slots.lua, the main script, and the relevant parts of the SuperCollider engine. It's well structured: the hook-wrapping in Audio.init is a clean way to keep the world model free of engine code. Several things the README describes don't actually happen, though, and a few of them change how it sounds.

Bugs that change the sound
1. Tonality is relative, not absolute. In seq_tick, the step's pitch offset gets snapped to the scale, then applied to t.freq, the oscillator's free rotation frequency (55–880 Hz, not quantized). So with C major selected and the oscillator sitting at 300 Hz, you get major-scale intervals starting from a note between D and D#. The result is in no key at all. The same problem affects the sub-oscillator follow snapping. The fix is to snap the absolute note:

lua
local base = 69 + 12 * math.log(t.freq / 440, 2)
local n = Tonality.snap(math.floor(base + pitch + 0.5), ton.root, ton.scale)
engine.trigger(n.out, 440 * 2 ^ ((n - 69) / 12))
snap only searches octaves −3 to +3 around the root, so for absolute MIDI note numbers you'd want to snap by pitch class (n % 12, wrapping to the nearest degree) instead. MIDI input isn't passed through tonality at all.

2. Longer chains can go silent depending on connection order. connect_audio does a pairwise src.moveBefore(dst), but sync_connections walks pairs(desired), which has no guaranteed order. With a generator feeding two effects in a row, some orders leave the generator running after the first effect. The effect then reads a zeroed bus. Your connection rule makes a clean fix possible: effects only feed effects closer to the center, so sorting the node group by distance from the center, farthest first with generators at the head, is a valid execution order. Hardlinks are the one exception, so after every recompute, do a topological sort and move each node to the tail in that order.

3. The sampler's instrument mode goes silent after the first MIDI note-off. A MIDI note-off sets gate to 0, but the trigger command only sets freq and t_trig for samplers and never raises gate again. The gated envelope stays shut from then on.

4. Sequencer "duration" sets step length, not note length. dur only reloads o._left, and nothing ever sends a gate-off. So an oscillator with sustain above zero just holds until the next step triggers. In the original, duration is how long the note lasts. You could schedule a gate-off at dur 32nd notes after the trigger.

5. Retriggering probably needs testing. Sending gate -1 and then gate 1 as two separate .set calls can land in the same control block. If they do, the second value overwrites the first before the envelope runs, so it never sees the edge and repeated notes don't re-attack. Check this with repeated notes at the same pitch and a non-zero sustain. If it fails, an explicit retrigger argument (for example gate * (1 - Trig1.kr(t_retrig, ControlDur.ir))) or a short scheduled gap will fix it.

6. There are two clocks, and sequencers aren't aligned to the bar. Sequencers run on a Lua metro, while loops, LFO sync, and delay quantizing use the engine's tempo bus. The two will drift apart. Each sequencer also starts counting from the moment it's placed, so it isn't locked to the table's bar the way it is on the original. Moving to the norns clock (clock.run with clock.sync(1/8), and the tempo object writing clock_tempo) fixes the drift and also gets you MIDI clock, Ableton Link, and crow sync. That covers the Ableton and Traktor sync from the transcript.

Features the README lists that aren't there
Poly sequencer: subtype 2 only changes the pictogram. Each step still has one pitch, and seq_tick never checks for poly.
Reverb rotation: for the reverb subtype, rotation sets time, but FreeVerb doesn't use time, so rotating does nothing. The slider sets room size and the mix is fixed at 0.6. The original has rotation set room size and the slider set dry/wet.
Tonality on the sampler: only sequencer notes are snapped. The sampler's rotation pitch isn't. The oscillator's rotation is deliberately left continuous (the comment in tonality.lua says so), which departs from the transcript.
Patching behavior that differs from the original
Generators can send audio outward. A generator connects to the nearest effect even if that effect is farther from the center. Effects have the "closer to center" check; generators don't.
Hardlinking two effects silences both. Hardlink keys are symmetric, so each effect finds the other as its hardlink target. You get A→B→A and neither reaches the output.
Each object can have only one hardlink. hardlink_target returns the first match, so one sequencer can't drive a generator and a filter together.
Controllers can grab an object they can't control. Controllers target the nearest non-global object, even when that object does nothing with them: a sequencer next to a loop or input, or an LFO next to another controller. That connection then does nothing. Filtering by SEQ_TARGETS or HAS_SYNTH would pick the nearest object that actually responds.
Connections to the output can't be muted. toggle_mute skips connections whose target is the output.
Minor issues
World.remove never cleans up hardlinks. Lua patterns don't support |, so "(^|:)" only matches that literal text. Since ids are never reused, this just leaves stale keys that slots save and then drop, so it's harmless but worth fixing.
MIDI note-off doesn't check which note. Releasing any key closes the gate, which cuts legato playing short. Tracking the held note would fix it.
More than 16 audio objects run out of level meters. After 16 audio objects, new ones silently get no meter.
That leaves the items from my earlier list that the code confirms are simply not implemented: four synced loops per loop object, multi-sample drum kits, drawn waveforms, placing an object silent, and locking a slider.

If I were prioritizing, I'd fix 1, 2, and 6 first, since they affect every patch. 3 and 4 are small changes, and poly and reverb rotation would bring the code in line with the README. I can write patches for any of these if you'd like.
