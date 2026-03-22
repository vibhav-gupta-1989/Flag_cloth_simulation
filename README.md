GPU-Accelerated Textured Flag Simulation (OpenGL + CUDA)

- Developed a real-time fluttering flag simulation using OpenGL (GLEW + FreeGLUT) with dynamic sine-wave deformation of a high-resolution mesh (~1M vertices).
- Built a CUDA-OpenGL interop pipeline using VBOs and cudaGraphicsResource for zero-copy GPU memory sharing.
- Parallelized vertex updates on GPU via custom CUDA kernel, achieving 4x speedup over CPU implementation.
