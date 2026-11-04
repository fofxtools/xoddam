"""Generate simple retro placeholder SFX (stdlib only). Usage: python tools/gen_sfx.py <out_dir>"""
import math, random, struct, sys, wave
R = 44100

def render(segs, vol=0.4, wave_kind="square", noise=False):
    # segs: (freq_start, freq_end, seconds). Square/triangle tone with linear sweep and decay.
    out, phase = [], 0.0
    for f0, f1, dur in segs:
        n = int(R * dur)
        for i in range(n):
            t = i / n
            f = f0 + (f1 - f0) * t
            phase += f / R
            p = phase % 1.0
            if noise:
                s = random.uniform(-1, 1)
            elif wave_kind == "square":
                s = 1.0 if p < 0.5 else -1.0
            else:
                s = 4 * abs(p - 0.5) - 1
            env = min(1.0, i / 200) * (1 - t) ** 0.8
            out.append(s * env * vol)
    return out

def save(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))

def bonk():
    # Item block bump: a tiny click then a short, dull falling "bonk".
    return render([(0, 0, 0.015)], noise=True, vol=0.3) + render([(260, 120, 0.13)], wave_kind="tri", vol=0.7)


def roar(seconds=1.4, vol=0.7):
    # T-Rex roar: a low saw wave whose pitch falls, with a vibrato, a fast growl wobble and rough noise,
    # soft-clipped for grit, with a quick attack and a slow fade.
    out, phase, lp = [], 0.0, 0.0
    n = int(R * seconds)
    for i in range(n):
        t = i / n
        sec = i / R
        base = 95 - 35 * t
        phase += (base + 8 * math.sin(2 * math.pi * 24 * sec)) / R
        saw = 2 * (phase % 1.0) - 1
        growl = 0.55 + 0.45 * math.sin(2 * math.pi * 31 * sec)
        lp += 0.12 * (random.uniform(-1, 1) - lp)
        sample = math.tanh(2.4 * (0.8 * saw * growl + 1.6 * lp))
        env = min(1.0, t / 0.08) * (1.0 - t) ** 0.7
        out.append(sample * env * vol)
    return out


def stomp_hard():
    # Mario-style stomp: a hard click, a fast falling square "bwip", then a low thump, all loud and over in 0.2 s
    click = render([(0, 0, 0.012)], noise=True, vol=0.42)
    bwip = render([(1100, 260, 0.08)], vol=0.45)
    thump = render([(200, 55, 0.11)], wave_kind="tri", vol=0.57)
    return click + bwip + thump


def death():
    # Falling jingle: four quick notes stepping down, then a long sad slide into the floor
    notes = render([(f, f, 0.1) for f in (784, 659, 523, 392)], vol=0.5)
    return notes + render([(330, 70, 0.55)], wave_kind="tri", vol=0.7)


def rescued():
    # Puppy freed: a happy rising fanfare, then two excited yips
    fanfare = render([(f, f, 0.11) for f in (523, 659, 784, 1047)], vol=0.44) + render([(1047, 1047, 0.35)], wave_kind="tri", vol=0.48)
    gap = render([(0, 0, 0.12)], vol=0.0)
    yip = render([(700, 1500, 0.08)], vol=0.6) + render([(1500, 1100, 0.05)], vol=0.5)
    return fanfare + gap + yip + render([(0, 0, 0.06)], vol=0.0) + yip


def denied():
    # "Nope": two low, flat buzzes
    gap = render([(0, 0, 0.05)], vol=0.0)
    return render([(170, 160, 0.1)], vol=0.44) + gap + render([(150, 130, 0.16)], vol=0.44)


def laser():
    # Sci-fi "pew": a bright sweep from high to low with a buzz on top
    out = []
    phase = 0.0
    n = int(R * 0.22)
    for i in range(n):
        t = i / n
        f = 2200 * (1 - t) ** 1.6 + 260
        phase += f / R
        p = phase % 1.0
        s = (2 * p - 1) * 0.6 + (1.0 if (phase * 3.01) % 1.0 < 0.5 else -1.0) * 0.25
        out.append(s * min(1.0, i / 40) * (1 - t) ** 0.9 * 0.4)
    return out


random.seed(1)
sounds = {
    "jump": render([(300, 700, 0.16)]),
    "coin": render([(988, 988, 0.06), (1319, 1319, 0.25)]),
    "stomp": render([(220, 60, 0.12)], wave_kind="tri", vol=0.6) + render([(0, 0, 0.05)], noise=True, vol=0.25),
    "powerup": render([(f, f, 0.07) for f in (392, 494, 587, 784, 988, 1175)], wave_kind="tri"),
    "hit": render([(0, 0, 0.18)], noise=True, vol=0.35) + render([(200, 80, 0.15)]),
    "extra_life": render([(f, f, 0.1) for f in (659, 784, 1319, 1047, 1175, 1568)]),
    "game_over": render([(f, f, 0.22) for f in (392, 330, 262, 196)], wave_kind="tri"),
    "ui_click": render([(800, 600, 0.05)], vol=0.3),
    "block": bonk(),
    "roar": roar(),
    "stomp_hard": stomp_hard(),
    "death": death(),
    "laser": laser(),
    "rescued": rescued(),
    "denied": denied(),
}
out = sys.argv[1]
for name, s in sounds.items():
    save(f"{out}/{name}.wav", s)
print("wrote", ", ".join(sounds))
