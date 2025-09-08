package raumortis

import "base:intrinsics"
import "core:mem"
import "core:reflect"
import "base:runtime"

type_info_base             :: runtime.type_info_base
Raw_Dynamic_Array          :: runtime.Raw_Dynamic_Array
Type_Info                  :: runtime.Type_Info
Type_Info_Array            :: runtime.Type_Info_Array
Type_Info_Boolean          :: runtime.Type_Info_Boolean
Type_Info_Dynamic_Array    :: runtime.Type_Info_Dynamic_Array
Type_Info_Enum             :: runtime.Type_Info_Enum
Type_Info_Enum_Value       :: runtime.Type_Info_Enum_Value
Type_Info_Float            :: runtime.Type_Info_Float
Type_Info_Integer          :: runtime.Type_Info_Integer
Type_Info_Named            :: runtime.Type_Info_Named
Type_Info_Pointer          :: runtime.Type_Info_Pointer
Type_Info_Rune             :: runtime.Type_Info_Rune
Type_Info_String           :: runtime.Type_Info_String
Type_Info_Struct           :: runtime.Type_Info_Struct
Type_Info_Union            :: runtime.Type_Info_Union

struct_field_names         :: reflect.struct_field_names
struct_field_count         :: reflect.struct_field_count
struct_field_at            :: reflect.struct_field_at
struct_field_by_name       :: reflect.struct_field_by_name
struct_field_value         :: reflect.struct_field_value
struct_field_value_by_name :: reflect.struct_field_value_by_name
typeid_elem                :: reflect.typeid_elem
is_array                   :: reflect.is_array
is_boolean                 :: reflect.is_boolean
is_dynamic_array           :: reflect.is_dynamic_array
is_enum                    :: reflect.is_enum
is_pointer                 :: reflect.is_pointer
is_string                  :: reflect.is_string
Struct_Field               :: reflect.Struct_Field

