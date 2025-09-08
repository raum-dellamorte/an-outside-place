package raumortis

import "core:fmt"
import "core:io"
import "core:strconv"
import "core:strings"
// import "core:text/regex"

io :: io

wprintf                    :: fmt.wprintf
wprintln                   :: fmt.wprintln
wprintfln                  :: fmt.wprintfln
sbprint                    :: fmt.sbprint

parse_f32                  :: strconv.parse_f32
parse_f64                  :: strconv.parse_f64
parse_uint                 :: strconv.parse_uint
parse_int                  :: strconv.parse_int

concatenate                :: strings.concatenate
split                      :: strings.split
string_builder_make        :: strings.builder_make
string_builder_destroy     :: strings.builder_destroy
string_to_writer           :: strings.to_writer
unsafe_string_to_cstring   :: strings.unsafe_string_to_cstring

cat_to_cstr :: proc(s: []string) -> cstring {
  return unsafe_string_to_cstring(concatenate(s))
}

ParseResError :: enum {
  Ok,
  NoMatch,
  Incomplete,
  EmptyInput,
  ParseIntFail,
  ParseFloatFail,
}

ParseRes :: struct {
  pre: string,
  res: string,
  rem: string,
  err: ParseResError,
  // Data
  data: string,
  data_int: int,
  data_float: f64,
}

ParseRule :: enum {
  ToNewline,
  ToMatching,
  DataToInt,
  DataToFloat,
}

process_parse_res :: proc(r: ^ParseRes, rule: ParseRule) {
  switch rule {
  case .ToNewline:
    r^.data, r^.rem = two_strings(take_until(r.rem, is_newline, true))
  case .ToMatching:
    r^.data, r^.rem = two_strings(take_thru_matching(r.rem))
  case .DataToInt:
    data, ok := parse_int(r.data)
    if ok {
      r^.data_int = data
    } else {
      r^.err = .ParseIntFail
      println("parse_int failed:", r.data)
    }
  case .DataToFloat:
    data, ok := parse_f64(r.data)
    if ok {
      r^.data_float = data
    } else {
      r^.err = .ParseFloatFail
      println("parse_f64 failed:", r.data)
    }
  }
}

expect_one_of :: proc(s: string, labels: []string, terminator := "", discard_term_and_ws := true) -> ParseRes {
  sn := len(s)
  if sn == 0 { return { err = .EmptyInput } }
  tn := len(terminator)
  ln := 0
  for lbl in labels {
    ln = len(lbl)
    rem_marker : int
    if sn >= ln && lbl == s[:ln] {
      if discard_term_and_ws &&
         tn > 0 && 
         sn >= ln + tn && 
         s[ln:ln + tn] == terminator
      {
        rem_marker = ln + tn
      } else {
        rem_marker = ln
      }
    }
    if rem_marker > 0 {
      if discard_term_and_ws {
        return { res = lbl, rem = strip_left(s[rem_marker:]) }
      }
      return { res = lbl, rem = s[rem_marker:] }
    }
  }
  return { err = .NoMatch, rem = s }
}

expect_label :: proc(s: string, label: string, terminator := "", discard_term_and_ws := true) -> ParseRes {
  return expect_one_of(s, { label }, terminator, discard_term_and_ws)
}

take_while :: proc(s: string, f: proc(rune: rune) -> bool) -> ParseRes {
  idx := 0
  for r in s {
    if !f(r) {
      break
    }
    idx += 1
  }
  return {res = s[:idx], rem = s[idx:]}
}

take_thru :: proc(s: string, f: proc(rune: rune) -> bool) -> ParseRes {
  idx := 0
  for r in s {
    if f(r) {
      idx += 1
      break
    }
    idx += 1
  }
  return {res = s[:idx], rem = s[idx:]}
}

take_until :: proc(s: string, f: proc(rune: rune) -> bool, discard := false) -> ParseRes {
  idx := 0
  for r in s {
    if f(r) {
      break
    }
    idx += 1
  }
  if discard && idx < len(s) {
    return {res = s[:idx], rem = strip_left(s[idx + 1:])}
  } else {
    return {res = s[:idx], rem = s[idx:]}
  }
}

discard_until_then_while :: proc(s: string, f: proc(rune: rune) -> bool) -> string {
  return take_while(take_until(s, f).rem, f).rem
}

take_thru_matching :: proc(s: string) -> ParseRes {
  if len(s) < 1 {
    return {rem = s, err = .EmptyInput}
  }
  before, s := two_strings(take_thru(s, is_open_matchable))
  if len(s) < 1 {
    return {rem = s, err = .Incomplete}
  }
  if len_b := len(before); len_b < 1 {
    return {rem = s, err = .NoMatch}
  } else if len_b > 1 {
    before = before[len(before) - 1:]
  }
  open_f : proc(rune) -> bool
  close_f : proc(rune) -> bool
  switch before[len(before) - 1] {
  case '{':
    open_f = is_open_brace
    close_f = is_close_brace
  case '[':
    open_f = is_open_bracket
    close_f = is_close_bracket
  case '(':
    open_f = is_open_paren
    close_f = is_close_paren
  }
  depth := 0
  idx := 0
  loop: for r, i in s {
    switch {
    case depth == 0 && close_f(r):
      idx = i
      break loop
    case open_f(r): depth += 1
    case close_f(r): depth -= 1
    }
  }
  rem := s[idx + 1:len(s)]
  if len(rem) > 0 {
    rem = strip_left(rem)
  }
  return {pre = before, res = strip_string(s[0:idx]), rem = rem}
}

strip_left :: proc(s: string) -> string {
  return take_while(s, is_space).rem
}

strip_right :: proc(s: string) -> string {
  i := len(s)
  #reverse for r in s {
    if is_space(r) {
      i -= 1
    } else { break }
  }
  return s[:i]
}

strip_string :: proc(s: string) -> string {
  return strip_left(strip_right(s))
}

two_strings :: proc(ss: ParseRes) -> (string, string) {
  return ss.res, ss.rem
}

three_strings :: proc(ss: ParseRes) -> (string, string, string) {
  return ss.pre, ss.res, ss.rem
}

// Example predicates
is_digit :: proc(r: rune) -> bool {
  return '0' <= r && r <= '9'
}

is_alpha :: proc(r: rune) -> bool {
  return ('a' <= r && r <= 'z') || ('A' <= r && r <= 'Z')
}

is_colon :: proc(r: rune) -> bool {
  return r == ':'
}

is_space :: proc(r: rune) -> bool {
  return r == ' ' || r == '\t' || is_newline(r)
}

is_newline :: proc(r: rune) -> bool {
  return r == '\n' || r == '\r'
}

is_open_brace :: proc(r: rune) -> bool {
  return r == '{'
}

is_close_brace :: proc(r: rune) -> bool {
  return r == '}'
}

is_open_bracket :: proc(r: rune) -> bool {
  return r == '['
}

is_close_bracket :: proc(r: rune) -> bool {
  return r == ']'
}

is_open_paren :: proc(r: rune) -> bool {
  return r == '('
}

is_close_paren :: proc(r: rune) -> bool {
  return r == ')'
}

is_matchable :: proc(r: rune) -> bool {
  return is_open_matchable(r) || is_close_matchable(r)
}

is_open_matchable :: proc(r: rune) -> bool {
  return is_open_brace(r) || is_open_bracket(r) || is_open_paren(r)
}

is_close_matchable :: proc(r: rune) -> bool {
  return is_close_brace(r) || is_close_bracket(r) || is_close_paren(r)
}


