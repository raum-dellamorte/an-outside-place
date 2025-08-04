package raumortis

import "core:fmt"
import "core:io"
import "core:reflect"
import "base:runtime"
import "core:text/regex"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

wprint                     :: fmt.wprint
wprintf                    :: fmt.wprintf
wprintln                   :: fmt.wprintln
wprintfln                  :: fmt.wprintfln
sbprint                    :: fmt.sbprint

type_info_base             :: runtime.type_info_base
Type_Info                  :: runtime.Type_Info
Type_Info_Array            :: runtime.Type_Info_Array
Type_Info_Boolean          :: runtime.Type_Info_Boolean
Type_Info_Enum             :: runtime.Type_Info_Enum
Type_Info_Enum_Value       :: runtime.Type_Info_Enum_Value
Type_Info_Float            :: runtime.Type_Info_Float
Type_Info_Integer          :: runtime.Type_Info_Integer
Type_Info_Named            :: runtime.Type_Info_Named
Type_Info_Pointer          :: runtime.Type_Info_Pointer
Type_Info_Rune             :: runtime.Type_Info_Rune
Type_Info_String           :: runtime.Type_Info_String

struct_field_names         :: reflect.struct_field_names
struct_field_count         :: reflect.struct_field_count
struct_field_at            :: reflect.struct_field_at
struct_field_by_name       :: reflect.struct_field_by_name
struct_field_value         :: reflect.struct_field_value
struct_field_value_by_name :: reflect.struct_field_value_by_name
is_array                   :: reflect.is_array
is_enum                    :: reflect.is_enum
is_boolean                 :: reflect.is_boolean
is_string                  :: reflect.is_string

parse_f32                  :: strconv.parse_f32
parse_f64                  :: strconv.parse_f64
parse_uint                 :: strconv.parse_uint
parse_int                  :: strconv.parse_int

unsafe_string_to_cstring   :: strings.unsafe_string_to_cstring
concatenate                :: strings.concatenate