world_to_data :: proc(
  world: WorldEnvSOA, allocator := context.allocator, loc := #caller_location
) -> (data: string, err: Maybe(u32)) {
  b := string_builder_make(allocator, loc)
  defer if err != nil {
    string_builder_destroy(&b)
  }
  w := string_to_writer(&b) // I'll write my own format! With strippers! And blackjack!
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
      // case is_pointer(fld.type) && is_dynamic_array(fld.type.variant.(Type_Info_Pointer).elem):
      case is_dynamic_array(fld.type):
        // fixme: can't assume this is ActionTrackers
        val := struct_field_value(thing, fld).(ActionTrackers)
        iostr_indent(w)
        wprintln(w, fld.name, ": [", sep = "")
        indent_ctl(.IncIndent)
        for item in val {
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
      iostr_open(w, "Props: ")
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
  indent_ctl(.ResetIndent)
  entity:WorldEnvEntity = {}
  entity.actions = make_action_tracker_list()
  before, ent, rem : = "", "", data
  for ; len(rem) > 0 ; {
    before, ent, rem = three_strings(take_thru_matching(rem))
    read_data_into_struct(entity, ent)
    append_soa(world, entity)
    entity = WorldEnvEntity{}
    entity.actions = make_action_tracker_list()
  }
}

read_data_into_struct :: proc(strct: any, data: string) {
  data := strip_left(data)
  if len(data) < 1 { return }
  {
    _props := expect_label(data, "Props", ": ", false)
    if _props.err == .Ok {
      // println(_props)
      props := take_thru_matching(_props.rem)
      toggle_boolean_fields(strct, split(props.res, sep = ","))
      read_data_into_struct(strct, props.rem)
      return
    }
  }
  strct_info := type_info_base(type_info_of(strct.id))
  field_names := struct_field_names(strct.id)
  fld_parse := expect_one_of(data, field_names, ": ")
  #partial switch fld_parse.err {
  case .NoMatch:
    println("NoMatch: Current Type:", strct.id, "No Match:", fld_parse, "data:", data)
    fld_parse.rem = take_thru(fld_parse.rem, is_newline).rem
  case .Incomplete:
    println("Incomplete:", fld_parse)
    fld_parse.rem = take_thru(fld_parse.rem, is_newline).rem
  case .EmptyInput:
    return
  case .Ok:
    // fld_name = fld_match.res
    fld := struct_field_by_name(strct.id, fld_parse.res)
    #partial switch info in type_info_base(type_info_of(fld.type.id)).variant {
    case Type_Info_String:
      process_parse_res(&fld_parse, .ToNewline)
      write_struct_data(strct, fld.offset, fld_parse.data)
    case Type_Info_Integer:
      process_parse_res(&fld_parse, .ToNewline)
      process_parse_res(&fld_parse, .DataToInt)
      if fld_parse.err == .Ok {
        write_struct_int(strct, fld.offset, fld_parse.data_int, fld.type.size, info.signed)
      } else {
        println("parse_int failed:", fld_parse.data)
      }
      // printfln("Did we write? entity.%v = %v", fld_parse.res, struct_field_value_by_name(strct, fld_parse.res).(u32))
    case Type_Info_Union:
      // unfinished: currently supports Maybe of Integer types only.
      // no other Unions or non-integer Maybe
      println("Maybe Union:", info.variants)
      if len(info.variants) == 1 {
        // Maybe(x)
        #partial switch _info in info.variants[0].variant {
        case Type_Info_Integer:
          process_parse_res(&fld_parse, .ToNewline)
          process_parse_res(&fld_parse, .DataToInt)
          if fld_parse.err == .Ok {
            write_struct_int(strct, fld.offset, fld_parse.data_int, info.variants[0].size, _info.signed, is_maybe = true)
          } else {
            println("parse_int failed:", fld_parse.data)
          }
        case:
          println("Unhandled Maybe variant")
        }
      } else {
        println("unhandled Union variant")
      }
      // printfln("Did we write? entity.%v = %v", fld_parse.res, struct_field_value_by_name(strct, fld_parse.res).(Maybe(u32)))
    case Type_Info_Array:
      write_struct_array_data(strct, fld, info, &fld_parse)
    case Type_Info_Named:
      // fixme: so far nothing has triggered this so I'm not entirely sure what to do here.
      process_parse_res(&fld_parse, .ToMatching)
      println("named:", strip_string(fld_parse.data))
    case Type_Info_Struct:
      process_parse_res(&fld_parse, .ToMatching)
      fld_data := struct_field_value(strct, fld)
      read_data_into_struct(fld_data, fld_parse.data)
    case Type_Info_Enum:
      process_parse_res(&fld_parse, .ToNewline)
      for enm, i in info.names {
        if enm == fld_parse.res {
          ptr := cast(^Type_Info_Enum_Value)struct_field_value(strct, fld).data
          ptr^ = info.values[i]
          break
        }
      }
    case Type_Info_Dynamic_Array:
      write_struct_dyn_array_data(strct, fld, &fld_parse)
    case:
      println("unhandled info:", info)
    }
  }
  if len(fld_parse.rem) > 0 {
    read_data_into_struct(strct, fld_parse.rem)
  }
}

toggle_boolean_fields :: proc(strct: any, field_names: []string) {
  field_names := field_names
  if len(field_names) > 1 && field_names[len(field_names) - 1] == "" {
    field_names = field_names[:len(field_names) - 1]
  }
  for fld_name in field_names {
    for name in struct_field_names(strct.id) {
      if fld_name == name {
        _fld := struct_field_by_name(strct.id, name)
        #partial switch info in _fld.type.variant {
        case Type_Info_Boolean:
          ptr := cast(^bool)rawptr(uintptr(strct.data) + _fld.offset)
          ptr^ = true
          // printfln("Did we write? entity.%v = %t", name, struct_field_value_by_name(entity, name).(bool))
        }
      }
    }
  }
}

Dyn_Array_Append_Err :: enum {
  Ok,
  NotDynArray,
  ElemWrongType,
  NewLengthNotAsExpected,
}
// Appends an element into a dynamic array for which we have no
// runtime `Type`, only `typeid`s to work with.
// Intended for unmarshalling.
// Fails if `anyray` is not a dynamic array or if the `typeid` of
// the the dynamic array's element and the `elem` pass aren't equal. 
dyn_array_append :: proc(anyray: any, elem: any) -> Dyn_Array_Append_Err {
  ray_info := type_info_base(type_info_of(anyray.id))
  dyn_info, ok := ray_info.variant.(Type_Info_Dynamic_Array)
  if !ok {
    return .NotDynArray
  } else if elem.id != dyn_info.elem.id {
    return .ElemWrongType
  }
  // Cast any.data, a rawptr now known to point to a Dynamic Array,
  // to a pointer to a Raw_Dynamic_array, granting us access to its
  // fields; data: rawptr, len, cap: int, and allocator. 
  rda := (^runtime.Raw_Dynamic_Array)(anyray.data)
  old_len := rda.len
  elem_align := type_info_of(elem.id).align
  new_len := runtime.__dynamic_array_append(rda, dyn_info.elem_size, elem_align, elem.data, 1)
  if new_len == old_len + 1 { return .Ok } else { return .NewLengthNotAsExpected }
}

