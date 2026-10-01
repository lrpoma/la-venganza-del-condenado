#!/usr/bin/env python3
"""Genera el proyecto de Kdenlive del tráiler de 1 minuto a partir de trailer/clips y trailer/audio.

    python3 tools/make_trailer_project.py
    -> trailer/trailer_1min.kdenlive   (proyecto editable en Kdenlive)
    -> trailer/_render.mlt             (el mismo montaje para renderizar con melt)

Cambia SEGMENTOS / TITULOS / MUSICA / SFX y vuelve a ejecutarlo para regenerar el montaje.
Tiempos en segundos. Vídeo: 1920x1080 a 30 fps.
"""
import os
import subprocess
import uuid
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "trailer"))
CLIPS = os.path.join(ROOT, "clips")
AUDIO = os.path.join(ROOT, "audio")
FPS = 30
W, H = 1920, 1080

# (clip, inicio_en_origen, duración)  -> pista de vídeo V1, uno tras otro
SEGMENTOS = [
    ("01_noche", 0.0, 7.0),
    ("03b_ojos", 0.0, 4.0),
    ("02_cinematica", 10.2, 2.6),
    ("04_perro", 1.0, 3.4),
    ("05_remolino", 0.5, 3.0),
    ("03_despertar", 0.0, 3.0),
    ("07_sal_remolino", 0.5, 3.0),
    ("06_sal_humano", 1.0, 2.0),
    ("08_abismo", 0.6, 3.0),
    ("16_gameover", 0.0, 1.2),
    ("10_perro_guardian", 0.2, 3.0),
    ("11_traidor", 1.5, 4.0),
    ("13a_jefe_escudo", 3.0, 6.0),
    ("13b_jefe_combate", 2.0, 4.0),
    ("14_amanecer", 2.0, 6.0),
    ("NEGRO", 0.0, 4.8),   # fondo negro para la tarjeta final
]

# (texto, inicio_seg_en_montaje, duración, tamaño_px, color RGB[, pista_rótulos 1|2])
BLANCO, NARANJA = (255, 255, 255), (255, 170, 60)
TITULOS = [
    ("Pucarani, La Paz.", 0.8, 2.8, 64, BLANCO),
    ("Lo mataron por su oro.", 4.0, 2.8, 64, BLANCO),
    ("Pero el rencor no muere.", 7.4, 3.0, 64, BLANCO),
    ("PERRO", 13.8, 2.6, 96, NARANJA),
    ("REMOLINO", 17.2, 2.6, 96, NARANJA),
    ("HUMANO", 20.2, 2.6, 96, NARANJA),
    ("Sal. Incienso. Abismos.", 23.4, 3.6, 64, BLANCO),
    ("Un solo hombre se preparó.", 41.6, 3.4, 64, BLANCO),
    ("LA VENGANZA DEL CONDENADO", 55.4, 4.6, 88, NARANJA),
    ("PC · Windows / Linux   ·   Limbert Poma   ·   UMSA · INF-266", 56.6, 3.4, 40, BLANCO, 2),  # 2 = segunda pista de rótulos
]

# (archivo, inicio_en_montaje, in_origen, duración, ganancia lineal, fade_in, fade_out)
MUSICA = [
    ("music_ambient", 0.0, 0.0, 13.6, 0.35, 2.0, 0.6),
    ("music_tense", 13.6, 0.0, 30.0, 0.45, 0.2, 0.0),
    ("music_tense", 43.6, 4.0, 5.6, 0.5, 0.0, 1.2),
    ("music_ambient", 49.2, 6.0, 5.0, 0.3, 1.0, 0.8),
    ("music_victory", 54.2, 0.0, 5.8, 0.5, 0.3, 1.5),
]
SFX = [
    ("sfx_transform", 13.7, 0.5, 0.5),
    ("sfx_transform", 17.1, 0.5, 0.5),
    ("sfx_transform", 20.1, 0.5, 0.5),
    ("sfx_bark", 15.2, 0.4, 0.6),
    ("sfx_wind", 17.6, 1.2, 0.5),
    ("sfx_sizzle", 25.6, 0.55, 0.7),
    ("sfx_death", 31.0, 1.3, 0.7),
    ("sfx_bark", 33.0, 0.4, 0.6),
    ("sfx_shield", 41.4, 0.6, 0.7),
    ("sfx_incense", 43.6, 0.5, 0.7),
    ("sfx_incense", 46.2, 0.5, 0.7),
]