world_to_data :: proc(
  world: ^WorldEnvSOA, allocator := context.allocator, loc := #caller_location
) -> (data: string, err: Maybe(u32)) {
  b := strings.builder_make(allocator, loc)
  defer if err != nil {
    strings.builder_destroy(&b)
  }
  w := strings.to_writer(&b) // I'll write my own format! With strippers! And blackjack!
  fn := struct_field_count(WorldEnvEntity)
  for &thing in world {
    // Non boolean named fields
    iostr_open(w, "Entity")
    for f in 0..<fn {
      fld := struct_field_at(WorldEnvEntity, f)
      switch {
      case is_string(fld.type):
        val := struct_field_value(thing, fld).(string)
        if val == "" { continue }
        iostr_indent(w)
        wprintfln(w, "%v: %v", fld.name, val)
      case fld.type == type_info_of(u32):
        val := struct_field_value(thing, fld).(u32)
        if val == 0 { continue }
        iostr_indent(w)
        wprintfln(w, "%v: %v", fld.name, val)
      case fld.type == type_info_of(Maybe(u32)):
        val := struct_field_value(thing, fld).(Maybe(u32)).? or_continue
        iostr_indent(w)
        wprintfln(w, "%v: %v", fld.name, val)
      // case fld.type == type_info_of(rl.Color):
      //   val := struct_field_value(thing, fld).(rl.Color)
      //   if val == cast(rl.Color){} { continue }
      //   write_indent(w)
      //   wprintfln(w, "%v: Color{{r:%i, g:%i, b:%i, a:%i}}", fld.name, val.r, val.g, val.b, val.a)
      case is_array(fld.type): // fld.type == type_info_of(rl.Vector3):
        a_ptr := rawptr(uintptr(any(thing).data) + fld.offset)
        iostr_indent(w)
        wprintfln(w, "%v: [", fld.name)
        indent_ctl(.IncIndent)
        iostr_indent(w)
        iostr_for_each_raw(w, a_ptr, fld.type, proc(w: io.Stream, v: any) {
          wprintf(w, "%v,", v)
        })
        // case runtime.Type_Info_Named:
        //   a := cast([^]type_of(v.elem.id))a_ptr
        //   for i in 0..<c {
        //     wprintf(w, "%v,", a[i])
        //   }
        // }
        wprintln(w)
        indent_ctl(.DecIndent)
        iostr_indent(w)
        wprintln(w, "]")
        // val := struct_field_value(thing, fld).(rl.Vector3)
        // if val == cast(rl.Vector3){} { continue }
        // write_indent(w)
        // wprintfln(w, "%v: Vector3{{x:%v, y:%v, z:%v}}", fld.name, val.x, val.y, val.z)
      case reflect.is_pointer(fld.type) && reflect.is_dynamic_array(fld.type.variant.(Type_Info_Pointer).elem):
        val := struct_field_value(thing, fld).(^ActionTrackers)
        iostr_indent(w)
        wprintln(w, fld.name, ": [", sep = "")
        indent_ctl(.IncIndent)
        for item in val^ {
          // write_indent(w)
          // wprintln(w, item, ",", sep = "")
          t := type_info_of(type_of(item)).variant
          iostr_struct(w, item, &t.(Type_Info_Named))
        }
        indent_ctl(.DecIndent)
        iostr_indent(w)
        wprintln(w, "]", sep = "")
      }
    }
    // boolean Properties
    bool_count := 0
    for f in 0..<fn {
      fld := struct_field_at(WorldEnvEntity, f)
      if is_boolean(fld.type) {
        if struct_field_value(thing, fld).(bool) {
          bool_count += 1
        }
      }
    }
    if bool_count > 0 {
      iostr_open(w, "Props")
      iostr_indent(w)
      for f in 0..<fn {
        fld := struct_field_at(WorldEnvEntity, f)
        if is_boolean(fld.type) {
          if struct_field_value(thing, fld).(bool) {
            wprint(w, fld.name, ",", sep = "")
          }
        }
      }
      wprintln(w)
      iostr_close(w)
    }
    iostr_close(w)
  }
  return sbprint(&b), nil
}

