package raumortis

import rl "vendor:raylib"

Direction :: enum{
  Up, UpLt, UpRt,
  Lt, Rt,
  Dn, DnLt, DnRt,
  NoOp,
}
Rotation :: enum{
  RotLt, RotRt,
  NoOp,
}

get_direction :: proc() -> Direction {
  switch {
  case (rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)) && (rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)):
    return .NoOp
  case (rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)) && (rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT)):
    return .NoOp
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

get_rotation :: proc() -> Rotation {
  switch {
  case rl.IsKeyDown(.Q) && rl.IsKeyDown(.E): return .NoOp
  case rl.IsKeyDown(.Q): return .RotLt
  case rl.IsKeyDown(.E): return .RotRt
  }
  return .NoOp
}
