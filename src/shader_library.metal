#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_texture>
#include <metal_geometric>
#include <metal_math>
#include <metal_graphics>

using namespace metal;



#import "dc_metal_types.h"

#define MTL_DEBUG_ON
#ifdef MTL_DEBUG_ON
#define MTL_DEBUG(expr) expr

template <typename... Rest> constexpr  void MTL_print_outer_(device char** out_buffer, constant char* const first, const Rest... rest);
constexpr void MTL_print_(device char** out_buffer);
template <typename... Rest> constexpr void MTL_print_(device char** out_buffer, constant float& first, const Rest... rest);
template <typename... Rest> constexpr void MTL_print_(device char** out_buffer, constant char* const first, const Rest... rest);

constexpr void MTL_print_(device char** out_buffer) 
{
	*(*out_buffer) = '\0';
	return;
}
constexpr void MTL_print_() 
{
}
template <typename... Rest> constexpr void MTL_print_(device char** out_buffer, float first, const Rest... rest)
{
	uint _first = as_type<uint>(first);
	(*out_buffer)[0] =  _first        & 0xFF;
	(*out_buffer)[1] = (_first >> 8)  & 0xFF;
	(*out_buffer)[2] = (_first >> 16) & 0xFF;
	(*out_buffer)[3] = (_first >> 24) & 0xFF;

	(*out_buffer) += sizeof(float);

	MTL_print_(out_buffer, rest...);
}
template <typename... Rest> constexpr void MTL_print_(device char** out_buffer, constant char* const first, const Rest... rest)
{
	uint i = 0;
	while (first[i] != '\0') {
		(*out_buffer)[i] = first[i];
		i += 1;
	}
	(*out_buffer)[i] = '\0';
	(*out_buffer) += i;
	MTL_print_(out_buffer, rest...);
}
template <typename... Rest> constexpr void MTL_print_outer_(device char** out_buffer, constant char* const first, const Rest... rest)
{
	uint i = 0;
	while (first[i] != '\0') {
		(*out_buffer)[i + 1] = first[i];
		i += 1;
	}
	// length for format string (max of 255 for now)
	(*out_buffer)[0] = (i & 0xFF) + 'a' - 1;
	(*out_buffer) += i + 1;
	MTL_print_(out_buffer, rest...);
}

#define MTL_print(out_buffer, ...) MTL_print_outer_(out_buffer, __VA_ARGS__)
#else
#define MTL_DEBUG(expr)
#define MTL_print(...)
#endif

/*
kernel void SDF_init_field()
{
	
}
*/



kernel void SDF_sphere(device SDF_Field_Entry* field [[buffer (0)]],
					   constant SDF_Command* cmds [[buffer (1)]],
					   constant uint& dim [[buffer (2)]],
					   constant uint& phase_idx [[buffer (3)]],
					#ifdef MTL_DEBUG_ON
					   device char* log_out [[buffer (4)]],
					#endif
                       uint3 index [[thread_position_in_grid]])
{
	#define IDX() (((index.z * dim) + index.y) * dim + index.x)

	if (IDX() >= dim * dim * dim) {
		return;
	}

	uint log_idx = 128 * (IDX());
	device char* log_ptr = &log_out[log_idx];
	MTL_print(&log_ptr, "%f\n", 7889340.4598, "hello");

	float3 vec = float3(index.x, index.y, index.z) - cmds[phase_idx].center.xyz;
	float d = length(vec) - cmds[phase_idx].args.x;

	if (d < SDF_Distance(field[IDX()])) {
		SDF_Distance(field[IDX()]) = d;
		SDF_Normal(field[IDX()])   = normalize(vec);
		MTL_DEBUG(field[IDX()].db.check_passed = 1);
	} MTL_DEBUG(else {
		field[IDX()].db.check_passed = 0;
	})


	// DEBUG
	MTL_DEBUG(
		field[IDX()].db.vec = vec;
		field[IDX()].db.d   = d;

	    // DEBUG
	    field[IDX()].db.gid = index;
	    field[IDX()].db.gid_as_float = float3(index.x, index.y, index.z);
	    field[IDX()].db.gid_flat = IDX();
	    field[IDX()].db.phase_idx = phase_idx;
	    field[IDX()].db.cmd.center = cmds[phase_idx].center;
	    field[IDX()].db.cmd.args = cmds[phase_idx].args;
	    field[IDX()].db.address_of_log_buffer = log_idx;
    )


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
