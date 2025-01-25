package raumortis

import "core:fmt"
// import "core:math/linalg"
// import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"

import rl "vendor:raylib"
// import rlgl "vendor:raylib/rlgl"

print :: fmt.print
printf :: fmt.printf
println :: fmt.println
parse_int :: strconv.parse_int

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

main :: proc() {
  // Constants
  WIN: rl.Vector2 = {1280, 720}
  
  // Init Window
  rl.InitWindow(i32(WIN.x), i32(WIN.y), "An Outside Place")
  defer rl.CloseWindow()
  
  // rl.SetTargetFPS(60)
  
  // // Shaders
  // rope_trail_shader := rl.LoadShader(
  //   "res/shaders/rope_trail_instanced.vs",
  //   "res/shaders/rope_trail_instanced.fs",
  // )
  // defer rl.UnloadShader(rope_trail_shader) // Segfaults if you don't defer rl.WindowClose()
  // rope_trail_shader.locs[SLI.MATRIX_MVP] = i32(
  //   rl.GetShaderLocation(rope_trail_shader, "mvp"),
  // )
  // rope_trail_shader.locs[SLI.MATRIX_MODEL] = i32(
  //   rl.GetShaderLocationAttrib(rope_trail_shader, "instance"),
  // )
  // rope_trail_shader_yOffset := rl.GetShaderLocation(rope_trail_shader, "yOffset")
  // rope_trail_shader.locs[SLI.MATRIX_VIEW] = i32(
  //   rl.GetShaderLocation(rope_trail_shader, "view"),
  // )
  // rope_trail_shader.locs[SLI.MATRIX_PROJECTION] = i32(
  //   rl.GetShaderLocation(rope_trail_shader, "projection"),
  // )
  // player_shader := rl.LoadShader("res/shaders/player.vs", "res/shaders/player.fs")
  // defer rl.UnloadShader(player_shader)
  // player_shader.locs[SLI.MATRIX_MVP] = i32(rl.GetShaderLocation(player_shader, "mvp"))
  // player_shader.locs[SLI.MATRIX_VIEW] = i32(rl.GetShaderLocation(player_shader, "view"))
  // player_shader.locs[SLI.MATRIX_PROJECTION] = i32(
  //   rl.GetShaderLocation(player_shader, "projection"),
  // )
  // // Shaders list
  // shaders: []rl.Shader = {player_shader, rope_trail_shader}
  
  // //Textures
  // textures := [?]rl.Texture {
  //   rl.LoadTexture("CubeTex.png"),
  //   rl.LoadTextureFromImage(rl.GenImageColor(256, 256, rl.RED)),
  //   rl.LoadTextureFromImage(rl.GenImageColor(256, 256, rl.ORANGE)),
  // }
  // // Load Models
  // player := rl.LoadModel("cube-1x1x1.obj")
  // _ = player // because reasons
  // // player_tex_bak := cube.materials[0].maps[MMI.ALBEDO].texture // Backup included Texture for no reason
  // cube := rl.LoadModel("cube-tex-atlas.obj")
  
  // // Material Assignments
  // player_assign := MatAssign{1, Tex[.Player], 1, 0.0}
  // rope_trail_assign := MatAssign{2, Tex[.Rope], 1, 0.0}
  
  // // Fix Cube Materials
  // cube_mat_helper := gen_materials(
  //   {player_assign, rope_trail_assign},// it seems you must keep the vars you point to
  //   shaders,                           // in scope. makes sense
  //   textures[:],
  //   colors,
  // )
  // defer delete_mat_helper(cube_mat_helper)
  
  // cube.materials = cube_mat_helper.pointer
  
  // Camera
  camera := rl.Camera3D {
    position   = [3]f32{0, 2, 4},
    target     = [3]f32{0, 0, 0},
    up         = [3]f32{0, 1, 0},
    fovy       = 90.0,
    projection = rl.CameraProjection.PERSPECTIVE,
  }
  
  // Game Vars
  ctx := make_game_context()
  defer delete_game_context(ctx)
  append_soa(ctx.world,
    WorldEnvSOA{
      name = "The Player",
      is_player = true, is_cam_target = true, color = rl.Color {200,100,120,255},
      is_alive = true, health = 100,
      actions = make_action_tracker_list({ { id = 1 } }),
    },
    WorldEnvSOA{
      name = "Blue",
      is_mob = true, pos = {10.0, 0.0, -5.0}, color = rl.BLUE,
      is_alive = true, health = 30,
      actions = make_action_tracker_list({ { id = 2 } }),
    },
    WorldEnvSOA{
      name = "Green",
      is_mob = true, pos = {4.0, 0.0, -3.0}, color = rl.GREEN,
      is_alive = true, health = 50,
      actions = make_action_tracker_list({ { id = 2 } }),
    },
    WorldEnvSOA{
      name = "Purple",
      is_mob = true, pos = {-8.0, 0.0, 2.0}, color = rl.DARKPURPLE,
      is_alive = true, health = 70,
      actions = make_action_tracker_list({ { id = 2 } }),
    }
  )
  player := ctx.world[0]
  combatants := make([dynamic]u32, 0, 50)
  defer delete(combatants)
  player_speed : f32 = 10.0
  player_move_dist : f32 = player_speed / 60.0
  TIC : f64 : 1.0 / 60.0
  TIC_MIN_TIME :: TIC * 0.9
  TIC_OVERTIME :: TIC * 1.2
  time_prev: f64 = rl.GetTime()
  tic_ready := true
  
  // Game Loop
  game_loop: for !rl.WindowShouldClose() {
    if tic_ready {
      for &thing in ctx.world {
        if thing.is_player || thing.is_mob {
          thing.prev_pos = thing.pos
        }
      }
      if len(&combatants) == 0 {
        // Move "Player"
        if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {player.pos.z -= player_move_dist}
        if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {player.pos.z += player_move_dist}
        if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {player.pos.x -= player_move_dist}
        if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {player.pos.x += player_move_dist}
        // Check Collision
        check_for_collisions(&ctx, &combatants)
      } else { // In Combat!
        process_combat_tic(&ctx, &combatants)
      }
      // Move Camera
      cam_follow_world_target(&camera, &ctx)
      tic_ready = false
    }
    // Skip render if overtime
    if rl.GetTime() - time_prev >= TIC_OVERTIME {
      // println("Overtime")
      time_prev += TIC
      continue game_loop
    }
    // Render Phase
    render(&camera, &ctx)
    // Only render next pass if undertime
    if rl.GetTime() - time_prev >= TIC_MIN_TIME {
      time_prev += TIC
      tic_ready = true
    }
  }
}

