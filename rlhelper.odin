package raumortis

import "core:log"
import math "core:math/linalg"
// import "core:os"
// import "core:slice"
// import "core:strings"

// import gl "vendor:OpenGL"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

MMI :: rl.MaterialMapIndex
SLI :: rlgl.ShaderLocationIndex
SADT :: rlgl.ShaderAttributeDataType
SUDT :: rlgl.ShaderUniformDataType

MAX_MATERIAL_MAPS :: 12

ZeroPtr :: rawptr(uintptr(0)) // this is the same as c.NULL

RL_Flat4x4Matrix :: [16]f32

// Transcoded from rmodels.c in Raylib source
// ------------------------------------------
// Draw multiple mesh instances with material and different transforms
draw_mesh_instanced :: proc (mesh: rl.Mesh, material: rl.Material, transforms: ^[dynamic]rl.Matrix) {
  instances: int = len(transforms)
  if instances < 1 { return }
  
  // Bind shader program
  rlgl.EnableShader(material.shader.id)
  defer rlgl.DisableShader()
  
  // Send required data to shader (matrices, values)
  //-----------------------------------------------------
  // Upload to shader material.colDiffuse
  if material.shader.locs[SLI.COLOR_DIFFUSE] != -1 {
    values: [4]f32 = {
      f32(material.maps[MMI.ALBEDO].color.r),
      f32(material.maps[MMI.ALBEDO].color.g),
      f32(material.maps[MMI.ALBEDO].color.b),
      f32(material.maps[MMI.ALBEDO].color.a),
    }/255.0 // Divides each element by 255.0 to get values between 0.0 and 1.0
    rlgl.SetUniform(
      locIndex = material.shader.locs[SLI.COLOR_DIFFUSE], 
      value = &values[0], 
      uniformType = i32(SUDT.VEC4), 
      count = 1,
    )
  }
  
  // Upload to shader material.colSpecular (if location available)
  if material.shader.locs[SLI.COLOR_SPECULAR] != -1 {
    values: [4]f32 = {
      f32(material.maps[SLI.COLOR_SPECULAR].color.r),
      f32(material.maps[SLI.COLOR_SPECULAR].color.g),
      f32(material.maps[SLI.COLOR_SPECULAR].color.b),
      f32(material.maps[SLI.COLOR_SPECULAR].color.a),
    }/255.0
    rlgl.SetUniform(
      locIndex = material.shader.locs[SLI.COLOR_SPECULAR], 
      value = &values[0], 
      uniformType = i32(SUDT.VEC4), 
      count = 1,
    )
  }
  
  // Get a copy of current matrices to work with,
  // just in case stereo render is required, and we need to modify them
  // NOTE: At this point the modelview matrix just contains the view matrix (camera)
  // That's because BeginMode3D() sets it and there is no model-drawing function
  // that modifies it, all use rlPushMatrix() and rlPopMatrix()
  matModel: rl.Matrix = rl.Matrix(1)
  matView: rl.Matrix = rlgl.GetMatrixModelview()
  matModelView: rl.Matrix
  matProjection: rl.Matrix = rlgl.GetMatrixProjection()
  
  // Upload view and projection matrices (if locations available)
  if material.shader.locs[SLI.MATRIX_VIEW] != -1 {
    rlgl.SetUniformMatrix(
      locIndex = material.shader.locs[SLI.MATRIX_VIEW], 
      mat = matView,
    )
  }
  if material.shader.locs[SLI.MATRIX_PROJECTION] != -1 {
    rlgl.SetUniformMatrix(
      locIndex = material.shader.locs[SLI.MATRIX_PROJECTION],
      mat = matProjection,
    )
  }
  
  // Create instances buffer
  instanceTransforms := (cast ([^]RL_Flat4x4Matrix) rl.MemAlloc(cast (u32) instances * size_of(RL_Flat4x4Matrix)))
  defer rl.MemFree(instanceTransforms)
  
  // Fill buffer with instances transformations as float16 arrays
  for i in 0..<instances {
    instanceTransforms[i] = transmute ([16]f32) math.transpose(transforms[i])
  }
  
  // Enable mesh VAO to attach new buffer
  rlgl.EnableVertexArray(mesh.vaoId)
  
  // This could alternatively use a static VBO and either glMapBuffer() or glBufferSubData()
  // It isn't clear which would be reliably faster in all cases and on all platforms,
  // anecdotally glMapBuffer() seems very slow (syncs) while glBufferSubData() seems
  // no faster, since we're transferring all the transform matrices anyway
  instancesVboId := rlgl.LoadVertexBuffer(instanceTransforms, cast (i32) instances * size_of(RL_Flat4x4Matrix), false)
  defer rlgl.UnloadVertexBuffer(instancesVboId)
  
  // Instances transformation matrices are sent to shader attribute location: SLI.MATRIX_MODEL
  for i in 0..<i32(4) {
    rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.MATRIX_MODEL] + i))
    // I was using i * size_of(rl.Vector4) for the pointer
    offset := i * size_of(rl.Vector4)
    rlgl.SetVertexAttribute(
      index = u32(material.shader.locs[SLI.MATRIX_MODEL] + i),
      compSize = 4,
      type = rlgl.FLOAT,
      normalized = false,
      stride = size_of(rl.Matrix),
      offset = offset,
    )
    rlgl.SetVertexAttributeDivisor(u32(material.shader.locs[SLI.MATRIX_MODEL] + i), 1)
  }
  
  rlgl.DisableVertexBuffer()
  rlgl.DisableVertexArray()
  
  // Accumulate internal matrix transform (push/pop) and view matrix
  // NOTE: In this case, model instance transformation must be computed in the shader
  // matModelView = rlgl.GetMatrixTransform() * matView
  matModelView = transmatmult(rlgl.GetMatrixTransform(),matView)
  
  // Upload model normal matrix (if locations available)
  if material.shader.locs[SLI.MATRIX_NORMAL] != -1 {
    rlgl.SetUniformMatrix(
      material.shader.locs[SLI.MATRIX_NORMAL], 
      rl.MatrixTranspose(rl.MatrixInvert(matModel)),
    )
  }
  //-----------------------------------------------------
  
  // Bind active texture maps (if available)
  for i in 0..<MAX_MATERIAL_MAPS {
    if (material.maps[i].texture.id > 0) {
      // Select current shader texture slot
      rlgl.ActiveTextureSlot(i32(i))
      // Enable texture for active slot
      #partial switch cast(MMI) i {
      case .IRRADIANCE, .PREFILTER, .CUBEMAP:
        rlgl.EnableTextureCubemap(material.maps[i].texture.id)
      case:
        rlgl.EnableTexture(material.maps[i].texture.id)
      }
      
      value :int = i
      rlgl.SetUniform(material.shader.locs[SLI.MAP_ALBEDO + SLI(i)], &value, i32(SUDT.INT), 1)
    }
  }

  // Try binding vertex array objects (VAO)
  // or use VBOs if not possible
  if !rlgl.EnableVertexArray(mesh.vaoId) {
    // Bind mesh VBO data: vertex position (shader-location = 0)
    rlgl.EnableVertexBuffer(mesh.vboId[0])
    rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_POSITION]), 3, rlgl.FLOAT, false, 0, 0)
    rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_POSITION]))
    
    // Bind mesh VBO data: vertex texcoords (shader-location = 1)
    rlgl.EnableVertexBuffer(mesh.vboId[1])
    rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD01]), 2, rlgl.FLOAT, false, 0, 0)
    rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD01]))
    
    if material.shader.locs[SLI.VERTEX_NORMAL] != -1 {
      // Bind mesh VBO data: vertex normals (shader-location = 2)
      rlgl.EnableVertexBuffer(mesh.vboId[2])
      rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_NORMAL]), 3, rlgl.FLOAT, false, 0, 0)
      rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_NORMAL]))
    }
    
    // Bind mesh VBO data: vertex colors (shader-location = 3, if available)
    if (material.shader.locs[SLI.VERTEX_COLOR] != -1) {
      if (mesh.vboId[3] != 0) {
        rlgl.EnableVertexBuffer(mesh.vboId[3])
        rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_COLOR]), 4, rlgl.UNSIGNED_BYTE, true, 0, 0)
        rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_COLOR]))
      } else {
        // Set default value for unused attribute
        // NOTE: Required when using default shader and no VAO support
        value: [4]f32 = { 1, 1, 1, 1 }
        rlgl.SetVertexAttributeDefault(material.shader.locs[SLI.VERTEX_COLOR], raw_data(value[:]), i32(SADT.VEC4), 4)
        rlgl.DisableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_COLOR]))
      }
    }
    
    // Bind mesh VBO data: vertex tangents (shader-location = 4, if available)
    if (material.shader.locs[SLI.VERTEX_TANGENT] != -1) {
      rlgl.EnableVertexBuffer(mesh.vboId[4])
      rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TANGENT]), 4, rlgl.FLOAT, false, 0, 0)
      rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TANGENT]))
    }
    
    // Bind mesh VBO data: vertex texcoords2 (shader-location = 5, if available)
    if material.shader.locs[SLI.VERTEX_TEXCOORD02] != -1 {
      rlgl.EnableVertexBuffer(mesh.vboId[5])
      rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD02]), 2, rlgl.FLOAT, false, 0, 0)
      rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD02]))
    }
  
    if mesh.indices != ZeroPtr { rlgl.EnableVertexBufferElement(mesh.vboId[6]) }
  }
  
  eyeCount:i32 = 1
  if rlgl.IsStereoRenderEnabled() { eyeCount = 2 }
  
  for eye in 0..<eyeCount {
    // Calculate model-view-projection matrix (MVP)
    matModelViewProjection := rl.Matrix(1)
    if eyeCount == 1 {
      // matModelViewProjection = matModelView * matProjection // This doesn't work
      matModelViewProjection = transmatmult(matModelView, matProjection)
    } else {
      // Setup current eye viewport (half screen width)
      rlgl.Viewport(eye * rlgl.GetFramebufferWidth() / 2, 0, rlgl.GetFramebufferWidth() / 2, rlgl.GetFramebufferHeight())
      matModelViewProjection = transmatmult(
        rl.MatrixTranspose(transmatmult(matModelView, rlgl.GetMatrixViewOffsetStereo(eye))),
        rlgl.GetMatrixProjectionStereo(eye),
      )
    }
    
    // Send combined model-view-projection matrix to shader
    rlgl.SetUniformMatrix(material.shader.locs[SLI.MATRIX_MVP], matModelViewProjection)
    
    // Draw mesh instanced
    if mesh.indices != ZeroPtr {
      rlgl.DrawVertexArrayElementsInstanced(0, mesh.triangleCount * 3, ZeroPtr, i32(instances))
    } else {
      rlgl.DrawVertexArrayInstanced(0, mesh.vertexCount, i32(instances)) // We call this one.
    }
  }

  // Unbind all bound texture maps
  for i in 0..<MAX_MATERIAL_MAPS {
    if material.maps[i].texture.id > 0 {
      // Select current shader texture slot
      rlgl.ActiveTextureSlot( i32(i) )
      
      #partial switch cast(MMI) i {
      case .IRRADIANCE, .PREFILTER, .CUBEMAP:
        rlgl.DisableTextureCubemap()
      case:
        rlgl.DisableTexture()
      }
    }
  }

  // Disable all possible vertex array objects (or VBOs)
  rlgl.DisableVertexArray()
  rlgl.DisableVertexBuffer()
  rlgl.DisableVertexBufferElement()
}

