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

main :: proc() {
  // Constants
  WIN: rl.Vector2 = {1280, 720}
  
  // Init Window
  rl.InitWindow(i32(WIN.x), i32(WIN.y), "An Outside Place")
  defer rl.CloseWindow()
  
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
  move_cam :: proc(camera: ^rl.Camera3D, target: ^[3]f32) {
    camera.position.x = target^.x
    camera.position.y = target^.y + 2.0
    camera.position.z = target^.z + 4.0
    camera.target.x = target^.x
    camera.target.y = target^.y
    camera.target.z = target^.z
  }
  
  // Game Vars
  world: #soa[dynamic]WorldEnvSOA
  world = make_soa(#soa[dynamic]WorldEnvSOA, 0, 100)
  defer delete_soa(world)
  append_soa(&world, WorldEnvSOA{
    name = "The Player",
    is_player = true, color = rl.Color {200,100,120,255},
    is_alive = true, health = 100,
  })
  append_soa(&world, WorldEnvSOA{
    name = "Blue",
    is_mob = true, pos = {10.0, 0.0, -5.0}, color = rl.BLUE,
    is_alive = true, health = 30,
  })
  append_soa(&world, WorldEnvSOA{
    name = "Green",
    is_mob = true, pos = {4.0, 0.0, -3.0}, color = rl.GREEN,
    is_alive = true, health = 50,
  })
  append_soa(&world, WorldEnvSOA{
    name = "Purple",
    is_mob = true, pos = {-8.0, 0.0, 2.0}, color = rl.DARKPURPLE,
    is_alive = true, health = 70,
  })
  player := &world[0]
  in_combat := false
  mob_combat := 0
  player_speed : f32 = 0.2
  player_move_dist : f32 = 0
  frametime : f32
  player_attack := ActionUnit {
    name = "Sword Attack",
    base_damage = 10,
    prep = 5, perform = 2, cool = 5
  }
  mob_attack := ActionUnit {
    name = "Bite",
    base_damage = 15,
    prep = 5, perform = 3, cool = 8
  }
  combat_timer := 0
  
  // Game Loop
  for !rl.WindowShouldClose() {
    for &thing in world {
      if thing.is_player || thing.is_mob {
        thing.prev_pos = thing.pos
      }
    }
    if !in_combat {
      // Move "Player"
      if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {player.pos.z -= player_move_dist}
      if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {player.pos.z += player_move_dist}
      if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {player.pos.x -= player_move_dist}
      if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {player.pos.x += player_move_dist}
      // Check Collision
      collision := false
      for &mob, i in world {
        if mob.is_mob && mob.is_alive {
          collision = rl.CheckCollisionBoxes(
            {player.pos - 0.5,player.pos + 0.5}, // Assumes Size is 1x1x1
            {mob.pos - 0.5, mob.pos + 0.5}
          )
          if collision {
            // println("Player Collided With", mob.pos)
            player.pos = player.prev_pos
            in_combat = true
            mob_combat = i
            break 
          }
        }
      }
    } else { // In Combat!
      mob := &world[mob_combat]
      if combat_timer == 0 {
        println("Player", player.name, "readies", player_attack.name)
        println("Mob", mob.name, "readies", mob_attack.name)
        combat_timer += 1
      } else {
        attacks := [?]^ActionUnit{ &player_attack, &mob_attack }
        fight_loop: for attack, i in attacks {
          stage_loop: for {
            print("Who", i, "Stage", attack.timer.stage)
            switch attack.timer.stage {
            case .Prep:
              if attack.prep == 0 {
                attack.timer.stage = .BlockingPrep
                // print("No Prep")
                continue stage_loop
              } else if attack.prep == attack.timer.seconds {
                attack.timer.stage = .BlockingPrep
                attack.timer.seconds = 0
              }
              print("Who", i, "timer", attack.timer.seconds)
              break stage_loop
            case .BlockingPrep:
              if attack.blocking_prep == 0 {
                attack.timer.stage = .Perform
                // print("No Blocking Prep")
                continue stage_loop
              } else if attack.blocking_prep == attack.timer.seconds {
                attack.timer.stage = .Perform
                attack.timer.seconds = 0
              } else { break stage_loop }
            case .Perform:
              // do stuff
              if i == 0 { // player
                println(player.name, "attacks", mob.name, "with", attack.name, "for", attack.base_damage, "damage.")
                if mob.health <= attack.base_damage {
                  mob.health = 0
                  mob.is_alive = false
                  println(mob.name, "has been defeated!")
                  in_combat = false
                  break fight_loop
                } else {
                  mob.health -= attack.base_damage / attack.perform
                  println(mob.name, "has", mob.health, "health.")
                }
              } else { // mob
                println(mob.name, "attacks", player.name, "with", attack.name, "for", attack.base_damage, "damage.")
                if player.health <= attack.base_damage {
                  player.health = 0
                  player.is_alive = false
                  println("YOU DIED!")
                  in_combat = false
                  break fight_loop
                } else {
                  player.health -= attack.base_damage / attack.perform
                  println(player.name, "has", player.health, "health.")
                }
              }
              if attack.perform == 0 || attack.perform == attack.timer.seconds {
                attack.timer.stage = .BlockingCooldown
                attack.timer.seconds = 0
              }
              break stage_loop
            case .BlockingCooldown:
              if attack.blocking_cool == 0 {
                attack.timer.stage = .Cooldown
                continue stage_loop
              } else if attack.blocking_cool == attack.timer.seconds {
                attack.timer.stage = .Cooldown
                attack.timer.seconds = 0
              }
              break stage_loop
            case .Cooldown:
              if attack.cool == attack.timer.seconds {
                attack.timer.stage = .Prep
                attack.timer.seconds = 0
              }
              break stage_loop
            }
          }
          print(".")
          attack.timer.seconds += 1
          combat_timer += 1
        }
      }
      if !mob.is_alive {
        in_combat = false
        mob_combat = 0
      }
    }
    // Move Camera
    move_cam(&camera, &player.pos)
    player_move_dist = player_speed / 60.0
    frametime = rl.GetFrameTime()
    // Render Phase
    { rl.BeginDrawing()
      defer rl.EndDrawing()
      rl.ClearBackground(rl.Color {50,20,20,255} )
      { rl.BeginMode3D(camera)
        defer rl.EndMode3D()
        draw_world(world[:])
      } // End 3D Mode
    } // End Draw Mode
  }
}

draw_world :: proc(world: #soa[]WorldEnvSOA) {
  for &thing in world {
    rl.DrawCubeV(thing.pos, {f32(1), f32(1), f32(1)}, thing.color)
  }
}

WorldEnvSOA :: struct {
  is_player: bool,
  is_mob: bool,
  is_object: bool,
  is_platform: bool,
  is_alive: bool,
  name: string,
  color: rl.Color,
  pos: rl.Vector3,
  prev_pos: rl.Vector3,
  health: u32,
  // need list of actions/spells etc
}

ActionUnit :: struct {
  timer: ActionTimer,
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