// _resize_dynamic_array :: #force_inline proc(a: ^Raw_Dynamic_Array, size_of_elem, align_of_elem: int, length: int, should_zero: bool, loc := #caller_location) -> runtime.Allocator_Error {
//   if a == nil {
//     return nil
//   }
//   if should_zero && a.len < length {
//     num_reused := min(a.cap, length) - a.len
//     intrinsics.mem_zero(([^]byte)(a.data)[a.len*size_of_elem:], num_reused*size_of_elem)
//   }
//   if length <= a.cap {
//     a.len = max(length, 0)
//     return nil
//   }
//   if a.allocator.procedure == nil {
//     a.allocator = context.allocator
//   }
//   assert(a.allocator.procedure != nil)
//   old_size  := a.cap  * size_of_elem
//   new_size  := length * size_of_elem
//   allocator := a.allocator
//   new_data : []byte
//   if should_zero {
//     new_data = runtime.mem_resize(a.data, old_size, new_size, align_of_elem, allocator, loc) or_return
//   } else {
//     new_data = runtime.non_zero_mem_resize(a.data, old_size, new_size, align_of_elem, allocator, loc) or_return
//   }
//   if new_data == nil && new_size > 0 {
//     return .Out_Of_Memory
//   }
//   a.data = raw_data(new_data)
//   a.len = length
//   a.cap = length
//   return nil
// }

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

write_struct_data :: proc(thing: any, offset: uintptr, data: $T, maybe := false) {
  ptr := cast(^T)rawptr(uintptr(thing.data) + offset)
  ptr^ = data
}

write_struct_int :: proc(strct: any, offset: uintptr, data: int, size: int, signed: bool, is_maybe := false) {
  ptr := rawptr(uintptr(strct.data) + offset)
  if is_maybe {
    if signed {
      switch size {
      case size_of(i8):
        a := cast(^Maybe(i8))ptr
        _data : Maybe(i8) = cast(i8)data
        a^ = _data
      case size_of(i16):
        a := cast(^Maybe(i16))ptr
        _data : Maybe(i16) = cast(i16)data
        a^ = _data
      case size_of(i32):
        a := cast(^Maybe(i32))ptr
        _data : Maybe(i32) = cast(i32)data
        a^ = _data
      case size_of(i64):
        a := cast(^Maybe(i64))ptr
        _data : Maybe(i64) = cast(i64)data
        a^ = _data
      case size_of(i128):
        a := cast(^Maybe(i128))ptr
        _data : Maybe(i128) = cast(i128)data
        a^ = _data
      }
    } else {
      switch size {
      case size_of(u8):
        a := cast(^Maybe(u8))ptr
        _data : Maybe(u8) = cast(u8)data
        a^ = _data
      case size_of(u16):
        a := cast(^Maybe(u16))ptr
        _data : Maybe(u16) = cast(u16)data
        a^ = _data
      case size_of(u32):
        a := cast(^Maybe(u32))ptr
        _data : Maybe(u32) = cast(u32)data
        a^ = _data
      case size_of(u64):
        a := cast(^Maybe(u64))ptr
        _data : Maybe(u64) = cast(u64)data
        a^ = _data
      case size_of(u128):
        a := cast(^Maybe(u128))ptr
        _data : Maybe(u128) = cast(u128)data
        a^ = _data
      }
    }
  } else {
    if signed {
      switch size {
      case size_of(i8):
        a := cast(^i8)ptr
        a^ = cast(i8)data
      case size_of(i16):
        a := cast(^i16)ptr
        a^ = cast(i16)data
      case size_of(i32):
        a := cast(^i32)ptr
        a^ = cast(i32)data
      case size_of(i64):
        a := cast(^i64)ptr
        a^ = cast(i64)data
      case size_of(i128):
        a := cast(^i128)ptr
        a^ = cast(i128)data
      }
    } else {
      switch size {
      case size_of(u8):
        a := cast(^u8)ptr
        a^ = cast(u8)data
      case size_of(u16):
        a := cast(^u16)ptr
        a^ = cast(u16)data
      case size_of(u32):
        a := cast(^u32)ptr
        a^ = cast(u32)data
      case size_of(u64):
        a := cast(^u64)ptr
        a^ = cast(u64)data
      case size_of(u128):
        a := cast(^u128)ptr
        a^ = cast(u128)data
      }
    }
  }
}

