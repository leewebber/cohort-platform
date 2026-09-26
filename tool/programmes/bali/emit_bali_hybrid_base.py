#!/usr/bin/env python3
"""Emit canonical Bali Hybrid Base Plan Package + founder session YAML.

Source authority is the founder DOCX. This script only encodes that
prescription; it does not invent loads, zones, or HYROX/running work.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PACKAGE_PATH = ROOT / "tool/programmes/bali_hybrid_base_v1.plan-package.yaml"
FOUNDER_PATH = ROOT / "tool/programmes/bali_hybrid_base_v1.founder.yaml"
MANIFEST_PATH = ROOT / "content/programmes/bali_hybrid_base/v1/source_manifest.json"

LINEAGE = "BALI-HYBRID-BASE"
VERSION = 1


def _scalar(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        return str(value)
    text = str(value)
    return json.dumps(text, ensure_ascii=False)


def _dump(value, indent, lines, list_item=False):
    pad = "  " * indent
    if isinstance(value, dict):
        items = [(k, v) for k, v in value.items() if v is not None]
        if not items:
            lines.append(f"{pad}- {{}}" if list_item else f"{pad}{{}}")
            return
        for index, (key, child) in enumerate(items):
            if list_item and index == 0:
                prefix = f"{pad}- "
                nested_indent = indent + 1
            elif list_item:
                prefix = "  " * (indent + 1)
                nested_indent = indent + 2
            else:
                prefix = pad
                nested_indent = indent + 1
            if isinstance(child, dict):
                nested_items = [(k, v) for k, v in child.items() if v is not None]
                if not nested_items:
                    lines.append(f"{prefix}{key}: {{}}")
                else:
                    lines.append(f"{prefix}{key}:")
                    _dump(child, nested_indent, lines)
            elif isinstance(child, list):
                if not child:
                    lines.append(f"{prefix}{key}: []")
                else:
                    lines.append(f"{prefix}{key}:")
                    _dump(child, nested_indent, lines)
            else:
                lines.append(f"{prefix}{key}: {_scalar(child)}")
        return
    if isinstance(value, list):
        if not value:
            lines.append(f"{pad}[]")
            return
        for child in value:
            if isinstance(child, dict):
                _dump(child, indent, lines, list_item=True)
            elif isinstance(child, list):
                lines.append(f"{pad}-")
                _dump(child, indent + 1, lines)
            else:
                lines.append(f"{pad}- {_scalar(child)}")
        return
    lines.append(f"{pad}{_scalar(value)}")


def dump_yaml(data):
    lines = []
    _dump(data, 0, lines)
    return "\n".join(lines) + "\n"


def lineage_id(week, day, slot):
    return f"b1{week:02d}{day:02d}{slot:02d}-0000-4000-8000-{week:02d}{day:02d}{slot:02d}000000"


def ids(week, day, slot):
    return {
        "session_key": f"SES-BALI-W{week:02d}-D{day:02d}-S{slot:02d}",
        "protocol_id": f"BALI-W{week:02d}-D{day:02d}-S{slot:02d}-R1",
        "session_lineage_id": lineage_id(week, day, slot),
        "slot_key": f"BALI-W{week:02d}-D{day:02d}-S{slot:02d}",
    }


def mv(name, order, sets=None, reps=None, rest=None, notes=None, duration=None, distance=None, load=None, extra=None):
    prescription = {}
    if sets is not None:
        prescription["sets"] = sets
    if reps is not None:
        prescription["reps"] = reps
    if duration is not None:
        prescription["duration"] = duration
    if distance is not None:
        prescription["distance"] = distance
    if rest is not None:
        prescription["rest_seconds"] = rest
    if load is not None:
        prescription["load"] = load
    if extra:
        prescription.update(extra)
    return {
        "exercise_name": name,
        "exercise_slug": name.lower().replace(" ", "-").replace("/", "-"),
        "order": order,
        "prescription": prescription or None,
        "notes": notes,
    }


def blk(title, block_type, order, exercises, notes=None):
    numbered = []
    for i, ex in enumerate(exercises, start=1):
        item = dict(ex)
        item["order"] = i
        numbered.append(item)
    return {
        "title": title,
        "block_type": block_type,
        "order": order,
        "coach_notes": notes,
        "exercises": numbered,
    }


def rpe(text):
    return {"type": "freeText", "text": text}


# --- session bodies ---------------------------------------------------------

def strength_a_warmup():
    return blk(
        "Warm-up",
        "warm_up",
        1,
        [
            mv("Easy BikeErg", 1, sets=1, duration="5 min"),
            mv("Bodyweight squat", 2, sets=2, reps=8),
            mv("Reverse lunge", 3, sets=2, reps="8/side"),
            mv("Glute bridge", 4, sets=2, reps=10),
            mv("Cossack squat", 5, sets=2, reps="8 alternating"),
            mv("Band pull-apart", 6, sets=2, reps=10),
            mv("Scapular pull-up", 7, sets=2, reps=8),
            mv("Calf raise", 8, sets=2, reps=10),
            mv("Front squat warm-up sets", 9, sets=1, notes="Progressive warm-up sets. Do not turn the warm-up into conditioning."),
        ],
        notes="12–15 min. 5 min easy BikeErg, then 2 rounds of the listed movements.",
    )


def cooldown_easy_bike(minutes="5"):
    return blk(
        "Cooldown",
        "cool_down",
        99,
        [mv("Very easy BikeErg", 1, sets=1, duration=f"{minutes} min")],
        notes="Do not add conditioning.",
    )


def strength_a(week):
    notes = {
        1: "Leave feeling that this was a good strength session and you could have done more. Record load/reps/RPE every working set. Athlete-selected loads.",
        2: "If Week 1 was genuinely ≤RPE 7 and clean, increase front squat ~2.5–5 kg; otherwise repeat load and improve reps. No conditioning finisher.",
        3: "Hardest Strength A of Block I. No missed or grinding reps.",
        4: "Deload. Working volume down ~40–50%. No farmer carries.",
        5: "Block II: strength intensity rises while volume stays controlled. No grinders.",
        6: "Keep intensity high while accessory volume begins shrinking. +2.5–5 kg on front squat only if Week 5 was crisp.",
        7: "Heavy, lower volume. Leave strong rather than battered.",
        8: "Strength primer. Fast reps. You should wonder whether you did enough.",
    }[week]
    if week == 1:
        main = [
            mv("Front squat", 1, sets=4, reps=5, rest="180-240", load=rpe("RPE 7"), notes="Full controlled depth, strong brace, fast concentric intent, no grinders. Final set ~3 RIR."),
            mv("Romanian deadlift", 2, sets=3, reps=6, rest="150-180", load=rpe("RPE 7"), notes="Slow controlled eccentric, strong hip extension. Do not chase DOMS."),
            mv("Weighted pull-up", 3, sets=4, reps=5, rest="150-180", load=rpe("RPE 7"), notes="Dead hang → chest high → controlled descent. Clean reps. Record load."),
            mv("Rear-foot-elevated split squat", 4, sets=3, reps="8/leg", load=rpe("RPE 7"), notes="DBs at sides. Controlled eccentric. Also serves future running-preparation work."),
            mv("Chest-supported row", 5, sets=3, reps="8-10", load=rpe("RPE 7-8"), notes="Full scapular movement."),
            mv("Ab wheel", 6, sets=3, reps="8-12", notes="Stop before lumbar extension substitutes for abdominal control."),
            mv("Farmer carry", 7, sets=3, distance="40 m", notes="Heavy. Challenge grip/posture without compromising walking mechanics."),
        ]
    elif week == 2:
        main = [
            mv("Front squat", 1, sets=4, reps=5, rest="180-240", load=rpe("RPE 7-7.5"), notes="If Week 1 ≤RPE 7 and clean, +2.5–5 kg; otherwise repeat load."),
            mv("Romanian deadlift", 2, sets=3, reps=6, rest="150-180", load=rpe("RPE 7-7.5"), notes="Modest load increase only if justified."),
            mv("Weighted pull-up", 3, sets=4, reps=5, rest="150-180", load=rpe("RPE 7-8"), notes="Add ~1.25–2.5 kg if all Week 1 reps were strict."),
            mv("Rear-foot-elevated split squat", 4, sets=3, reps="8/leg", load=rpe("RPE 7-8")),
            mv("Chest-supported row", 5, sets=3, reps="8-10", load=rpe("RPE 8"), notes="If 10/10/10 cleanly, increase load."),
            mv("Ab wheel", 6, sets=3, reps="10-12"),
            mv("Farmer carry", 7, sets=3, distance="40 m", notes="Progress load rather than distance."),
        ]
    elif week == 3:
        main = [
            mv("Front squat", 1, sets=5, reps=4, rest="180-240", load=rpe("RPE 7.5-8"), notes="Heavier strength, no grinders."),
            mv("Romanian deadlift", 2, sets=4, reps=6, rest="150-180", load=rpe("RPE 7-8"), notes="Add a set rather than chasing large load."),
            mv("Weighted pull-up", 3, sets=5, reps=4, rest="150-180", load=rpe("RPE 7.5-8")),
            mv("Rear-foot-elevated split squat", 4, sets=3, reps="8/leg", load=rpe("RPE 8")),
            mv("Chest-supported row", 5, sets=3, reps=8, load=rpe("RPE 8"), notes="Heavy."),
            mv("Ab wheel", 6, sets=3, reps="10-12"),
            mv("Farmer carry", 7, sets=4, distance="40 m", notes="Heavy."),
        ]
    elif week == 4:
        main = [
            mv("Front squat", 1, sets=3, reps=4, load=rpe("RPE 6-7"), notes="Use ~80–90% of Week 3 5×4 load depending on feel."),
            mv("Romanian deadlift", 2, sets=2, reps=6, load=rpe("RPE 6-7")),
            mv("Weighted pull-up", 3, sets=3, reps=4, load=rpe("RPE 6-7")),
            mv("Rear-foot-elevated split squat", 4, sets=2, reps="6/leg", load=rpe("RPE 6")),
            mv("Chest-supported row", 5, sets=2, reps=8),
            mv("Ab wheel", 6, sets=2, reps=10),
        ]
    elif week == 5:
        main = [
            mv("Front squat", 1, sets=5, reps=3, rest="180-240", load=rpe("RPE 8"), notes="Heavier high-force work. No grinders."),
            mv("Romanian deadlift", 2, sets=4, reps=5, load=rpe("RPE 7.5-8")),
            mv("Weighted pull-up", 3, sets=5, reps=3, load=rpe("RPE 8")),
            mv("Rear-foot-elevated split squat", 4, sets=3, reps="6/leg", load=rpe("RPE 8")),
            mv("Chest-supported row", 5, sets=3, reps=8, load=rpe("RPE 8")),
            mv("Ab wheel", 6, sets=3, reps="10-12"),
            mv("Farmer carry", 7, sets=4, distance="40 m", notes="Heavy."),
        ]
    elif week == 6:
        main = [
            mv("Front squat", 1, sets=5, reps=3, rest="180-240", load=rpe("RPE 8"), notes="+2.5–5 kg only if Week 5 was crisp."),
            mv("Romanian deadlift", 2, sets=3, reps=5, load=rpe("RPE 8"), notes="One set removed versus Week 5."),
            mv("Weighted pull-up", 3, sets=5, reps=3, load=rpe("RPE 8")),
            mv("Rear-foot-elevated split squat", 4, sets=3, reps="6/leg", load=rpe("RPE 7.5-8")),
            mv("Chest-supported row", 5, sets=3, reps=8, load=rpe("RPE 8")),
            mv("Ab wheel", 6, sets=3, reps="10-12"),
            mv("Farmer carry", 7, sets=3, distance="40 m", notes="Heavy."),
        ]
    elif week == 7:
        main = [
            mv("Front squat", 1, sets=4, reps=3, rest="180-240", load=rpe("RPE 8"), notes="One fewer set than Week 6."),
            mv("Romanian deadlift", 2, sets=3, reps=5, load=rpe("RPE 7.5-8")),
            mv("Weighted pull-up", 3, sets=4, reps=3, load=rpe("RPE 8")),
            mv("Rear-foot-elevated split squat", 4, sets=2, reps="6/leg", load=rpe("RPE 7.5")),
            mv("Chest-supported row", 5, sets=3, reps=8),
            mv("Ab wheel", 6, sets=3, reps=10),
            mv("Farmer carry", 7, sets=2, distance="40 m", notes="Heavy."),
        ]
    else:
        main = [
            mv("Front squat", 1, sets=3, reps=3, load=rpe("RPE 6-7"), notes="Fast reps."),
            mv("Romanian deadlift", 2, sets=2, reps=5, load=rpe("RPE 6")),
            mv("Weighted pull-up", 3, sets=3, reps=3, load=rpe("RPE 6-7")),
            mv("Rear-foot-elevated split squat", 4, sets=2, reps="5/leg", notes="Easy."),
            mv("Row", 5, sets=2, reps=8),
            mv("Standing calf raise", 6, sets=2, reps=8),
            mv("Bent-knee soleus raise", 7, sets=2, reps=12),
        ]
    blocks = [strength_a_warmup(), blk("Main strength", "strength", 2, main, notes=notes)]
    if week != 8:
        blocks.append(cooldown_easy_bike("5"))
    else:
        blocks.append(blk("Finish", "cool_down", 3, [mv("Session complete", 1, notes="Finish in ~45–55 min. No extra work.")]))
    return blocks


def long_bike(week):
    spec = {
        1: ("60 min", "10 min progressive — 5 min extremely easy, 3 min easy, 2 min approaching target aerobic effort.", "45 min continuous Z2 at RPE 3–4/10.", "5 min extremely easy", "First major engine-building session. Breathing controlled; able to speak in sentences. HR observational this week. Known max HR around 195 — do not blindly chase a generic percentage. Record every 10 min: watts, HR, cadence; also average watts, average HR, final HR, RPE. Do not increase output because you are bored."),
        2: ("70 min", "10 min warm-up", "55 min continuous Z2", "5 min", "Progression is +10 min duration, not substantially more power. RPE 3–4, stable HR, manageable drift. Record watts/HR/cadence every 10 min plus average watts, average HR, HR drift and RPE."),
        3: ("80 min", "10 min progressive", "65 min continuous Z2", "5 min", "Use established aerobic output. Do not chase Week-3 power; duration is overload. Record watts/HR/cadence every 10 min plus average watts, average HR, HR drift and RPE."),
        4: ("60 min", "10 min easy", "45 min Z2", "5 min", "Aerobic maintenance. Same approximate aerobic output; do not force watts if HR unusually high. RPE 2–3. Record watts/HR."),
        5: ("85 min", "10 min warm-up", "70 min continuous aerobic", "5 min", "Use Week 4 aerobic-efficiency data; stay below LT1 / genuine Z2, RPE 3–4. Progression is duration. Record watts/HR/cadence every 10 min plus average power, average HR, drift and RPE."),
        6: ("95 min", "10 min progressive", "80 min continuous Z2", "5 min", "RPE 3–4. Final 20 min must not become tempo. Practise roughly 30–45 g carbohydrate/hour. Fluids/electrolytes according to Bali heat and sweat rate. Record watts/HR/cadence every 10–15 min plus average watts, average HR, drift and RPE."),
        7: ("105 min", "10 min progressive", "90 min continuous Z2", "5 min", "RPE 3–4. The achievement is 90 continuous working minutes at low physiological cost. Practise 30–45 g carbohydrate/hour. Record watts/HR/cadence every 15 min plus average watts, average HR, drift and RPE."),
        8: ("50 min", "10 min easy", "35 min comfortable Z2", "5 min", "RPE 2–3. No fixed-output target required. No PM strength."),
    }[week]
    total, wu, main, cd, note = spec
    extra = {
        "modality": "BikeErg",
        "runtime": "time_based_steady_state",
        "numeric_target": "none",
        "b2_calculation": False,
    }
    return [
        blk("Warm-up", "warm_up", 1, [mv("BikeErg progressive warm-up", 1, duration=wu, extra=extra)]),
        blk("Main", "conditioning", 2, [mv("BikeErg continuous aerobic", 1, duration=main, extra=extra)], notes=note),
        blk("Cooldown", "cool_down", 3, [mv("Easy BikeErg", 1, duration=cd, extra=extra)]),
    ]


def upper(week):
    notes = "Ideally 6+ hours after BikeErg. This is not supposed to create huge upper-body fatigue."
    wu = blk(
        "Warm-up",
        "warm_up",
        1,
        [
            mv("Easy SkiErg", 1, duration="5 min"),
            mv("Band external rotation", 2, notes="Include scapular pull-ups, wall slides, band pull-aparts and light overhead pressing."),
        ],
    )
    if week == 1:
        main = [
            mv("Strict press", 1, sets=4, reps=5, rest="150-180", load=rpe("RPE 7"), notes="No leg drive."),
            mv("Pull-up", 2, sets=4, reps=8, notes="Bodyweight initially; lightly load if trivial. Keep 2–3 RIR."),
            mv("Incline DB press", 3, sets=3, reps=8, load=rpe("RPE 7")),
            mv("Chest-supported/cable row", 4, sets=3, reps=10),
            mv("Face pull", 5, sets=3, reps="12-15"),
            mv("Cable/band external rotation", 6, sets=3, reps="12-15/side"),
            mv("Dead hang", 7, sets=3, duration="30-60 sec", notes="Shoulders controlled."),
        ]
    elif week == 2:
        main = [
            mv("Strict press", 1, sets=4, reps=5, rest="150-180", load=rpe("RPE 7-7.5")),
            mv("Pull-up", 2, sets=4, reps="8-10", notes="Progress reps before load; add external load after comfortable 4×10."),
            mv("Incline DB press", 3, sets=3, reps=8, load=rpe("RPE 7-8")),
            mv("Chest-supported/cable row", 4, sets=3, reps=10, load=rpe("RPE 8")),
            mv("Face pull", 5, sets=3, reps=15),
            mv("External rotation", 6, sets=3, reps="12-15/side"),
            mv("Dead hang", 7, sets=3, duration="45-60 sec"),
        ]
    elif week == 3:
        main = [
            mv("Strict press", 1, sets=5, reps=4, load=rpe("RPE 7.5-8")),
            mv("Pull-up", 2, sets=4, reps=10, notes="If easy, introduce small external load."),
            mv("Incline DB press", 3, sets=3, reps=8, load=rpe("RPE 8")),
            mv("Cable/chest-supported row", 4, sets=4, reps="8-10"),
            mv("Face pull", 5, sets=3, reps=15),
            mv("External rotation", 6, sets=3, reps="15/side"),
            mv("Dead hang", 7, sets=3, duration="45-60 sec"),
        ]
    elif week == 4:
        main = [
            mv("Strict press", 1, sets=3, reps=4, load=rpe("RPE 6-7")),
            mv("Pull-up", 2, sets=3, reps=6, notes="Comfortable."),
            mv("Incline DB press", 3, sets=2, reps=8),
            mv("Row", 4, sets=2, reps="8-10"),
            mv("Face pull", 5, sets=2, reps=15),
            mv("External rotation", 6, sets=2, reps=15),
        ]
        notes = "Deload. Finish in ~40–50 min."
    elif week == 5:
        main = [
            mv("Strict press", 1, sets=5, reps=3, load=rpe("RPE 8")),
            mv("Weighted/lightly weighted pull-up", 2, sets=4, reps=8),
            mv("Incline DB press", 3, sets=3, reps=8, load=rpe("RPE 8")),
            mv("Chest-supported/cable row", 4, sets=4, reps="8-10"),
            mv("Face pull", 5, sets=3, reps=15),
            mv("External rotation", 6, sets=3, reps="15/side"),
            mv("Dead hang/grip hold", 7, sets=3, duration="45-60 sec"),
        ]
    elif week == 6:
        main = [
            mv("Strict press", 1, sets=4, reps=4, load=rpe("RPE 7.5-8")),
            mv("Pull-up", 2, sets=4, reps=8, notes="Weighted/lightly weighted."),
            mv("Incline DB press", 3, sets=3, reps=8, load=rpe("RPE 8")),
            mv("Cable/chest-supported row", 4, sets=4, reps=8),
            mv("Face pull", 5, sets=3, reps=15),
            mv("External rotation", 6, sets=3, reps="15/side"),
            mv("Dead hang", 7, sets=2, duration="60 sec"),
        ]
    else:
        main = [
            mv("Strict press", 1, sets=3, reps=4, load=rpe("RPE 7-8")),
            mv("Pull-up", 2, sets=3, reps=8, notes="Moderately weighted."),
            mv("Incline DB press", 3, sets=2, reps=8),
            mv("Chest-supported/cable row", 4, sets=3, reps=8),
            mv("Face pull", 5, sets=2, reps=15),
            mv("External rotation", 6, sets=2, reps="15/side"),
            mv("Dead hang", 7, sets=2, duration="45-60 sec"),
        ]
        notes = "Maintenance. ~45–55 min. Ideally 6+ hours after BikeErg."
    return [wu, blk("Upper strength", "strength", 2, main, notes=notes)]


def threshold_warmup():
    extra = {"modality": "BikeErg", "runtime": "time_based_intervals", "numeric_target": "none", "b2_calculation": False}
    return blk(
        "Warm-up",
        "warm_up",
        1,
        [
            mv("Progressive easy cycling", 1, duration="10 min", extra=extra),
            mv("High-cadence opener", 2, sets=3, duration="30 sec high cadence / 60 sec easy", extra=extra),
            mv("Moderately hard", 3, duration="2 min", extra=extra),
            mv("Easy", 4, duration="2 min", extra=extra),
        ],
        notes="~15 min.",
    )


def threshold_a(week):
    extra = {
        "modality": "BikeErg",
        "runtime": "time_based_intervals",
        "numeric_target": "none",
        "p20_guidance": "90-95% P20 as authored textual guidance after Week 4. Not a calculated target." if week >= 5 else None,
        "b2_calculation": False,
    }
    extra = {k: v for k, v in extra.items() if v is not None}
    spec = {
        1: ("3 × 8 min controlled threshold", "3 min very easy", "RPE ~7/10 initially → perhaps 8/10 late. Highest output you can hold extremely consistently. Example 255/256/254 W = excellent; 255/245/225 = first interval too aggressive. Record average HR each interval, final HR, average watts, cadence and RPE. Total ~55–60 min."),
        2: ("3 × 10 min @ approximately Week-1 threshold output", "3 min very easy", "Raises accumulated threshold from 24 to 30 min. RPE ~7 initially → ~8 final interval. Ideally all intervals within ~1–2% power. Record average watts, average/final HR, cadence and RPE for each interval."),
        3: ("3 × 12 min threshold", "3 min easy", "36 min accumulated threshold. Use Week 2 output as starting point; volume progression takes precedence over wattage increase. RPE ~7 / 7.5–8 / 8–8.5. Aim for ≤1–2% power variation."),
        5: ("2 × 15 min", "4 min very easy", "Let Week-4 20-min power = P20. Initially set longer threshold intervals around 90–95% of P20, then refine from HR/RPE and stability. Do not treat the percentage as physiological truth. RPE ~7–8. Record watts, %P20 (manual), avg/final HR, cadence and RPE. 30 min high-quality threshold."),
        6: ("3 × 12 min", "3 min easy", "36 min threshold. Use Week 5 data. RPE ~7 → 7.5 → 8–8.5. Target ≤2% power variation."),
        7: ("2 × 20 min", "4 min easy", "40 min. This is not two 20-min tests. Use established threshold-training range. RPE 7–7.5 first; 8–8.5 second. Target <2% difference between interval average power."),
    }[week]
    main, rec, note = spec
    return [
        threshold_warmup(),
        blk("Main", "conditioning", 2, [mv("BikeErg threshold intervals", 1, duration=main, notes=f"Recovery: {rec}. {note}", extra=extra)]),
        blk("Cooldown", "cool_down", 3, [mv("Easy BikeErg", 1, duration="10 min", extra=extra)]),
    ]


def muscular_endurance(week):
    spec = {
        1: ("4 rounds", "4-minute working block", "3 min complete/easy recovery", "10 DB step-ups (5/leg)", "RPE 6–7, not 10. Sled moderately heavy but continuous; farmer carry challenging but unbroken; step-ups moderate with perfect mechanics; Ski controlled. Record sled load, farmer load, step-up load, Ski metres, HR and round RPE."),
        2: ("4 rounds", "5-min work blocks", "3 min recovery", "10 DB step-ups (5/leg)", "Use approximately Week 1 loads. Progression is work duration, not load. Target RPE 6–7.5 and minimal degradation. Record Ski metres each round."),
        3: ("4 rounds", "5 min", "2 min recovery", "10 DB step-ups (5/leg)", "Keep loads around Week 2; progression is shorter recovery. Target RPE 6.5 → 7 → 7.5 → ~8. No all-out final round."),
        5: ("5 rounds", "5-min blocks", "2 min recovery", "10 DB step-ups (5/leg)", "Increase sled/carry loads modestly ~5–10% from Week 3 if appropriate. Target RPE 6.5 → 7 → 7 → 7.5 → 8. Repeatability is KPI."),
        6: ("5 rounds", "6-min blocks", "2 min recovery", "12 DB step-ups (6/leg)", "Keep roughly Week 5 loads because work duration and step-up reps increased. RPE 6.5/7/7/7.5/8. 30 min accumulated work."),
        7: ("5 rounds", "5 min", "2 min recovery", "10 DB step-ups", "If appropriate, load ~5% heavier than Week 6. Target RPE 7–8. Prioritise mechanical strength endurance over metabolic destruction. Volume reduced because AM threshold is now 40 min."),
    }[week]
    rounds, work, rec, steps, note = spec
    return [
        blk("Warm-up", "warm_up", 1, [mv("Movement preparation + easy Ski/row", 1, duration="10 min")]),
        blk(
            "Main — mixed muscular endurance",
            "conditioning",
            2,
            [
                mv("Sled push", 1, distance="20 m", notes="Each working block."),
                mv("Sled pull", 2, distance="20 m"),
                mv("Farmer carry", 3, distance="40 m"),
                mv("DB step-up", 4, reps=steps),
                mv("Easy/moderate SkiErg", 5, notes="Remaining time in the working block. Controlled."),
            ],
            notes=f"{rounds}. Each working block is {work}, then {rec}. {note} Manual capture — not an automated running workout.",
        ),
    ]


def efficiency(week, test=False):
    extra = {"modality": "BikeErg", "runtime": "time_based_steady_state", "numeric_target": "none", "fixed_output": True, "b2_calculation": False}
    spec = {
        1: ("50 min", "10 min easy", "35 min steady aerobic", "5 min", "Same effort domain as Sunday, RPE 3–4. Once Sunday data identifies a sensible aerobic wattage, select one output and hold it. Record HR response. No second session. No accessories."),
        2: ("55 min", "10 min", "40 min fixed-output block", "5 min", "Choose a wattage from Week 1 that produced genuine Z2 and hold that exact output. Record HR at 5/10/20/30/40 min plus average HR and RPE."),
        3: ("60 min", "10 min easy", "45 min fixed-output aerobic block", "5 min", "Same standardised wattage. Record HR at 5/10/20/30/40/45 min. RPE 3–4."),
        4: ("60 min", "10 min warm-up", "45 min at exact standardised BikeErg wattage", "5 min", "TEST 3. Same Bike, setup and similar hydration/caffeine/time of day where practical. Record HR at 5/10/15/20/25/30/35/40/45 min plus average HR, first-half average HR, second-half average HR, cadence, RPE and bodyweight."),
        5: ("60 min", "10 min easy", "45 min fixed output", "5 min", "Use same fixed wattage as Week 4 efficiency test. Do not increase yet. RPE 2–3."),
        6: ("65 min", "10 min", "50 min fixed-output aerobic work", "5 min", "Same standardised wattage. Record HR at 10/20/30/40/50 min plus average HR and RPE."),
        7: ("70 min", "10 min easy", "55 min fixed output", "5 min", "Same standardised wattage. Record HR at 10/20/30/40/50/55 min plus average HR and RPE. RPE 2–3."),
        8: ("60 min", "10 min warm-up", "45 min at fixed benchmark power", "5 min", "EXIT TEST 4. Exact same BikeErg standardised watts as Week 4. Record HR at 5/10/15/20/25/30/35/40/45 min plus average HR, first-half HR, second-half HR, HR drift, cadence and RPE."),
    }[week]
    total, wu, main, cd, note = spec
    return [
        blk("Warm-up", "warm_up", 1, [mv("BikeErg", 1, duration=wu, extra=extra)]),
        blk("Main", "conditioning", 2, [mv("BikeErg fixed-output aerobic", 1, duration=main, extra=extra)], notes=note),
        blk("Cooldown", "cool_down", 3, [mv("Easy BikeErg", 1, duration=cd, extra=extra)]),
    ]


def vo2(week):
    extra = {"modality": "BikeErg", "runtime": "time_based_intervals", "numeric_target": "none", "b2_calculation": False}
    spec = {
        1: ("4 × 4 min hard", "3 min easy", "RPE 8–9/10, but repeatable. Interval four should remain close to interval one. Do not sprint the first minute. Example 290/289/286/284 = excellent; 320/290/270/250 = wrong intensity. Warm-up 15 min; cooldown 10 min; no lifting afterwards."),
        2: ("4 × 4 min", "3 min easy", "Do not add a fifth interval yet. Progress quality/output using Week 1 data. If Week 1 was 290/289/286/284 W, target roughly 288–292 W across all four. RPE ~8 → 8.5 → 9 → 9."),
        3: ("5 × 4 min hard", "3 min easy", "20 min VO2 work. Do not simultaneously chase dramatically higher power. Target RPE 8 / 8.5 / 8.5 / 9 / 9+. Record individual watts, mean session interval watts, power decay, HR, cadence and RPE."),
        5: ("6 × 3 min", "2.5–3 min easy", "18 min. Slightly higher power than longer 4-min intervals. Use Week 3 and P20 to establish initial target; do not rely on a universal percentage. RPE ~7.5–8 / 8 / 8 / 8.5 / 9 / 9+."),
        6: ("5 × 4 min", "3 min easy", "20 min. Direct comparison to Week 3 5×4. Target RPE 8 / 8.5 / 8.5–9 / 9 / 9+. Keep interval decay below ~3%."),
        7: ("6 × 3 min", "3 min easy", "18 min. Reduces total high-intensity work versus Week 6. Use Week 5 6×3 as direct benchmark. RPE 8/8/8.5/8.5/9/9+."),
    }[week]
    main, rec, note = spec
    return [
        blk(
            "Warm-up",
            "warm_up",
            1,
            [
                mv("Easy-progressive BikeErg", 1, duration="8 min", extra=extra),
                mv("High-cadence opener", 2, sets=3, duration="30 sec / 60 sec easy", extra=extra),
                mv("Hard / easy", 3, sets=2, duration="1 min hard / 2 min easy", extra=extra),
                mv("Easy before main", 4, duration="2-3 min", extra=extra),
            ],
            notes="15 min.",
        ),
        blk("Main", "conditioning", 2, [mv("BikeErg VO2 intervals", 1, duration=main, notes=f"Recovery: {rec}. {note}", extra=extra)]),
        blk("Cooldown", "cool_down", 3, [mv("Easy BikeErg", 1, duration="10 min", extra=extra)]),
    ]


def strength_c(week):
    elastic = {
        1: [],
        2: [mv("Pogo hops", 1, sets=3, reps="20 contacts", rest="45-60", notes="Low amplitude, stiff ankle, quick contact, quiet landing."), mv("Skipping", 2, sets=3, duration="30 sec")],
        3: [mv("Pogo hops", 1, sets=3, reps=25), mv("Skipping", 2, sets=3, duration="45 sec"), mv("Low box snap-down/low jump", 3, sets=3, reps=3)],
        4: [mv("Pogo hops", 1, sets=2, reps=20), mv("Skipping", 2, sets=2, duration="30 sec"), mv("Low snap-down/jump", 3, sets=2, reps=3)],
        5: [mv("Pogo hops", 1, sets=3, reps=30), mv("Skipping", 2, sets=3, duration="60 sec"), mv("Low countermovement jump", 3, sets=3, reps=3), mv("Lateral pogo", 4, sets=2, reps="15/side")],
        6: [mv("Pogo hops", 1, sets=3, reps=30), mv("Skipping", 2, sets=3, duration="60 sec"), mv("Countermovement jumps", 3, sets=4, reps=3), mv("Lateral pogos", 4, sets=3, reps="15/side"), mv("Low forward bounds", 5, sets=2, reps="10 contacts")],
        7: [mv("Pogo hops", 1, sets=3, reps=30), mv("Skipping", 2, sets=3, duration="60 sec"), mv("Countermovement jumps", 3, sets=4, reps=3), mv("Lateral pogos", 4, sets=3, reps="20/side"), mv("Forward bounds", 5, sets=3, reps="8 contacts"), mv("Single-leg pogo", 6, sets=2, reps="10/side", notes="Quality only; stop if Achilles/calf/knee response is poor.")],
    }[week]
    lifts = {
        1: [
            mv("Bulgarian split squat", 1, sets=4, reps="6/leg", load=rpe("RPE 7")),
            mv("Hip thrust", 2, sets=3, reps=8, load=rpe("RPE 7-8")),
            mv("Nordic hamstring curl", 3, sets=3, reps="4-6", notes="Assisted if necessary; quality eccentric control."),
            mv("Weighted chin-up", 4, sets=3, reps=6, load=rpe("RPE 7")),
            mv("Cable/chest-supported row", 5, sets=3, reps=10),
            mv("Standing calf raise", 6, sets=3, reps="8-10", notes="Heavy, full ROM."),
            mv("Seated/bent-knee calf raise", 7, sets=3, reps="12-15"),
            mv("Tibialis raise", 8, sets=2, reps="15-20"),
            mv("Pallof press", 9, sets=3, reps="10/side"),
        ],
        2: [
            mv("Bulgarian split squat", 1, sets=4, reps="6/leg", load=rpe("RPE 7-7.5")),
            mv("Hip thrust", 2, sets=3, reps=8, load=rpe("RPE 7-8")),
            mv("Nordic hamstring curl", 3, sets=3, reps="5-6", notes="Only if Week 1 tolerated."),
            mv("Weighted chin-up", 4, sets=3, reps=6, load=rpe("RPE 7-8")),
            mv("Chest-supported row", 5, sets=3, reps=10),
            mv("Standing calf raise", 6, sets=4, reps="8-10"),
            mv("Bent-knee/soleus raise", 7, sets=3, reps="12-15"),
            mv("Tibialis raise", 8, sets=3, reps="15-20"),
            mv("Pallof press", 9, sets=3, reps="10/side"),
        ],
        3: [
            mv("Bulgarian split squat", 1, sets=4, reps="6/leg", load=rpe("RPE 8")),
            mv("Hip thrust", 2, sets=4, reps=6, load=rpe("RPE 7.5-8")),
            mv("Nordic hamstring curl", 3, sets=3, reps=6, notes="If tolerated."),
            mv("Weighted chin-up", 4, sets=4, reps=5, load=rpe("RPE 7.5-8")),
            mv("Chest-supported row", 5, sets=3, reps=10),
            mv("Standing calf raise", 6, sets=4, reps=8, notes="Heavy."),
            mv("Bent-knee soleus", 7, sets=4, reps=12),
            mv("Tibialis raise", 8, sets=3, reps=20),
            mv("Pallof press", 9, sets=3, reps="10/side"),
        ],
        4: [
            mv("Bulgarian split squat", 1, sets=2, reps="6/leg", load=rpe("RPE 6-7")),
            mv("Hip thrust", 2, sets=2, reps=6, load=rpe("RPE 6-7")),
            mv("Nordic hamstring curl", 3, sets=2, reps=4, notes="Controlled."),
            mv("Weighted chin-up", 4, sets=2, reps=5, load=rpe("RPE 6-7")),
            mv("Row", 5, sets=2, reps=8),
            mv("Standing calf raise", 6, sets=3, reps=8),
            mv("Bent-knee soleus", 7, sets=3, reps=12),
            mv("Tibialis raise", 8, sets=2, reps=15),
            mv("Pallof press", 9, sets=2, reps="10/side"),
        ],
        5: [
            mv("Bulgarian split squat", 1, sets=4, reps="5/leg", load=rpe("RPE 8")),
            mv("Hip thrust", 2, sets=4, reps=6, load=rpe("RPE 8")),
            mv("Nordic hamstring curl", 3, sets=3, reps=6),
            mv("Weighted chin-up", 4, sets=4, reps=5, load=rpe("RPE 8")),
            mv("Chest-supported row", 5, sets=3, reps="8-10"),
            mv("Standing calf raise", 6, sets=4, reps=8, notes="Heavy."),
            mv("Bent-knee soleus", 7, sets=4, reps="12-15"),
            mv("Tibialis raise", 8, sets=3, reps=20),
            mv("Pallof press", 9, sets=3, reps="10/side"),
        ],
        6: [
            mv("Bulgarian split squat", 1, sets=4, reps="5/leg", load=rpe("RPE 8")),
            mv("Hip thrust", 2, sets=3, reps=6, load=rpe("RPE 8")),
            mv("Nordic hamstring curl", 3, sets=3, reps=6),
            mv("Weighted chin-up", 4, sets=4, reps=5, load=rpe("RPE 8")),
            mv("Chest-supported row", 5, sets=3, reps=8),
            mv("Standing calf raise", 6, sets=4, reps="6-8", notes="Heavy."),
            mv("Bent-knee soleus", 7, sets=4, reps="12-15"),
            mv("Tibialis raise", 8, sets=3, reps=20),
            mv("Pallof press", 9, sets=3, reps="10/side"),
        ],
        7: [
            mv("Bulgarian split squat", 1, sets=3, reps="5/leg", load=rpe("RPE 8")),
            mv("Hip thrust", 2, sets=3, reps=5, load=rpe("RPE 8")),
            mv("Nordic hamstring curl", 3, sets=3, reps=5),
            mv("Weighted chin-up", 4, sets=3, reps=5, load=rpe("RPE 8")),
            mv("Chest-supported row", 5, sets=3, reps=8),
            mv("Standing calf raise", 6, sets=4, reps=6, notes="Heavy. Calf/soleus volume remains deliberately protected."),
            mv("Bent-knee soleus", 7, sets=4, reps=12),
            mv("Tibialis raise", 8, sets=3, reps=20),
            mv("Pallof press", 9, sets=2, reps="10/side"),
        ],
    }[week]
    blocks = [
        blk(
            "Warm-up",
            "warm_up",
            1,
            [mv("Easy BikeErg", 1, duration="5 min"), mv("Ankle/hip preparation", 2, notes="Split squat, single-leg hinge, calf/ankle preparation and scapular pull-up.")],
        )
    ]
    if elastic:
        blocks.append(blk("Elastic / running preparation", "skill", 2, elastic, notes="No plyometrics in Week 1. Elastic contacts stop if Achilles/calf/knee response is poor."))
    blocks.append(blk("Strength C", "strength", 3, lifts))
    return blocks


def row_friday(week):
    extra = {"modality": "RowErg", "runtime": "time_based_intervals", "numeric_target": "none", "b2_calculation": False}
    if week <= 3:
        spec = {
            1: ("3 × 10 min", "3 min easy rowing", "RPE 6–7. Noticeably harder than Z2 and easier than Monday threshold. Stroke rate ~22–26 spm. Record average /500m, watts, stroke rate, HR and RPE. Total ~60 min."),
            2: ("3 × 12 min", "3 min easy rowing", "RPE 6–7. Use Week 1 pace as reference; increase duration, not necessarily speed. Stroke rate ~22–26 spm."),
            3: ("3 × 15 min", "3 min easy rowing", "45 min. RPE 6 → 6.5 → 7. Stroke rate ~22–26 spm. If clearly over-fatigued, replace with 40–50 min easy Row/Bike Z2. That substitution is coaching guidance, not automatic deletion."),
        }[week]
        title = "Sub-threshold RowErg"
    else:
        spec = {
            5: ("3 × 10 min", "3 min easy row", "True threshold. Use Week 4 2k plus Block-I sub-threshold pace and HR/RPE as references. Target RPE ~7–8 and stable pace. Stroke rate likely ~24–28 spm."),
            6: ("3 × 12 min", "3 min easy rowing", "36 min. Use Week 5 average pace as starting reference; do not automatically row faster because duration rises 20%. RPE 7 → 7.5 → 8–8.5. Stroke rate ~24–28 spm."),
            7: ("3 × 15 min", "3 min easy recovery", "45 min. Use Week 6 output as reference; do not automatically increase pace. RPE 7 → 7.5 → 8–8.5. Stroke rate ~24–28 spm. If Friday warm-up HR is abnormally high and fatigue is clear, convert to easy aerobic work — guidance only."),
        }[week]
        title = "Threshold B — RowErg"
    main, rec, note = spec
    return [
        blk(
            "Warm-up",
            "warm_up",
            1,
            [
                mv("Easy technical rowing", 1, duration="12-15 min", extra=extra, notes="Legs → body → arms; arms → body → legs."),
                mv("Building strokes", 2, sets=3, duration="20 strokes building pace", extra=extra),
            ],
        ),
        blk("Main", "conditioning", 2, [mv(title, 1, duration=main, notes=f"Recovery: {rec}. {note}", extra=extra)]),
        blk("Cooldown", "cool_down", 3, [mv("Easy row", 1, duration="8-10 min" if week == 2 else "10 min", extra=extra)]),
    ]


def bike_20_test(week):
    extra = {"modality": "BikeErg", "runtime": "time_based_steady_state", "numeric_target": "none", "test": True, "b2_calculation": False}
    note = (
        "Highest average power sustainable for the entire 20 min. Repeatable performance benchmark, not an automatic FTP estimate. "
        "Standardise: normal carbohydrate Sunday; hydrated; normal caffeine; same BikeErg setup for Week 4 and Week 8; record damper/gearing and morning bodyweight. "
        "Pacing: 0–5 controlled; 5–15 lock sustainable maximum; 15–18 squeeze; final 2 min progressively empty. "
        "Record 20-min average watts (primary), W/kg, average HR, peak HR, average cadence, first 10-min watts, second 10-min watts, RPE and bodyweight. "
        "Manual evidence where typed metrics are absent. No PM muscular endurance."
    )
    if week == 8:
        note += " Same protocol as Week 4. 0–5 controlled; 5–10 settle; 10–15 work; 15–18 squeeze; 18–20 empty."
    return [
        blk(
            "Warm-up",
            "warm_up",
            1,
            [
                mv("Easy", 1, duration="8 min", extra=extra),
                mv("Moderate", 2, duration="3 min", extra=extra),
                mv("Easy", 3, duration="2 min", extra=extra),
                mv("Hard / easy", 4, sets=2, duration="1 min hard / 2 min easy", extra=extra),
                mv("Fast / easy", 5, sets=3, duration="20 sec fast / 60 sec easy", extra=extra),
                mv("Very easy", 6, duration="2-3 min", extra=extra),
            ],
            notes="~20 min.",
        ),
        blk("20-minute test", "conditioning", 2, [mv("BikeErg 20-minute maximum sustainable power", 1, duration="20 min", extra=extra, notes=note)]),
        blk("Cooldown", "cool_down", 3, [mv("Extremely easy BikeErg", 1, duration="10-15 min", extra=extra)]),
    ]


def row_2k_test(week):
    extra = {
        "modality": "RowErg",
        "runtime": "manual_distance_test",
        "numeric_target": "none",
        "distance_termination": "not_automated",
        "b2_calculation": False,
    }
    note = (
        "2,000 m maximum effort. Manual/test execution — current runtime cannot honestly terminate on distance. "
        "Record damper setting, drag factor (preferred over damper number), bodyweight and time of day. "
        "Pacing: 0–500 controlled aggression; 500–1,000 lock pace; 1,000–1,500 hold technique; 1,500–1,750 apply pressure; final 250 empty. "
        "Record total time, every 500 m split, average /500m, average watts, average stroke rate, average HR, max HR and RPE. "
        "Historical ~6:45 / ~1:41.3 per 500 m is a reference, not a requirement."
    )
    return [
        blk(
            "Warm-up",
            "warm_up",
            1,
            [
                mv("Easy row", 1, duration="8 min", extra=extra),
                mv("Building 20 strokes", 2, sets=3, duration="20 strokes / ~60 sec easy", extra=extra),
                mv("500 m around projected 2k pace", 3, distance="500 m", extra=extra),
                mv("Easy", 4, duration="2-3 min", extra=extra),
                mv("Hard strokes", 5, sets=2, duration="10 hard strokes with plenty of easy rowing", extra=extra),
                mv("Very easy", 6, duration="2-3 min", extra=extra),
            ],
            notes="~20 min.",
        ),
        blk("2 km test", "conditioning", 2, [mv("2,000 m RowErg maximum effort", 1, distance="2000 m", extra=extra, notes=note)]),
        blk("Cooldown", "cool_down", 3, [mv("Easy row", 1, duration="10-15 min", extra=extra)]),
    ]


def recovery_bike(duration, rpe_text, optional=False, mobility=None):
    extra = {"modality": "BikeErg", "runtime": "time_based_steady_state", "numeric_target": "none", "b2_calculation": False}
    blocks = [
        blk("Recovery aerobic", "conditioning", 1, [mv("Easy BikeErg", 1, duration=duration, extra=extra, notes=rpe_text)]),
    ]
    if mobility:
        blocks.append(blk("Mobility", "cool_down", 2, [mv("Mobility", 1, duration=mobility, notes="Ankles, calves, hips, T-spine, lats.")]))
    if optional:
        blocks[0]["coach_notes"] = (blocks[0].get("coach_notes") or "") + " Visibly optional. Guidance only — not automatic deletion."
    return blocks


def relative_strength_tests():
    return [
        blk("General warm-up", "warm_up", 1, [mv("General warm-up", 1, notes="Then progressive front-squat build-up.")]),
        blk(
            "Test A — Front squat 3RM",
            "strength",
            2,
            [
                mv("Front squat 3RM", 1, sets=1, reps=3, load=rpe("RPE 9-9.5, not failure"), notes="Heaviest load for 3 technically excellent reps. No collapsed torso or ugly grinder. Record 3RM load, bodyweight and load/bodyweight ratio. Suggested build: bar × several; ~40% ×5; ~55% ×4; ~70% ×3; ~80% ×2; then heavier singles/doubles as appropriate."),
            ],
        ),
        blk(
            "Test B — Weighted pull-up 1RM",
            "strength",
            3,
            [
                mv("Weighted pull-up 1RM", 1, sets=1, reps=1, notes="Warm up with bodyweight reps, then progressive loading (e.g. +10, +20, +25 kg) with long rests. Standard: dead hang, no kip, chin clearly over bar. Record external load and system load (bodyweight + external)."),
            ],
        ),
        blk(
            "Optional post-test",
            "accessory",
            4,
            [
                mv("Row", 1, sets=2, reps=10),
                mv("Face pull", 2, sets=2, reps=15),
                mv("External rotation", 3, sets=2, reps=15),
            ],
            notes="Optional. Nothing more.",
        ),
    ]


def w8_thu():
    extra = {"modality": "BikeErg", "runtime": "time_based_steady_state", "numeric_target": "none", "b2_calculation": False}
    return [
        blk("Recovery aerobic", "conditioning", 1, [mv("Very easy BikeErg", 1, duration="40 min", extra=extra, notes="RPE 2.")]),
        blk(
            "Running preparation",
            "skill",
            2,
            [
                mv("Pogo hops", 1, sets=2, reps=20),
                mv("Skipping", 2, sets=2, duration="45 sec"),
                mv("Countermovement jump", 3, sets=3, reps=3),
                mv("Lateral pogo", 4, sets=2, reps="10/side"),
                mv("Single-leg pogo", 5, sets=2, reps="8/side"),
            ],
            notes="No lower-body lifting.",
        ),
    ]


def w8_sat_recovery():
    return [
        blk(
            "Recovery",
            "cool_down",
            1,
            [
                mv("Walk, swim or easy mobility", 1, notes="No training objective."),
                mv("Optional recovery spin", 2, duration="20-30 min", notes="Optional. Guidance only."),
            ],
            notes="Visibly optional recovery day. Do not invent extra work.",
        )
    ]


# --- schedule ---------------------------------------------------------------

DAY_NAMES = {
    1: "Saturday",
    2: "Sunday",
    3: "Monday",
    4: "Tuesday",
    5: "Wednesday",
    6: "Thursday",
    7: "Friday",
    8: "Saturday (spillover)",
    9: "Sunday (spillover)",
}


def session(week, day, slot, title, session_type, duration, adaptation, load, purpose, blocks, tod="any", optional=False, summary=None):
    ident = ids(week, day, slot)
    return {
        **ident,
        "week": week,
        "day": day,
        "slot": slot,
        "title": title,
        "session_type": session_type,
        "estimated_duration_minutes": duration,
        "time_of_day": tod,
        "primary_adaptation": adaptation,
        "load_classification": load,
        "purpose": purpose,
        "optional": optional,
        "prescription_summary": summary or purpose,
        "blocks": blocks,
        "coach_notes": f"{purpose} Primary adaptation: {adaptation}. Load: {load}.",
    }


def all_sessions():
    s = []
    for w in (1, 2, 3, 5, 6, 7):
        s.append(session(w, 1, 1, "Strength A — Heavy Lower + Pull", "strength", 75 if w != 7 else 60, "Maximum / relative strength", "moderately hard" if w < 5 else "high intensity controlled volume", "Maintain/develop high force production.", strength_a(w)))
        s.append(session(w, 2, 1, "Long Aerobic — BikeErg", "conditioning", {1: 60, 2: 70, 3: 80, 5: 85, 6: 95, 7: 105}[w], "Aerobic capacity", "easy", "Engine-building continuous BikeErg.", long_bike(w), tod="morning", summary={1: "60 min BikeErg Z2", 2: "70 min BikeErg Z2", 3: "80 min BikeErg Z2", 5: "85 min BikeErg Z2", 6: "95 min BikeErg Z2", 7: "105 min BikeErg Z2"}[w]))
        s.append(session(w, 2, 2, "Strength B — Upper Strength", "strength", 55 if w != 7 else 50, "Upper strength / shoulder robustness", "moderate", "Useful upper-body strength without unnecessary hypertrophy volume.", upper(w), tod="afternoon"))
        s.append(session(w, 3, 1, "Threshold A — BikeErg", "conditioning", 60, "LT2 / sustainable power", "hard", "Flagship aerobic-quality session.", threshold_a(w), tod="morning", summary={1: "3 × 8 min BikeErg threshold", 2: "3 × 10 min BikeErg threshold", 3: "3 × 12 min BikeErg threshold", 5: "2 × 15 min BikeErg threshold ~90–95% P20 guidance", 6: "3 × 12 min BikeErg threshold", 7: "2 × 20 min BikeErg threshold"}[w]))
        s.append(session(w, 3, 2, "Muscular Endurance — Structural Capacity", "conditioning", 45, "Repeatable functional force", "moderate", "Loaded movement, repeated force and aerobic recovery; at least 6 hours after threshold.", muscular_endurance(w), tod="afternoon"))
        s.append(session(w, 4, 1, "Aerobic Efficiency — BikeErg", "conditioning", {1: 50, 2: 55, 3: 60, 5: 60, 6: 65, 7: 70}[w], "Aerobic efficiency / recovery", "easy", "Standardised fixed-output aerobic session.", efficiency(w)))
        s.append(session(w, 5, 1, "VO2max — BikeErg", "conditioning", 60, "Aerobic ceiling", "hard", "Hard cardiovascular intervals. No lifting afterwards.", vo2(w), summary={1: "4 × 4 min BikeErg VO2", 2: "4 × 4 min BikeErg VO2 — higher quality", 3: "5 × 4 min BikeErg VO2", 5: "6 × 3 min BikeErg VO2", 6: "5 × 4 min BikeErg VO2", 7: "6 × 3 min BikeErg VO2"}[w]))
        s.append(session(w, 6, 1, "Strength C — Lower + Pull + Running Prep", "strength", 70, "Unilateral/posterior-chain strength + tissue capacity", "moderately hard", "Unilateral/posterior-chain robustness and tissues that will later tolerate running. No running required in this programme.", strength_c(w)))
        if w <= 3:
            s.append(session(w, 7, 1, "Sub-threshold — RowErg", "conditioning", 60, "Whole-body aerobic development", "moderately hard", "Work between LT1 and LT2; not Threshold B yet." if w < 5 else "", row_friday(w), summary={1: "3 × 10 min RowErg sub-threshold", 2: "3 × 12 min RowErg sub-threshold", 3: "3 × 15 min RowErg sub-threshold"}[w]))
        else:
            s.append(session(w, 7, 1, "Threshold B — RowErg", "conditioning", 60, "LT2 / whole-body aerobic development", "hard", "Second genuine weekly threshold exposure.", row_friday(w), summary={5: "3 × 10 min RowErg threshold", 6: "3 × 12 min RowErg threshold", 7: "3 × 15 min RowErg threshold"}[w]))

    # Week 4 — 8 sessions
    s.append(session(4, 1, 1, "Strength A — Deload", "strength", 50, "Strength maintenance", "easy-moderate", "Deload Strength A. No farmer carries.", strength_a(4)))
    s.append(session(4, 2, 1, "Easy Long Aerobic — BikeErg", "conditioning", 60, "Aerobic maintenance/recovery", "easy", "60 min easy Z2.", long_bike(4), tod="morning", summary="60 min easy BikeErg Z2"))
    s.append(session(4, 2, 2, "Upper Strength — Deload", "strength", 45, "Upper strength maintenance", "easy-moderate", "Deload upper strength.", upper(4), tod="afternoon"))
    s.append(session(4, 3, 1, "BikeErg 20-min Benchmark", "test", 55, "Threshold/power test", "test", "TEST 1 — 20-minute BikeErg.", bike_20_test(4), summary="20-min BikeErg benchmark"))
    s.append(session(4, 4, 1, "Recovery aerobic", "recovery", 50, "Absorb/test preparation", "easy", "Protect Wednesday's test.", recovery_bike("40 min", "RPE 2–3, HR low.", mobility="10-15 min")))
    s.append(session(4, 5, 1, "2 km Row Test", "test", 50, "Primary performance benchmark", "test", "TEST 2 — 2 km Row. Manual distance test.", row_2k_test(4), summary="2 km Row test"))
    s.append(session(4, 6, 1, "Strength C — Deload + Running Prep", "strength", 50, "Tissue/strength maintenance", "easy-moderate", "Deload Strength C plus low-dose elastic work.", strength_c(4)))
    s.append(session(4, 7, 1, "Aerobic Efficiency Test", "test", 60, "Quantify aerobic adaptation", "test", "TEST 3 — fixed-output BikeErg.", efficiency(4, test=True), summary="45 min fixed-output BikeErg efficiency test"))

    # Week 8 — 9 days
    s.append(session(8, 1, 1, "Strength primer", "strength", 50, "Maintain neural strength; remove fatigue", "easy", "Strength primer. Finish ~45–55 min.", strength_a(8)))
    s.append(session(8, 2, 1, "Easy aerobic — BikeErg", "conditioning", 50, "Recovery / aerobic maintenance", "easy", "No PM strength.", long_bike(8)))
    s.append(session(8, 3, 1, "20-min BikeErg test", "test", 55, "Sustained aerobic power", "test", "EXIT TEST 1.", bike_20_test(8), summary="Week 8 20-min BikeErg exit test"))
    s.append(session(8, 4, 1, "Recovery + mobility", "recovery", 50, "Freshen up", "easy", "Optional 30–40 min extremely easy BikeErg at RPE 1–2, or walk.", recovery_bike("30-40 min", "RPE 1–2 or walk. Optional.", optional=True, mobility="15-20 min"), optional=True))
    s.append(session(8, 5, 1, "2 km Row test", "test", 50, "Whole-body aerobic power", "test", "EXIT TEST 2.", row_2k_test(8), summary="Week 8 2 km Row exit test"))
    s.append(session(8, 6, 1, "Easy aerobic + running prep", "recovery", 55, "Recovery / tissue prep", "easy", "No lower-body lifting.", w8_thu()))
    s.append(session(8, 7, 1, "Relative-strength testing", "test", 60, "Front squat + weighted pull-up", "test", "EXIT TEST 3.", relative_strength_tests(), summary="Front squat 3RM and weighted pull-up 1RM"))
    s.append(session(8, 8, 1, "Recovery", "recovery", 30, "Shed testing fatigue", "easy", "Walk, swim, easy mobility. Optional 20–30 min recovery spin.", w8_sat_recovery(), optional=True))
    s.append(session(8, 9, 1, "Aerobic Efficiency Test", "test", 60, "Final aerobic-base measurement", "test", "EXIT TEST 4.", efficiency(8, test=True), summary="Week 8 fixed-output efficiency test"))
    return s


def build_package(sessions):
    session_refs = []
    weeks = []
    by_week = {}
    for item in sessions:
        by_week.setdefault(item["week"], []).append(item)
        session_refs.append({
            "session_key": item["session_key"],
            "protocol_id": item["protocol_id"],
            "session_lineage_id": item["session_lineage_id"],
            "revision_number": 1,
            "title": item["title"],
        })
    week_titles = {
        1: "Calibration + Productive Training",
        2: "First Progression Week",
        3: "Peak Loading Week — Block I",
        4: "Consolidation + Testing",
        5: "Block II Begins",
        6: "Main Development Week — Block II",
        7: "Peak Week",
        8: "Taper + Bali Exit Testing",
    }
    for week in range(1, 9):
        days_map = {}
        for item in by_week[week]:
            days_map.setdefault(item["day"], []).append(item)
        days = []
        for day in sorted(days_map):
            slots = []
            for item in sorted(days_map[day], key=lambda x: x["slot"]):
                slots.append({
                    "slot_key": item["slot_key"],
                    "session_order": item["slot"],
                    "session_key": item["session_key"],
                    "time_of_day": item["time_of_day"],
                    "is_optional": item["optional"],
                    "completion_expectation": "optional" if item["optional"] else "required",
                    "display_title": item["title"],
                    "coach_note": item["coach_notes"],
                    "progression": {
                        "prescription_summary": item["prescription_summary"],
                        "volume_note": item["purpose"],
                        "intensity_note": item["load_classification"],
                        "coach_note": item["primary_adaptation"],
                    },
                })
            days.append({
                "day_key": f"day_{day}",
                "day_order": day,
                "day_type": "training",
                "title": DAY_NAMES[day],
                "intent": "test" if week in (4, 8) and day in (3, 5, 7, 9) else "build",
                "slots": slots,
            })
        weeks.append({
            "week_number": week,
            "phase_key": "PHASE-BALI-BASE",
            "title": week_titles[week],
            "intent": "test" if week in (4, 8) else "build",
            "coach_note": week_titles[week],
            "days": days,
        })
    assessments = [
        {"id": "ASM-BALI-BIKE-P20-W4", "slot_ref": ids(4, 3, 1)["slot_key"], "evidence_requirement": "manual_bike_20min_profile", "comparison_identity_id": "CMP-BALI-BIKE-P20", "label": "Week 4 BikeErg 20-min"},
        {"id": "ASM-BALI-ROW-2K-W4", "slot_ref": ids(4, 5, 1)["slot_key"], "evidence_requirement": "manual_row_2k_profile", "comparison_identity_id": "CMP-BALI-ROW-2K", "label": "Week 4 2 km Row"},
        {"id": "ASM-BALI-EFF-W4", "slot_ref": ids(4, 7, 1)["slot_key"], "evidence_requirement": "manual_fixed_power_hr", "comparison_identity_id": "CMP-BALI-EFF", "label": "Week 4 aerobic efficiency"},
        {"id": "ASM-BALI-BIKE-P20-W8", "slot_ref": ids(8, 3, 1)["slot_key"], "evidence_requirement": "manual_bike_20min_profile", "comparison_identity_id": "CMP-BALI-BIKE-P20", "label": "Week 8 BikeErg 20-min"},
        {"id": "ASM-BALI-ROW-2K-W8", "slot_ref": ids(8, 5, 1)["slot_key"], "evidence_requirement": "manual_row_2k_profile", "comparison_identity_id": "CMP-BALI-ROW-2K", "label": "Week 8 2 km Row"},
        {"id": "ASM-BALI-FS-3RM-W8", "slot_ref": ids(8, 7, 1)["slot_key"], "evidence_requirement": "manual_front_squat_3rm", "comparison_identity_id": "CMP-BALI-FS-3RM", "label": "Week 8 front squat 3RM"},
        {"id": "ASM-BALI-WPU-W8", "slot_ref": ids(8, 7, 1)["slot_key"], "evidence_requirement": "manual_weighted_pullup", "comparison_identity_id": "CMP-BALI-WPU", "label": "Week 8 weighted pull-up"},
        {"id": "ASM-BALI-EFF-W8", "slot_ref": ids(8, 9, 1)["slot_key"], "evidence_requirement": "manual_fixed_power_hr", "comparison_identity_id": "CMP-BALI-EFF", "label": "Week 8 aerobic efficiency"},
    ]
    return {
        "package_schema_version": 1,
        "programme": {
            "lineage_code": LINEAGE,
            "version_number": VERSION,
            "name": "Bali Hybrid Base",
            "description": "Internal Lee-specific 8-week endurance-led hybrid base. 71 sessions across 58 calendar days including Week 8 testing spillover. No running required. Not commercial HYROX Base. Withheld from the public catalogue.",
            "library_scope": "coach_private",
            "owner_type": "coach",
            "coaching_intent": "Build the aerobic engine, useful force and running-ready tissues required to enter a later 16-week elite HYROX race-preparation phase. Forget HYROX movements and random WODs during this block.",
            "duration_weeks": 8,
            "sessions_per_week": 9,
            "primary_goal": "Large aerobic engine, higher sustainable power, retained functional strength, improved relative power, and running-ready tissues.",
        },
        "sessions": session_refs,
        "phases": [
            {
                "phase_key": "PHASE-BALI-BASE",
                "phase_order": 1,
                "title": "Bali Hybrid Base",
                "intent": "build",
                "coach_note": "Eight labelled weeks. Week 8 includes day_order 8 and 9 spillover. Duration remains 8 weeks.",
            }
        ],
        "weeks": weeks,
        "adaptation_permissions": [],
        "protected_invariants": [
            {"id": "INV-BALI-TESTS-IMMUTABLE", "kind": "assessment_immutable", "target_ref": "ASM-BALI-BIKE-P20-W4", "description": "Benchmark sessions must not be automatically rewritten."},
        ],
        "assessments": assessments,
        "performance_evidence_requirements": [
            {"id": "EVD-BALI-P20", "comparison_identity_id": "CMP-BALI-BIKE-P20", "metric": "average_watts", "required": True},
            {"id": "EVD-BALI-ROW", "comparison_identity_id": "CMP-BALI-ROW-2K", "metric": "total_time", "required": True},
        ],
        "comparison_identities": [
            {"id": "CMP-BALI-BIKE-P20", "session_lineage_id": ids(4, 3, 1)["session_lineage_id"], "label": "BikeErg 20-min like-for-like"},
            {"id": "CMP-BALI-ROW-2K", "session_lineage_id": ids(4, 5, 1)["session_lineage_id"], "label": "2 km Row like-for-like"},
            {"id": "CMP-BALI-EFF", "session_lineage_id": ids(4, 7, 1)["session_lineage_id"], "label": "Fixed-power aerobic efficiency"},
            {"id": "CMP-BALI-FS-3RM", "session_lineage_id": ids(8, 7, 1)["session_lineage_id"], "label": "Front squat 3RM"},
            {"id": "CMP-BALI-WPU", "session_lineage_id": ids(8, 7, 1)["session_lineage_id"], "label": "Weighted pull-up"},
        ],
    }


def build_founder(sessions):
    weeks = []
    by_week = {}
    for item in sessions:
        by_week.setdefault(item["week"], []).append(item)
    for week in range(1, 9):
        days_map = {}
        for item in by_week[week]:
            days_map.setdefault(item["day"], []).append(item)
        days = []
        for day in sorted(days_map):
            day_sessions = []
            for item in sorted(days_map[day], key=lambda x: x["slot"]):
                day_sessions.append({
                    "title": item["title"],
                    "session_type": item["session_type"],
                    "estimated_duration_minutes": item["estimated_duration_minutes"],
                    "coach_notes": item["coach_notes"],
                    "blocks": item["blocks"],
                })
            days.append({
                "day_number": day,
                "display_name": DAY_NAMES[day],
                "is_rest_day": False,
                "sessions": day_sessions,
            })
        weeks.append({"week_number": week, "title": f"Week {week}", "days": days})
    return {
        "schema_version": 1,
        "programme": {
            "import_key": "founder-bali-hybrid-base-v1",
            "title": "Bali Hybrid Base",
            "code": LINEAGE,
            "description": "Internal / Lee-specific private 8-week hybrid base. 71 sessions. No running required. Not a public catalogue programme.",
            "objective": "Prepare to enter a later 16-week elite HYROX race-preparation phase.",
            "duration_weeks": 8,
            "sessions_per_week": 9,
        },
        "weeks": weeks,
    }


def build_manifest(sessions):
    counts = {}
    entries = []
    for item in sessions:
        counts[item["week"]] = counts.get(item["week"], 0) + 1
        entries.append({
            "id": item["session_key"],
            "week": item["week"],
            "day_order": item["day"],
            "session_order": item["slot"],
            "time_of_day": item["time_of_day"],
            "title": item["title"],
            "optional": item["optional"],
            "protocol_id": item["protocol_id"],
            "session_lineage_id": item["session_lineage_id"],
            "prescription_summary": item["prescription_summary"],
        })
    return {
        "programme": "Bali Hybrid Base",
        "lineage_code": LINEAGE,
        "version_number": VERSION,
        "library_scope": "coach_private",
        "public_catalogue": False,
        "duration_weeks": 8,
        "calendar_span_days": 58,
        "session_count": len(sessions),
        "sessions_by_week": {str(k): counts[k] for k in sorted(counts)},
        "source_document": "Cohort_Bali_8_Week_Hybrid_Base_Programme.docx",
        "start_date_when_assigned": "2026-09-26",
        "timezone_when_assigned": "Asia/Makassar",
        "sessions": entries,
    }


def main():
    sessions = all_sessions()
    assert len(sessions) == 71, len(sessions)
    counts = [sum(1 for s in sessions if s["week"] == w) for w in range(1, 9)]
    assert counts == [9, 9, 9, 8, 9, 9, 9, 9], counts
    PACKAGE_PATH.write_text(dump_yaml(build_package(sessions)))
    FOUNDER_PATH.write_text(dump_yaml(build_founder(sessions)))
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(build_manifest(sessions), indent=2) + "\n")
    print(f"wrote {PACKAGE_PATH}")
    print(f"wrote {FOUNDER_PATH}")
    print(f"wrote {MANIFEST_PATH}")
    print(f"sessions={len(sessions)} by_week={counts}")


if __name__ == "__main__":
    main()