#define DEBUG
#ifdef DEBUG
#include <stdio.h>
#endif

void generate_field_compute(const uint N, bool use_low_power) 
{
	// resource reference counting, yay
	@autoreleasepool {

		// get device
		NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
		id<MTLDevice> device;
		if (use_low_power) {
			for (id<MTLDevice> device_candidate in devices) {
				if (device_candidate.lowPower == YES) {
					device = device_candidate;
					break;
				}
			}
		} else {
			for (id<MTLDevice> device_candidate in devices) {
				if (device_candidate.lowPower == NO) {
					device = device_candidate;
					break;
				}
			}
		}
		NSLog(@"%@\n", device.name);


		// build shader path
		NSFileManager *filemgr;
		NSString *currentpath;
		filemgr = [[NSFileManager alloc] init];
		currentpath = [filemgr currentDirectoryPath];
		NSString *shader_directory = [currentpath stringByAppendingString:@"/../src"];
		NSError* error;
		NSString* where = [shader_directory stringByAppendingString:@"/shader_library.metallib"];

		// load the shader library
		id<MTLLibrary> shader_library = [device newLibraryWithFile:where error:&error];
		if(!shader_library) {
		    //[NSException raise:@"Failed to compile shaders" format:@"%@", [error localizedDescription]];
		    [NSException raise:@"Failed to load shader program" format:@"%@", [error localizedDescription]];
		}

		// get the desired shader function from the library
		id<MTLFunction> init_field_func = [shader_library newFunctionWithName:@"init_field"];
		if (!init_field_func) {
            NSLog(@"Failed to find the function.");
            return;
        }


        // create a compute pipeline state object for the shader function
       	id<MTLComputePipelineState> init_field_pso = [device newComputePipelineStateWithFunction: init_field_func error:&error];
        if (!init_field_pso) {
            //  If the Metal API validation is enabled, you can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to create pipeline state object, error %@.", error);
            return;
        }

        // SDF compute shader function types
		enum struct SDF_COMPUTE_FUNCTION_TYPE : uint16_t {
			SPHERE,
			TORUS,
			CUBE,

			ENUM_COUNT
		};
		const char* const SDF_COMPUTE_FUNCTION_TYPE_TO_NAME[(uint16_t)SDF_COMPUTE_FUNCTION_TYPE::ENUM_COUNT] = {
			"SDF_sphere",
			"SDF_torus",
			"SDF_cube",
		};

		struct SDF_COMPUTE_INFO {
			SDF_COMPUTE_FUNCTION_TYPE   type;
			id<MTLFunction>             func;
			id<MTLComputePipelineState> pipeline;
		};

        SDF_COMPUTE_INFO sdf_compute_info[(uint16_t)SDF_COMPUTE_FUNCTION_TYPE::ENUM_COUNT];
        for (uint16_t i = 0; i < (uint16_t)SDF_COMPUTE_FUNCTION_TYPE::ENUM_COUNT; i += 1) {
   
        	sdf_compute_info[i].func = [
        		shader_library newFunctionWithName:
        			[NSString stringWithUTF8String:SDF_COMPUTE_FUNCTION_TYPE_TO_NAME[i]]
        	];
			if (!sdf_compute_info[i].func) {
	            NSLog(@"Failed to find the function.");
	            abort();
	            return;
	        }
        	sdf_compute_info[i].pipeline = [
  				device newComputePipelineStateWithFunction:sdf_compute_info[i].func error:&error
        	];
	        if (!sdf_compute_info[i].pipeline) {
	            NSLog(@"Failed to create pipeline state object, error %@.", error);
	            abort();
	            return;
	        }   		        
        }


        // create the command queue to handle GPU command submission
        id<MTLCommandQueue> command_queue = [device newCommandQueue];
        if (!command_queue) {
            NSLog(@"Failed to find the command queue.");
            return;
        }

        // create the initial dual contouring field grid,
        // zero initialize it


        const unsigned int len = N*N*N;
        //id<MTLBuffer> field_buffer = [device newBufferWithLength:(len * sizeof(SDF_Field_Entry)) options:MTLResourceStorageModeShared];
        //SDF_Field_Entry* field_data = (SDF_Field_Entry*)field_buffer.contents;
       	//memset(field_data, 0, len * sizeof(SDF_Field_Entry));
       	#define DEBUG
       	#ifdef DEBUG
       	FILE* write_out = fopen("log.txt", "w");
       	id<MTLBuffer> field_buffer = [device newBufferWithLength:(len * sizeof(SDF_Field_Entry)) options:MTLResourceStorageModeShared];
       	#else
       	FILE* write_out = stdout;
       	id<MTLBuffer> field_buffer = [device newBufferWithLength:(len * sizeof(SDF_Field_Entry)) options:MTLResourceStorageModePrivate];
       	#endif       	//id<MTLBuffer> ubo = [device newBufferWithLength:(sizeof(SDF_Uniform_Buffer)) options:MTLResourceStorageModeShared];

        NSUInteger thread_group_max = init_field_pso.maxTotalThreadsPerThreadgroup;
        NSUInteger execution_width  = init_field_pso.threadExecutionWidth;
        NSUInteger ratio            = thread_group_max / execution_width;

        // radeon is 64, 4, 4 to get to 1024 (thread_group_max)
     	MTLSize threads_per_threadgroup = MTLSizeMake(execution_width, 4 * (64 / execution_width), 4);
        NSLog(@"%@ %lu %@ %lu %@ %lu \n", @"maxTotalThreadsPerThreadgroup: ", thread_group_max, @"threadExecutionWidth: ", init_field_pso.threadExecutionWidth, @"ratio", ratio);

        #define PER_GRID
        #ifdef PER_GRID
        MTLSize threadgroups_per_grid = MTLSizeMake(
        	(N + threads_per_threadgroup.width - 1) / threads_per_threadgroup.width,
        	(N + threads_per_threadgroup.height - 1) / threads_per_threadgroup.height,
        	(N + threads_per_threadgroup.depth - 1) / threads_per_threadgroup.depth
        );
        #else
        MTLSize threads_per_grid = MTLSizeMake(
        	N,
        	N,
        	N
        );
        #endif

        const uint max_sdf_commands = 256;
        struct SDF_Command_Info {
        	uint len;
        	SDF_COMPUTE_FUNCTION_TYPE cmd_types[max_sdf_commands];
        	uint phase_idx;
        	uint phase_ids[max_sdf_commands];
        	id<MTLBuffer> cmds;
        } sdf_cmd_info;
        for (uint i = 0; i < max_sdf_commands; i += 1) {
        	sdf_cmd_info.phase_ids[i] = i;
        }
        sdf_cmd_info.len = 1;
        sdf_cmd_info.cmd_types[0] = SDF_COMPUTE_FUNCTION_TYPE::SPHERE;
        sdf_cmd_info.cmds = [device newBufferWithLength:(max_sdf_commands * sizeof(SDF_Command)) options:MTLResourceStorageModeShared];
       	{
       		SDF_Command* cmd_data = (SDF_Command*)sdf_cmd_info.cmds.contents;
       		memset(cmd_data, 0, max_sdf_commands * sizeof(SDF_Command));

       		cmd_data->center = float4(0.0);
       		cmd_data->args   = float4(0.0);
       		cmd_data->args[0] = 70.0;
       	}

        const uint test_count = 1;
        double times[test_count];
	
		
		auto start_phase_1 = high_resolution_clock::now(); 
        for (uint i = 0; i < test_count; i += 1) {
	        // command buffer to send commands to GPU
	        id<MTLCommandBuffer> cmd_buffer = [command_queue commandBuffer];

	        id<MTLComputeCommandEncoder> compute_encoder = [cmd_buffer computeCommandEncoder];

        	sdf_cmd_info.phase_idx = 0;

	        [compute_encoder setComputePipelineState:init_field_pso];
	        //[compute_encoder setBuffer:field_buffer offset:0 atIndex:0];
	        [compute_encoder setBuffer:field_buffer offset:0 atIndex:0];
	        [compute_encoder setBuffer:sdf_cmd_info.cmds offset:0 atIndex:1];	        
	        // for data < 4kb in size that are used once, best to use this function instead
	        [compute_encoder setBytes:&N length: sizeof(uint) atIndex:2];
	        [compute_encoder setBytes:&sdf_cmd_info.phase_ids[sdf_cmd_info.phase_idx] length: sizeof(uint) atIndex:3];

	        sdf_cmd_info.phase_idx += 1;


	        // begin a GPU compute pass

	        // NOTE(Toby): This is where the compute parameters are used
	        #ifdef PER_GRID
	        [compute_encoder dispatchThreadgroups:threadgroups_per_grid threadsPerThreadgroup:threads_per_threadgroup];
	   		#else
	   		[compute_encoder dispatchThreads:threads_per_grid threadsPerThreadgroup:threads_per_threadgroup];
	   		#endif

	        // must be called 
			[compute_encoder endEncoding];

			// all commands ready to be committed (we could use multiple encoders)
	        [cmd_buffer commit];

	        // this is a blocking wait - in a real application we'd use
	        // the variant of this call that accepts an asynchronously-called completion
	        // handler callback
	        [cmd_buffer waitUntilCompleted]; 


	        // rough estimate of performance. Note this is only the first pass... and all I'm doing in
	        // the shader is setting 2 fields to float4(1.0, 1.0, 1.0, 1.0)!
	        times[i] = cmd_buffer.GPUEndTime - cmd_buffer.GPUStartTime;
	       	
	        // #if 1

	        // for (uint el = 0; el < len; el += 1) {

	        // 	assert(field_data_out[i].pos.x == 1);
	        // 	assert(field_data_out[i].pos.y == 1);
	        // 	assert(field_data_out[i].pos.z == 1);
	        // 	assert(field_data_out[i].nor.x == 1);
	        // 	assert(field_data_out[i].nor.y == 1);
	        // 	assert(field_data_out[i].nor.z == 1);
	        // }
	        // // reset to 0
       		// memset(field_data_out, 0, len * sizeof(SDF_Field_Entry));

       		// for (uint el = 0; el < len; el += 1) {

	        // 	assert(field_data_out[i].pos.x == 0);
	        // 	assert(field_data_out[i].pos.y == 0);
	        // 	assert(field_data_out[i].pos.z == 0);
	        // 	assert(field_data_out[i].nor.x == 0);
	        // 	assert(field_data_out[i].nor.y == 0);
	        // 	assert(field_data_out[i].nor.z == 0);
	        // }
	        // #endif

    	}
		auto stop_phase_1  = high_resolution_clock::now();

		uint* IDSx = (uint*)malloc(sizeof(uint)*N);
		uint* IDSy = (uint*)malloc(sizeof(uint)*N);
		uint* IDSz = (uint*)malloc(sizeof(uint)*N);
		memset(IDSx, 0, sizeof(uint)*N);
		memset(IDSy, 0, sizeof(uint)*N);
		memset(IDSz, 0, sizeof(uint)*N);

    	for (uint i = 0; i < test_count; i += 1) {
    		fprintf(write_out, "\tGPU Compute field gen time: %f\n", times[i]);
    		SDF_Field_Entry* field_data_out = (SDF_Field_Entry*)field_buffer.contents;
    		for (uint e = 0; e < N*N*N; e += 1) {
    			fprintf(write_out, "{\n");
    			SDF_Field_Entry* entry = &field_data_out[e];
    			SDF_Field_Entry_print_debug(entry, write_out);
    			assert(entry->db.gid.x < N && entry->db.gid.y < N && entry->db.gid.z < N);
    			IDSx[entry->db.gid.x] = 1;
    			IDSy[entry->db.gid.y] = 1;
    			IDSz[entry->db.gid.z] = 1;
    			fprintf(write_out, "}\n");
    		}
    	}
    	{
    		for (uint e = 0; e < N; e += 1) {
    			assert(IDSx[e] == 1);
    		}
    		for (uint e = 0; e < N; e += 1) {
    			assert(IDSy[e] == 1);
    		}
    		for (uint e = 0; e < N; e += 1) {
    			assert(IDSz[e] == 1);
    		}
    	}

		fprintf(write_out, "compute field time: %llu\n", duration_cast<milliseconds>(stop_phase_1 - start_phase_1).count());

		#ifdef DEBUG
		fflush(write_out);
		fclose(write_out);
		#endif




	}
}
