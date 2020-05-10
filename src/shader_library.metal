#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_texture>
#include <metal_geometric>
#include <metal_math>
#include <metal_graphics>

using namespace metal;



#import "dc_metal_types.h"

kernel void add_arrays(device const float* inA,
                       device const float* inB,
                       device float* result,
                       uint index [[thread_position_in_grid]])
{
    // the for-loop is replaced with a collection of threads, each of which
    // calls this function.
    result[index] = inA[index] + inB[index];
}

// I know "field" is unused, but I'll need to pass in some more data anyway for the real thing
kernel void init_field(device const SDF_Field_Entry* field [[buffer (0)]],
					   device SDF_Field_Entry* field_out [[buffer (1)]],
					   constant uint& dim [[buffer (2)]],
                       uint3 index [[thread_position_in_grid]])
{
	if ((((index.z * dim) + index.y) * dim + index.x) >= dim * dim * dim) {
		return;
	}


    SDF_Field_Entry_Dist(field_out[((index.z * dim) + index.y) * dim + index.x]) = 1.0;
    SDF_Field_Entry_Norm(field_out[((index.z * dim) + index.y) * dim + index.x]) = float3(1, 1, 1);
}

/////////////////////////////////////////////////////////////////////////


kernel void SDF_sphere(device SDF_Field_Entry* field        [[buffer (0)]],
					   constant const SDF_Command* cmd_args [[buffer (1)]],
					   constant const uint& dim             [[buffer (2)]],
					   constant const uint& which_cmd       [[buffer (3)]],
                       uint3 index [[thread_position_in_grid]])
{
	#define IDX() (((index.z * dim) + index.y) * dim + index.x)

	field[((index.z * dim) + index.y) * dim + index.x].db.gid.x = index.x;
	return;
	if ((((index.z * dim) + index.y) * dim + index.x) >= dim * dim * dim) {
		return;
	}

/*
		auto& cell = field[upos];
		auto  vec  = Vec3(upos) - center;
		auto  d    = vec.len() - rad;
		
		if (d < cell.dist) {
			cell.dist    = d;
			cell.normal  = normalized(vec);
		}

#define SDF_Field_Entry_Dist(e) e.data[3]
#define SDF_Field_Entry_Norm(e) e.data.xyz 

*/
	field[(((index.z * dim) + index.y) * dim + index.x)].data = float4(0.0);

	// TODO(Toby): figure if the coordinate matches the index correctly
    float3 vec = float3(index.x, index.y, index.z) - cmd_args[which_cmd].center.xyz;
    float d = length(vec) - cmd_args[which_cmd].args.x; // args.x should be the radius

    field[IDX()].db.cmd = cmd_args[which_cmd];
    field[IDX()].db.dim = dim;
    field[IDX()].db.which_cmd = which_cmd;
    field[IDX()].db.vec = vec;
    field[IDX()].db.d = d;

    const uint3 GID_SAVED = index;

    field[IDX()].db.gid = GID_SAVED;

    if (d < SDF_Field_Entry_Dist(field[(((index.z * dim) + index.y) * dim + index.x)])) {
    	SDF_Field_Entry_Dist(field[(((index.z * dim) + index.y) * dim + index.x)]) = d;
    	SDF_Field_Entry_Norm(field[(((index.z * dim) + index.y) * dim + index.x)]) = normalize(vec);

    	field[IDX()].db.dist_check_passed = 1.0;
    	field[IDX()].db.field_d_out = SDF_Field_Entry_Dist(field[(((index.z * dim) + index.y) * dim + index.x)]);

    	field[IDX()].db.field_nor_out = SDF_Field_Entry_Norm(field[(((index.z * dim) + index.y) * dim + index.x)]);

    } else {
    	field[IDX()].db.dist_check_passed = 0.0;
    }

    #undef IDX

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
