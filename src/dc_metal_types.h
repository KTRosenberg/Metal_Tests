
#ifndef DC_METAL_TYPES_H
#define DC_METAL_TYPES_H

#include <simd/simd.h>
using namespace simd;

struct SDF_Field_Entry {
	float4 pos;
	float4 nor;
};

struct SDF_Args {
	float4 center; // use fourth element for addition or subtraction
	float4 args;
};


struct alignas(16) SDF_Uniform_Buffer {
	uint dim;
};

#endif