def probe_frames(path):
    out = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_packets",
                                   "-show_entries", "stream=nb_read_packets", "-of", "csv=p=0", path]).decode().strip()
    return int(out)


def probe_dur(path):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", path]).decode().strip())


def fr(sec):
    return round(sec * FPS)


_next_id = [3]


def new_id():
    _next_id[0] += 1
    return _next_id[0]


def prop(parent, name, value=""):
    p = ET.SubElement(parent, "property", name=name)
    p.text = str(value)
    return p


def build(render_only=False):
    doc_uuid = "{%s}" % uuid.uuid4()
    seq_uuid = doc_uuid
    total = sum(fr(d) for _, _, d in SEGMENTOS)
    mlt = ET.Element("mlt", {"LC_NUMERIC": "C", "producer": "tractor_project" if render_only else "main_bin",
                             "root": ROOT, "version": "7.40.0"})
    ET.SubElement(mlt, "profile", description="HD 1080p 30 fps", width=str(W), height=str(H), progressive="1",
                  sample_aspect_num="1", sample_aspect_den="1", display_aspect_num="16", display_aspect_den="9",
                  frame_rate_num=str(FPS), frame_rate_den="1", colorspace="709")

    # ---- producers (bin)
    bin_entries = []
    chains = {}

    def add_chain(path, kind):
        if path in chains:
            return chains[path]
        cid = "chain%d" % len(chains)
        kid = new_id()
        if kind == "video":
            n = probe_frames(path)
        else:
            n = fr(probe_dur(path))
        ch = ET.SubElement(mlt, "chain", id=cid, out=str(n - 1))
        prop(ch, "length", n)
        prop(ch, "eof", "pause")
        prop(ch, "resource", path)
        prop(ch, "mlt_service", "avformat-novalidate")
        prop(ch, "seekable", 1)
        prop(ch, "aspect_ratio", 1)
        prop(ch, "audio_index", -1 if kind == "video" else 0)
        prop(ch, "video_index", 0 if kind == "video" else -1)
        prop(ch, "mute_on_pause", 0)
        prop(ch, "kdenlive:clipname", os.path.basename(path))
        prop(ch, "kdenlive:folderid", -1)
        prop(ch, "kdenlive:id", kid)
        prop(ch, "kdenlive:control_uuid", "{%s}" % uuid.uuid4())
        prop(ch, "kdenlive:clip_type", 2 if kind == "video" else 1)
        prop(ch, "xml", "was here")
        chains[path] = (cid, n)
        bin_entries.append((cid, n))
        return chains[path]

    # ---- títulos
    title_ids = []
    for i, tt in enumerate(TITULOS):
        text, start, dur, size, color = tt[:5]
        lane = tt[5] if len(tt) > 5 else 1
        n = fr(dur)
        approx_w = len(text) * size * 0.55
        x = max(20, (W - approx_w) / 2)
        y = 800 if size < 80 else 430   # rótulo abajo; palabras grandes al centro
        if size == 40:
            y = 600
        xml = ET.Element("kdenlivetitle", {"LC_NUMERIC": "C", "width": str(W), "height": str(H), "out": str(n - 1)})
        item = ET.SubElement(xml, "item", {"type": "QGraphicsTextItem", "z-index": "0"})
        pos = ET.SubElement(item, "position", x=str(int(x)), y=str(int(y)))
        ET.SubElement(pos, "transform").text = "1,0,0,0,1,0,0,0,1"
        content = ET.SubElement(item, "content", {
            "font": "Liberation Sans", "font-pixel-size": str(size), "font-italic": "0", "font-underline": "0",
            "letter-spacing": "0", "font-outline": "3", "font-outline-color": "0,0,0,255", "font-weight": "75",
            "font-color": "%d,%d,%d,255" % color, "alignment": "4", "line-spacing": "0"})
        content.text = text
        ET.SubElement(xml, "startviewport", rect="0,0,%d,%d" % (W, H))
        ET.SubElement(xml, "endviewport", rect="0,0,%d,%d" % (W, H))
        ET.SubElement(xml, "background", color="0,0,0,0")
        pid = "title%d" % i
        kid = new_id()
        pr = ET.SubElement(mlt, "producer", id=pid, **{"in": "0", "out": str(n - 1)})
        prop(pr, "length", n)
        prop(pr, "eof", "pause")
        prop(pr, "resource", "")
        prop(pr, "meta.media.progressive", 1)
        prop(pr, "aspect_ratio", 1)
        prop(pr, "seekable", 1)
        prop(pr, "mlt_service", "kdenlivetitle")
        prop(pr, "kdenlive:clipname", "Título: " + text)
        prop(pr, "xmldata", ET.tostring(xml, encoding="unicode"))
        prop(pr, "kdenlive:folderid", -1)
        prop(pr, "kdenlive:id", kid)
        prop(pr, "kdenlive:clip_type", 2)
        prop(pr, "kdenlive:duration", n)
        prop(pr, "force_reload", 0)
        title_ids.append((pid, fr(start), n, lane))
        bin_entries.append((pid, n))

    black = ET.SubElement(mlt, "producer", id="producer_black", **{"in": "0", "out": str(total - 1)})
    prop(black, "length", total)
    prop(black, "eof", "pause")
    prop(black, "resource", "black")
    prop(black, "aspect_ratio", 1)
    prop(black, "mlt_service", "color")
    prop(black, "kdenlive:playlistid", "black_track")
    prop(black, "mlt_image_format", "rgba")
    prop(black, "set.test_audio", 0)

    # ---- pistas (cada pista = tractor con dos playlists, como hace Kdenlive)
    def make_track(tid, name, audio, entries, filters):
        pl_a = ET.SubElement(mlt, "playlist", id="playlist_%s" % tid)
        if audio:
            prop(pl_a, "kdenlive:audio_track", 1)
        pos = 0
        for (cid, start, in_f, n_f, gain, fin, fout) in sorted(entries, key=lambda e: e[1]):
            if start > pos:
                ET.SubElement(pl_a, "blank", length=str(start - pos))
            ent = ET.SubElement(pl_a, "entry", producer=cid, **{"in": str(in_f), "out": str(in_f + n_f - 1)})
            if audio and (gain != 1.0 or fin or fout):
                f = ET.SubElement(ent, "filter", **{"in": str(in_f), "out": str(in_f + n_f - 1)})
                prop(f, "window", 75)
                prop(f, "max_gain", "20dB")
                prop(f, "mlt_service", "volume")
                prop(f, "kdenlive_id", "volume")
                prop(f, "gain", gain)
                prop(f, "disable", 0)
                if fin:
                    f2 = ET.SubElement(ent, "filter", **{"in": str(in_f), "out": str(in_f + fr(fin) - 1)})
                    prop(f2, "mlt_service", "volume")
                    prop(f2, "kdenlive_id", "fadein")
                    prop(f2, "gain", 0)
                    prop(f2, "end", 1)
                    prop(f2, "alpha", "1")
                if fout:
                    f3 = ET.SubElement(ent, "filter", **{"in": str(in_f + n_f - fr(fout)), "out": str(in_f + n_f - 1)})
                    prop(f3, "mlt_service", "volume")
                    prop(f3, "kdenlive_id", "fadeout")
                    prop(f3, "gain", 1)
                    prop(f3, "end", 0)
                    prop(f3, "alpha", "1")
            elif not audio and (fin or fout):
                ent_len = n_f
                if fin:
                    f2 = ET.SubElement(ent, "filter", **{"in": str(in_f), "out": str(in_f + fr(fin) - 1)})
                    prop(f2, "mlt_service", "brightness")
                    prop(f2, "kdenlive_id", "fade_from_black")
                    prop(f2, "start", 0)
                    prop(f2, "end", 1)
                    prop(f2, "alpha", "1")
                if fout:
                    f3 = ET.SubElement(ent, "filter", **{"in": str(in_f + ent_len - fr(fout)), "out": str(in_f + ent_len - 1)})
                    prop(f3, "mlt_service", "brightness")
                    prop(f3, "kdenlive_id", "fade_to_black")
                    prop(f3, "start", 1)
                    prop(f3, "end", 0)
                    prop(f3, "alpha", "1")
            pos = start + n_f
        pl_b = ET.SubElement(mlt, "playlist", id="playlist_%sb" % tid)
        if audio:
            prop(pl_b, "kdenlive:audio_track", 1)
        tr = ET.SubElement(mlt, "tractor", id="tractor_%s" % tid, **{"in": "0", "out": str(total - 1)})
        if audio:
            prop(tr, "kdenlive:audio_track", 1)
        prop(tr, "kdenlive:trackheight", 67)
        prop(tr, "kdenlive:timeline_active", 1)
        prop(tr, "kdenlive:collapsed", 0)
        prop(tr, "kdenlive:track_name", name)
        hide = "video" if audio else "audio"
        ET.SubElement(tr, "track", hide=hide, producer="playlist_%s" % tid)
        ET.SubElement(tr, "track", hide=hide, producer="playlist_%sb" % tid)
        if audio:
            fv = ET.SubElement(tr, "filter", id="filter_vol_%s" % tid)
            prop(fv, "window", 75)
            prop(fv, "max_gain", "20dB")
            prop(fv, "channel_mask", "-1")
            prop(fv, "mlt_service", "volume")
            prop(fv, "internal_added", 237)
            prop(fv, "disable", 0)
            fp = ET.SubElement(tr, "filter", id="filter_pan_%s" % tid)
            prop(fp, "channel", -1)
            prop(fp, "mlt_service", "panner")
            prop(fp, "internal_added", 237)
            prop(fp, "start", 0.5)
            prop(fp, "disable", 0)
        return "tractor_%s" % tid

    # clip de color negro para la tarjeta final
    blk = ET.SubElement(mlt, "producer", id="color_negro", **{"in": "0", "out": "899"})
    prop(blk, "length", 900)
    prop(blk, "eof", "pause")
    prop(blk, "resource", "0x000000ff")
    prop(blk, "aspect_ratio", 1)
    prop(blk, "mlt_service", "color")
    prop(blk, "mlt_image_format", "rgba")
    prop(blk, "kdenlive:clipname", "Negro")
    prop(blk, "kdenlive:folderid", -1)
    prop(blk, "kdenlive:id", new_id())
    prop(blk, "kdenlive:clip_type", 4)
    prop(blk, "kdenlive:duration", 900)
    bin_entries.append(("color_negro", 900))
    # V1
    v1 = []
    pos = 0
    for i, (name, ss, dur) in enumerate(SEGMENTOS):
        if name == "NEGRO":
            cid = "color_negro"
        else:
            cid, n = add_chain(os.path.join(CLIPS, name + ".mp4"), "video")
        n_f = fr(dur)
        v1.append((cid, pos, fr(ss), n_f, 1.0, 1.0 if i == 0 else 0, 0))
        pos += n_f
    # V2 (rótulos)
    v2 = [(pid, start, 0, n, 1.0, 0, 0) for pid, start, n, lane in title_ids if lane == 1]
    v3 = [(pid, start, 0, n, 1.0, 0, 0) for pid, start, n, lane in title_ids if lane == 2]
    # A1 música / A2 sfx
    a1, a2 = [], []
    for f, start, in_s, dur, gain, fin, fout in MUSICA:
        cid, n = add_chain(os.path.join(AUDIO, f + ".ogg"), "audio")
        a1.append((cid, fr(start), fr(in_s), fr(dur), gain, fin, fout))
    for f, start, dur, gain in SFX:
        cid, n = add_chain(os.path.join(AUDIO, f + ".ogg"), "audio")
        a2.append((cid, fr(start), 0, min(fr(dur), n), gain, 0, 0))

    t_a2 = make_track("a2", "Efectos", True, a2, [])
    t_a1 = make_track("a1", "Música", True, a1, [])
    t_v1 = make_track("v1", "Vídeo", False, v1, [])
    t_v2 = make_track("v2", "Rótulos", False, v2, [])
    t_v3 = make_track("v3", "Rótulos 2", False, v3, [])

    # ---- secuencia (línea de tiempo)
    seq = ET.SubElement(mlt, "tractor", id=seq_uuid if not render_only else "tractor_project",
                        **{"in": "0", "out": str(total - 1)})
    prop(seq, "kdenlive:uuid", seq_uuid)
    prop(seq, "kdenlive:clipname", "Tráiler 1 minuto")
    prop(seq, "kdenlive:duration", total)
    prop(seq, "kdenlive:maxduration", total)
    prop(seq, "kdenlive:producer_type", 17)
    prop(seq, "kdenlive:control_uuid", seq_uuid)
    prop(seq, "kdenlive:id", 3)
    prop(seq, "kdenlive:folderid", 2)
    prop(seq, "kdenlive:sequenceproperties.hasAudio", 1)
    prop(seq, "kdenlive:sequenceproperties.hasVideo", 1)
    prop(seq, "kdenlive:sequenceproperties.activeTrack", 3)
    prop(seq, "kdenlive:sequenceproperties.tracksCount", 5)
    prop(seq, "kdenlive:sequenceproperties.documentuuid", doc_uuid)
    prop(seq, "kdenlive:sequenceproperties.position", 0)
    prop(seq, "kdenlive:sequenceproperties.scrollPos", 0)
    prop(seq, "kdenlive:sequenceproperties.verticalzoom", 1)
    prop(seq, "kdenlive:sequenceproperties.zonein", 0)
    prop(seq, "kdenlive:sequenceproperties.zoneout", 75)
    prop(seq, "kdenlive:sequenceproperties.zoom", 8)
    ET.SubElement(seq, "track", producer="producer_black")
    for t in (t_a2, t_a1, t_v1, t_v2, t_v3):
        ET.SubElement(seq, "track", producer=t)
    # mezcla de audio y composición de vídeo (transiciones internas de Kdenlive)
    for bt in (1, 2):
        tr = ET.SubElement(seq, "transition", id="transition_mix_%d" % bt)
        prop(tr, "a_track", 0)
        prop(tr, "b_track", bt)
        prop(tr, "mlt_service", "mix")
        prop(tr, "kdenlive_id", "mix")
        prop(tr, "internal_added", 237)
        prop(tr, "always_active", 1)
        prop(tr, "accepts_blanks", 1)
        prop(tr, "sum", 1)
    for bt in (3, 4, 5):
        tr = ET.SubElement(seq, "transition", id="transition_blend_%d" % bt)
        prop(tr, "a_track", 0)
        prop(tr, "b_track", bt)
        prop(tr, "mlt_service", "qtblend")
        prop(tr, "kdenlive_id", "qtblend")
        prop(tr, "internal_added", 237)
        prop(tr, "always_active", 1)
        prop(tr, "compositing", 0)
        prop(tr, "distort", 0)
        prop(tr, "rotate_center", 0)

    if render_only:
        return ET.ElementTree(mlt)

    # ---- bin principal
    mb = ET.SubElement(mlt, "playlist", id="main_bin")
    prop(mb, "kdenlive:folder.-1.2", "Sequences")
    prop(mb, "kdenlive:sequenceFolder", 2)
    prop(mb, "kdenlive:docproperties.version", "1.1")
    prop(mb, "kdenlive:docproperties.kdenliveversion", "26.08.0")
    prop(mb, "kdenlive:docproperties.uuid", doc_uuid)
    prop(mb, "kdenlive:docproperties.activetimeline", seq_uuid)
    prop(mb, "kdenlive:docproperties.opensequences", seq_uuid)
    prop(mb, "kdenlive:docproperties.documentid", str(int(uuid.uuid4().int % 10**13)))
    prop(mb, "kdenlive:docproperties.profile", "atsc_1080p_30")
    prop(mb, "kdenlive:docproperties.enableTimelineZone", 0)
    prop(mb, "kdenlive:docproperties.enableexternalproxy", 0)
    prop(mb, "kdenlive:docproperties.enableproxy", 0)
    prop(mb, "kdenlive:docproperties.audioChannels", 2)
    prop(mb, "kdenlive:docproperties.seekOffset", 0)
    prop(mb, "kdenlive:docproperties.timelinezoom", 8)
    prop(mb, "kdenlive:docproperties.uuid", doc_uuid)
    prop(mb, "xml_retain", 1)
    ET.SubElement(mb, "entry", producer=seq_uuid, **{"in": "0", "out": str(total - 1)})
    for cid, n in bin_entries:
        ET.SubElement(mb, "entry", producer=cid, **{"in": "0", "out": str(n - 1)})

    # tractor final que envuelve la secuencia activa
    tp = ET.SubElement(mlt, "tractor", id="tractor_final", **{"in": "0", "out": str(total - 1)})
    prop(tp, "kdenlive:projectTractor", 1)
    ET.SubElement(tp, "track", producer=seq_uuid, **{"in": "0", "out": str(total - 1)})
    return ET.ElementTree(mlt)


def write(tree, path):
    ET.indent(tree, space=" ")
    tree.write(path, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    write(build(False), os.path.join(ROOT, "trailer_1min.kdenlive"))
    write(build(True), os.path.join(ROOT, "_render.mlt"))
    total = sum(fr(d) for _, _, d in SEGMENTOS)
    print("Proyecto generado: %.1f s (%d fotogramas)" % (total / FPS, total))