render :: proc(camera: ^rl.Camera3D, ctx: ^GameContext) {
  rl.BeginDrawing()
  defer rl.EndDrawing()
  rl.ClearBackground(rl.Color {50,20,20,255} )
  { rl.BeginMode3D(camera^)
    defer rl.EndMode3D()
    draw_world(ctx)
  } // End 3D Mode
  // No mode needed... I think
  draw_gui(ctx)
}

draw_gui :: proc(ctx: ^GameContext) {
  // Health and FPS and other garbage for the player to read
  rl.DrawText(rl.TextFormat("FPS: % 6.02f", 60.0), 50, 50, 20, rl.RED)
}

draw_world :: proc(ctx: ^GameContext) {
  for &thing in ctx.world {
    rl.DrawCubeV(thing.pos, {f32(1), f32(1), f32(1)}, thing.color)
  }
}

get_active_player :: proc(ctx: ^GameContext) -> int {
  for thing, i in ctx.world {
    if thing.is_player {
      return i
    }
  }
  return -1 // fixme: this should probably return an error
}

get_cam_target :: proc(ctx: ^GameContext) -> int {
  for thing, i in ctx.world {
    if thing.is_cam_target {
      return i
    }
  }
  return -1 // fixme: this should probably return an error
}

check_for_collisions :: proc(ctx: ^GameContext, combatants: ^[dynamic]u32) {
  ctx := ctx // explicit mutation
  combatants := combatants
  player := &ctx.world[get_active_player(ctx)]
  collision := false
  for &mob, i in ctx.world {
    if mob.is_mob && mob.is_alive {
      collision = rl.CheckCollisionBoxes(
        {player.pos - 0.5,player.pos + 0.5}, // Assumes Size is 1x1x1
        {mob.pos - 0.5, mob.pos + 0.5}
      )
      if collision {
        // println("Player Collided With", mob.pos)
        player^.pos = player.prev_pos
        if player.is_alive {
          mob.actions[0].focus = 0 // 0 is the player atm
          player.actions[0].focus = u32(i)
          append(combatants, u32(0), u32(i))
        }
        break
      }
    }
  }
}

