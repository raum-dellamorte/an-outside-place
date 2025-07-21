package raumortis

import rl "vendor:raylib"

make_game_context :: proc() -> GameContext {
  camera := rl.Camera3D {
    position   = [3]f32{0, 2, 4},
    target     = [3]f32{0, 0, 0},
    up         = [3]f32{0, 1, 0},
    fovy       = 90.0,
    projection = rl.CameraProjection.PERSPECTIVE,
  }
  world := make_world_env_soa()
  combatants := new([dynamic]u32)
  combatants^ = make([dynamic]u32, 0, 50)
  prev_calc_times := [120]f64{0..<120 = 60.0}
  prev_draw_times := [120]f64{0..<120 = 60.0}
  return GameContext{
    world = world,
    camera = camera,
    combatants = combatants,
    prev_calc_times = prev_calc_times,
    calc_time_ptr = 0,
    prev_draw_times = prev_draw_times,
    draw_time_ptr = 0,
  }
}

make_world_env_soa :: proc() -> (world: ^WorldEnvSOA) {
  world  = new(WorldEnvSOA)
  world^ = make_soa(WorldEnvSOA, 0, 100)
  return
}

GameContext :: struct {
  camera: rl.Camera3D,
  world: ^WorldEnvSOA,
  combatants: ^[dynamic]u32,
  prev_calc_times: [120]f64,
  calc_time_ptr: int,
  avg_calc_time: f64,
  prev_draw_times: [120]f64,
  draw_time_ptr: int,
  avg_draw_time: f64,
  fps: f64,
  
  // I'm sure there will be other things to keep track of
}
delete_game_context :: proc(game_context: GameContext) {
  ctx := game_context
  world := ctx.world^
  combatants := ctx.combatants^
  delete(combatants)
  delete_world(world)
}


WorldEnvSOA :: #soa[dynamic]WorldEnvEntity
  
WorldEnvEntity :: struct {
  name: string `json:"name"`,
  is_cam_target: bool `json:"is_cam_target"`,
  is_player: bool `json:"is_player"`,
  is_mob: bool `json:"is_mob"`,
  is_object: bool `json:"is_object"`,
  is_platform: bool `json:"is_platform"`,
  is_alive: bool `json:"is_alive"`,
  action_is_blocking: Maybe(u32) `json:"action_is_blocking"`,
  color: rl.Color `json:"color"`,
  pos: rl.Vector3 `json:"pos"`,
  rot: rl.Vector3 `json:"rot"`,
  prev_pos: rl.Vector3 `json:"prev_pos"`,
  health: u32 `json:"health"`,
  actions: ^ActionTrackers `json:"actions"`,
}
delete_world :: proc(world: WorldEnvSOA) {
  for &thing in world {
    if thing.actions != nil {
      actions := thing.actions^
      thing.actions = nil
      delete(actions)
    }
  }
  delete_soa(world)
}

