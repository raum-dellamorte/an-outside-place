package raumortis

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"

make_msg_system :: proc(max_length: int, line_length: int, page_len: int) -> MsgSystem {
  arena := mem.Dynamic_Arena{}
  mem.dynamic_arena_init(&arena)
  alloc := mem.dynamic_arena_allocator(&arena)
  data := make([]u8,max_length * line_length, alloc)
  msgs := make([][]u8,max_length, alloc)
  page_list := make([]int,page_len, alloc)
  for i in 0..<page_len { page_list[i] = -1 }
  for i in 0..<max_length {
    offset := i * line_length
    msgs[i] = data[offset:offset + line_length]
  }
  return MsgSystem {
    arena = arena,
    len = 0,
    max_lines = max_length,
    line_len = line_length,
    last = 0,
    ptr = 0,
    page_len = page_len,
    page_list = page_list,
    _data = data,
    msgs = msgs,
  }
}

delete_msg_system :: proc(msgsys: ^MsgSystem) {
  // We don't have to delete the slices bc they're allocated in the arena
  // delete_slice(msgsys.msgs)
  // delete_slice(msgsys._data)
  mem.dynamic_arena_destroy(&msgsys.arena)
}

msg_ptr_pos :: proc(msgs: ^MsgSystem) -> MsgIndicator {
  if msgs.len == 0 {
    return .Empty
  }
  if msgs.ptr == msgs.last { return .Omega }
  if msgs.ptr == ((msgs.last + 1) %% msgs.max_lines) { return .Alpha }
  return .Sigma
}

msg_on_last_page :: proc(msgs: ^MsgSystem) -> bool {
  if msgs.len == 0 { return true }
  p := ((msgs.last - msgs.ptr) %% msgs.max_lines)
  return p < msgs.page_len
}

rebuild_page_idcs :: proc(msgs: ^MsgSystem) {
  for i in 0..<msgs.page_len { msgs.page_list[i] = -1 }
  p := ((msgs.last - msgs.ptr) %% msgs.max_lines)
  p = math.min(p, msgs.page_len)
  for i in 0..<p {
    msgs.page_list[i] = ((msgs.ptr + i) %% msgs.max_lines)
  }
}

msg_next_in_page :: proc(msgs: ^MsgSystem) {
  if msgs.len == 0 { return }
  msgs^.page_ptr = ((msgs.page_ptr + 1) %% msgs.page_len)
}

msg_prev_in_page :: proc(msgs: ^MsgSystem) {
  if msgs.len == 0 { return }
  msgs^.page_ptr = ((msgs.page_ptr - 1) %% msgs.page_len)
}

msg_read_in_page :: proc(msgs: ^MsgSystem) -> string {
  if msgs.len == 0 { return "" }
  return string(msgs.msgs[msgs.page_list[msgs.page_ptr]])
}

msg_page_lines :: proc(msgs: ^MsgSystem) -> []int {
  if msgs.len == 0 { return []int{} }
  i := 0
  for {
    if i == len(msgs.page_list) { break }
    if msgs.page_list[i] == -1 { break }
    i += 1
  }
  return msgs.page_list[0:i]
}

msg_read_line :: proc(msgs: ^MsgSystem, line: int) -> string {
  if msgs.len == 0 { return "" }
  return string(msgs.msgs[line])
}

msg_next :: proc(msgs: ^MsgSystem) {
  if msgs.len == 0 { return }
  msgs^.ptr = ((msgs.ptr + 1) %% msgs.max_lines)
}

msg_prev :: proc(msgs: ^MsgSystem) {
  if msgs.len == 0 { return }
  msgs^.ptr = ((msgs.ptr - 1) %% msgs.max_lines)
}

msg_read :: proc(msgs: ^MsgSystem) -> string {
  if msgs.len == 0 { return "" }
  return string(msgs.msgs[msgs.ptr])
}