// rlhSetUniform :: proc(locIndex: int, value: $T, uniformType: SUDT, count: int) {
//   switch uniformType {
//   case .FLOAT:     gl.Uniform1fv(locIndex, count, value)
//   case .VEC2:      gl.Uniform2fv(locIndex, count, value)
//   case .VEC3:      gl.Uniform3fv(locIndex, count, value)
//   case .VEC4:      gl.Uniform4fv(locIndex, count, value)
//   case .INT:       gl.Uniform1i(locIndex, value)
//   case .IVEC2:     gl.Uniform2iv(locIndex, count, value)
//   case .IVEC3:     gl.Uniform3iv(locIndex, count, value)
//   case .IVEC4:     gl.Uniform4iv(locIndex, count, value)
//   case .SAMPLER2D: gl.Uniform1iv(locIndex, count, value)
//   case: // TRACELOG(RL_LOG_WARNING, "SHADER: Failed to set uniform value, data type not recognized");
//   }
// }

// // This is not needed. transmute ([16]f32) rl.MatrixTranspose(row_major_matrix) is equivalent.
// rlhMatrixToFloatV :: proc(mat: #row_major matrix[4,4]f32) -> RL_Flat4x4Matrix {
//   out : [16]f32
//   out[0]  = mat[0,0]
//   out[1]  = mat[1,0]
//   out[2]  = mat[2,0]
//   out[3]  = mat[3,0]
//   out[4]  = mat[0,1]
//   out[5]  = mat[1,1]
//   out[6]  = mat[2,1]
//   out[7]  = mat[3,1]
//   out[8]  = mat[0,2]
//   out[9]  = mat[1,2]
//   out[10] = mat[2,2]
//   out[11] = mat[3,2]
//   out[12] = mat[0,3]
//   out[13] = mat[1,3]
//   out[14] = mat[2,3]
//   out[15] = mat[3,3]
//   return out
// }

