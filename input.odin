package raumortis

import rl "vendor:raylib"

Direction :: enum{
  Up, UpLt, UpRt,
  Lt, Rt,
  Dn, DnLt, DnRt,
  // RotLt, RotRt,
  NoOp,
}

get_direction :: proc() -> Direction {
  switch {
  case (rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)) && (rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)): 
    return .UpLt
  case (rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)) && (rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT)):
    return .UpRt
  case (rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)) && (rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)): 
    return .DnLt
  case (rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)) && (rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT)):
    return .DnRt
  case rl.IsKeyDown(.W) || rl.IsKeyDown(.UP):
    return .Up
  case rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN):
    return .Dn
  case rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT):
    return .Lt
  case rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT):
    return .Rt
  }
  return .NoOp
}
