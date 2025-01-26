package raumortis

make_action_tracker_list :: proc(action_trackers: []ActionTracker) -> ^[dynamic]ActionTracker {
  out := new([dynamic]ActionTracker)
  out^ = make([dynamic]ActionTracker,0,6)
  for at in action_trackers {
    append(out, at)
  }
  return out
}

ActionList :: [?]ActionUnit {
  ActionUnit {
    name = "No Action",
  },
  ActionUnit {
    name = "Sword Attack",
    base_damage = 10,
    prep = 3, perform = 2, cool = 2
  },
  ActionUnit {
    name = "Bite",
    base_damage = 15,
    prep = 5, perform = 3, cool = 8
  },
}

ActionTracker :: struct {
  id: u32, // id 0 should be a no-op, action list immutable
  focus: u32,
  timer: ActionTimer,
}

ActionUnit :: struct {
  name: string,
  prep: u32,
  blocking_prep: u32,
  perform: u32,
  blocking_cool: u32,
  cool: u32,
  immediate_cast: bool,
  max_dist: f32,
  base_damage: u32,
}

ActionStage :: enum {
  Prep,
  BlockingPrep,
  Perform,
  BlockingCooldown,
  Cooldown,
}

ActionTimer :: struct {
  seconds: u32,
  stage: ActionStage,
}


