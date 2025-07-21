package raumortis

import "core:fmt"
// import "core:math/linalg"
// import "core:os"
// import "core:slice"
// import "core:strings"
// import "core:encoding/json"
import "core:strconv"

import rl "vendor:raylib"
// import rlgl "vendor:raylib/rlgl"

print :: fmt.print
printf :: fmt.printf
println :: fmt.println
printfln :: fmt.printfln

main :: proc() {
  // Constants
  WIN: rl.Vector2 = {1280, 720}
  
  // Init Window
  rl.InitWindow(i32(WIN.x), i32(WIN.y), "An Outside Place")
  defer rl.CloseWindow()
  
  rl.SetTargetFPS(60)
  
  // Game Vars
  ctx := make_game_context()
  defer delete_game_context(ctx)
  append_soa(ctx.world,
    WorldEnvEntity{
      name = "The Player",
      is_player = true, is_cam_target = true, color = rl.Color {200,100,120,255},
      is_alive = true, health = 100,
      actions = make_action_tracker_list({ { id = 1 } }),
    },
    WorldEnvEntity{
      name = "Blue",
      is_mob = true, pos = {10.0, 0.0, -5.0}, color = rl.BLUE,
      is_alive = true, health = 30,
      actions = make_action_tracker_list({ { id = 2 } }),
    },
    WorldEnvEntity{
      name = "Green",
      is_mob = true, pos = {4.0, 0.0, -3.0}, color = rl.GREEN,
      is_alive = true, health = 50,
      actions = make_action_tracker_list({ { id = 2 } }),
    },
    WorldEnvEntity{
      name = "Purple",
      is_mob = true, pos = {-8.0, 0.0, 2.0}, color = rl.DARKPURPLE,
      is_alive = true, health = 70,
      actions = make_action_tracker_list({ { id = 2 } }),
    },
  )
  
  // wesoa, err := json.marshal(
  //   WorldEnvEntity{
  //     name = "Purple",
  //     is_mob = true, pos = {-8.0, 0.0, 2.0}, color = rl.DARKPURPLE,
  //     is_alive = true, health = 70,
  //     actions = make_action_tracker_list({ { id = 2 } }),
  //   }, {spec = .JSON5, pretty = true, use_enum_names = true})
  // if err == nil {
  //   printf("%s", wesoa)
  // } else {
  //   fmt.eprintfln("Unable to marshal JSON: %v", err)
  // }
  save_data, err := world_to_data(ctx.world)
  if err == nil {
    print(save_data)
  }
  loaded_data := data_to_world(save_data)
  
  player := &ctx.world[0]
  player_speed : f32 = 10.0
  player_move_dist : f32 = player_speed / 60.0
  TIC : f64 : 1.0 / 60.0
  TIC_MIN_TIME :: TIC * 0.99
  TIC_OVERTIME :: TIC * 1.2
  tic_counter: f64 = rl.GetTime()
  calc_timestamp: f64 = rl.GetTime()
  draw_timestamp: f64 = rl.GetTime()
  tic_ready := true
  
  // Game Loop
  game_loop: for !rl.WindowShouldClose() {
    if tic_ready {
      for &thing in ctx.world {
        if thing.is_player || thing.is_mob {
          thing.prev_pos = thing.pos
        }
      }
      if len(ctx.combatants) == 0 {
        // Move "Player"
        switch get_direction() {
        case .UpLt:
          player^.pos.z -= player_move_dist / 2.0
          player^.pos.x -= player_move_dist / 2.0
        case .UpRt:
          player^.pos.z -= player_move_dist / 2.0
          player^.pos.x += player_move_dist / 2.0
        case .DnLt:
          player^.pos.z += player_move_dist / 2.0
          player^.pos.x -= player_move_dist / 2.0
        case .DnRt:
          player^.pos.z += player_move_dist / 2.0
          player^.pos.x += player_move_dist / 2.0
        case .Up: player^.pos.z -= player_move_dist
        case .Dn: player^.pos.z += player_move_dist
        case .Lt: player^.pos.x -= player_move_dist
        case .Rt: player^.pos.x += player_move_dist
        case .NoOp: {}
        }
        // Check Collision
        check_for_collisions(&ctx)
      } else { // In Combat!
        process_combat_tic(&ctx)
      }
      // Move.studiostudio. Camera
      cam_follow_world_target(&ctx)
      calc_timestamp = write_calc_time(&ctx, draw_timestamp)
      tic_counter += TIC
      // Skip render if overtime
      calc_time := calc_timestamp - draw_timestamp
      if calc_time > TIC_OVERTIME {
        print("Overtime:", 1.0 / calc_time, ":: ")
        draw_timestamp = calc_timestamp
        continue game_loop
      }
      tic_ready = false
    }
    // Render Phase
    render(&ctx)
    // Only render next pass if undertime
    draw_timestamp = write_draw_time(&ctx, calc_timestamp, draw_timestamp)
    if draw_timestamp - tic_counter >= TIC_MIN_TIME {
      tic_ready = true
    }
  }
}

render :: proc(ctx: ^GameContext) {
  rl.BeginDrawing()
  defer rl.EndDrawing()
  rl.ClearBackground(rl.Color {50,20,20,255} )
  { rl.BeginMode3D(ctx.studio.camera)
    defer rl.EndMode3D()
    draw_world(ctx)
  } // End 3D Mode
  // No mode needed... I think
  draw_gui(ctx)
}