write_struct_float :: proc(strct: any, offset: uintptr, data: f64, size: int) {
  ptr := rawptr(uintptr(strct.data) + offset)
  switch size {
  case size_of(f16):
    a := cast(^f16)ptr
    a^ = cast(f16)data
  case size_of(f32):
    a := cast(^f32)ptr
    a^ = cast(f32)data
  case size_of(f64):
    a := cast(^f64)ptr
    a^ = cast(f64)data
  }
}

write_struct_array_data :: proc(strct: any, fld: Struct_Field, info: Type_Info_Array, fld_parse: ^ParseRes) {
  process_parse_res(fld_parse, .ToMatching)
  // println("array:", fld_parse)
  data_list := split(strip_string(fld_parse.data), ",")
  if len(data_list) > info.count {
    data_list = data_list[:info.count]
  }
  for n, idx in data_list {
    #partial switch _info in info.elem.variant {
    case Type_Info_Float:
      data, ok := parse_f64(n)
      if ok {
        // println("write float array", idx, data)
        write_struct_float(strct, fld.offset + uintptr(info.elem_size * idx), data, info.elem_size)
      } else {
        println("parse_f64 failed:", n)
      }
    case Type_Info_Integer:
      data, ok := parse_int(n)
      if ok {
        // println("write int array", idx, data)
        write_struct_int(strct, fld.offset + uintptr(info.elem_size * idx), data, info.elem_size, _info.signed)
      } else {
        println("parse_int failed:", n)
      }
    case:
      println("unhandled array item info", info.elem)
    }
  }
}

write_struct_dyn_array_data :: proc(strct: any, fld: Struct_Field, fld_parse: ^ParseRes) {
  process_parse_res(fld_parse, .ToMatching)
  t := typeid_elem(fld.type.id)
  ti := type_info_of(t)
  #partial switch _info in ti.variant {
  case Type_Info_Named:
    name := _info.name
    data := split(fld_parse.data, name)
    if len(data) > 1 {
      elem_size := type_info_of(fld.type.id).variant.(Type_Info_Dynamic_Array).elem_size
      data = data[1:]
      anyray := struct_field_value(strct, fld)
      if _data_alloc, err := mem.alloc_bytes(elem_size); err == .None {
        for datum in data {
          elem := any{rawptr(raw_data(_data_alloc)), t}
          if d := take_thru_matching(datum); d.err == .Ok {
            read_data_into_struct(elem, d.res)
            switch dyn_array_append(anyray, elem) {
            case .NotDynArray:
              println("read_data_into_struct>dyn_array_append: 'anyray' not a dynamic array:", anyray, elem)
            case .ElemWrongType:
              println("read_data_into_struct>dyn_array_append: typeid of 'elem' does not match 'anyray' element typeid:", anyray, elem)
            case .NewLengthNotAsExpected:
              println("read_data_into_struct>dyn_array_append: wrong length reported after append:", anyray, elem)
            case .Ok:
              // Success!
            }
          } else { println("read_data_into_struct: dyn array of named: datum not as expected:", d, datum) }
          mem.zero_explicit(raw_data(_data_alloc), elem_size)
        } // todo: else it didn't work
        mem.free_with_size(raw_data(_data_alloc), elem_size)
      }
    }
  case:
    println("Dynamic Array of something:", t)
  }
}

println_max :: proc(labl: string, s: string, max_len: int, sep := ": ") {
  l := len(s)
  if len(s) == 0 {
    println(labl, "{empty string}", sep = sep)
  }
  out : string
  if max_len > l {
    out = s
  } else {
    out = s[:max_len]
  }
  println(labl, out, sep = sep)
}