move_cam :: proc(camera: ^rl.Camera3D, target: ^[3]f32) {
  camera.position.x = target^.x
  camera.position.y = target^.y + 2.0
  camera.position.z = target^.z + 4.0
  camera.target.x = target^.x
  camera.target.y = target^.y
  camera.target.z = target^.z
}
cam_follow_world_target :: proc(camera: ^rl.Camera3D, ctx: ^GameContext) {
  target : ^[3]f32 = nil
  for &thing in ctx.world {
    if thing.is_cam_target {
      target = &thing.pos
    }
  }
  if target != nil {
    move_cam(camera, target)
  }
}

process_combat_tic :: proc(ctx: ^GameContext, combatants: ^[dynamic]u32) { // In Combat!
  action_list := ActionList
  ctx := ctx
  fight_loop: for i in combatants {
    entity := &ctx.world[i]
    if !entity.is_alive { continue fight_loop }
    action_loop: for &action_tracker in entity.actions {
      if entity.action_is_blocking != nil && entity.action_is_blocking != action_tracker.id {
        continue action_loop
      }
      action_focus := &ctx.world[action_tracker.focus]
      stage_loop: for {
        action := &action_list[action_tracker.id]
        // print("Entity:", entity.name, " Stage:", entity.action_timer.stage)
        switch action_tracker.timer.stage {
        case .Prep:
          if action.prep != 0 && action_tracker.timer.seconds == 0 {
            println(entity.name, "prepares", action.name, "against", action_focus.name)
            action_tracker.timer.seconds += 1
          } else if action.prep == 0 {
            action_tracker.timer.stage = .BlockingPrep
            continue stage_loop
          } else if action.prep == action_tracker.timer.seconds {
            action_tracker.timer.stage = .BlockingPrep
            action_tracker.timer.seconds = 0
          } else {
            action_tracker.timer.seconds += 1
            // print(
            //   ":", entity.name, "is preparing", action.name,
            //   "for", action.prep - entity.action_timer.seconds, "more seconds:"
            // )
          }
          break stage_loop
        case .BlockingPrep:
          if action.blocking_prep != 0 && action_tracker.timer.seconds == 0 {
            entity.action_is_blocking = action_tracker.id
            println(
              entity.name, "focuses solely on", action.name,
              "against", action_focus.name
            )
            action_tracker.timer.seconds += 1
          } else if action.blocking_prep == 0 {
            action_tracker.timer.stage = .Perform
            continue stage_loop
          } else if action.blocking_prep == action_tracker.timer.seconds {
            entity.action_is_blocking = nil
            action_tracker.timer.stage = .Perform
            action_tracker.timer.seconds = 0
          } else {
            action_tracker.timer.seconds += 1
            // print(
            //   ":", entity.name, "focuses on", action.name, 
            //   "for", action.blocking_prep - entity.action_timer.seconds, "more seconds:"
            // )
          }
          break stage_loop
        case .Perform:
          if action.perform != 0 && action_tracker.timer.seconds == 0 {
            entity.action_is_blocking = action_tracker.id
            println(
              entity.name, "uses", action.name,
              "against", action_focus.name
            )
            println(
              entity.name, "attacks", action_focus.name,
              "for", action.base_damage, "damage over", action.perform,"seconds."
            )
          }
          if action.perform == action_tracker.timer.seconds {
            entity.action_is_blocking = nil
            action_tracker.timer.stage = .BlockingCooldown
            action_tracker.timer.seconds = 0
            continue stage_loop
          }
          damage_this_tic := action.base_damage / action.perform
          if action.perform - action_tracker.timer.seconds == 1 {
            damage_this_tic += (action.base_damage % damage_this_tic)
          }
          if action_focus.health <= damage_this_tic {
            action_focus.health = 0
            action_focus.is_alive = false
            if action_focus.is_player {
              println("You were defeated by", entity.name)
              println("YOU DIED!")
            } else {
              println(action_focus.name, "has been defeated by", entity.name,"!")
            }
            //
            // entity.action_timer.seconds = 0 // maybe???
            break fight_loop
          } else {
            action_focus.health -= damage_this_tic
            println(
              action_focus.name,
              "took", damage_this_tic,"damage.")
            println(
              action_focus.name,"Health:", action_focus.health, ":"
            )
          }
          action_tracker.timer.seconds += 1
          break stage_loop
        case .BlockingCooldown:
          if action.blocking_cool != 0 && action_tracker.timer.seconds == 0 {
            entity.action_is_blocking = action_tracker.id
            println(
              entity.name, "is paralyzed after using", action.name,
              "for", action.blocking_cool, "seconds."
            )
            action_tracker.timer.seconds += 1
          } else if action.blocking_cool == 0 {
            action_tracker.timer.stage = .Cooldown
            continue stage_loop
          } else if action.blocking_cool == action_tracker.timer.seconds {
            println(entity.name, "recovers from paralysis induced by", action.name, ".")
            entity.action_is_blocking = nil
            action_tracker.timer.stage = .Cooldown
            action_tracker.timer.seconds = 0
          } else {
            action_tracker.timer.seconds += 1
          }
          break stage_loop
        case .Cooldown:
          if action.cool != 0 && action_tracker.timer.seconds == 0 {
            println(
              entity.name, "cannot use", action.name,
              "for", action.cool, "seconds."
            )
            action_tracker.timer.seconds += 1
          } else if action.cool == action_tracker.timer.seconds {
            action_tracker.timer.stage = .Prep
            action_tracker.timer.seconds = 0
          } else {
            action_tracker.timer.seconds += 1
          }
          break stage_loop
        }
      }
    }
  }
  // Bring out your dead
  for i := 0; i < len(combatants); i += 1 {
    entity := &ctx.world[combatants[i]]
    if !entity.is_alive {
      if entity.is_player {
        clear(combatants)
        break
      } else {
        ordered_remove(combatants, i)
        i -= 1
      }
    }
    if len(combatants) < 2 {
      clear(combatants)
      break
    }
  }
}

GameContext :: struct {
  world: ^#soa[dynamic]WorldEnvSOA,
  prev_frame_times: [120]f64,
  frame_time_ptr: int,
  // I'm sure there will be other things to keep track of
}
make_game_context :: proc() -> GameContext {
  world := new(#soa[dynamic]WorldEnvSOA)
  world^ = make_soa(#soa[dynamic]WorldEnvSOA, 0, 100)
  prev_frame_times := [120]f64{0..<120 = 60.0}
  return GameContext{
    world = world,
    prev_frame_times = prev_frame_times,
    frame_time_ptr = 0,
  }
}
delete_game_context :: proc(game_context: GameContext) {
  ctx := game_context
  world := ctx.world^
  // ctx.world = nil
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

ActionTracker :: struct {
  id: u32, // id 0 should be a no-op, action list immutable
  focus: u32,
  timer: ActionTimer,
}

make_action_tracker_list :: proc(action_trackers: []ActionTracker) -> ^[dynamic]ActionTracker {
  out := new([dynamic]ActionTracker)
  out^ = make([dynamic]ActionTracker,0,6)
  for at in action_trackers {
    append(out, at)
  }
  return out
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
