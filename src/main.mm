#include <vol/Contouring.hpp>
#include <Settings.hpp>
#include <fstream>
#include <iostream>
#include <random>
#include <chrono> 

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <CoreFoundation/CoreFoundation.h>



using namespace math;
using namespace std;
using namespace util;
using namespace vol;

using namespace std::chrono; 


void addCylinder(Field& field)
{
	const real rad    = field.size().x / 10.0f;
	const auto center = Vec2(field.size().xy) * 0.5f;  // in the X-Y-plane

	foreach3D(field.size(), [&](Vec3u upos) {
		auto& cell = field[upos];
		auto  vec  = Vec2(upos.xy) - center;
		auto  d    = vec.len() - rad;

		if (d < cell.dist) {
			cell.dist    = d;
			cell.normal  = Vec3(normalized(vec), 0);
		}
	});
}

void removeCylinder(Field& field)
{
	const real rad    = field.size().x / 10.0f;
	const auto center = Vec2(field.size().xy) * 0.5f;  // in the X-Y-plane

	foreach3D(field.size(), [&](Vec3u upos) {
		auto& cell = field[upos];
		auto  vec  = Vec2(upos.xy) - center;
		auto  d    = vec.len() - rad;

		if (-d > cell.dist) {
			cell.dist    = -d;
			cell.normal  = -Vec3(normalized(vec), 0);
		}
	});
}

void addCube(Field& field, Vec3 center, real rad) {
	const Vec3 size(rad);
	
	foreach3D(field.size(), [&](Vec3u p) {
		auto& cell = field[p];
		auto  r    = Vec3(p) - center;
		
		auto a      = r.maxAbsAxis();
		auto dist   = std::abs(r[a]) - size[a];
		auto normal = sign(r[a]) * Vec3::Axes[a];
		
		if (dist < cell.dist) {
			cell.dist    = dist;
			cell.normal  = normal;
		}
	});
}

// real SDF_sphere(Vec3 p, real rad) {
// 	return p.len() - rad;
// }
// Vec3 SDF_normal_Sphere(Vec3 p, real rad) {
// 	(void)rad;
// 	//return normalized(p);

// 	const real h = 0.0001;
// 	const Vec2 k = Vec2(1.0, -1.0);
// 	return normalized(
// 		Vec3(k.x, k.y, k.y) * SDF_sphere(p + (Vec3(k.x, k.y, k.y) * h), rad) +
// 		Vec3(k.y, k.y, k.x) * SDF_sphere(p + (Vec3(k.y, k.y, k.x) * h), rad) +
// 		Vec3(k.y, k.x, k.y) * SDF_sphere(p + (Vec3(k.y, k.x, k.y) * h), rad) +
// 		Vec3(k.x, k.x, k.x) * SDF_sphere(p + (Vec3(k.x, k.x, k.x) * h), rad)
// 	);
// }

real SDF_torus(Vec3 p, Vec2 t) {
	real x = Vec2(p.x, p.z).len();
	x -= t.x;
	Vec2 q = Vec2(x, p.y);
	return q.len() - t.y;
}
Vec3 SDF_normal_torus(Vec3 p, Vec2 t) {
	const real h = 0.0001;
	const Vec2 k = Vec2(1.0, -1.0);
	return normalized(
		Vec3(k.x, k.y, k.y) * SDF_torus(p + (Vec3(k.x, k.y, k.y) * h), t) +
		Vec3(k.y, k.y, k.x) * SDF_torus(p + (Vec3(k.y, k.y, k.x) * h), t) +
		Vec3(k.y, k.x, k.y) * SDF_torus(p + (Vec3(k.y, k.x, k.y) * h), t) +
		Vec3(k.x, k.x, k.x) * SDF_torus(p + (Vec3(k.x, k.x, k.x) * h), t)
	);
}

void addTorus(Field& field, Vec3 center, real t) {

	/*
	float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}*/
	foreach3D(field.size(), [&](Vec3u upos) {
		auto& cell = field[upos];
		auto  vec  = Vec3(upos) - center;
		auto  d    = SDF_torus(vec, Vec2(t, t / 4));
		
		if (d < cell.dist) {
			cell.dist    = d;
			cell.normal  = SDF_normal_torus(vec, Vec2(t, t / 4));
		}
	});


}

void addSphere(Field& field, Vec3 center, real rad) {
	foreach3D(field.size(), [&](Vec3u upos) {
		auto& cell = field[upos];
		auto  vec  = Vec3(upos) - center;
		auto  d    = vec.len() - rad;
		
		if (d < cell.dist) {
			cell.dist    = d;
			cell.normal  = normalized(vec);
		}
	});
}

void removeSphere(Field& field, Vec3 center, real rad) {
	foreach3D(field.size(), [&](Vec3u upos) {
		auto& cell = field[upos];
		auto  vec  = Vec3(upos) - center;
		auto  d    = vec.len() - rad;
		
		if (-d > cell.dist) {
			cell.dist    = -d;
			cell.normal  = -normalized(vec);
		}
	});
}