data_to_world :: proc(world: ^WorldEnvSOA, data: string) {
  // world = make_world_env_soa()
  lines, _ := strings.split_lines(data)
  Stage :: enum {
    New,
    Entity,
    Struct,
    Array,
    Props,
  }
  stage := [10]Stage{}
  indent_ctl(.ResetIndent)
  entity:WorldEnvEntity = {}
  entity.actions = make_action_tracker_list()
  for line in lines {
    line := strip_left(line)
    if line == "" { continue }
    switch stage[indent_ctl()] {
    case .New:
      switch line {
      case "Entity{":
        println("Entity found!")
        stage[indent_ctl(.IncIndent)] = .Entity
      case: println("Oops, you broke it.")
      }
    case .Entity: 
      switch line {
      case "}":
        append_soa(world, entity)
        entity = WorldEnvEntity{}
        indent_ctl(.DecIndent)
        continue
      case "Props{":
        stage[indent_ctl(.IncIndent)] = .Props
        continue
      }
      struct_match, _ := regex.create("[A-Za-z_]*{{$")
      field_match, _ := regex.create(" *([a-z_]+): +(.+)$")
      name_and_data, _ := regex.match(field_match, line)
      if len(name_and_data.groups) < 3 { continue }
      for grp in name_and_data.groups[1:] {
        print(grp, " ", sep = "")
      }
      println()
      fld_name := name_and_data.groups[1] 
      fld_data := name_and_data.groups[2]
      _, struct_test := regex.match(struct_match, fld_data)
      if struct_test {
        stage[indent_ctl(.IncIndent)] = .Struct
        continue
      }
      fields: for name in struct_field_names(WorldEnvEntity) {
        if name == fld_name {
          _fld := struct_field_by_name(WorldEnvEntity, name)
          switch type_info_of(_fld.type.id) {
          case type_info_of(string):
            write_struct_data(entity, _fld.offset, fld_data)
            printfln("Did we write? entity.%v = %v", name, entity.name)
            continue fields
          case type_info_of(u32):
            data, ok := parse_int(fld_data)
            if ok {
              write_struct_data(entity, _fld.offset, cast(u32)data)
            } else {
              println("parse_int failed:", line)
            }
            printfln("Did we write? entity.%v = %v", name, struct_field_value_by_name(entity, name).(u32))
            continue fields
          case type_info_of(Maybe(u32)):
            data, ok := parse_int(fld_data)
            if ok {
              data: Maybe(u32) = cast(u32)data
              write_struct_data(entity, _fld.offset, data)
            } else {
              println("parse_int failed:", line)
            }
            printfln("Did we write? entity.%v = %v", name, struct_field_value_by_name(entity, name).(Maybe(u32)))
            continue fields
          // case type_info_of(rl.Color):
          //   println("Struct field rl.Color name is", name)
          //   // we have parse_uint, we CAN do this.
          // case type_info_of(rl.Vector3):
          //   println("Struct field rl.Vector3 name is", name)
          // case type_info_of(^ActionTrackers):
          //   
          case: check_and_write_entity_struct_field(&entity, name, fld_data)
          }
        }
      }
    case .Struct:
      if line == "}" {
        indent_ctl(.DecIndent)
        continue
      }
      
    case .Array:
      if line == "]" {
        indent_ctl(.DecIndent)
        continue
      }
      
    case .Props: 
      if line == "}" {
        indent_ctl(.DecIndent)
        continue
      }
      props := strings.split(line,",")
      if len(props) > 1 && props[len(props) - 1] == "" {
        props = props[:len(props) - 1]
      }
      for prop in props {
        for name in struct_field_names(WorldEnvEntity) {
          if prop == name {
            _fld := struct_field_by_name(WorldEnvEntity, name)
            #partial switch info in _fld.type.variant {
            case Type_Info_Boolean:
              ptr := cast(^bool)rawptr(uintptr(any(entity).data) + _fld.offset)
              ptr^ = true
              // printfln("Did we write? entity.%v = %t", name, struct_field_value_by_name(entity, name).(bool))
            }
          }
        }
      }
    }
  }
}

check_and_write_entity_struct_field :: proc(entity: ^WorldEnvEntity, field_name: string, line: string,) {
  fld := struct_field_by_name(type_of(entity^), field_name)
  _s := take_thru(line, is_open_brace)[1]
  if len(_s) == 0 { println("take_thru failed", line, _s, sep = ";"); return }
  _s = take_until(_s, is_close_brace)[0]
  if len(_s) == 0 { println("take_until failed", line, _s, sep = ";"); return }
  s_flds, _ := strings.split(_s,",")
  for s_fld, idx in s_flds {
    nv, _ := strings.split(s_fld, ":")
    if len(nv) != 2 { println("split should have made 2 strings:", s_fld); return }
    fld_name := nv[0]
    fld_data := nv[1]
    #partial switch info in fld.type.variant {
    case Type_Info_Named:
      for name in struct_field_names(fld.type.id) {
        if name == fld_name {
          _fld := struct_field_by_name(fld.type.id, name)
          switch type_info_of(_fld.type.id) {
          case type_info_of(u32):
            data, ok := parse_int(fld_data)
            if ok {
              println("write u32 field", cast(u32)data)
              write_struct_data(entity^, fld.offset + _fld.offset, data)
            } else {
              println("parse_int failed:", line)
            }
          case type_info_of(f32):
            data, ok := parse_f32(fld_data)
            if ok {
              println("write f32 field", data)
              write_struct_data(entity^, fld.offset + _fld.offset, data)
            } else {
              println("parse_f32 failed:", line)
            }
          }
        }
      }
    case Type_Info_Array:
      if info.elem == type_info_of(f32) {
        data, ok := parse_f32(fld_data)
        if ok {
          println("write f32 array", idx, data)
          write_struct_data(entity^, fld.offset + uintptr(size_of(f32) * idx), data)
        } else {
          println("parse_f32 failed:", line)
        }
      }
    case: println("info: ", info)
    }
  }
  println("Did we write? entity", entity^)
}

