package raumortis

import rl "vendor:raylib"

ShaderDir :: "res/shaders/"

make_game_context :: proc() -> GameContext {
  world := make_world_env_soa()
  studio := gen_studio()
  combatants := new([dynamic]u32)
  combatants^ = make([dynamic]u32, 0, 50)
  prev_calc_times := [120]f64{0..<120 = 60.0}
  prev_draw_times := [120]f64{0..<120 = 60.0}
  return GameContext{
    world = world,
    studio = studio,
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

gen_studio :: proc() -> Studio { // maybe take a Config struct?
  // Camera
  camera := rl.Camera3D {
    position   = [3]f32{0, 2, 4},
    target     = [3]f32{0, 0, 0},
    up         = [3]f32{0, 1, 0},
    fovy       = 90.0,
    projection = rl.CameraProjection.PERSPECTIVE,
  }
  // Shaders
  shaders := make_shaders_list()
  instanced := get_shader_set("instanced")
  defer rl.UnloadShader(instanced.shader) // Segfaults if you don't defer rl.WindowClose()
  instanced.shader.locs[SLI.MATRIX_MVP] = i32(
    rl.GetShaderLocation(instanced.shader, "mvp"),
  )
  instanced.shader.locs[SLI.MATRIX_MODEL] = i32(
    rl.GetShaderLocationAttrib(instanced.shader, "instance"),
  )
  _instanced_shader_yOffset := rl.GetShaderLocation(instanced.shader, "yOffset")
  instanced.shader.locs[SLI.MATRIX_VIEW] = i32(
    rl.GetShaderLocation(instanced.shader, "view"),
  )
  instanced.shader.locs[SLI.MATRIX_PROJECTION] = i32(
    rl.GetShaderLocation(instanced.shader, "projection"),
  )
  append(shaders, instanced)
    
  // //Textures
  // textures := gen_texture_list()
  // // Load Models
  // cube := rl.LoadModel("res/models/cube.instanced.obj")
  
  // // Material Assignments
  // instanced_assign := MatAssign{2, {"cube-color-atlas"}, 1, 0.0}
  
  // // Fix Cube Materials
  // cube_mat_helper := gen_materials(
  //   {instanced_assign, },// it seems you must keep the vars you point to
  //   shaders,                           // in scope. makes sense
  //   textures[:],
  //   {},
  // )
  // defer delete_mat_helper(cube_mat_helper)
  
  // cube.materials = cube_mat_helper.pointer
  
  return Studio {
    camera  = camera,
    shaders = shaders,
  }
}

GameContext :: struct {
  world: ^WorldEnvSOA,
  studio: Studio,
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
  delete_studio(ctx.studio)
  delete(combatants)
  delete_world(world)
}

Studio :: struct {
  camera: rl.Camera3D,
  shaders: ^[dynamic]ShaderSet,
}
delete_studio :: proc(studio: Studio) {
  _studio := studio
  shaders := _studio.shaders^
  delete(shaders)
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

ShaderSet :: struct {
  name: string,
  shader: rl.Shader,
}

make_shaders_list :: proc() -> ^[dynamic]ShaderSet {
  out := new([dynamic]ShaderSet)
  out^ = make([dynamic]ShaderSet,0,10)
  return out
}

get_shader_set :: proc(name: string) -> ShaderSet {
  _vert := []string { ShaderDir, name, ".vs"}
  _frag := []string { ShaderDir, name, ".fs"}
  vert := cat_to_cstr(_vert)
  frag := cat_to_cstr(_frag)
  shader := rl.LoadShader(vert, frag)
  return ShaderSet {
    name = name,
    shader = shader,
  }
}


