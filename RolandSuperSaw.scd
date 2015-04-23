
// Boot
s.reboot
(
s.boot;
s.makeGui;
s.plotTree;
s.meter;
s.scope;
FreqScope.new;
MIDIClient.init;
)



// Setup 

(
var channel, synthCnt, func_velCal, func_StToFreq;
s.freeAll;
~midiNotes = Array.newClear(128);
~midiBend = 8192;
~sourceGroup = Group.new;

func_velCal = { |vel| (vel * 1/synthCnt).linexp(1, 127, 0.1, 0.3)};

// Midi 


~midiNoteOffset = 0;
~detuneAmount = 0.5;

channel=0;
synthCnt=1;


MIDIdef.noteOn(\MidiCh0NoteOn, {
    |vel, nn, chan, src|
    var bend, currentVel, rand, detune;
    nn = nn + ~midiNoteOffset;
    bend = ~midiBend.linlin(0, 16383, 0, 1);
    rand = Array.fill(6, {0.1.bilinrand + 0.1});
    currentVel = 0.75; //func_velCal.value(vel);
    currentVel.postln;
    detune = ~detuneAmount;
    if (~midiNotes[nn] == nil,
        {
            ~midiNotes[nn] = Group.new(~sourceGroup);
            // Add Synths Here:
            // e.g: Synth.new(\syn1,[\freq, nn,\amp, currentVel,\gate, 1,\bend, bend, \outBus, ~filterBus], ~midiNotes[nn]);
            Synth.new(\rolandSuperSaw,[\freq, nn,\amp, currentVel,\gate, 1,\bend, bend, \detune, detune, \rand, rand, \outBus,  ~filterBus], ~midiNotes[nn]);
        },
        {
            ~midiNotes[nn].set(\amp, currentVel, \gate, 1, \bend, bend, \detune, detune, \rand, rand);
        }
    )
},chan:channel);

MIDIdef.noteOff(\MidiCh0NoteOff, {
    |vel, nn, chan, src|
    nn = nn + ~midiNoteOffset;
    ~midiNotes[nn].set(\gate, 0);

},chan:channel);

MIDIdef.bend(\MidiCh0Bend, {
    |val, chan, src|
    ~midiBend = val;
    ~sourceGroup.set(\bend, val.linlin(0, 168383, -2, 2));
},chan:channel);

// Global Filter

~filterGroup = Group.after(~sourceGroup);
~filterBus.free;
~filterBus = Bus.audio(s, 1);

SynthDef.new(\filterLPF, {
    |outBus=0, inBus, freq=24000, gate=1|
    var sig, ctl, amp, env;
    sig = In.ar(inBus);
    ctl = HPF.ar(sig, 50, 1);
    ctl = LPF.ar(ctl, freq, 1);

    env = EnvGen.kr(Env.adsr, gate);
    amp = Amplitude.kr(ctl);
    Out.ar(outBus, (ctl )!2);
}).add;

Synth.new(\filterLPF, [\inBus, ~filterBus], ~filterGroup);
//~filterGroup.set(\freq, 1200);

// Synths


func_StToFreq = { |st, freq=440| freq * (2.pow(1/12)).pow(st); };


SynthDef.new(\rolandSuperSaw, {
    // see: https://www.nada.kth.se/utbildning/grukth/exjobb/rapportlistor/2010/rapporter10/szabo_adam_10131.pdf
    |freq=440, amp=0.5, gate=1, bend=0, rand=#[0,0,0,0,0,0], detune=0, outBus=0, outPercent=1, sendBus, sendPercentage=0|
    var sig, env, sig1, hpf, samp, detune_f;
    samp = -0.73764 * amp.pow(2) + 1.2841 * amp + 0.044372;
    freq = freq.midicps * bend.midiratio;
    detune_f = {|detune|
        detune=detune.value;
        (10028.7312891634 * detune.pow(11)) -
        (50818.8652045924 * detune.pow(10)) +
        (111363.4808729368 * detune.pow(9)) -
        (138150.6761080548 * detune.pow(8)) +
        (106649.6679158292 * detune.pow(7)) -
        (53046.9642751875 * detune.pow(6)) +
        (17019.9518580080 * detune.pow(5)) -
        (3425.0836591318 * detune.pow(4)) +
        (404.2703938388 * detune.pow(3)) -
        (24.1878824391 * detune.pow(2)) +
        (0.6717417634 * detune) +
        0.0030115596; };
    detune = detune_f.value(detune);
    //detune.poll;
    sig = Mix.new([
        Saw.ar(freq, 0, -0.55366 * amp + 0.99785),  // center
        Saw.ar(detune * -0.11002313 * freq + freq, rand[0] , samp), // osc 1
        Saw.ar(detune * -0.06288439 * freq + freq, rand[1] , samp), // osc 2
        Saw.ar(detune * -0.01952356 * freq + freq, rand[2], samp), // osc 3
        Saw.ar(detune * 0.01991221 * freq + freq, rand[3], samp), // osc 5
        Saw.ar(detune * 0.06216538 * freq + freq, rand[4], samp), // osc 6
        Saw.ar(detune * 0.10745242 * freq + freq, rand[5], samp) // osc 7
    ]);
    sig = HPF.ar(sig,freq -1);

    /* User Area */
   
    
    env = EnvGen.kr(Env.adsr(0.1, 5, 0.3, 3), gate);

    /* */ 
    
    sig = sig * env * amp;
    Out.ar(outBus, sig * outPercent);
    Out.ar(sendBus, sig * sendPercentage);
}).add;
)
