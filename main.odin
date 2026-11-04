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

// rl :: raylib

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
  _ctx := make_game_context()
  defer delete_game_context(_ctx)
  ctx := &_ctx
  world_file := #load("res/data/world", string)
  data_to_world(&ctx.world, world_file)
  // For testing purposes, print out the world loaded from the world file
  save_data, err := world_to_data(ctx.world)
  if err == nil {
    print(save_data)
  }
  
  // Pre-game setup
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
  autoscroll := true
  
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
        check_for_collisions(ctx)
      } else { // In Combat!
        combat_menu(ctx)
        process_combat_tic(ctx)
      }
      for &thing in ctx.world {
        if !thing.is_alive && thing.color.a > 25 {
          r := thing.color.a - 25
          s : u8 = 4
          thing.color.a -= r > s ? s : 1
        }
      }
      // universal user input
      switch {
      case rl.IsKeyPressed(.T) : { ctx^.should.draw_combat_log = !ctx.should.draw_combat_log }
      case rl.IsKeyPressed(.TAB) : { ctx^.should.draw_combat_menu = !ctx.should.draw_combat_menu }
      }
      // if mouse is inside combat log bounds
      // check for and apply scrolling
      mouse_pos := rl.GetMousePosition()
      if rl.CheckCollisionPointRec(mouse_pos, ctx.combat_log.bounds) {
        autoscroll = false // don't autoscroll when the mouse is in the combat_log
        wheel := rl.GetMouseWheelMove()
        msg_scroll(&ctx.msg_system, int(wheel))
      } else if !autoscroll {
        autoscroll = true // resume autoscroll
      }
      // Move Camera
      cam_follow_world_target(ctx)
      calc_timestamp = write_calc_time(ctx, draw_timestamp)
      tic_counter += TIC
      // Skip render if overtime
      calc_time := calc_timestamp - draw_timestamp
      if calc_time > TIC_OVERTIME {
        print("Overtime:", 1.0 / calc_time, ":: ")
        draw_timestamp = calc_timestamp
        continue game_loop
      }
      tic_ready = false
      ctx^.tic_ready = true
      ctx^.tic_counter += 1
		  if ctx.tic_counter % 5 == 0 {
        if autoscroll && !msg_on_last_page(&ctx.msg_system) {
          msg_next(&ctx.msg_system)
        }
		  }
      rebuild_page_idcs(&ctx.msg_system)
    }
    // Render Phase
    render(ctx)
    // Only render next pass if undertime
    draw_timestamp = write_draw_time(ctx, calc_timestamp, draw_timestamp)
    if draw_timestamp - tic_counter >= TIC_MIN_TIME {
      tic_ready = true
    }
    ctx^.tic_ready = false
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
  draw_combat_log(ctx)
  draw_combat_menu(ctx)
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
          append(&ctx.combatants, u32(0), u32(i)) // fixme: need to potentially add multiple combatants
                                                  // maybe add_team_to_combatants(ctx, player)
                                                  //       add_team_to_combatants(ctx, &mob)
          select_first_target(ctx, &mob, .Enemy)
          select_first_target(ctx, player, .Enemy)
        }
        ctx^.should.draw_combat_log = true
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

combat_menu :: proc(ctx: ^GameContext) {
  if !ctx.should.wait_for_player { return }
  action_list := ActionList
  ctx := ctx
  // Need a player menu struct in the GameContext.
  // Use the switch statement to manipulate the state
  // of the menu.
  switch get_menu_input() {
  case .Up:
  case .Dn:
  case .Lt:
  case .Rt:
  case .Select:
    // If the selected thing is an action, add that action
    // to the player's action slots.
    // If it's a submenu, enter the submenu.
    // Temporarily, we can just assign Sword Attack and
    // stop displaying the menu.
    player := &ctx.world[0]
    select_first_target(ctx, player, .Enemy)
    ctx.should.draw_combat_menu = false
    ctx.should.wait_for_player = false
  case .Cancel:
  case .NoOp:
  }
}

