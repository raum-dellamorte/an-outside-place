package raumortis

import rl "vendor:raylib"
import "core:math"
import la "core:math/linalg"

Vec3X :: [3]f32{1,0,0}
Vec3Y :: [3]f32{0,1,0}
Vec3Z :: [3]f32{0,0,1}

cam_follow_world_target :: proc(ctx: ^GameContext) {
  target : #soa ^WorldEnvSOA
  for &thing in ctx.world {
    if thing.is_cam_target {
      target = &thing
    }
  }
  if target != nil {
    orbit_cam_target(ctx, target)
  }
}

get_cam_target :: proc(ctx: ^GameContext) -> int {
  for thing, i in ctx.world {
    if thing.is_cam_target {
      return i
    }
  }
  return -1 // fixme: this should probably return an error
}

orbit_cam_target :: proc(ctx: ^GameContext, target: #soa ^WorldEnvSOA) {
  cam_target := &ctx.studio.camera.target
  cam_target^ = target.pos
  orbit_center := target.pos + Vec3Y * ctx.studio.cam_above
  target_cam_pos := calc_cam_pos(target.pos, target.rot, ctx.studio.cam_above, ctx.studio.cam_behind)
  current_offset := ctx.studio.camera.position - orbit_center
  desired_offset := target_cam_pos - orbit_center
  current_horizontal := [2]f32{current_offset.x, current_offset.z}
  desired_horizontal := [2]f32{desired_offset.x, desired_offset.z}
  desired_radius := ctx.studio.cam_behind
  current_radius := la.length(current_horizontal)
  current_angle := current_radius > 0.001 \
    ? math.atan2(current_horizontal.y,current_horizontal.x) \
    : math.atan2(desired_horizontal.y,desired_horizontal.x)
  desired_angle := math.atan2(desired_horizontal.y,desired_horizontal.x)
  t : f32 = la.smootherstep(cast(f32)0,1,(1.0/60.0) * ctx.studio.follow_drift)
  t = current_radius < ctx.studio.cam_behind ? t * 2.0 : t
  angle_delta := math.angle_diff(current_angle, desired_angle)
  new_angle := current_angle + angle_delta * t;
  // If the camera has gotten too close to the target, 
  // push it back toward the desired orbit radius
  new_radius := math.lerp(current_radius,desired_radius, t)
  new_y := math.lerp(ctx.studio.camera.position.y,target_cam_pos.y, t)
  cam_pos := &ctx.studio.camera.position
  cam_pos^ = {
    orbit_center.x + math.cos(new_angle) * new_radius,
    new_y,
    orbit_center.z + math.sin(new_angle) * new_radius,
  }
}

calc_cam_pos :: proc(
  look_at_pos: [3]f32,
  look_at_rot: quaternion128,
  above: f32,
  behind: f32,
) -> [3]f32 {
  behind_vec := la.quaternion128_mul_vector3(look_at_rot,Vec3Z)
  return look_at_pos + behind_vec * behind + Vec3Y * above
}

draw_model :: proc(model: ^rl.Model, transform: #row_major matrix[4,4]f32) {
  for i in 0..<model.meshCount {
    rl.DrawMesh(
      model.meshes[i],
      model.materials[model.meshMaterial[i]],
      transform,
    )
  }
}

delete_studio :: proc(studio: Studio) {
	_studio := studio
	shaders := _studio.shaders
	for _ in 0..<len(shaders) {
    shader_set : ShaderSet = pop(&shaders)
		rl.UnloadShader(shader_set.shader)
	}
	delete(shaders)
	// delete_mat_helper(mat_helper)
}
Studio :: struct {
  camera: rl.Camera3D,
  shaders: [dynamic]ShaderSet,
  follow_drift: f32,
  pan_drift: f32,
  cam_above: f32,
  cam_behind: f32,
}
