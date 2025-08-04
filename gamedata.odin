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
    write_open(w, "Entity")
    for f in 0..<fn {
      fld := struct_field_at(WorldEnvEntity, f)
      switch {
      case is_string(fld.type):
        val := struct_field_value(thing, fld).(string)
        if val == "" { continue }
        write_indent(w)
        wprintfln(w, "%v: %v", fld.name, val)
      case fld.type == type_info_of(u32):
        val := struct_field_value(thing, fld).(u32)
        if val == 0 { continue }
        write_indent(w)
        wprintfln(w, "%v: %v", fld.name, val)
      case fld.type == type_info_of(Maybe(u32)):
        val := struct_field_value(thing, fld).(Maybe(u32)).? or_continue
        write_indent(w)
        wprintfln(w, "%v: %v", fld.name, val)
      case fld.type == type_info_of(rl.Color):
        val := struct_field_value(thing, fld).(rl.Color)
        if val == cast(rl.Color){} { continue }
        write_indent(w)
        wprintfln(w, "%v: Color{{r:%i, g:%i, b:%i, a:%i}}", fld.name, val.r, val.g, val.b, val.a)
      case fld.type == type_info_of(rl.Vector3):
        val := struct_field_value(thing, fld).(rl.Vector3)
        if val == cast(rl.Vector3){} { continue }
        write_indent(w)
        wprintfln(w, "%v: Vector3{{x:%v, y:%v, z:%v}}", fld.name, val.x, val.y, val.z)
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
      write_open(w, "Props")
      write_indent(w)
      for f in 0..<fn {
        fld := struct_field_at(WorldEnvEntity, f)
        if is_boolean(fld.type) {
          if struct_field_value(thing, fld).(bool) {
            wprint(w, fld.name, ",", sep = "")
          }
        }
      }
      wprintln(w)
      write_close(w)
    }
    write_close(w)
  }
  return sbprint(&b), nil
}

data_to_world :: proc(data: string) -> (world: ^WorldEnvSOA) {
  world = make_world_env_soa()
  lines, _ := strings.split_lines(data)
  // entity_type_info := type_info_of(WorldEnvEntity).variant.(runtime.Type_Info_Struct)
  Stage :: enum {
    Entity,
    Props,
    New,
  }
  stage := Stage.New
  entity:WorldEnvEntity = {}
  for line in lines {
    line := strip_left(line)
    if line == "" { continue }
    switch stage {
    case .New:
      switch line {
      case "Entity{":
        println("Entity found!")
        stage = .Entity
      case: println("Oops, you broke it.")
      }
    case .Entity: 
      switch line {
      case "}":
        append_soa(world, entity)
        entity = WorldEnvEntity{}
        stage = .New
        continue
      case "Props{":
        stage = .Props
        continue
      }
      field_match, _ := regex.create(" *([a-z_]+): +(.+)$")
      res, _ := regex.match(field_match, line)
      if len(res.groups) < 3 { continue }
      for grp in res.groups[1:] {
        print(grp, " ", sep = "")
      }
      println()
      fld_name := res.groups[1] 
      fld_data := res.groups[2]
      for name in struct_field_names(WorldEnvEntity) {
        if name == fld_name {
          _fld := struct_field_by_name(WorldEnvEntity, name)
          switch type_info_of(_fld.type.id) {
          case type_info_of(string):
            ptr := cast(^string)rawptr(uintptr(any(entity).data) + _fld.offset)
            ptr^ = fld_data
            println("Did we write? entity.name =", entity.name)
          case type_info_of(u32):
            ptr := cast(^u32)rawptr(uintptr(any(entity).data) + _fld.offset)
            data, ok := parse_int(fld_data)
            if ok {
              ptr^ = cast(u32)data
            } else {
              println("parse_int failed:", line)
            }
            printfln("Did we write? entity.%v = %v", name, struct_field_value_by_name(entity, name).(u32))
          case type_info_of(Maybe(u32)):
            ptr := cast(^Maybe(u32))rawptr(uintptr(any(entity).data) + _fld.offset)
            data, ok := parse_int(fld_data)
            if ok {
              ptr^ = cast(u32)data
            } else {
              println("parse_int failed:", line)
            }
            printfln("Did we write? entity.%v = %v", name, struct_field_value_by_name(entity, name).(Maybe(u32)))
          case type_info_of(rl.Color):
            println("Struct field rl.Color name is", name)
            // we have parse_uint, we CAN do this.
          case type_info_of(rl.Vector3):
            println("Struct field rl.Vector3 name is", name)
        }
      }
      }
    case .Props: 
      if line == "}" {
        stage = .Entity
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
  return
}

IndentStr :: "  "

IndentCtl :: enum{
  GetIndent, IncIndent, DecIndent,
}

indent_ctl :: proc(ictl:= IndentCtl.GetIndent) -> int {
  @(static) i := 0
  switch ictl {
  case .GetIndent: return i
  case .IncIndent: i += 1
  case .DecIndent: i -= 1
  }
  return i
}

write_indent :: proc(w: io.Stream) {
  for _ in 0..<indent_ctl() {
    wprint(w, IndentStr)
  }
}

write_open :: proc(w: io.Stream, title: string) {
  write_indent(w)
  wprintln(w, title, "{", sep = "")
  indent_ctl(.IncIndent)
}

write_close :: proc(w: io.Stream) {
  indent_ctl(.DecIndent)
  write_indent(w)
  wprintln(w, "}")
}

strip_left :: proc(s: string) -> string {
  i := 0
  for ; i < len(s) && s[i] == ' '; i += 1 {}
  return s[i:]
}

cat_to_cstr :: proc(s: []string) -> cstring {
  return unsafe_string_to_cstring(concatenate(s))
}

