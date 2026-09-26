// Engine_Rotatable.sc — reactable emulator engine (phase 4)
// one group + synth + private inBus per object; sources retarget their out bus.
// control connections: controller writes a control bus, target param is .map'ed.

Engine_Rotatable : CroneEngine {
	var <silentBus, <masterBus, <master;
	var <silentBuf; // 1s mono silence; default buf for loop player (avoids NaN rate)
	var nodeGroup; // all object synths live here, before the master synth
	var nodes; // id -> (group, synth, bus, type, out, muted)

	*new { arg context, doneCallback; ^super.new(context, doneCallback); }

	alloc {
		var s = context.server;
		nodes = IdentityDictionary.new;

		SynthDef(\rot_osc, { arg in=0, out=0, gate=1, freq=220, amp=0.8, select=0,
			a=0.01, d=0.1, s=0.7, r=0.3, mod=0;
			var sig, env;
			freq = Lag.kr(freq, 0.05);
			sig = SelectX.ar(Lag.kr(select, 0.05), [
				SinOsc.ar(freq),
				Saw.ar(freq),
				Pulse.ar(freq, 0.5),
				LPF.ar(WhiteNoise.ar, (freq * 8).clip(100, 18000))
			]);
			env = EnvGen.kr(Env.adsr(a, d, s, r), gate);
			// mod = LFO control-bus input (dedicated arg: .set never breaks its mapping)
			Out.ar(out, sig * env * Lag.kr(amp, 0.05) * (1 - mod));
		}).add;

		// Phasor+BufRd: always looping, no trigger edge to miss.
		// (oneshot/pitchlock subtypes arrive in a later iteration)
		SynthDef(\rot_loop, { arg in=0, out=0, buf=0, rate=1, amp=0.8, mod=0;
			var frames = BufFrames.kr(buf).max(1);
			var pos = Phasor.ar(0, Lag.kr(rate, 0.05) * BufRateScale.kr(buf), 0, frames);
			var sig = BufRd.ar(1, buf, pos, 1);
			Out.ar(out, sig * Lag.kr(amp, 0.05) * (1 - mod));
		}).add;

		SynthDef(\rot_filter, { arg in=0, out=0, select=0, cutoff=1200, rq=0.5, amp=1, mod=0;
			var sig = In.ar(in, 1);
			cutoff = Lag.kr(cutoff, 0.05).clip(40, 12000);
			rq = Lag.kr(rq, 0.1).clip(0.05, 1);
			sig = SelectX.ar(Lag.kr(select, 0.05), [
				RLPF.ar(sig, cutoff, rq),
				BPF.ar(sig, cutoff, rq),
				RHPF.ar(sig, cutoff, rq)
			]);
			Out.ar(out, sig * Lag.kr(amp, 0.05) * (1 - mod));
		}).add;

		SynthDef(\rot_delay, { arg in=0, out=0, time=0.3, feedback=0.4, amp=1, mod=0;
			var dry = In.ar(in, 1);
			var fb = LocalIn.ar(1);
			var wet = DelayC.ar(dry + (fb * Lag.kr(feedback, 0.1).clip(0, 0.99)), 2, Lag.kr(time, 0.2));
			LocalOut.ar(wet);
			Out.ar(out, (dry + wet) * Lag.kr(amp, 0.05) * (1 - mod));
		}).add;

		// select: 0 ring, 1 chorus, 2 flanger
		SynthDef(\rot_mod, { arg in=0, out=0, select=0, main=0.5, drywet=0.5, amp=1, mod=0;
			var dry = In.ar(in, 1);
			var m = Lag.kr(main, 0.05);
			var ring = dry * SinOsc.ar(m.linexp(0, 1, 10, 2000));
			var chorus = DelayL.ar(dry, 0.05, SinOsc.kr(m.linexp(0, 1, 0.1, 8), 0, 0.002, 0.005));
			var flang = DelayL.ar(dry, 0.02, SinOsc.kr(m.linexp(0, 1, 0.05, 2), 0, 0.001, 0.0025));
			var wet = SelectX.ar(Lag.kr(select, 0.05), [ring, chorus, flang]);
			var dw = Lag.kr(drywet, 0.05) * (1 - mod);
			Out.ar(out, (dry * (1 - dw) + wet * dw) * Lag.kr(amp, 0.05));
		}).add;

		// control-rate: unipolar 0..depth (tremolo / wetness wobble style)
		SynthDef(\rot_lfo, { arg out=0, select=0, freq=2, depth=0.5;
			var sig = SelectX.kr(Lag.kr(select, 0.05), [
				SinOsc.kr(freq),
				LFSaw.kr(freq),
				LFPulse.kr(freq, 0, 0.5),
				LFNoise0.kr(freq)
			]);
			Out.kr(out, (sig * 0.5 + 0.5) * Lag.kr(depth, 0.05));
		}).add;

		SynthDef(\rot_out, { arg in=0, out=0, volume=0.8;
			var sig = In.ar(in, 1) * Lag.kr(volume, 0.1);
			Out.ar(out, [sig, sig]);
		}).add;

		s.sync;

		silentBuf = Buffer.alloc(s, s.sampleRate, 1);
		s.sync;

		silentBus = Bus.audio(s, 1);
		masterBus = Bus.audio(s, 1);
		// context.xg runs before crone's monitor synths, so amp polls see us.
		// audio buses are zeroed each control block, so every source synth
		// must execute before the master reads masterBus: nodeGroup first.
		nodeGroup = Group.new(context.xg, \addToTail);
		master = Synth(\rot_out, [\in, masterBus, \out, context.out_b.index],
			context.xg, \addToTail);

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
					master.set(\volume, msg[3]);
				} {
					if (node[\synth].notNil) { node[\synth].set(msg[2].asSymbol, msg[3]) };
				};
			};
		});
		// sequencer note: force-retrigger gate (negative gate = release+retrigger)
		this.addCommand("trigger", "if", { arg msg;
			var node = nodes[msg[1]];
			if (node.notNil and: { node[\synth].notNil }) {
				node[\synth].set(\gate, -1);
				node[\synth].set(\freq, msg[2], \gate, 1);
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
	}

	addNode { arg id, type, subtype;
		var def, bus, synth;
		this.freeNode(id);
		def = switch(type,
			\oscillator, { \rot_osc },
			\loop, { \rot_loop },
			\filter, { \rot_filter },
			\delay, { \rot_delay },
			\modulator, { \rot_mod },
			\lfo, { \rot_lfo },
			{ nil });
		if (def.isNil) {
			// sequencer (lua-driven) and output (master synth) need no node
			nodes[id] = (type: type, synth: nil, bus: nil, out: nil, muted: 0);
		} {
			if (def == \rot_lfo) {
				bus = Bus.control(context.server, 1);
				synth = Synth(def, [\out, bus, \select, subtype], nodeGroup, \addToTail);
			} {
				bus = Bus.audio(context.server, 1);
				if (def == \rot_loop) {
					synth = Synth(def, [\in, bus, \out, silentBus, \buf, silentBuf],
						nodeGroup, \addToTail);
				} {
					synth = Synth(def, [\in, bus, \out, silentBus, \select, subtype],
						nodeGroup, \addToTail);
				};
			};
			nodes[id] = (type: type, synth: synth, bus: bus, out: silentBus, muted: 0);
		};
	}

	freeNode { arg id;
		var node = nodes[id];
		if (node.notNil) {
			if (node[\synth].notNil) { node[\synth].free };
			if (node[\bus].notNil) { node[\bus].free };
			nodes.removeAt(id);
		};
	}

	free {
		nodes.keys.do { arg id; this.freeNode(id) };
		master.free;
		nodeGroup.free;
		silentBus.free;
		masterBus.free;
		silentBuf.free;
	}
}
