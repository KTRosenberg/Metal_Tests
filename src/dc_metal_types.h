
#ifndef DC_METAL_TYPES_H
#define DC_METAL_TYPES_H

#include <simd/simd.h>
using namespace simd;





struct alignas(16) SDF_Command {
	float4 center; // use fourth element for addition or subtraction
	float4 args; // radius, second radius, (maybe object ID?)
};

struct alignas(16) SDF_Compute_Debug {
	uint3 gid;
	float3 gid_as_float;
	uint gid_flat;
	uint phase_idx;
	SDF_Command cmd;
	float3 vec;
	float d;
	uint check_passed;
};

#define SDF_Normal(entry) entry.info.xyz
#define SDF_Distance(entry) entry.info[3]
struct alignas(16) SDF_Field_Entry {
	float4 info;

	SDF_Compute_Debug db;
};


#ifdef METAL_HOST_DEBUG
#include <stdio.h>
void SDF_Field_Entry_print_debug(SDF_Field_Entry* entry, FILE* fp);
void SDF_Field_Entry_print_debug(SDF_Field_Entry* entry, FILE* fp)
{
	// printf(
	// 	"SDF_Command:{\n"
	// 	"\tcenter:[%f,%f,%f,%f]\n"
	// 	"\targs:[%f,%f,%f,%f]\n"
	// 	"}\n"
	// 	"dim:[%u]\n"
	// 	"which_cmd:[%u]\n"
	// 	"vec:[%f,%f%f]\n"
	// 	"d:[%f]\n"
	// 	"gid:[%u,%u,%u]\n"
	// 	"dist_check_passed:[%u]\n"
	// 	"field_d_out:[%f]\n"
	// 	"field_nor_out:[%f,%f,%f]\n",
	// 	db->cmd.center[0],db->cmd.center[1],db->cmd.center[2],db->cmd.center[3],
	// 	db->cmd.args[0],db->cmd.args[1],db->cmd.args[2],db->cmd.args[3],
	// 	db->dim,
	// 	db->which_cmd,
	// 	db->vec[0],db->vec[1],db->vec[2],
	// 	db->d,
	// 	db->gid[0],db->gid[1],db->gid[2],
	// 	db->dist_check_passed,
	// 	db->field_d_out,
	// 	db->field_nor_out[0], db->field_nor_out[1], db->field_nor_out[2]
	// );

	SDF_Compute_Debug* db = &entry->db;
	fprintf(fp,
		"\tgid:[%u,%u,%u]\n"
		"\tgid_as_float:[%f,%f,%f]\n"
		"\tgid_flat:[%u]\n"
		"\tphase_idx:[%u]\n"
		"\tSDF_Command:{\n"
		"\t\tcenter:[%f,%f,%f,%f]\n"
		"\t\targs:[%f,%f,%f,%f]\n"
		"\t}\n"
		"\tdist:[%f]\n"
		"\tnorm:[%f,%f,%f]\n"
		"\tvec:[%f,%f,%f]\n"
		"\td:[%f]\n"
		"\tcheck_passed:[%u]\n",
		db->gid[0],db->gid[1],db->gid[2],
		db->gid_as_float[0],db->gid_as_float[1],db->gid_as_float[2],
		db->gid_flat,
		db->phase_idx,
		db->cmd.center[0],db->cmd.center[1],db->cmd.center[2],db->cmd.center[3],
		db->cmd.args[0],db->cmd.args[1],db->cmd.args[2],db->cmd.args[3],
		SDF_Distance((*entry)),
		SDF_Normal((*entry))[0],SDF_Normal((*entry))[1],SDF_Normal((*entry))[2],
		db->vec[0],db->vec[1],db->vec[2],
		db->d,
		db->check_passed
	);
}
#endif


struct alignas(16) SDF_Uniform_Buffer {
	uint dim;
};

#endif