draw_gui :: proc(ctx: ^GameContext) {
  // Health and FPS and other garbage for the player to read
  rl.DrawText(rl.TextFormat("FPS: % 6.02f", ctx.fps), 50, 50, 20, rl.RED)
  // player := &ctx.world[get_active_player(ctx)]
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

check_for_collisions :: proc(ctx: ^GameContext) {
  ctx := ctx // explicit mutation
  player := &ctx.world[get_active_player(ctx)]
  collision := false
  for &mob, i in ctx.world {
    if mob.is_mob && mob.is_alive {
      collision = rl.CheckCollisionBoxes(
        {player.pos - 0.5,player.pos + 0.5}, // Assumes Size is 1x1x1
        {mob.pos - 0.5, mob.pos + 0.5},
      )
      if collision {
        // println("Player Collided With", mob.pos)
        player^.pos = player.prev_pos
        if player.is_alive {
          mob.actions[0].focus = 0 // 0 is the player atm
          player.actions[0].focus = u32(i)
          append(ctx.combatants, u32(0), u32(i)) // fixme: need to potentially add multiple combatants
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
cam_follow_world_target :: proc(ctx: ^GameContext) {
  target : ^[3]f32 = nil
  for &thing in ctx.world {
    if thing.is_cam_target {
      target = &thing.pos
    }
  }
  if target != nil {
    move_cam(&ctx.studio.camera, target)
  }
}

process_combat_tic :: proc(ctx: ^GameContext) { // In Combat!
  action_list := ActionList
  ctx := ctx
  fight_loop: for i in ctx.combatants {
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
              "against", action_focus.name,
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
              "against", action_focus.name,
            )
            println(
              entity.name, "attacks", action_focus.name,
              "for", action.action.base_damage, "damage over", action.perform,"seconds.",
            )
          }
          if action.perform == action_tracker.timer.seconds {
            entity.action_is_blocking = nil
            action_tracker.timer.stage = .BlockingCooldown
            action_tracker.timer.seconds = 0
            continue stage_loop
          }
          damage_this_tic := action.action.base_damage / action.perform
          if action.perform - action_tracker.timer.seconds == 1 {
            damage_this_tic += (action.action.base_damage % damage_this_tic)
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
              action_focus.name,"Health:", action_focus.health, ":",
            )
          }
          action_tracker.timer.seconds += 1
          break stage_loop
        case .BlockingCooldown:
          if action.blocking_cool != 0 && action_tracker.timer.seconds == 0 {
            entity.action_is_blocking = action_tracker.id
            println(
              entity.name, "is paralyzed after using", action.name,
              "for", action.blocking_cool, "seconds.",
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
              "for", action.cool, "seconds.",
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
  for i := 0; i < len(ctx.combatants); i += 1 {
    entity := &ctx.world[ctx.combatants[i]]
    if !entity.is_alive {
      if entity.is_player {
        clear(ctx.combatants)
        break
      } else {
        ordered_remove(ctx.combatants, i)
        i -= 1
      }
    }
    if len(ctx.combatants) < 2 {
      clear(ctx.combatants)
      break
    }
  }
}

write_calc_time :: proc(ctx: ^GameContext, end_of_last_frame: f64) -> f64 {
  ctx := ctx
  time := rl.GetTime()
  ctx.prev_calc_times[ctx.calc_time_ptr] = time - end_of_last_frame
  if ctx.calc_time_ptr < 119 {
    ctx.calc_time_ptr += 1
  } else {
    ctx.calc_time_ptr = 0
    gen_avg_calc_time(ctx)
    ctx.fps = 1.0 / (ctx.avg_calc_time + ctx.avg_draw_time) // ish...
  }
  return time
}
read_last_calc_time :: proc(ctx: ^GameContext) -> f64 {
  if ctx.calc_time_ptr == 0 {
    return ctx.prev_calc_times[119]
  } else {
    return ctx.prev_calc_times[ctx.calc_time_ptr - 1]
  }
}
gen_avg_calc_time :: proc(ctx: ^GameContext) {
  ctx := ctx
  avg : f64 = 0.0
  for n in ctx.prev_calc_times {
    avg += n
  }
  ctx.avg_calc_time = avg / 120.0
}
write_draw_time :: proc(ctx: ^GameContext, last_calc_timestamp, last_draw_timestamp: f64) -> f64 {
  ctx := ctx
  time := rl.GetTime()
  draw_start := last_draw_timestamp > last_calc_timestamp ? last_draw_timestamp : last_calc_timestamp
  ctx.prev_draw_times[ctx.draw_time_ptr] = time - draw_start
  if ctx.draw_time_ptr < 119 {
    ctx.draw_time_ptr += 1
  } else {
    ctx.draw_time_ptr = 0
    gen_avg_draw_time(ctx)
  }
  return time
}
read_last_draw_time :: proc(ctx: ^GameContext) -> f64 {
  if ctx.draw_time_ptr == 0 {
    return ctx.prev_draw_times[119]
  } else {
    return ctx.prev_draw_times[ctx.draw_time_ptr - 1]
  }
}
gen_avg_draw_time :: proc(ctx: ^GameContext) -> f64 {
  avg : f64 = 0.0
  for n in ctx.prev_draw_times {
    avg += n
  }
  return avg / 120.0
}