IndentStr :: "  "

IndentCtl :: enum{
  GetIndent, IncIndent, DecIndent, ResetIndent,
}

indent_ctl :: proc(ictl:= IndentCtl.GetIndent) -> int {
  @(static) i := 0
  switch ictl {
  case .GetIndent: return i
  case .IncIndent: i += 1
  case .DecIndent: i -= 1
  case .ResetIndent: i = 0
  }
  return i
}

iostr_indent :: proc(w: io.Stream) {
  for _ in 0..<indent_ctl() {
    wprint(w, IndentStr)
  }
}

iostr_open :: proc(w: io.Stream, title: string, indent := true) {
  if indent { iostr_indent(w) }
  wprintln(w, title, "{", sep = "")
  indent_ctl(.IncIndent)
}

iostr_close :: proc(w: io.Stream, newline := true) {
  indent_ctl(.DecIndent)
  iostr_indent(w)
  wprint(w, "}")
  if newline { wprintln(w) }
}

iostr_struct :: proc(w: io.Stream, thing: any, info: ^Type_Info_Named, not_elem := true) {
  iostr_open(w, info.name, not_elem)
  field_count := struct_field_count(info.base.id)
  for fn in 0..<field_count {
    fld := struct_field_at(info.base.id, fn)
    iostr_field(w, fld.name, struct_field_value(thing, fld), fld.type)
  }
  iostr_close(w, not_elem)
}

iostr_field :: proc(w: io.Stream, name: string, data: any, info: ^Type_Info) {
  iostr_indent(w)
  wprintf(w, "%v: ", name)
  base := type_info_base(info)
  #partial switch &v in info.variant {
  case Type_Info_Array:
    
  case Type_Info_Named:
    if is_enum(base) {
      wprint(w, data)
    } else if is_array(base) {
      iostr_array(w, data, &base.variant.(Type_Info_Array))
    } else {
      iostr_struct(w, data, &v, false)
    }
  case Type_Info_Integer: iostr_int(w, data, info.size, v.signed)
  case Type_Info_Float: iostr_float(w, data, info.size)
  // case runtime.Type_Info_Rune:
  case Type_Info_String:
    a := data.(string)
    wprint(w, a)
  case Type_Info_Boolean:
  }
  wprintln(w)
}

iostr_array :: proc(w: io.Stream, thing: any, info: ^Type_Info_Array, not_elem := false) {
  a_ptr := rawptr(uintptr(any(thing).data))
  if not_elem { iostr_indent(w) }
  wprintfln(w, "[")
  indent_ctl(.IncIndent)
  iostr_indent(w)
  iostr_for_each_raw(w, a_ptr, info.elem, proc(w: io.Stream, v: any) {
    wprintf(w, "%v,", v)
  })
  wprintln(w)
  indent_ctl(.DecIndent)
  iostr_indent(w)
  wprint(w, "]")
  if not_elem { wprintln(w) }
}

iostr_int :: proc(w: io.Stream, data: any, size: int, signed: bool) {
  if signed {
    switch size {
    case size_of(i8):
      a := cast(^i8)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(i16):
      a := cast(^i16)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(i32):
      a := cast(^i32)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(i64):
      a := cast(^i64)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(i128):
      a := cast(^i128)rawptr(uintptr(data.data))
      wprint(w, a^)
    }
  } else {
    switch size {
    case size_of(u8):
      a := cast(^u8)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(u16):
      a := cast(^u16)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(u32):
      a := cast(^u32)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(u64):
      a := cast(^u64)rawptr(uintptr(data.data))
      wprint(w, a^)
    case size_of(u128):
      a := cast(^u128)rawptr(uintptr(data.data))
      wprint(w, a^)
    }
  }
}