transmatmult :: proc(left, right: #row_major matrix[4,4]f32) -> #row_major matrix[4,4]f32 {
  result : #row_major matrix[4,4]f32
  
  // result.m0 = left.m0*right.m0 + left.m1*right.m4 + left.m2*right.m8 + left.m3*right.m12;
  result[0,0] = left[0,0]*right[0,0] + left[1,0]*right[0,1] + left[2,0]*right[0,2] + left[3,0]*right[0,3]
  // result.m1 = left.m0*right.m1 + left.m1*right.m5 + left.m2*right.m9 + left.m3*right.m13;
  result[1,0] = left[0,0]*right[1,0] + left[1,0]*right[1,1] + left[2,0]*right[1,2] + left[3,0]*right[1,3]
  // result.m2 = left.m0*right.m2 + left.m1*right.m6 + left.m2*right.m10 + left.m3*right.m14;
  result[2,0] = left[0,0]*right[2,0] + left[1,0]*right[2,1] + left[2,0]*right[2,2] + left[3,0]*right[2,3]
  // result.m3 = left.m0*right.m3 + left.m1*right.m7 + left.m2*right.m11 + left.m3*right.m15;
  result[3,0] = left[0,0]*right[3,0] + left[1,0]*right[3,1] + left[2,0]*right[3,2] + left[3,0]*right[3,3]
  // result.m4 = left.m4*right.m0 + left.m5*right.m4 + left.m6*right.m8 + left.m7*right.m12;
  result[0,1] = left[0,1]*right[0,0] + left[1,1]*right[0,1] + left[2,1]*right[0,2] + left[3,1]*right[0,3]
  // result.m5 = left.m4*right.m1 + left.m5*right.m5 + left.m6*right.m9 + left.m7*right.m13;
  result[1,1] = left[0,1]*right[1,0] + left[1,1]*right[1,1] + left[2,1]*right[1,2] + left[3,1]*right[1,3]
  // result.m6 = left.m4*right.m2 + left.m5*right.m6 + left.m6*right.m10 + left.m7*right.m14;
  result[2,1] = left[0,1]*right[2,0] + left[1,1]*right[2,1] + left[2,1]*right[2,2] + left[3,1]*right[2,3]
  // result.m7 = left.m4*right.m3 + left.m5*right.m7 + left.m6*right.m11 + left.m7*right.m15;
  result[3,1] = left[0,1]*right[3,0] + left[1,1]*right[3,1] + left[2,1]*right[3,2] + left[3,1]*right[3,3]
  // result.m8 = left.m8*right.m0 + left.m9*right.m4 + left.m10*right.m8 + left.m11*right.m12;
  result[0,2] = left[0,2]*right[0,0] + left[1,2]*right[0,1] + left[2,2]*right[0,2] + left[3,2]*right[0,3]
  // result.m9 = left.m8*right.m1 + left.m9*right.m5 + left.m10*right.m9 + left.m11*right.m13;
  result[1,2] = left[0,2]*right[1,0] + left[1,2]*right[1,1] + left[2,2]*right[1,2] + left[3,2]*right[1,3]
  // result.m10 = left.m8*right.m2 + left.m9*right.m6 + left.m10*right.m10 + left.m11*right.m14;
  result[2,2] = left[0,2]*right[2,0] + left[1,2]*right[2,1] + left[2,2]*right[2,2] + left[3,2]*right[2,3]
  // result.m11 = left.m8*right.m3 + left.m9*right.m7 + left.m10*right.m11 + left.m11*right.m15;
  result[3,2] = left[0,2]*right[3,0] + left[1,2]*right[3,1] + left[2,2]*right[3,2] + left[3,2]*right[3,3]
  // result.m12 = left.m12*right.m0 + left.m13*right.m4 + left.m14*right.m8 + left.m15*right.m12;
  result[0,3] = left[0,3]*right[0,0] + left[1,3]*right[0,1] + left[2,3]*right[0,2] + left[3,3]*right[0,3]
  // result.m13 = left.m12*right.m1 + left.m13*right.m5 + left.m14*right.m9 + left.m15*right.m13;
  result[1,3] = left[0,3]*right[1,0] + left[1,3]*right[1,1] + left[2,3]*right[1,2] + left[3,3]*right[1,3]
  // result.m14 = left.m12*right.m2 + left.m13*right.m6 + left.m14*right.m10 + left.m15*right.m14;
  result[2,3] = left[0,3]*right[2,0] + left[1,3]*right[2,1] + left[2,3]*right[2,2] + left[3,3]*right[2,3]
  // result.m15 = left.m12*right.m3 + left.m13*right.m7 + left.m14*right.m11 + left.m15*right.m15;
  result[3,3] = left[0,3]*right[3,0] + left[1,3]*right[3,1] + left[2,3]*right[3,2] + left[3,3]*right[3,3]
  
  return result
}

