// Engine_Rotatable.sc — reactable emulator engine (phase 4 + v2/phase 7)
// one group + synth + private inBus per object; sources retarget their out bus.
// control connections: controller writes a control bus, target param is .map'ed.
// v2: tempo control bus (bpm) consumed by LFO sync / delay quantize / loop
// bar-entry; mod bus is bipolar (-1..1) and each target synth applies its own
// scale (pitch-like params bipolar, amp/dry-wet unipolar).

Engine_Rotatable : CroneEngine {
	var <silentBus, <masterBus, <master;
	var <silentBuf; // 1s mono silence; default buf for loop player (avoids NaN rate)
	var <tempoBus; // control bus holding current bpm (set via "tempo" command)
	var nodeGroup; // all object synths live here, before the master synth
	var nodes; // id -> (group, synth, bus, type, out, muted, lvlSlot)
	var lvlSlots, lvlFree; // fixed pool of 16 level buses; polls are registered
		// at alloc time because matron only discovers polls at engine load

	*new { arg context, doneCallback; ^super.new(context, doneCallback); }

	alloc {
		var s = context.server;
		nodes = IdentityDictionary.new;

		// mod is bipolar (-1..1); pitch-like target: +-1 octave around current
		// sub-oscillators (spec §3.1): 4 subs x (waveform/amp/detune/offset),
		// summed pre-envelope. off = semitones, det = cents.
		SynthDef(\rot_osc, { arg in=0, out=0, gate=1, freq=220, amp=0.8, select=0,
			a=0.01, d=0.1, s=0.7, r=0.3, mod=0, lvl=0,
			sub1w=0, sub1a=0, sub1d=0, sub1o=0,
			sub2w=0, sub2a=0, sub2d=0, sub2o=0,
			sub3w=0, sub3a=0, sub3d=0, sub3o=0,
			sub4w=0, sub4a=0, sub4d=0, sub4o=0;
			var sig, env, outSig, subSig;
			var mkSub = { arg f, w, amp, det, off;
				var sf = f * (2 ** ((off + (det / 100)) / 12));
				SelectX.ar(Lag.kr(w.clip(0, 3), 0.05), [
					SinOsc.ar(sf),
					Saw.ar(sf),
					Pulse.ar(sf, 0.5),
					LPF.ar(WhiteNoise.ar, (sf * 8).clip(100, 18000))
				]) * Lag.kr(amp.clip(0, 1), 0.05);
			};
			freq = Lag.kr(freq, 0.05) * (2 ** mod.clip(-1, 1));
			sig = SelectX.ar(Lag.kr(select, 0.05), [
				SinOsc.ar(freq),
				Saw.ar(freq),
				Pulse.ar(freq, 0.5),
				LPF.ar(WhiteNoise.ar, (freq * 8).clip(100, 18000))
			]);
			subSig = mkSub.(freq, sub1w, sub1a, sub1d, sub1o)
				+ mkSub.(freq, sub2w, sub2a, sub2d, sub2o)
				+ mkSub.(freq, sub3w, sub3a, sub3d, sub3o)
				+ mkSub.(freq, sub4w, sub4a, sub4d, sub4o);
			sig = sig + subSig;
			env = EnvGen.kr(Env.adsr(a, d, s, r), gate);
			// mod = LFO control-bus input (dedicated arg: .set never breaks its mapping)
			outSig = sig * env * Lag.kr(amp, 0.05);
			Out.ar(out, outSig);
			Out.kr(lvl, Amplitude.kr(outSig, 0.01, 0.15));
		}).add;

		// Phasor+BufRd for the looping subtype: no trigger edge to miss.
		// select: 0 loop, 1 oneshot (PlayBuf fired by t_trig; silent after end).
		// bar-entry sync: sync arg (0 immediate, 1 quarter, 2 bar) waits for the
		// next tempo-grid boundary before (re)starting the phasor.
		// tbus = index of the engine tempo control bus (bpm).
		SynthDef(\rot_loop, { arg in=0, out=0, buf=0, rate=1, amp=0.8, select=0,
			gate=1, sync=0, tbus=0, mod=0, lvl=0, t_trig=0;
			var frames = BufFrames.kr(buf).max(1);
			var bpm = In.kr(tbus).max(1);
			var beat = 60 / bpm;
			var grid = Select.kr(sync.clip(0, 2).round, [0, beat, beat * 4]);
			var onGrid = grid > 0;
			var trig = Impulse.kr(0) + Changed.kr(buf);
			var sweep = Sweep.kr(trig);
			// one kr tick at each grid crossing after trig (never at time 0)
			var crossed = onGrid * ((sweep % grid) <= ControlDur.ir) * (sweep > ControlDur.ir);
			var start = Select.kr(onGrid, [trig.clip(0, 1), crossed]);
			var rateM = Lag.kr(rate, 0.05) * (2 ** mod.clip(-1, 1));
			var oneshot = select.round.clip(0, 1);
			var posLoop = Phasor.ar(start, rateM * BufRateScale.kr(buf), 0, frames);
			// PlayBuf + t_trig: the norns-canonical one-shot (fires once per
			// trigger pulse, outputs silence after the sample ends)
			var sigLoop = BufRd.ar(1, buf, posLoop, 1);
			var sigOnce = PlayBuf.ar(1, buf, rateM * BufRateScale.kr(buf), t_trig, 0, 0, 0);
			var sig = Select.ar(oneshot, [sigLoop, sigOnce]);
			sig = sig * Lag.kr(amp, 0.05);
			Out.ar(out, sig);
			Out.kr(lvl, Amplitude.kr(sig, 0.01, 0.15));
		}).add;

		// envelope -> cutoff (x2^(env*3), idle-neutral at env=0);
		// gate retrigs on sequencer notes
		SynthDef(\rot_filter, { arg in=0, out=0, select=0, cutoff=1200, rq=0.5, amp=1,
			mod=0, lvl=0, gate=1, a=0.01, d=0.4, s=0, r=0.3;
			var sig = In.ar(in, 1);
			var env = EnvGen.kr(Env.adsr(a, d, s, r), gate);
			cutoff = (Lag.kr(cutoff, 0.05) * (2 ** mod.clip(-1, 1)) * (2 ** (env * 3))).clip(40, 12000);
			rq = Lag.kr(rq, 0.1).clip(0.05, 1);
			sig = SelectX.ar(Lag.kr(select, 0.05), [
				RLPF.ar(sig, cutoff, rq),
				BPF.ar(sig, cutoff, rq),
				RHPF.ar(sig, cutoff, rq)
			]);
			sig = sig * Lag.kr(amp, 0.05);
			Out.ar(out, sig);
			Out.kr(lvl, Amplitude.kr(sig, 0.01, 0.15));
		}).add;

		// select: 0 feedback, 1 pingpong (cross-feedback dual tap), 2 reverb.
		// sync=1 quantizes time to 32nd notes off the tempo bus; sweep = time
		// glide (seconds of lag on time changes). envelope -> feedback
		// (swells toward 0.99, idle-neutral at env=0); gate retrigs on seq notes.
		SynthDef(\rot_delay, { arg in=0, out=0, time=0.3, feedback=0.4, amp=1,
			select=0, sync=0, sweep=0.2, tbus=0, mod=0, lvl=0, room=0.4,
			gate=1, a=0.01, d=0.4, s=0, r=0.3;
			var dry = In.ar(in, 1);
			var bpm = In.kr(tbus).max(1);
			var env = EnvGen.kr(Env.adsr(a, d, s, r), gate);
			var t, fb, fb0, local, wet1, ppA, ppB, pingpong, reverb, wet;
			t = Lag.kr(time, sweep.clip(0.01, 2));
			t = t * (2 ** (mod.clip(-1, 1) * 0.5)); // bipolar, +-half octave
			t = Select.kr(sync.clip(0, 1).round,
				[t, (t / (60 / bpm / 8)).round(1) * (60 / bpm / 8)]);
			t = t.clip(0.01, 2);
			fb0 = Lag.kr(feedback, 0.1);
			fb = (fb0 + (env * (0.99 - fb0))).clip(0, 0.99);
			local = LocalIn.ar(3); // ch0: feedback loop; ch1-2: pingpong cross
			wet1 = DelayC.ar(dry + (local[0] * fb), 2, t);
			ppA = DelayC.ar(dry + local[2], 2, t);
			ppB = DelayC.ar(dry + local[1], 2, t * 0.75);
			LocalOut.ar([wet1, ppA * fb, ppB * fb]);
			pingpong = (ppA + ppB) * 0.5;
			// reverb subtype: feedback arg = mix, room arg = room size (v3.0.1)
			reverb = FreeVerb.ar(dry, fb, Lag.kr(room, 0.1).clip(0, 1), 0.5);
			wet = Select.ar(select.clip(0, 2).round, [wet1, pingpong, reverb]);
			wet = (dry + wet) * Lag.kr(amp, 0.05);
			Out.ar(out, wet);
			Out.kr(lvl, Amplitude.kr(wet, 0.01, 0.15));
		}).add;

		// select: 0 ring, 1 chorus, 2 flanger
		// mod target = dry-wet, unipolar: (1 - mod01)
		// envelope swells dry-wet toward 1 (idle-neutral at env=0)
		SynthDef(\rot_mod, { arg in=0, out=0, select=0, main=0.5, drywet=0.5, amp=1,
			mod=0, lvl=0, gate=1, a=0.01, d=0.4, s=0, r=0.3;
			var dry = In.ar(in, 1);
			var env = EnvGen.kr(Env.adsr(a, d, s, r), gate);
			var m = Lag.kr(main, 0.05);
			var ring = dry * SinOsc.ar(m.linexp(0, 1, 10, 2000));
			var chorus = DelayL.ar(dry, 0.05, SinOsc.kr(m.linexp(0, 1, 0.1, 8), 0, 0.002, 0.005));
			var flang = DelayL.ar(dry, 0.02, SinOsc.kr(m.linexp(0, 1, 0.05, 2), 0, 0.001, 0.0025));
			var wet = SelectX.ar(Lag.kr(select, 0.05), [ring, chorus, flang]);
			var dw0 = (Lag.kr(drywet, 0.05) * (1 - (mod * 0.5 + 0.5))).clip(0, 1);
			var dw = (dw0 + (env * (1 - dw0))).clip(0, 1);
			wet = (dry * (1 - dw) + wet * dw) * Lag.kr(amp, 0.05);
			Out.ar(out, wet);
			Out.kr(lvl, Amplitude.kr(wet, 0.01, 0.15));
		}).add;

		// control-rate, bipolar -depth..depth (targets scale it themselves).
		// sync=1: freq locks to the tempo grid; mult = period in 32nd notes.
		SynthDef(\rot_lfo, { arg out=0, select=0, freq=2, depth=0.5, sync=0, mult=8, tbus=0;
			var bpm = In.kr(tbus).max(1);
			var syncedFreq = 8 * bpm / 60 / mult.clip(1, 128);
			var f = Select.kr(sync.clip(0, 1).round, [freq, syncedFreq]);
			var sig = SelectX.kr(Lag.kr(select, 0.05), [
				SinOsc.kr(f),
				LFSaw.kr(f),
				LFPulse.kr(f, 0, 0.5),
				LFNoise0.kr(f)
			]);
			Out.kr(out, sig * Lag.kr(depth, 0.05));
		}).add;

		// select: 0 resampler (downsample+bitcrush), 1 compressor, 2 distortion.
		// main = effect intensity, drywet = mix. mod -> dry-wet (unipolar).
		// envelope swells dry-wet toward 1 (idle-neutral at env=0)
		SynthDef(\rot_shaper, { arg in=0, out=0, select=0, main=0.5, drywet=0.5, amp=1,
			mod=0, lvl=0, gate=1, a=0.01, d=0.4, s=0, r=0.3;
			var dry = In.ar(in, 1);
			var env = EnvGen.kr(Env.adsr(a, d, s, r), gate);
			var m = Lag.kr(main, 0.05);
			var resamp, comp, dist, wet, dw, dw0;
			resamp = Latch.ar(dry, Impulse.ar(m.linexp(0, 1, 400, 16000)));
			resamp = (resamp * m.linexp(0, 1, 16, 4)).round / m.linexp(0, 1, 16, 4);
			comp = Compander.ar(dry, dry, 0.5, 1, m.linlin(0, 1, 1, 0.05).clip(0.05, 1), 0.01, 0.1);
			dist = (dry * m.linexp(0, 1, 1, 30)).tanh;
			wet = SelectX.ar(Lag.kr(select, 0.05), [resamp, comp, dist]);
			dw0 = (Lag.kr(drywet, 0.05) * (1 - (mod * 0.5 + 0.5))).clip(0, 1);
			dw = (dw0 + (env * (1 - dw0))).clip(0, 1);
			wet = (dry * (1 - dw) + wet * dw) * Lag.kr(amp, 0.05);
			Out.ar(out, wet);
			Out.kr(lvl, Amplitude.kr(wet, 0.01, 0.15));
		}).add;

		// line in (shield has no mic); rotation = gain. mod -> gain (unipolar).
		SynthDef(\rot_input, { arg in=0, out=0, gain=0.8, mod=0, lvl=0;
			var sig = SoundIn.ar([0, 1]).sum * 0.5;
			var g = (Lag.kr(gain, 0.05) * (1 - (mod * 0.5 + 0.5))).clip(0, 1);
			sig = sig * g;
			Out.ar(out, sig);
			Out.kr(lvl, Amplitude.kr(sig, 0.01, 0.15));
		}).add;

		// single-sample melodic player (phase-6 decision: no SF2/multi-zone).
		// one WAV pitched via Phasor+BufRd; base = the sample's natural pitch.
		// select: 0 instrument (gated ADSR), 1 drum (one-shot, full length).
		// notes arrive via the trigger command (freq + gate edge).
		SynthDef(\rot_sampler, { arg in=0, out=0, buf=0, freq=220, base=261.6256,
			gate=1, amp=0.8, select=0, a=0.005, d=0.1, s=0.9, r=0.2, mod=0, lvl=0, t_trig=0;
			var frames = BufFrames.kr(buf).max(1);
			var rate = (Lag.kr(freq, 0.03) * (2 ** mod.clip(-1, 1))) / base.max(1);
			var oneshot = select.round.clip(0, 1);
			// PlayBuf + t_trig: norns-canonical one-shot, silent after sample end
			var sig = PlayBuf.ar(1, buf, rate * BufRateScale.kr(buf), t_trig, 0, 0, 0);
			var envGated = EnvGen.kr(Env.adsr(a, d, s, r), gate.clip(0, 1));
			var envDrum = EnvGen.kr(Env.perc(0.005, (frames / BufSampleRate.kr(buf)).max(0.05), 1, -4), t_trig);
			var env = Select.kr(oneshot, [envGated, envDrum]);
			sig = sig * env * Lag.kr(amp, 0.05);
			Out.ar(out, sig);
			Out.kr(lvl, Amplitude.kr(sig, 0.01, 0.15));
		}).add;

		// master stage: volume -> FreeVerb (mix/room, mix 0 = dry) ->
		// Compander (comp 0 = slope 1, neutral). spec §3.13 Global Effects.
		SynthDef(\rot_out, { arg in=0, out=0, volume=0.8, rev=0, room=0.5, comp=0;
			var sig = In.ar(in, 1) * Lag.kr(volume, 0.1);
			sig = FreeVerb.ar(sig, Lag.kr(rev, 0.1), Lag.kr(room, 0.1), 0.5);
			sig = Compander.ar(sig, sig, 0.4, 1,
				Lag.kr(comp, 0.1).linlin(0, 1, 1, 0.2), 0.01, 0.1);
			Out.ar(out, [sig, sig]);
		}).add;

		s.sync;

		silentBuf = Buffer.alloc(s, s.sampleRate, 1);
		s.sync;

		silentBus = Bus.audio(s, 1);
		masterBus = Bus.audio(s, 1);
		tempoBus = Bus.control(s, 1);
		tempoBus.set(120);
		// context.xg runs before crone's monitor synths, so amp polls see us.
		// audio buses are zeroed each control block, so every source synth
		// must execute before the master reads masterBus: nodeGroup first.
		nodeGroup = Group.new(context.xg, \addToTail);
		master = Synth(\rot_out, [\in, masterBus, \out, context.out_b.index],
			context.xg, \addToTail);

		// per-object level polls: fixed pool (matron discovers polls only at
		// engine load, so runtime addPoll is invisible to lua)
		lvlSlots = 16.collect { Bus.control(s, 1) };
		lvlFree = (1..16).asList;
		16.do { arg i;
			this.addPoll("lvl_" ++ (i + 1), { lvlSlots[i].getSynchronous });
		};

		this.addCommand("add", "isi", { arg msg;
			this.addNode(msg[1], msg[2].asSymbol, msg[3]);
		});
		this.addCommand("remove", "i", { arg msg;
			this.freeNode(msg[1]);
		});
		this.addCommand("connect_audio", "ii", { arg msg;
			var src = nodes[msg[1]], dst = nodes[msg[2]];
			if (src.notNil and: { dst.notNil and: { src[\synth].notNil and: { dst[\bus].notNil } } }) {
				// buses are zeroed per control block: source must run first
				src[\synth].moveBefore(dst[\synth]);
				src[\out] = dst[\bus];
				if (src[\muted] != 1) { src[\synth].set(\out, dst[\bus]) };
			};
		});
		this.addCommand("connect_output", "i", { arg msg;
			var src = nodes[msg[1]];
			if (src.notNil and: { src[\synth].notNil }) {
				src[\out] = masterBus;
				if (src[\muted] != 1) { src[\synth].set(\out, masterBus) };
			};
		});
		this.addCommand("disconnect_audio", "i", { arg msg;
			var src = nodes[msg[1]];
			if (src.notNil and: { src[\synth].notNil }) {
				src[\out] = silentBus;
				src[\synth].set(\out, silentBus);
			};
		});
		this.addCommand("mute", "ii", { arg msg;
			var src = nodes[msg[1]];
			if (src.notNil and: { src[\synth].notNil }) {
				src[\muted] = msg[2];
				src[\synth].set(\out, if(msg[2] == 1, silentBus, src[\out]));
			};
		});
		// control connect: LFO bus mapped onto the dedicated \mod arg
		// (mapping a user-set arg breaks on every .set; \mod is touch-free)
		this.addCommand("connect_control", "iis", { arg msg;
			var src = nodes[msg[1]], dst = nodes[msg[2]];
			if (src.notNil and: { dst.notNil and: { src[\bus].notNil and: { dst[\synth].notNil } } }) {
				dst[\synth].map(\mod, src[\bus]);
			};
		});
		this.addCommand("disconnect_control", "is", { arg msg;
			var dst = nodes[msg[1]];
			if (dst.notNil and: { dst[\synth].notNil }) {
				dst[\synth].set(\mod, 0);
			};
		});
		this.addCommand("set", "isf", { arg msg;
			var node = nodes[msg[1]];
			if (node.notNil) {
				if (node[\type] == \output) {
					master.set(msg[2].asSymbol, msg[3]);
				} {
					if (node[\synth].notNil) { node[\synth].set(msg[2].asSymbol, msg[3]) };
				};
			};
		});
		// sequencer note: sampler/loop one-shots fire PlayBuf via t_trig
		// (single-pair set, auto-clearing trigger arg); oscillators retrigger
		// via the classic gate -1 -> 1 edge; effects (filter/delay/mod/shaper)
		// get the bare gate edge for their param envelopes.
		this.addCommand("trigger", "if", { arg msg;
			var node = nodes[msg[1]];
			if (node.notNil and: { node[\synth].notNil }) {
				if (node[\type] == \sampler or: { node[\type] == \loop }) {
					node[\synth].set(\freq, msg[2]);
					// raise gate too: a MIDI note-off shuts the gated ADSR and
					// only this path can reopen it (v3.0.1)
					node[\synth].set(\gate, 1);
					node[\synth].set(\t_trig, 1);
				} {
					if (#[\filter, \delay, \modulator, \waveshaper].includes(node[\type])) {
						node[\synth].set(\gate, -1);
						node[\synth].set(\gate, 1);
					} {
						node[\synth].set(\gate, -1);
						node[\synth].set(\freq, msg[2], \gate, 1);
					};
				};
			};
		});
		this.addCommand("loadbuf", "is", { arg msg;
			var node = nodes[msg[1]];
			("LOAD cmd id " ++ msg[1] ++ " path " ++ msg[2]).postln;
			if (node.notNil and: { node[\synth].notNil }) {
				Buffer.readChannel(s, msg[2].asString, channels: [0], action: { arg b;
					("LOAD done bufnum " ++ b.bufnum ++ " frames " ++ b.numFrames).postln;
					node[\synth].set(\buf, b.bufnum);
				});
			};
		});
		this.addCommand("volume", "f", { arg msg;
			master.set(\volume, msg[1]);
		});
		// single source of truth for bpm (lua rot_tempo param pushes here)
		this.addCommand("tempo", "f", { arg msg;
			tempoBus.set(msg[1]);
		});
		// debug: recreate the master synth
		this.addCommand("remaster", "", { arg msg;
			master.free;
			master = Synth(\rot_out, [\in, masterBus, \out, context.out_b.index],
				context.xg, \addToTail);
		});
		// debug: post server node tree + master controls
		this.addCommand("tree", "", { arg msg;
			s.queryAllNodes;
			master.get(\in, { arg v; ("PROBE master in=" ++ v).postln });
			master.get(\out, { arg v; ("PROBE master out=" ++ v).postln });
			master.get(\volume, { arg v; ("PROBE master volume=" ++ v).postln });
		});
		// debug: post a node's synth control values
		this.addCommand("probe", "i", { arg msg;
			var node = nodes[msg[1]];
			if (node.notNil and: { node[\synth].notNil }) {
				node[\synth].get(\out, { arg v; ("PROBE out=" ++ v).postln });
				node[\synth].get(\amp, { arg v; ("PROBE amp=" ++ v).postln });
				node[\synth].get(\freq, { arg v; ("PROBE freq=" ++ v).postln });
				node[\synth].get(\gate, { arg v; ("PROBE gate=" ++ v).postln });
			} {
				("PROBE no node " ++ msg[1]).postln;
			};
		});
		// debug: post rot_sampler SynthDesc control layout (name + default)
		this.addCommand("definfo", "", { arg msg;
			SynthDescLib.global[\rot_sampler].controls.do { arg c;
				("DEF " ++ c.name ++ " = " ++ c.defaultValue).postln;
			};
		});
	}

	addNode { arg id, type, subtype;
		var def, bus, synth, slot;
		this.freeNode(id);
		def = switch(type,
			\oscillator, { \rot_osc },
			\loop, { \rot_loop },
			\sampler, { \rot_sampler },
			\input, { \rot_input },
			\filter, { \rot_filter },
			\delay, { \rot_delay },
			\modulator, { \rot_mod },
			\waveshaper, { \rot_shaper },
			\lfo, { \rot_lfo },
			{ nil });
		if (def.isNil) {
			// sequencer (lua-driven), tonality (lua-side) and output (master
			// synth) need no node
			nodes[id] = (type: type, synth: nil, bus: nil, out: nil, muted: 0);
		} {
			if (def == \rot_lfo) {
				bus = Bus.control(context.server, 1);
				synth = Synth(def, [\out, bus, \select, subtype, \tbus, tempoBus.index],
					nodeGroup, \addToTail);
			} {
				var args;
				bus = Bus.audio(context.server, 1); // before args: \in needs it
				args = [\in, bus, \out, silentBus, \select, subtype];
				slot = if(lvlFree.size > 0, { lvlFree.pop }, { nil });
				if (def == \rot_loop or: { def == \rot_sampler }) {
					args = args ++ [\buf, silentBuf];
				};
				if (def == \rot_loop or: { def == \rot_delay }) {
					args = args ++ [\tbus, tempoBus.index];
				};
				if (slot.notNil) { args = args ++ [\lvl, lvlSlots[slot - 1]] };
				synth = Synth(def, args, nodeGroup, \addToTail);
			};
			nodes[id] = (type: type, synth: synth, bus: bus, lvlSlot: slot,
				out: silentBus, muted: 0);
		};
	}

	freeNode { arg id;
		var node = nodes[id];
		if (node.notNil) {
			if (node[\synth].notNil) { node[\synth].free };
			if (node[\bus].notNil) { node[\bus].free };
			if (node[\lvlSlot].notNil) {
				lvlSlots[node[\lvlSlot] - 1].set(0);
				lvlFree.add(node[\lvlSlot]);
			};
			nodes.removeAt(id);
		};
	}

	free {
		nodes.keys.do { arg id; this.freeNode(id) };
		master.free;
		nodeGroup.free;
		lvlSlots.do { arg b; b.free };
		silentBus.free;
		masterBus.free;
		tempoBus.free;
		silentBuf.free;
	}
}