iostr_float :: proc(w: io.Stream, data: any, size: int) {
  switch size {
  case size_of(f16):
    a := cast(^f16)rawptr(uintptr(data.data))
    wprint(w, a^)
  case size_of(f32):
    a := cast(^f32)rawptr(uintptr(data.data))
    wprint(w, a^)
  case size_of(f64):
    a := cast(^f64)rawptr(uintptr(data.data))
    wprint(w, a^)
  }
}

strip_left :: proc(s: string) -> string {
  i := 0
  for ; i < len(s) && s[i] == ' '; i += 1 {}
  return s[i:]
}

cat_to_cstr :: proc(s: []string) -> cstring {
  return unsafe_string_to_cstring(concatenate(s))
}

write_struct_data :: proc(thing: any, offset: uintptr, data: $T, maybe := false) {
  ptr := cast(^T)rawptr(uintptr(thing.data) + offset)
  ptr^ = data
}

take_while :: proc(s: string, f: proc(rune: rune) -> bool) -> [2]string {
  idx := 0
  for r in s {
    if !f(r) {
      break
    }
    idx += 1
  }
  return {s[:idx], s[idx:]}
}

take_thru :: proc(s: string, f: proc(rune: rune) -> bool) -> [2]string {
  idx := 0
  for r in s {
    if f(r) {
      idx += 1
      break
    }
    idx += 1
  }
  return {s[:idx], s[idx:]}
}

take_until :: proc(s: string, f: proc(rune: rune) -> bool) -> [2]string {
  idx := 0
  for r in s {
    if f(r) {
      break
    }
    idx += 1
  }
  return {s[:idx], s[idx:]}
}

// Example predicates
is_digit :: proc(r: rune) -> bool {
  return '0' <= r && r <= '9'
}

is_alpha :: proc(r: rune) -> bool {
  return ('a' <= r && r <= 'z') || ('A' <= r && r <= 'Z')
}

is_space :: proc(r: rune) -> bool {
  return r == ' ' || r == '\t' || r == '\n' || r == '\r'
}

is_open_brace :: proc(r: rune) -> bool {
  return r == '{'
}

is_close_brace :: proc(r: rune) -> bool {
  return r == '}'
}

iostr_for_each_raw :: proc(w: io.Stream,a_ptr: rawptr, ti: ^Type_Info, f: proc(io.Stream, any)) {
  v := type_info_base(ti).variant.(Type_Info_Array)
  s := v.elem_size
  c := v.count
  #partial switch info in v.elem.variant {
  case Type_Info_Integer:
    for i in 0..<c {
      if info.signed {
        switch s {
        case size_of(i8):
          a := cast([^]i8)a_ptr
          f(w, a[i])
        case size_of(i16):
          a := cast([^]i16)a_ptr
          f(w, a[i])
        case size_of(i32):
          a := cast([^]i32)a_ptr
          f(w, a[i])
        case size_of(i64):
          a := cast([^]i64)a_ptr
          f(w, a[i])
        case size_of(i128):
          a := cast([^]i128)a_ptr
          f(w, a[i])
        }
      } else {
        switch s {
        case size_of(u8):
          a := cast([^]u8)a_ptr
          f(w, a[i])
        case size_of(u16):
          a := cast([^]u16)a_ptr
          f(w, a[i])
        case size_of(u32):
          a := cast([^]u32)a_ptr
          f(w, a[i])
        case size_of(u64):
          a := cast([^]u64)a_ptr
          f(w, a[i])
        case size_of(u128):
          a := cast([^]u128)a_ptr
          f(w, a[i])
        }
      }
    }
  case Type_Info_Float:
    a := cast([^]f32)a_ptr
    for i in 0..<c {
      f(w, a[i])
    }
  case Type_Info_Named:
    a := cast([^]type_of(v.elem.id))a_ptr
    for i in 0..<c {
      f(w, a[i])
    }
  }
}


