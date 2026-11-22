"""离线合成《洋芋粑帝国》的背景音乐。

六段 8-bit 五声音阶风格的循环曲，全部由本脚本纯 Python 合成（无外部素材、
无版权问题），输出 44.1kHz 立体声 ogg 到 res://music/。

用法：
    python tools/make_music.py            # 重新生成全部曲目
    python tools/make_music.py market     # 只生成指定曲目

循环无缝的做法：整首曲子渲染在固定长度的缓冲区里，所有音符的尾音按缓冲区
长度取模回卷，混响用环形延迟线，因此首尾天然咬合。
"""

import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "music")

SEMITONE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq_of(name):
    """把 'D5' / 'F#5' 这样的音名换算成频率，'.' 表示休止。"""
    if not name or name == ".":
        return 0.0
    letter = name[0].upper()
    rest = name[1:]
    sharp = 0
    if rest.startswith("#"):
        sharp = 1
        rest = rest[1:]
    elif rest.startswith("b"):
        sharp = -1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + SEMITONE[letter] + sharp
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


class Song:
    def __init__(self, bpm, bars, beats_per_bar=4.0, step=0.5):
        self.step_dur = 60.0 / bpm * step
        self.length = int(round(bars * beats_per_bar * 60.0 / bpm * SR))
        self.left = [0.0] * self.length
        self.right = [0.0] * self.length

    def _mix(self, start, samples, pan):
        n = self.length
        gain_l = 1.0 - max(0.0, pan)
        gain_r = 1.0 + min(0.0, pan)
        left, right = self.left, self.right
        for i, value in enumerate(samples):
            index = (start + i) % n
            left[index] += value * gain_l
            right[index] += value * gain_r

    def note(self, start, dur, name, amp=0.2, voice="square", pan=0.0,
             attack=0.004, decay=0.06, sustain=0.62, release=0.09,
             duty=0.5, vibrato=0.0, detune=1.0, glide=1.0):
        f0 = freq_of(name) * detune
        if f0 <= 0.0:
            return
        total = max(1, int(dur * SR))
        release_n = max(1, int(release * SR))
        attack_n = max(1, int(attack * SR))
        decay_n = max(1, int(decay * SR))
        phase = 0.0
        out = [0.0] * total
        for i in range(total):
            t = i / SR
            if i < attack_n:
                env = i / attack_n
            elif i < attack_n + decay_n:
                env = 1.0 - (1.0 - sustain) * ((i - attack_n) / decay_n)
            else:
                env = sustain
            tail = total - i
            if tail < release_n:
                env *= tail / release_n
            f = f0 * (1.0 + glide * 0.0)
            if vibrato:
                f *= 1.0 + vibrato * math.sin(2.0 * math.pi * 5.4 * t)
            phase += f / SR
            frac = phase - math.floor(phase)
            if voice == "square":
                value = 1.0 if frac < duty else -1.0
            elif voice == "pulse":
                value = 1.0 if frac < 0.25 else -1.0
            elif voice == "tri":
                value = 4.0 * abs(frac - 0.5) - 1.0
            elif voice == "saw":
                value = 2.0 * frac - 1.0
            else:
                value = math.sin(2.0 * math.pi * frac)
            out[i] = value * env * amp
        self._mix(start, out, pan)

    def noise(self, start, dur, amp=0.1, pan=0.0, tone=0.0, decay_pow=2.4, seed=0):
        total = max(1, int(dur * SR))
        rng = random.Random(seed)
        out = [0.0] * total
        phase = 0.0
        for i in range(total):
            frac = i / total
            env = (1.0 - frac) ** decay_pow
            value = rng.uniform(-1.0, 1.0)
            if tone:
                phase += tone / SR
                value = 0.6 * value + 0.4 * math.sin(2.0 * math.pi * phase)
            out[i] = value * env * amp
        self._mix(start, out, pan)

    def at(self, step):
        return int(round(step * self.step_dur * SR))

    def pattern(self, text, start_step, amp=0.2, length=1.0, **kwargs):
        """按 1/8 音符为一格铺一条声部，'.' 是休止。"""
        for index, token in enumerate(text.split()):
            if token == ".":
                continue
            self.note(self.at(start_step + index), self.step_dur * length,
                      token, amp=amp, **kwargs)

    def echoes(self, delay=0.34, feedback=0.34, wet=0.5):
        """环形延迟混响，因为取模回卷，循环点不会爆音。"""
        n = self.length
        d = int(delay * SR)
        for buf in (self.left, self.right):
            for i in range(n):
                buf[i] += (buf[(i - d) % n] + buf[(i - 2 * d) % n] * 0.6) * feedback * wet * 0.5

    def master(self, target=0.86, softness=1.0):
        peak = max(max(abs(v) for v in self.left), max(abs(v) for v in self.right), 1e-9)
        scale = target / peak
        for buf in (self.left, self.right):
            for i in range(len(buf)):
                buf[i] = math.tanh(buf[i] * scale * softness)

    def write(self, path):
        frames = bytearray()
        for i in range(self.length):
            l = max(-1.0, min(1.0, self.left[i]))
            r = max(-1.0, min(1.0, self.right[i]))
            frames += struct.pack("<hh", int(l * 32000), int(r * 32000))
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            wav_path = tmp.name
        with wave.open(wav_path, "wb") as handle:
            handle.setnchannels(2)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(bytes(frames))
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
             "-c:a", "libvorbis", "-q:a", "6", path],
            check=True,
        )
        os.unlink(wav_path)


