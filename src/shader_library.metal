#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_texture>
#include <metal_geometric>
#include <metal_math>
#include <metal_graphics>

using namespace metal;



#import "dc_metal_types.h"

// I know "field" is unused, but I'll need to pass in some more data anyway for the real thing
kernel void init_field(device SDF_Field_Entry* field [[buffer (0)]],
					   constant SDF_Command* cmds [[buffer (1)]],
					   constant uint& dim [[buffer (2)]],
					   constant uint& phase_idx [[buffer (3)]],
                       uint3 index [[thread_position_in_grid]])
{
	#define IDX() ((index.z * dim) + index.y) * dim + index.x

	if (IDX() >= dim * dim * dim) {
		return;
	}

	char CH = 'a';

	int x = __LINE__;

	float3 vec = float3(index.x, index.y, index.z) - cmds[phase_idx].center.xyz;
	float d = length(vec) - cmds[phase_idx].args.x;

	if (d < SDF_Distance(field[IDX()])) {
		SDF_Distance(field[IDX()]) = d;
		SDF_Normal(field[IDX()])   = normalize(vec);
		field[IDX()].db.check_passed = 1;
	} else {
		field[IDX()].db.check_passed = 0;
	}


	// DEBUG
	field[IDX()].db.vec = vec;
	field[IDX()].db.d   = d;

    // DEBUG
    field[IDX()].db.gid = index;
    field[IDX()].db.gid_as_float = float3(index.x, index.y, index.z);
    field[IDX()].db.gid_flat = IDX();
    field[IDX()].db.phase_idx = phase_idx;
    field[IDX()].db.cmd.center = cmds[phase_idx].center;
    field[IDX()].db.cmd.args = cmds[phase_idx].args;


    #undef IDX

}

kernel void SDF_sphere(device const SDF_Field_Entry* field [[buffer (0)]],
					   device SDF_Field_Entry* field_out [[buffer (1)]],
					   constant uint& dim [[buffer (2)]],
                       uint3 index [[thread_position_in_grid]])
{
	if ((((index.z * dim) + index.y) * dim + index.x) >= dim * dim * dim) {
		return;
	}
}

kernel void SDF_torus(device const SDF_Field_Entry* field [[buffer (0)]],
					   device SDF_Field_Entry* field_out [[buffer (1)]],
					   constant uint& dim [[buffer (2)]],
                       uint3 index [[thread_position_in_grid]])
{
	if ((((index.z * dim) + index.y) * dim + index.x) >= dim * dim * dim) {
		return;
	}
}

kernel void SDF_cube(device const SDF_Field_Entry* field [[buffer (0)]],
					   device SDF_Field_Entry* field_out [[buffer (1)]],
					   constant uint& dim [[buffer (2)]],
                       uint3 index [[thread_position_in_grid]])
{
	if ((((index.z * dim) + index.y) * dim + index.x) >= dim * dim * dim) {
		return;
	}
}
