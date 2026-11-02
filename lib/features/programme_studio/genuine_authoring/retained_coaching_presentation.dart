// Presentation-only mappings for exact retained source paragraphs. This is an
// explicit source-channel adapter, not a keyword filter or prose-based workout
// parser. Unknown/edited coaching text passes through unchanged. Full original
// text remains in the existing source, backups, exports and Advanced tools.
const retainedCoachingItems = <String, List<String>>{
  "Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.": [
    "5 minutes walking/marching",
    "10 bodyweight squats",
    "8 unloaded hinges",
    "8 scapular pull-ups OR shoulder-blade movements",
    "8 arm circles each direction",
    "First loaded lower-body pattern: 2–4 progressively loaded warm-up sets",
    "Each new upper-body pattern: 1–2 light sets as needed; no failure",
    "Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.",
  ],
  "Upper-body preparation only; 1–2 light sets per new upper-body pattern as needed, no failure. No lower-body lifting or squat/hinge warm-up inserted.":
      [
        "Upper-body preparation only",
        "1–2 light sets per new upper-body pattern as needed, no failure",
        "No lower-body lifting or squat/hinge warm-up inserted.",
      ],
  "3–5 minutes easy walking; retained proposed finish.": [
    "3–5 minutes easy walking",
  ],
  "Exact founder-selected standard and week-specific doses; full programme D8 review pending.":
      [],
  "Review order shown; within-session order remains part of D8 review. Preparation and warm-up sets are separate from working sets.":
      ["Preparation and warm-up sets are separate from working sets."],
  "Genuine selected draft. D8 full-programme content review pending.": [],
  "General draft; primary EASY work uses confirmed Zone 2. Quality requires explicit M2.3 selection/review/acceptance. No automatic fallback. ":
      [],
  "General draft; primary EASY work uses confirmed Zone 2. Quality requires explicit M2.3 selection/review/acceptance. No automatic fallback.":
      [],
  "General draft; primary EASY work uses confirmed Zone 2. Quality requires explicit M2.3 selection/review/acceptance. No automatic fallback. Founder-selected timed replacement. Warm-up exactly 13 minutes; no recovery after final work repetition. The 5-minute cooldown permits walking: it is included in programmed duration, but walking is not running volume. No fixed pace for relaxed accelerations or easy recoveries. Explicit M2.3 source selection and acceptance required. No extra mandatory walking phase is inserted before/after this exact replacement body.": [
    "Cooldown may be running or walking; walking counts towards duration, not running volume.",
    "No fixed pace for relaxed accelerations or easy recoveries.",
    "No extra mandatory walk before or after this workout.",
  ],
  "General draft; primary EASY work uses confirmed Zone 2. Quality requires explicit M2.3 selection/review/acceptance. No automatic fallback. Flat measured course or track preferred. Record elapsed time, exact distance, route/surface, weather, splits, RPE and environment. Disable auto-pause. First 2 km controlled; km 3–7 even sustainable effort; assess at 7 km and increase only if able; commit in final kilometre. Use training evidence to select pace. If unwell/in pain, do not force the assessment; retain an unavailable result and review timing.": [
    "Flat measured course or track preferred.",
    "Record elapsed time, exact distance, route/surface, weather, splits, RPE and environment. Disable auto-pause.",
    "First 2 km controlled; km 3–7 even sustainable effort; assess at 7 km and increase only if able; commit in final kilometre.",
    "Use training evidence to select pace. If unwell/in pain, do not force the assessment; retain an unavailable result and review timing.",
  ],
};

const retainedEffortGuidance = <String, String>{
  "Authored effort: EASY. RPE 3–4/10; full sentences, relaxed gait, slow down as needed; not fixed pace.":
      "RPE 3–4/10; full sentences, relaxed gait, slow down as needed; not fixed pace.",
  "Authored effort: STEADY. RPE 5–6/10; controlled moderate effort, short sentences, below threshold.":
      "RPE 5–6/10; controlled moderate effort, short sentences, below threshold.",
  "Authored effort: THRESHOLD. RPE 7/10 initially, up to 8 at the end; strong and repeatable, not a time trial; finish able to do one more repetition.":
      "RPE 7/10 initially, up to 8 at the end; strong and repeatable, not a time trial; finish able to do one more repetition.",
  "Authored effort: RECOVERY. RPE 2–3/10; very easy jog, walking allowed if needed.":
      "RPE 2–3/10; very easy jog, walking allowed if needed.",
  "Authored effort: STRIDE. RPE about 7–8, relaxed; smooth acceleration, quick running, never all-out sprint.":
      "RPE about 7–8, relaxed; smooth acceleration, quick running, never all-out sprint.",
  "Authored effort: RELAXED_ACCELERATION. ": "Relaxed acceleration",
  "Authored effort: VERY_EASY. ": "Very easy",
  "Authored effort: VERY_EASY_RUN_OR_WALK. ": "Very easy running or walking",
  "Authored effort: TEN_K. RPE about 7–8 early, at most 9 at end; current realistic 10K effort, repeatable output and controlled mechanics.":
      "RPE about 7–8 early, at most 9 at end; current realistic 10K effort, repeatable output and controlled mechanics.",
  "Authored effort: Best sustainable evenly paced effort; no early sprint. ":
      "Best sustainable evenly paced effort; no early sprint",
};

List<String> coachingItems(String? text) => text == null || text.trim().isEmpty
    ? const []
    : retainedCoachingItems[text] ?? [text];

String effortGuidance(String? notes) =>
    notes == null ? '' : retainedEffortGuidance[notes] ?? notes;