process_combat_tic :: proc(ctx: ^GameContext) { // In Combat!
  if ctx.should.wait_for_player { return }
  action_list := ActionList
  ctx := ctx
  fight_loop: for i in ctx.combatants {
    entity := &ctx.world[i]
    if !entity.is_alive { continue fight_loop }
    if cast(u32)len(entity.action_slots) < entity.max_action_slots {
      select_next_action(ctx, entity)
      if ctx.should.wait_for_player { return }
    }
    action_loop: for &action_tracker, action_i in entity.action_slots {
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
            msg_add(&ctx.msg_system, entity.name, "prepares", action.name, "against", action_focus.name)
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
            msg_add(&ctx.msg_system,
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
            msg_add(&ctx.msg_system,
              entity.name, "uses", action.name,
              "against", action_focus.name,
            )
            msg_add(&ctx.msg_system,
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
          if action_focus.is_alive {
            damage_this_tic := action.action.base_damage / action.perform
            if action.perform - action_tracker.timer.seconds == 1 {
              damage_this_tic += (action.action.base_damage % damage_this_tic)
            }
            if action_focus.health <= damage_this_tic {
              action_focus.health = 0
              action_focus.is_alive = false
              if action_focus.is_player {
                msg_add(&ctx.msg_system, "You were defeated by", entity.name)
                msg_add(&ctx.msg_system, "YOU DIED!")
              } else {
                // println("defeat:\n",&ctx.msg_system._data)
                msg_add(&ctx.msg_system, action_focus.name, "has been defeated by", entity.name,"!")
                msg_add(&ctx.msg_system, "<--+===+-->")
              }
            } else {
              action_focus.health -= damage_this_tic
              msg_add(&ctx.msg_system,
                action_focus.name,
                "took", damage_this_tic,"damage.")
              msg_add(&ctx.msg_system,
                action_focus.name,"Health:", action_focus.health, ":",
              )
            }
          }
          action_tracker.timer.seconds += 1
          break stage_loop
        case .BlockingCooldown:
          if action.blocking_cool != 0 && action_tracker.timer.seconds == 0 {
            entity.action_is_blocking = action_tracker.id
            msg_add(&ctx.msg_system,
              entity.name, "is paralyzed after using", action.name,
              "for", action.blocking_cool, "seconds.",
            )
            action_tracker.timer.seconds += 1
          } else if action.blocking_cool == 0 {
            action_tracker.timer.stage = .Cooldown
            continue stage_loop
          } else if action.blocking_cool == action_tracker.timer.seconds {
            msg_add(&ctx.msg_system, entity.name, "recovers from paralysis induced by", action.name, ".")
            entity.action_is_blocking = nil
            action_tracker.timer.stage = .Cooldown
            action_tracker.timer.seconds = 0
          } else {
            action_tracker.timer.seconds += 1
          }
          break stage_loop
        case .Cooldown:
          if action.cool != 0 && action_tracker.timer.seconds == 0 {
            msg_add(&ctx.msg_system,
              entity.name, "cannot use", action.name,
              "for", action.cool, "seconds.",
            )
            action_tracker.timer.seconds += 1
          } else if action.cool == action_tracker.timer.seconds {
            action_tracker.timer.stage = .Complete
            action_tracker.timer.seconds = 0
          } else {
            action_tracker.timer.seconds += 1
          }
          break stage_loop
        case .Complete:
          ordered_remove(&entity.action_slots, action_i)
          break stage_loop
        }
      }
    }
  }
  // Bring out your dead
  player := &ctx.world[0]
  combat_ended := false
  for i := 0; i < len(ctx.combatants); i += 1 {
    entity := &ctx.world[ctx.combatants[i]]
    if !entity.is_alive {
      clear(&entity.action_slots)
      if entity.is_player {
        clear(&ctx.combatants)
        break
      } else {
        flush: for {
          if j, ok := get_action_slot_from_focus(&player.action_slots, ctx.combatants[i]); ok {
            unordered_remove(&player.action_slots, j)
          } else { break flush }
        }
        ordered_remove(&ctx.combatants, i)
        i -= 1
      }
    }
    if len(ctx.combatants) < 2 {
      // in the future we need to check if only allies remain alive, unsurrendered.
      // it might be fun to have an ally surrender as a distraction? maybe taking them prisoner
      // takes an enemy's focus off the battle? If you continue to aggress, depending on the
      // temperment or ruthlessness of the enemy, they'll either use the surrendered ally as a
      // hostage or leave them locked up to go fight, giving the ally a chance to pick the lock
      // and escape. Too much ambition...
      combat_ended = true;
      break
    }
  }
  if combat_ended {
    clear(&player.action_slots)
    clear(&ctx.combatants)
  }
}

select_next_action :: proc(ctx: ^GameContext, entity: #soa ^WorldEnvSOA) {
  if entity.is_player {
    ctx^.should.wait_for_player = true
    ctx^.should.draw_combat_menu = true
    append(&entity.action_slots, ActionTracker { id = 1, focus = get_current_target(ctx,entity) } )
  } else {
    // At the moment, focus == 0 means that the player
    // is the focus so not declaring the focus here
    // inits the value at zero, and so we don't have
    // to specify the focus yet.
    append(&entity.action_slots, ActionTracker { id = 2, focus = get_current_target(ctx,entity) } )
  }
}

get_current_target :: proc(ctx: ^GameContext, entity: #soa ^WorldEnvSOA) -> u32 {
  return ctx.combatants[entity.current_target] // fixme: add validation checking
}

get_action_slot_from_focus :: proc(action_slots: ^ActionTrackers, focus_id: u32) -> (int, bool) {
  #reverse for action, i in action_slots {
    if action.focus == focus_id { return i, true }
  }
  return -1, false
}

select_first_target :: proc(ctx: ^GameContext, entity: #soa ^WorldEnvSOA, target_type: TargetType) {
  // println("select_first_target: combatants ", ctx.combatants[:])
  for target, i in ctx.combatants {
    switch target_type {
    case .All:
      entity^.current_target = cast(u32)i
      return
    case .Enemy:
      if ctx.world[target].team != entity.team {
        entity^.current_target = cast(u32)i
        // println("select_first_target: target ", i, target)
        return
      }
    case .Team:
      if ctx.world[target].team == entity.team {
        entity^.current_target = cast(u32)i
        return
      }
    }
  }
  // println("select_first_target: no target")
  return
}

select_next_target :: proc(ctx: ^GameContext, entity: #soa ^WorldEnvSOA, target_type: TargetType) {
  team := entity.team
  target := entity.current_target
  l := cast(u32)len(ctx.combatants)
  for _ in 0..<l {
    target = (target + 1) % l 
    target_ent := &ctx.world[target]
    switch target_type {
    case .All:
      entity.current_target = target
      return
    case .Enemy:
      if target_ent.team != team {
        entity.current_target = target
        return
      }
    case .Team:
      if target_ent.team == team {
        entity.current_target = target
        return
      }
    }
  }
  return
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