// Matrix multiplication between Odin and Raylib appears to be different.
// In Raylib C, mat.m2 == mat[row 1,col 0], mat.m12 == mat[row 0, col 3]
// From raymath.h: "In memory order, row0 is [m0 m4 m8 m12] but in semantic math row0 is [m0 m1 m2 m3]"
// draw_mesh_instanced now works using Raylib's MatrixMultiply ported to the Odin version above.
import "core:testing"
import "base:intrinsics"
rm_mat1 :: #row_major matrix[4,4]f32 {
   2., 3., 5., 7.,
  11.,13.,17.,19.,
  23.,29.,31.,37.,
  41.,43.,47.,53.,
}
cm_mat1 :: matrix[4,4]f32 {
   2., 3., 5., 7.,
  11.,13.,17.,19.,
  23.,29.,31.,37.,
  41.,43.,47.,53.,
}
rm_mat2 :: #row_major matrix[4,4]f32 {
   .2, .3, .5, .7,
  .11,.13,.17,.19,
  .23,.29,.31,.37,
  .41,.43,.47,.53,
}
cm_mat2 :: matrix[4,4]f32 {
   .2, .3, .5, .7,
  .11,.13,.17,.19,
  .23,.29,.31,.37,
  .41,.43,.47,.53,
}
@(test)
tests :: proc(^testing.T) {
  ident := rl.Matrix(1)
  log.info("Test")
  rlhm := transmatmult(rm_mat1, rm_mat2)
  cm_mul_odin := cm_mat1 * cm_mat2
  rm_mul_odin := rm_mat1 * rm_mat2
  cm_tpose_mul_odin := math.transpose(math.transpose(cm_mat1) * math.transpose(cm_mat2))
  rm_tpose_mul_odin := math.transpose(math.transpose(rm_mat1) * math.transpose(rm_mat2))
  assert(ident * ident == ident)
  assert(transmatmult(ident,ident) == ident)
  assert(transmatmult(rm_mat1,ident) == rm_mat1)
  assert(rlhm != rm_mul_odin)
  assert(rm_tpose_mul_odin == rlhm) // We did it!
  assert(cast (#row_major matrix[4,4]f32) (cm_mat1 * cm_mat2) != rlhm)
  assert(transmute (#row_major matrix[4,4]f32) (transmute (matrix[4,4]f32) rm_mat1 * transmute (matrix[4,4]f32) rm_mat2) != rlhm)
  assert(transmute (#row_major matrix[4,4]f32) (cast (matrix[4,4]f32) rm_mat1 * cast (matrix[4,4]f32) rm_mat2) != rlhm)
  assert(cast (#row_major matrix[4,4]f32) (cm_mat1 * cm_mat2) != rl.MatrixTranspose(rlhm))
  assert(rl.MatrixTranspose(rm_mat1 * rm_mat2) != transmatmult(rm_mat1, rm_mat2))
  assert(rl.MatrixTranspose(rm_mat1) * rl.MatrixTranspose(rm_mat2) != transmatmult(rm_mat1, rm_mat2))
  // assert(rlhMatrixToFloatV(rm_mat1) != matrix_flatten(rm_mat1))
  // assert((transmute ([16]f32) rl.MatrixTranspose(rm_mat1)) == rlhMatrixToFloatV(rm_mat1))
  log.info("transmatmult(rm_mat1, rm_mat2)",rlhm)
  log.info("native col major:",cm_mul_odin)
  log.info("native col major transpose(transpose(mat) * transpose(mat)):",cm_tpose_mul_odin)
  log.info("native row major transpose(transpose(mat) * transpose(mat)):",rm_tpose_mul_odin)
  log.info("native row major:",rm_mul_odin)
}

