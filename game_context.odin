package raumortis

import rl "vendor:raylib"

make_game_context :: proc() -> GameContext {
  world := new(#soa[dynamic]WorldEnvSOA)
  world^ = make_soa(#soa[dynamic]WorldEnvSOA, 0, 100)
  camera := rl.Camera3D {
    position   = [3]f32{0, 2, 4},
    target     = [3]f32{0, 0, 0},
    up         = [3]f32{0, 1, 0},
    fovy       = 90.0,
    projection = rl.CameraProjection.PERSPECTIVE,
  }
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

GameContext :: struct {
  world: ^#soa[dynamic]WorldEnvSOA,
  camera: rl.Camera3D,
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
  // ctx.world = nil
  combatants := ctx.combatants^
  delete(combatants)
  delete_world(world)
}

WorldEnvSOA :: struct {
  is_cam_target: bool,
  is_player: bool,
  is_mob: bool,
  is_object: bool,
  is_platform: bool,
  is_alive: bool,
  action_is_blocking: Maybe(u32),
  name: string,
  color: rl.Color,
  pos: rl.Vector3,
  rot: rl.Vector3,
  prev_pos: rl.Vector3,
  health: u32,
  actions: ^[dynamic]ActionTracker,
}
delete_world :: proc(world: #soa[dynamic]WorldEnvSOA) {
  for &thing in world {
    if thing.actions != nil {
      actions := thing.actions^
      thing.actions = nil
      delete(actions)
    }
  }
  delete_soa(world)
}

