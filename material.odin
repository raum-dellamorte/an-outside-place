package raumortis

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

MatError :: enum {
  Ok,
  FileNotFound,
}

TextureDir :: "res/textures/"
TextureExt :: ".png"

TextureItem :: struct {
  file: string,
  tex:  rl.Texture,
}
get_texture_by_name :: proc(textures: []TextureItem, name: string) -> (rl.Texture, MatError) {
  for &t in textures {
    if t.file == name { return t.tex, .Ok }
  }
  return {}, .FileNotFound
}

gen_texture_list :: proc() -> []TextureItem {
  out := []TextureItem {
    {file = "cube-color-atlas", tex = {} }, // Maybe don't hard code this
  }
  for i in 0..<len(out) {
    _file := []string { TextureDir, out[i].file, TextureExt }
    file := strings.unsafe_string_to_cstring(strings.concatenate(_file))
    out[i].tex = rl.LoadTexture(file)
  }
  return out
}

MaterialHelper :: struct {
  maps: [dynamic][11]rl.MaterialMap,
  mats: [dynamic]rl.Material,
  pointer: [^]rl.Material,
}

MatAssign :: struct {
  shader: int,
  texture: []string,
  color: int,
  value: f32,
}

// For assignments, a zero value for shader, texture, or color in MatAssign leaves zero values
// in the resulting MaterialHelper whereas 1 is the first element of the provided matching array.
// Example: MatAssign {1, 3, 0, 1.4} assigns shaders[0], the first shader in shaders, as the
// shader for the nth, with respect to assignments[n], Material, along with the third Texture,
// texures[2], and does not assign a color, thus leaving it at a zero value. And, while I'm
// pedantically documenting, value is set directly.
gen_materials :: proc(assignments: []MatAssign, shaders: ^[dynamic]ShaderSet, textures: []TextureItem, colors: []rl.Color) -> MaterialHelper {
  sz := len(assignments)
  matmaps := make([dynamic][11]rl.MaterialMap,sz,sz)
  mats := make([dynamic]rl.Material,sz,sz)
  for a, i in assignments {
    matmaps[i] = [11]rl.MaterialMap {}
    mats[i].maps = raw_data(matmaps[i][:])
    if a.shader > 0 && a.shader <= len(shaders) {
      mats[i].shader = shaders[a.shader - 1].shader
    }
    if len(a.texture) > 0 && a.texture[0] != "" {
      if tex, ok := get_texture_by_name(textures, a.texture[0]); ok == .Ok {
        mats[i].maps[0].texture = tex
      }
    }
    if len(colors) > 0 && a.color > 0 && a.color <= len(colors) {
      mats[i].maps[0].color = colors[a.color - 1]
    }
    mats[i].maps[0].value = a.value
  }
  return MaterialHelper{matmaps, mats, raw_data(mats[:])}
}
delete_mat_helper :: proc(mh: MaterialHelper) {
  delete(mh.maps)
  delete(mh.mats)
}