// Add random jitter to emulate noisy input
void perturbField(Field& field)
{
	if (DistJitter <= 0 && NormalJitter <= 0)
		return;
	
	std::mt19937 r;
#if true
	std::normal_distribution<> distJitter  (0, DistJitter);
	std::normal_distribution<> normalJitter(0, NormalJitter);
#else
	std::uniform_real_distribution<> distJitter  (-DistJitter, +DistJitter);
	std::uniform_real_distribution<> normalJitter(-NormalJitter, +NormalJitter);
#endif
	
	foreach3D(field.size(), [&](Vec3u upos) {
		auto& cell = field[upos];
		cell.dist += distJitter(r);
		cell.normal += Vec3{ normalJitter(r), normalJitter(r), normalJitter(r) };
		cell.normal.normalize();
	});
}


// Ensure periphery has dist>0
void closeField(Field& field)
{
	const int  oa[3][2]  = {{1,2}, {0,2}, {0,1}};
	const auto fs        = field.size();
	
	for (int a=0; a<3; ++a)
	{
		auto a0 = oa[a][0];
		auto a1 = oa[a][1];
		Vec2u sideSize = { fs[a0], fs[a1] };
		
		foreach2D(sideSize, [&](Vec2u p2) {
			Vec3u p3 = Zero;
			p3[a0] = p2[0];
			p3[a1] = p2[1];
			p3[a] = 0;
			
			if (field[p3].dist <= 0) {
				field[p3].dist = 0.5f;
				field[p3].normal = -Vec3::Axes[a];
			}
			
			p3[a] = fs[a]-1;
			
			if (field[p3].dist <= 0) {
				field[p3].dist = 0.5f;
				field[p3].normal = +Vec3::Axes[a];
			}
		});
	}
}

#define METAL_HOST_DEBUG
#include "dc_metal_types.h"
#undef METAL_HOST_DEBUG
#include "dc_metal.mm"

Field generateField(unsigned fieldSize, bool subSphere, bool subCyl, bool use_low_power)
{
	cout << "field size: " << fieldSize << endl;
	generate_field_compute(fieldSize, use_low_power);

	const auto Size  = Vec3u( fieldSize );
	Field field(Size, Plane{+INF, Zero});

	/* Similar test case to the original Dual Contouring paper:
	 * A cylinder with an added box and a sphere subracted from that box.
	*/


	
	{
		const auto center = Vec3(Size) * 0.5f;
		const real rad = Size.x * 3 / 16.0f;
		addCube(field, center, rad);
	}
	
	if (subSphere)
	{
		const auto center = Vec3(Size) * 0.5f + Vec3(0, 0, Size.z) * 2.0 / 16.0;
		const real rad    = Size.x * 3.5 / 16.0;
		removeSphere(field, center, rad);
	}
	else
	{
		const auto center = Vec3(Size) * 0.5f + Vec3(0, 0, Size.z) * 2.0 / 16.0;
		const real rad    = Size.x * 3.5 / 16.0;
		addSphere(field, center, rad);
	}

	{		
		const auto center = Vec3(Size) * 0.5f;
		const real rad    = Size.x * 3.5 / 16.0;
		addTorus(field, center, rad);
	}

	if (subCyl) {
		removeCylinder(field);
	} else {
		addCylinder(field);
	}
	
	if (PerturbField) {
		perturbField(field);
	}
	
	
	if (ClosedField) {
		// Ensure we get a closed mesh:
		closeField(field);
	}

	return field;
}

//////////////



//////////////

int main(int argc, char** argv) 
{
	//cout << "Generating " << FieldSize << "^3 field..." << endl;
	unsigned fieldSize = FieldSize;
	bool subSphere = SubtractSphere;
	bool subCyl = SubtractCylinder;
	bool use_low_power = false;

	if (argc >= 4) {
		fieldSize = atoi(argv[1]);
		subSphere = atoi(argv[2]);
		subCyl    = atoi(argv[3]);
	}
	if (argc == 5) {
		use_low_power = atoi(argv[4]);
	}

	cout << "using options: " << fieldSize << ", " << subSphere << ", " << subCyl << endl;

	auto start_field = high_resolution_clock::now();
	const auto field = generateField(fieldSize, subSphere, subCyl, use_low_power);
	auto stop_field = high_resolution_clock::now(); 


	//cout << "Contouring..." << endl;
	const auto mesh = dualContouring(field);
	auto stop_mesh = high_resolution_clock::now(); 

	cout << "field gen time: " << duration_cast<milliseconds>(stop_field - start_field).count() << endl;
	cout << "mesh gen time: " << duration_cast<milliseconds>(stop_mesh - stop_field).count() << endl;

	
	cout << mesh.vecs.size() << " vertices in " << mesh.triangles.size() << " triangles" << endl;

	auto fileName = "mesh.obj";
	cout << "Saving as " << fileName << "... " << endl;
	ofstream of(fileName);

	of << "# Vertices:" << endl;
	for (auto&& v_orig : mesh.vecs) {
		auto v = v_orig - 0.5*Vec3(field.size()); // Center
		of << "v " << v.x << " " << v.y << " " << v.z << endl;
	}

	of << endl << "# Triangles:" << endl;
	for (auto&& tri : mesh.triangles) {
		of << "f";
		for (auto&& ix : tri) {
			of << " " << (ix + 1);
		}
		of << endl;
	}
	
	cout << "Done!" << endl;
}


