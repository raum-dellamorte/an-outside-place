package raumortis

ActionTrackers :: [dynamic]ActionTracker

make_action_tracker_list :: proc(len := 0, cap := 6) -> ^[dynamic]ActionTracker {
  out := new([dynamic]ActionTracker)
  out^ = make([dynamic]ActionTracker,len,cap)
  return out
}

make_action_tracker_list_from_slice :: proc(action_trackers: []ActionTracker) -> ^[dynamic]ActionTracker {
  out := make_action_tracker_list()
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
    prep = 3, perform = 2, cool = 2,
    action = ActionAttack { damage_type = .PhysicalDamage, base_damage = 12, }
  },
  ActionUnit {
    name = "Bite",
    prep = 5, perform = 3, cool = 8,
    action = ActionAttack { damage_type = .PhysicalDamage, base_damage = 15, }
  },
  ActionUnit {
    name = "Claw",
    prep = 2, perform = 1, cool = 5,
    action = ActionAttack { damage_type = .PhysicalDamage, base_damage = 3, }
  },
  ActionUnit {
    name = "Stunned",
    blocking_cool = 10,
  },
  // ActionUnit {
  //   name = "Shield Bash",
  //   prep = 5, perform = 3, cool = 8,
  //   action = ActionSpell {  }
  // },
}

DamageEnum :: enum {
  PhysicalDamage,
  MagicalDamage,
}

ActionAttack :: struct {
  damage_type: DamageEnum,
  base_damage: u32,
  magic_damage: u32,
}

ActionSpell ::struct {
  effect: u32, // to be determined
  value: u32,
}

ActionType :: union {
  ActionAttack,
  ActionSpell,
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
  perform: u32, // Perform should be an enum with either doing simple damage or a set of instructions, or maybe even a proc???
  blocking_cool: u32,
  cool: u32,
  immediate_cast: bool, // do I need this?
  max_dist: f32,
  // action: ActionType,
  action: ActionAttack,
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