# ---------------------------------------------------------------- 集市 · 赶场调
def build_market():
    song = Song(bpm=132, bars=8)
    lead = [
        "D5 E5 F#5 A5  B5 . A5 F#5  E5 . D5 .  . E5 F#5 .",
        "D5 E5 F#5 A5  B5 . D6 B5  A5 . F#5 E5  D5 . . .",
        "A5 B5 D6 B5  A5 F#5 E5 .  D5 E5 F#5 E5  D5 . A4 .",
        "B4 D5 E5 F#5  A5 . F#5 E5  D5 . E5 F#5  D5 . . .",
    ]
    for bar, text in enumerate(lead):
        song.pattern(text, bar * 8, amp=0.17, length=0.92, voice="square", duty=0.5, vibrato=0.004)
        song.pattern(text, bar * 8, amp=0.06, length=0.92, voice="pulse", detune=1.004, pan=-0.5)
    harmony = [
        "A4 B4 D5 F#5  G5 . F#5 D5  B4 . A4 .  . B4 D5 .",
        "A4 B4 D5 F#5  G5 . B5 G5  F#5 . D5 B4  A4 . . .",
        "F#5 G5 B5 G5  F#5 D5 B4 .  A4 B4 D5 B4  A4 . F#4 .",
        "G4 A4 B4 D5  F#5 . D5 B4  A4 . B4 D5  A4 . . .",
    ]
    for bar, text in enumerate(harmony):
        song.pattern(text, bar * 8, amp=0.075, length=0.9, voice="pulse", pan=-0.34)
    bass = ["D3 . D3 . A2 . D3 .", "D3 . D3 . A2 . D3 .",
            "B2 . B2 . A2 . A2 .", "G2 . G2 . D3 . A2 ."] * 2
    for bar, text in enumerate(bass):
        song.pattern(text, bar * 8, amp=0.2, length=0.62, voice="tri")
    for bar in range(8):
        base = bar * 8
        song.note(song.at(base), 0.16, "D2", amp=0.28, voice="sine", glide=0.0)
        song.noise(song.at(base), 0.05, amp=0.05, tone=6200.0, decay_pow=3.4, seed=bar)
        song.noise(song.at(base + 2), 0.09, amp=0.1, tone=190.0, decay_pow=2.6, seed=bar + 40)
        song.noise(song.at(base + 4), 0.16, amp=0.12, tone=240.0, decay_pow=2.2, seed=bar + 80)
        song.noise(song.at(base + 3), 0.04, amp=0.038, tone=7200.0, decay_pow=3.8, seed=bar + 11)
        song.noise(song.at(base + 5), 0.04, amp=0.038, tone=7200.0, decay_pow=3.8, seed=bar + 12)
        song.noise(song.at(base + 6), 0.04, amp=0.038, tone=7200.0, decay_pow=3.8, seed=bar + 13)
        song.noise(song.at(base + 7), 0.04, amp=0.038, tone=7200.0, decay_pow=3.8, seed=bar + 14)
        song.noise(song.at(base + 6), 0.1, amp=0.07, tone=200.0, decay_pow=2.6, seed=bar + 90)
    song.echoes(delay=0.28, feedback=0.26, wet=0.4)
    return song