msg_add :: proc(msgs: ^MsgSystem, args: ..any) {
  // if _length is _max_len, overwrite oldest
  // else inc _length, _last
  s := fmt.tprint(..args)
  alloc := mem.dynamic_arena_allocator(&msgs.arena)
  chunks := _str_limiter(s, msgs.line_len, alloc)
  for line in chunks {
    _msg_add(msgs, line)
  }
  free_all(context.temp_allocator)
}
_msg_add :: proc(msgs: ^MsgSystem, s: string) {
  if msgs.len < msgs.max_lines {
    mem.copy(raw_data(msgs.msgs[msgs.len]),raw_data(s),cast(int)msgs.line_len)
    msgs^.last = msgs.len
    msgs^.len += 1
  } else {
    msgs^.last = (msgs.last + 1) %% msgs.max_lines
    mem.copy(raw_data(msgs^.msgs[msgs.last]),raw_data(s),cast(int)msgs.line_len)
  }
}
_str_limiter :: proc(s: string, max_len: int, alloc: mem.Allocator) -> []string {
  log.assert(max_len > 4, "_str_limiter: max_len must be at least 5")
  words := strings.split(s, " ", alloc)
  defer delete(words, alloc)
  out := make([dynamic]string, 0, (len(s) * 4) / max_len, alloc)
  temp := make([]u8, max_len, alloc);  
  mem.set(raw_data(temp), ' ', max_len)
  defer {
    mem.zero(raw_data(temp), max_len)
    delete(temp, alloc)
  }
  len_s := len(s)
  cur_line_len := 0
  for word in words {
    if cur_line_len != 0 && cur_line_len + len(word) + 1 > max_len {
      log.info("appending temp line and resetting temp")
      append(&out, strings.clone(cast(string)temp,alloc))
      mem.set(raw_data(temp), ' ', max_len)
      cur_line_len = 0
    }
    if cur_line_len == 0 && len(word) > max_len {
      log.info("word is too long to fit on a single line")
      mem.copy(raw_data(temp), raw_data(word[:max_len - 2]), max_len - 2)
      mem.set(&raw_data(temp)[max_len - 2], '-', 2)
      append(&out, strings.clone(cast(string)temp,alloc))
      mem.set(raw_data(temp), ' ', max_len)
      wptr := max_len - 2
      wlen := len(word) - wptr
      for wlen + 2 > max_len {
        mem.set(raw_data(temp), '-', 2)
        mem.copy(&raw_data(temp)[2], raw_data(word[wptr:wptr + max_len - 4]), max_len - 4)
        mem.set(&raw_data(temp)[max_len - 2], '-', 2)
        append(&out, strings.clone(cast(string)temp,alloc))
        mem.set(raw_data(temp), ' ', max_len)
        wptr += max_len - 4
        wlen -= max_len - 4
      }
      mem.set(raw_data(temp), '-', 2)
      mem.copy(&raw_data(temp)[2], raw_data(word[wptr:wptr + wlen]), wlen)
      cur_line_len = wlen + 2
      continue
    }
    if cur_line_len != 0 {
      cur_line_len += 1
    }
    log.info("appending word to temp line")
    dst_ptr : rawptr = &raw_data(temp)[cur_line_len]
    src_ptr : rawptr = raw_data(word)
    mem.copy(dst_ptr, src_ptr, len(word))
    cur_line_len += len(word)
    log.info("appending succeded")
  }
  log.info("appending final temp line")
  if cur_line_len > 0 {
    append(&out, strings.clone(cast(string)temp, alloc))
  }
  return out[:]
}

MsgSystem :: struct {
	arena: mem.Dynamic_Arena,
	len: int,
  max_lines: int,
  line_len: int,
  last: int,
  ptr: int,
  page_len: int,
  page_ptr: int,
  page_list: []int,
  _data: []u8,
  msgs: [][]u8,
}
MsgIndicator :: enum {
	Alpha,
	Omega,
	Sigma,
	Empty,
}

import "core:testing"

