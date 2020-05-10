
#ifndef DC_METAL_TYPES_H
#define DC_METAL_TYPES_H

#include <simd/simd.h>
using namespace simd;

struct alignas(16) SDF_Command {
	float4 center; // use fourth element for addition or subtraction
	float4 args; // radius, second radius, (maybe object ID?)
};

#define SDF_Field_Entry_Dist(e) e.data[3]
#define SDF_Field_Entry_Norm(e) e.data.xyz 

struct alignas(16) SDF_Invoke_Debug {
	SDF_Command cmd;
	uint   dim;
	uint   which_cmd;
	float3 vec;
	float  d;
	uint3 gid;
	uint   dist_check_passed;
	float  field_d_out;
	float3 field_nor_out;
};

#ifdef METAL_DEBUG_PRINT_ON_CPU
#include <stdio.h>
void SDF_Invoke_Debug_Print(SDF_Invoke_Debug* db);
void SDF_Invoke_Debug_Print(SDF_Invoke_Debug* db)
{
	printf(
		"SDF_Command:{\n"
		"\tcenter:[%f,%f,%f,%f]\n"
		"\targs:[%f,%f,%f,%f]\n"
		"}\n"
		"dim:[%u]\n"
		"which_cmd:[%u]\n"
		"vec:[%f,%f%f]\n"
		"d:[%f]\n"
		"gid:[%u,%u,%u]\n"
		"dist_check_passed:[%u]\n"
		"field_d_out:[%f]\n"
		"field_nor_out:[%f,%f,%f]\n",
		db->cmd.center[0],db->cmd.center[1],db->cmd.center[2],db->cmd.center[3],
		db->cmd.args[0],db->cmd.args[1],db->cmd.args[2],db->cmd.args[3],
		db->dim,
		db->which_cmd,
		db->vec[0],db->vec[1],db->vec[2],
		db->d,
		db->gid[0],db->gid[1],db->gid[2],
		db->dist_check_passed,
		db->field_d_out,
		db->field_nor_out[0], db->field_nor_out[1], db->field_nor_out[2]
	);
}
#endif

struct alignas(16) SDF_Field_Entry {
	float4 data;
	SDF_Invoke_Debug db;
};

struct alignas(16) SDF_Uniform_Buffer {
	uint dim;
};

#endif