# ---------------------------------------------------------------- 做饭 · 翻面歌
def build_cooking():
    song = Song(bpm=146, bars=8)
    lead = [
        "G5 . A5 .  B5 . D6 .  B5 A5 G5 A5  B5 . . .",
        "E5 . G5 .  A5 . B5 .  A5 G5 E5 D5  E5 . . .",
        "D5 E5 G5 A5  B5 . D6 B5  A5 . G5 E5  D5 . . .",
        "G5 A5 B5 D6  E6 . D6 B5  A5 G5 A5 B5  G5 . . .",
    ]
    for bar, text in enumerate(lead):
        song.pattern(text, bar * 8, amp=0.16, length=0.55, voice="square", duty=0.25)
        song.pattern(text, bar * 8, amp=0.05, length=0.55, voice="square", detune=0.996, pan=0.42)
    bass = ["G2 . G2 G2 G2 . D3 .", "E2 . E2 E2 E2 . D3 .",
            "D3 . D3 D3 G2 . G2 .", "G2 G2 D3 D3 G2 . G2 ."] * 2
    for bar, text in enumerate(bass):
        song.pattern(text, bar * 8, amp=0.19, length=0.5, voice="pulse")
    for bar in range(8):
        base = bar * 8
        song.note(song.at(base), 0.12, "G1", amp=0.26, voice="sine")
        song.noise(song.at(base), 0.045, amp=0.045, tone=6800.0, decay_pow=3.6, seed=bar + 5)
        song.noise(song.at(base + 2), 0.06, amp=0.085, tone=320.0, decay_pow=2.8, seed=bar + 60)
        song.noise(song.at(base + 4), 0.045, amp=0.045, tone=6800.0, decay_pow=3.6, seed=bar + 7)
        song.noise(song.at(base + 4), 0.1, amp=0.1, tone=250.0, decay_pow=2.4, seed=bar + 70)
        song.noise(song.at(base + 6), 0.045, amp=0.045, tone=6800.0, decay_pow=3.6, seed=bar + 9)
        song.noise(song.at(base + 7), 0.03, amp=0.03, tone=7600.0, decay_pow=3.8, seed=bar + 10)
    song.echoes(delay=0.2, feedback=0.2, wet=0.28)
    return song


# ---------------------------------------------------------------- 夜晚 · 夜里算账
def build_night():
    song = Song(bpm=74, bars=8, step=0.5)
    lead = [
        "A4 . . .  C5 . D5 .  E5 . . .  D5 . C5 .",
        "A4 . . .  G4 . E4 .  D4 . . .  . . . .",
        "C5 . D5 .  E5 . G5 .  E5 . D5 .  C5 . A4 .",
        "G4 . A4 .  C5 . A4 .  G4 . . .  . . . .",
    ]
    for bar, text in enumerate(lead):
        song.pattern(text, bar * 8, amp=0.15, length=1.9, voice="tri", attack=0.02,
                     decay=0.3, sustain=0.5, release=0.5)
        song.pattern(text, bar * 8, amp=0.045, length=1.9, voice="sine", detune=2.0, pan=-0.4)
    bass = ["A2 . . . . . . .", "F2 . . . . . . .",
            "C3 . . . . . . .", "G2 . . . . . . ."] * 2
    for bar, text in enumerate(bass):
        song.pattern(text, bar * 8, amp=0.16, length=7.4, voice="sine",
                     attack=0.06, decay=0.5, sustain=0.5, release=0.8)
    for bar in range(8):
        song.noise(song.at(bar * 8 + 4), 0.05, amp=0.022, tone=5200.0, decay_pow=3.6, seed=bar + 21)
        song.noise(song.at(bar * 8), 0.4, amp=0.03, tone=1800.0, decay_pow=5.0, seed=bar + 31)
    song.pattern("E6 . . . . . . .  A6 . . . . . . .", 8, amp=0.03, length=6.0, voice="sine", pan=0.5)
    song.echoes(delay=0.52, feedback=0.4, wet=0.6)
    return song


# ---------------------------------------------------------------- 校门 · 对峙
def build_school():
    song = Song(bpm=102, bars=8)
    lead = [
        "D5 . D5 .  F5 . D5 .  C5 . . .  A4 . . .",
        "D5 . F5 .  G5 . F5 .  E5 . D5 .  C5 . . .",
        "A4 . C5 .  D5 . F5 .  G5 . A5 .  G5 . F5 .",
        "E5 . D5 .  C5 . A4 .  D5 . . .  . . . .",
    ]
    for bar, text in enumerate(lead):
        song.pattern(text, bar * 8, amp=0.15, length=0.7, voice="square", duty=0.5)
        song.pattern(text, bar * 8, amp=0.05, length=0.7, voice="saw", detune=0.994, pan=0.45)
    low = ["D4 . . . D4 . . .", "D4 . . . D4 . . .",
           "C4 . . . C4 . . .", "A3 . . . A3 . . ."] * 2
    for bar, text in enumerate(low):
        song.pattern(text, bar * 8, amp=0.11, length=2.4, voice="pulse", attack=0.02)
    bass = ["D2 D2 . D2 D2 . D2 .", "D2 D2 . D2 D2 . A2 .",
            "C3 C3 . C3 C3 . C3 .", "A2 A2 . A2 A2 . A2 ."] * 2
    for bar, text in enumerate(bass):
        song.pattern(text, bar * 8, amp=0.19, length=0.42, voice="tri")
    for bar in range(8):
        base = bar * 8
        song.note(song.at(base), 0.14, "D2", amp=0.24, voice="sine")
        song.note(song.at(base + 4), 0.12, "A1", amp=0.2, voice="sine")
        song.noise(song.at(base + 2), 0.11, amp=0.11, tone=210.0, decay_pow=2.6, seed=bar + 100)
        song.noise(song.at(base + 6), 0.11, amp=0.1, tone=210.0, decay_pow=2.6, seed=bar + 110)
        for k in range(8):
            song.noise(song.at(base + k), 0.03, amp=0.022, tone=7400.0, decay_pow=4.0, seed=bar * 8 + k)
    song.echoes(delay=0.32, feedback=0.3, wet=0.42)
    return song


