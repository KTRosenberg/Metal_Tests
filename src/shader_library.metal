#include <metal_stdlib>
#include <simd/simd.h>

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

kernel void generate_field(device SDF_Field_Entry* field,
                       uint3 index [[thread_position_in_grid]])
{
    field[((index.z * 128) + index.y) * 128 + index.x].pos = float4(1, 1, 1, 1);
    field[((index.z * 128) + index.y) * 128 + index.x].nor = float4(1, 1, 1, 1);
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


    field_out[((index.z * dim) + index.y) * dim + index.x].pos = float4(1, 1, 1, 1);
    field_out[((index.z * dim) + index.y) * dim + index.x].nor = float4(1, 1, 1, 1);
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