@(test)
test_str_limiter :: proc(t: ^testing.T) {
  arena := mem.Dynamic_Arena{}
  mem.dynamic_arena_init(&arena)
  defer mem.dynamic_arena_destroy(&arena)
  alloc := mem.dynamic_arena_allocator(&arena)
  // String s01
  s01 := "a123456789b123456789"
  s01_t1r0 := "a123456789b123456789"
  s01_t2r0 := "a1234567--"
  s01_t2r1 := "--89b123--"
  s01_t2r2 := "--456789  "
  // _s01b := "x12 a123456789b123456789" // Maybe better version of test?
  // _s01b_t2r0 := "x12       "
  // _s01b_t2r1 := "a1234567--"
  // _s01b_t2r2 := "--89b123--"
  // _s01b_t2r3 := "--456789  "
  // Test s01t1
  s01_t1 := _str_limiter(s01,20, alloc)
  assert(len(s01_t1) == 1, "Expected _str_limiter(s_01,20, alloc) len to be 1")
  assert(s01_t1[0] == s01_t1r0, "Expected t_01[0] to be equal to s01_t1r0")
  // Test s01t2
  s01_t2 := _str_limiter(s01,10, alloc)
  log.info("s01_t2: %v", s01_t2)
  assert(len(s01_t2) == 3, "Expected _str_limiter(s_01,10, alloc) len to be 3")
  assert(s01_t2[0] == s01_t2r0, "Expected t_02[0] to be equal to s01_t2r0")
  assert(s01_t2[1] == s01_t2r1, "Expected t_02[1] to be equal to s01_t2r1")
  assert(s01_t2[2] == s01_t2r2, "Expected t_02[2] to be equal to s01_t2r2")
  // String s02
  s02 := "a123456789 b123456789"
  s02_t1r0 := "a123456789    "
  s02_t1r1 := "b123456789    "
  // Test s02t1
  s02_t1 := _str_limiter(s02,14, alloc)
  assert(len(s02_t1) == 2, "Expected len(t_03) to be equal to 2")
  assert(s02_t1[0] == s02_t1r0, "Expected t_03[0] to be equal to s02_t1r0")
  assert(s02_t1[1] == s02_t1r1, "Expected t_03[1] to be equal to s02_t1r1")
  // String s03
  s03 := "a123456789 b123456789 c1234"
  s03_t1r0 := "a123456789    "
  s03_t1r1 := "b123456789    "
  s03_t1r2 := "c1234         "
  s03_t2r0 := "a123456789      "
  s03_t2r1 := "b123456789 c1234"
  // Test s03t1
  s03_t1 := _str_limiter(s03,14, alloc)
  assert(len(s03_t1) == 3, "Expected len(t_04) to be equal to 3")
  assert(s03_t1[0] == s03_t1r0, "Expected s03_t1[0] to be equal to s03_t1r0")
  assert(s03_t1[1] == s03_t1r1, "Expected s03_t1[1] to be equal to s03_t1r1")
  assert(s03_t1[2] == s03_t1r2, "Expected s03_t1[2] to be equal to s03_t1r2")
  // Test s03t2
  s03_t2 := _str_limiter(s03,16, alloc)
  log.info("s03_t2: %v", s03_t2)
  assert(len(s03_t2) == 2, "Expected _str_limiter(s_03,10, alloc) len to be 3")
  assert(s03_t2[0] == s03_t2r0, "Expected t_04[0] to be equal to s03_t1r0")
  assert(s03_t2[1] == s03_t2r1, "Expected t_04[1] to be equal to s03_t1r1")
  // String s04
  s04 := "The quick brown fox jumped over the lazy dogs."
  s04_t1r0, s04_t1r1, s04_t1r2, s04_t1r3 := "The quick     ","brown fox     ","jumped over   ","the lazy dogs."
  // Test s04t1
  s04_t1 := _str_limiter(s04,14, alloc)
  log.info("s04_t1: %v", s04_t1)
  assert(len(s04_t1) == 4, "Expected len(t_05) to be equal to 5")
  assert(s04_t1[0] == s04_t1r0, "Expected t_05[0] to be equal to s04_t1r0")
  assert(s04_t1[1] == s04_t1r1, "Expected t_05[1] to be equal to s04_t1r1")
  assert(s04_t1[2] == s04_t1r2, "Expected t_05[2] to be equal to s04_t1r2")
  assert(s04_t1[3] == s04_t1r3, "Expected t_05[3] to be equal to s04_t1r3")
}

@(test)
test_msg_system :: proc(t: ^testing.T) {
  // Create message system for navigation testing
  msgs := make_msg_system(5, 15, 3)
  defer delete_msg_system(&msgs)
  
  msg_add(&msgs, "This is a nice long message that should be split into five parts.")
  log.info("msgs:", msg_read(&msgs), "ptr:", msgs.ptr, "last:", msgs.last)
  
  assert(msgs.last == 4, "Expected _last to be equal to 4")
  
  // Test navigation indicators
  line, pos := msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Alpha, "Expected the first message")
  assert(line == "This is a nice ", "Wrong msg")
  
  msg_next(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Sigma, "Expected a middle message")
  assert(line == "long message   ", "Wrong msg")

  msg_next(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Sigma, "Expected a middle message")
  assert(line == "that should be ", "Wrong msg")
  
  msg_next(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Sigma, "Expected a middle message")
  assert(line == "split into five", "Wrong msg")
  
  msg_next(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Omega, "Expected the last message")
  assert(line == "parts.         ", "Wrong msg")
  
  msg_next(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Alpha, "Expected the first message")
  assert(line == "This is a nice ", "Wrong msg")
  
  msg_prev(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Omega, "Expected the last message")
  assert(line == "parts.         ", "Wrong msg")
  
  msg_prev(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Sigma, "Expected a middle message")
  assert(line == "split into five", "Wrong msg")
  
  msg_add(&msgs, "ThisWillBeSplitUp") // "ThisWillBeSpl--", "--itUp         "
  assert(msgs.last == 1, "Expected _last to be equal to 1")
  
  msg_prev(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Alpha, "Expected .Alpha")
  assert(line == "that should be ", "Wrong msg")
  
  msg_prev(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Omega, "Expected .Omega")
  assert(line == "--itUp         ", "Wrong msg")
  
  msg_prev(&msgs)
  line, pos = msg_read(&msgs), msg_ptr_pos(&msgs)
  assert(pos == .Sigma, "Expected .Sigma")
  assert(line == "ThisWillBeSpl--", "Wrong msg")
}