# ---------------------------------------------------------------- 战斗 · 洋芋粑之力
def build_battle():
    song = Song(bpm=158, bars=8)
    lead = [
        "D5 D5 F5 D5  G5 F5 D5 C5  D5 D5 F5 G5  A5 . G5 .",
        "A5 G5 F5 D5  C5 D5 F5 .  D5 C5 A4 C5  D5 . . .",
        "F5 F5 A5 F5  G5 A5 C6 A5  G5 F5 D5 F5  G5 . A5 .",
        "A5 . G5 F5  D5 . C5 .  D5 C5 A4 .  D5 . . .",
    ]
    for bar, text in enumerate(lead):
        song.pattern(text, bar * 8, amp=0.17, length=0.85, voice="square", duty=0.35, vibrato=0.005)
        song.pattern(text, bar * 8, amp=0.055, length=0.85, voice="pulse", detune=1.006, pan=-0.48)
        song.pattern(text, bar * 8, amp=0.05, length=0.85, voice="saw", detune=0.994, pan=0.48)
    bass = ["D3 D3 D3 D3 A2 A2 D3 D3"] * 2 + ["C3 C3 C3 C3 G2 G2 C3 C3"] * 2
    for bar in range(8):
        text = bass[bar % len(bass)]
        song.pattern(text, bar * 8, amp=0.2, length=0.3, voice="pulse", attack=0.002)
    for bar in range(8):
        base = bar * 8
        for k in range(8):
            song.noise(song.at(base + k), 0.026, amp=0.026, tone=7600.0, decay_pow=4.2, seed=bar * 8 + k + 3)
        for k in (0, 3, 4, 7):
            song.note(song.at(base + k), 0.13, "D2", amp=0.3, voice="sine")
        for k in (2, 6):
            song.noise(song.at(base + k), 0.13, amp=0.13, tone=230.0, decay_pow=2.4, seed=bar * 8 + k + 200)
    song.pattern("D4 . . . D4 . . .", 0, amp=0.09, length=0.3, voice="square", duty=0.125)
    song.echoes(delay=0.24, feedback=0.24, wet=0.32)
    return song


# ---------------------------------------------------------------- 教室 · 升学
def build_classroom():
    song = Song(bpm=86, bars=8, step=0.5)
    lead = [
        "D5 . E5 .  F#5 . A5 .  B5 . A5 .  F#5 . E5 .",
        "D5 . . .  A4 . B4 .  D5 . . .  . . . .",
        "E5 . F#5 .  A5 . B5 .  A5 . F#5 .  E5 . D5 .",
        "B4 . D5 .  E5 . D5 .  A4 . . .  . . . .",
    ]
    for bar, text in enumerate(lead):
        song.pattern(text, bar * 8, amp=0.14, length=1.7, voice="tri", attack=0.02,
                     decay=0.28, sustain=0.55, release=0.4)
        song.pattern(text, bar * 8, amp=0.04, length=1.7, voice="square", duty=0.25, pan=-0.42)
    bass = ["D3 . . . . . . .", "B2 . . . . . . .",
            "G2 . . . . . . .", "A2 . . . . . . ."] * 2
    for bar, text in enumerate(bass):
        song.pattern(text, bar * 8, amp=0.14, length=7.2, voice="sine",
                     attack=0.05, decay=0.4, sustain=0.5, release=0.7)
    for bar in range(8):
        song.noise(song.at(bar * 8 + 4), 0.05, amp=0.018, tone=5600.0, decay_pow=3.8, seed=bar + 41)
    song.echoes(delay=0.46, feedback=0.36, wet=0.52)
    return song


BUILDERS = {
    "market": build_market,
    "cooking": build_cooking,
    "night": build_night,
    "school": build_school,
    "battle": build_battle,
    "classroom": build_classroom,
}


def main(argv):
    os.makedirs(OUT_DIR, exist_ok=True)
    wanted = argv[1:] or list(BUILDERS)
    for name in wanted:
        if name not in BUILDERS:
            print("unknown track: %s" % name)
            continue
        song = BUILDERS[name]()
        song.master()
        path = os.path.join(OUT_DIR, "%s.ogg" % name)
        song.write(path)
        seconds = song.length / SR
        print("%-10s %5.1f s  %6.1f KB  %s" % (
            name, seconds, os.path.getsize(path) / 1024.0, path))


if __name__ == "__main__":
    main(sys.argv)
