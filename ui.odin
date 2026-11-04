package raumortis

import rl "vendor:raylib"

// Constants

COMBAT_LOG_W :: 600.0
COMBAT_LOG_H :: 260.0
COMBAT_MENU_W :: 500.0
COMBAT_MENU_H :: 260.0

// procs

new_combat_log :: proc() -> UiWindow {
  win_w := cast(f32)rl.GetScreenWidth()
  win_h := cast(f32)rl.GetScreenHeight()
  bounds := rl.Rectangle {
    x = win_w - COMBAT_LOG_W - 10.0,
    y = win_h - COMBAT_LOG_H - 10.0,
    width = COMBAT_LOG_W,
    height = COMBAT_LOG_H,
  }
  return UiWindow {
    win_w = win_w,
    win_h = win_h,
    bounds = bounds,
    txt_bounds = rl.Rectangle {
      x = bounds.x + 10.0,
      y = bounds.y + 10.0,
      width = bounds.width - 20.0,
      height = bounds.width -20.0,
    },
  }
}

new_combat_menu :: proc() -> UiWindow {
  win_w := cast(f32)rl.GetScreenWidth()
  win_h := cast(f32)rl.GetScreenHeight()
  bounds := rl.Rectangle {
    x = 10.0,
    y = win_h - COMBAT_MENU_H - 10.0,
    width = COMBAT_MENU_W,
    height = COMBAT_MENU_H,
  }
  return UiWindow {
    win_w = win_w,
    win_h = win_h,
    bounds = bounds,
    txt_bounds = rl.Rectangle {
      x = bounds.x + 10.0,
      y = bounds.y + 10.0,
      width = bounds.width - 20.0,
      height = bounds.width - 20.0,
    },
  }
}

draw_combat_log :: proc(ctx: ^GameContext) {
  if !ctx.should.draw_combat_log { return }
  cl : ^UiWindow = &ctx.combat_log
  rl.DrawRectangleRounded(cl.bounds, .15, 5, { 100, 100, 100, 190 } )
  // Odin is `for value, index in array ...` and not index, value
  for line, i in msg_page_lines(&ctx.msg_system) {
    txt := msg_read_line(&ctx.msg_system, line)
    txt_y := i32(cl.txt_bounds.y) + (cast(i32)i * 25)
    rl.DrawText(rl.TextFormat("%s", txt), i32(cl.txt_bounds.x), txt_y, 20, rl.WHITE)
  }
}

draw_combat_menu :: proc(ctx: ^GameContext) {
  if !ctx.should.draw_combat_menu { return }
  cm: ^UiWindow = &ctx.combat_menu
  rl.DrawRectangleRounded(cm.bounds, .15, 5, { 100, 100, 100, 190 } )
  // 
  {
    txt := "Sword Attack"
    txt_y := i32(cm.txt_bounds.y) //  + (cast(i32)i * 25)
    rl.DrawText(rl.TextFormat("%s", txt), i32(cm.txt_bounds.x), txt_y, 20, rl.PURPLE)
  }
}

update_combat_log_screen_coords :: proc(cl: ^UiWindow) {
  cl.win_w = cast(f32)rl.GetScreenWidth()
  cl.win_h = cast(f32)rl.GetScreenHeight()
  cl.bounds.x = cl.win_w - cl.bounds.width - 10.0
  cl.bounds.y = cl.win_h - cl.bounds.height - 10.0
  cl.txt_bounds.x = cl.bounds.x + 10.0
  cl.txt_bounds.y = cl.bounds.y + 10.0
}

UiWindow :: struct {
  win_w: f32,
  win_h: f32,
  bounds: rl.Rectangle,
  txt_bounds: rl.Rectangle,
}