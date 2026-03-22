#define _USE_MATH_DEFINES 

#include <iostream>
#include <cmath>

#include <GL/glew.h>
#include <GL/freeglut.h>

#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <chrono>

GLuint textureID;
float* texCoords;



// Globals
static float s = 0.0;
static int p = 1000;
static int q = 1000;

#define M_PI 3.142

GLuint vbo;
struct cudaGraphicsResource* cudaVbo;

static float Xangle = 60.0, Yangle = 0.0, Zangle = 0.0;
static int isAnimate = 0;
static int animationPeriod = 1;

// CUDA error macro
#define CUDA_CHECK(err) \
if (err != cudaSuccess) { \
    std::cout << "CUDA Error: " << cudaGetErrorString(err) << std::endl; \
    exit(1); \
}

unsigned char* loadBMP(const char* filename, int& width, int& height)
{
    FILE* file = fopen(filename, "rb");
    if (!file) return nullptr;

    unsigned char header[54];
    fread(header, 1, 54, file);

    width = *(int*)&header[18];
    height = *(int*)&header[22];

    int size = 3 * width * height;
    unsigned char* data = new unsigned char[size];

    fread(data, 1, size, file);
    fclose(file);

    // BMP is BGR → convert to RGB
    for (int i = 0; i < size; i += 3)
        std::swap(data[i], data[i + 2]);

    return data;
}

// ========================================
// CUDA KERNEL
// ========================================
__global__ void updateVertices(float* vertices, int p, int q, float s)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = (p + 1) * (q + 1);

    if (idx >= total) return;

    int i = idx % (p + 1);
    int j = idx / (p + 1);

    float x = -20.0f + 40.0f * i / p;
    float y = 5.0f * sinf(s + (float)i / p * 1.8f * M_PI) - 5.0f * sinf(s);
    float z = -10.0f + 20.0f * j / q;

    vertices[3 * idx + 0] = x;
    vertices[3 * idx + 1] = y;
    vertices[3 * idx + 2] = z;
}

// ========================================
// CUDA INTEROP
// ========================================
void runCuda()
{
    float* dptr;
    size_t num_bytes;

    CUDA_CHECK(cudaGraphicsMapResources(1, &cudaVbo, 0));
    CUDA_CHECK(cudaGraphicsResourceGetMappedPointer((void**)&dptr, &num_bytes, cudaVbo));

    int total = (p + 1) * (q + 1);
    int threads = 1024;
    int blocks = (total + threads - 1) / threads;

    updateVertices<<<blocks, threads>>>(dptr, p, q, s);

    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaGetLastError());

    CUDA_CHECK(cudaGraphicsUnmapResources(1, &cudaVbo, 0));
}

// ========================================
// DRAW
// ========================================
void drawScene(void)
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();

    glTranslatef(0.0, 0.0, -35.0);

    glRotatef(Zangle, 0.0, 0.0, 1.0);
    glRotatef(Yangle, 0.0, 1.0, 0.0);
    glRotatef(Xangle, 1.0, 0.0, 0.0);

    auto start = std::chrono::high_resolution_clock::now();
    // 🚀 CUDA updates VBO
    runCuda();
    auto end = std::chrono::high_resolution_clock::now();

    double ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::cout << "Time taken (CUDA): " << ms << " ms\n";

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glVertexPointer(3, GL_FLOAT, 0, 0);

    //glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glColor3f(1.0f, 1.0f, 1.0f);

    for (int j = 0; j < q; j++)
    {
        glBegin(GL_TRIANGLE_STRIP);
        for (int i = 0; i <= p; i++)
        {
            int idx1 = (j + 1) * (p + 1) + i;
            int idx2 = j * (p + 1) + i;

            // Vertex 1
            glTexCoord2f(texCoords[2 * idx1], texCoords[2 * idx1 + 1]);
            glArrayElement(idx1);

            // Vertex 2
            glTexCoord2f(texCoords[2 * idx2], texCoords[2 * idx2 + 1]);
            glArrayElement(idx2);
        }
        glEnd();
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // Flag pole
    glColor3f(0.2f, 0.2f, 0.2f);
    glLineWidth(5.0);

    glBegin(GL_LINES);
    glVertex3f(-20.0, 0.0, -10.0);
    glVertex3f(-20.0, 0.0, 20.0);
    glEnd();

    glutSwapBuffers();
    glutPostRedisplay(); // continuous render
}

// ========================================
// ANIMATION
// ========================================
void animate(int value)
{
    if (isAnimate)
    {
        s += 1.8 * M_PI / p;
        if (s > 2.0 * M_PI) s -= 2.0 * M_PI;

        glutTimerFunc(animationPeriod, animate, 1);
    }
}

// ========================================
// SETUP
// ========================================
void setup(void)
{
    glClearColor(1.0, 1.0, 1.0, 0.0);

    glEnable(GL_DEPTH_TEST);
    glEnableClientState(GL_VERTEX_ARRAY);

    int totalVertices = (p + 1) * (q + 1);

    // Create VBO
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER,
        totalVertices * 3 * sizeof(float),
        NULL,
        GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // Register with CUDA
    CUDA_CHECK(cudaGraphicsGLRegisterBuffer(&cudaVbo, vbo, cudaGraphicsMapFlagsWriteDiscard));

    // Load texture
    int width, height;
    unsigned char* image = loadBMP("Flag_of_India.bmp", width, height);

    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB,
             width, height, 0,
             GL_RGB, GL_UNSIGNED_BYTE, image);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    delete[] image;

    texCoords = new float[(p + 1) * (q + 1) * 2];

    for (int j = 0; j <= q; j++)
    {
        for (int i = 0; i <= p; i++)
        {
            int idx = j * (p + 1) + i;

            texCoords[2 * idx + 0] = (float)i / p; // u
            texCoords[2 * idx + 1] = (float)j / q; // v
        }
    }
    glEnable(GL_TEXTURE_2D);
}

// ========================================
// RESIZE
// ========================================
void resize(int w, int h)
{
    glViewport(0, 0, w, h);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    //gluPerspective(60.0, (float)w / h, 1.0, 200.0);
    glFrustum(-5.0, 5.0, -5.0, 5.0, 5.0, 100.0);

    glMatrixMode(GL_MODELVIEW);
}

// ========================================
// INPUT
// ========================================
void keyInput(unsigned char key, int x, int y)
{
    switch (key)
    {
    case 27: exit(0); break;

    case ' ':
        isAnimate = !isAnimate;
        if (isAnimate) animate(1);
        break;

    case 'x': Xangle += 5.0; break;
    case 'X': Xangle -= 5.0; break;
    case 'y': Yangle += 5.0; break;
    case 'Y': Yangle -= 5.0; break;
    case 'z': Zangle += 5.0; break;
    case 'Z': Zangle -= 5.0; break;
    }

    glutPostRedisplay();
}

void specialKeyInput(int key, int x, int y)
{
    if (key == GLUT_KEY_DOWN) animationPeriod += 5;
    if (key == GLUT_KEY_UP && animationPeriod > 5) animationPeriod -= 5;
}

// ========================================
// MAIN
// ========================================
int main(int argc, char** argv)
{
    glutInit(&argc, argv);

    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);
    //glutInitWindowSize(800, 600);
    glutInitWindowSize(500, 500);
    glutInitWindowPosition(100, 100);
    glutCreateWindow("CUDA OpenGL Flag");

    glewInit();

    // CUDA init AFTER GL context
    int dev = 0;
    cudaSetDevice(dev);

    setup();

    glutDisplayFunc(drawScene);
    glutReshapeFunc(resize);
    glutKeyboardFunc(keyInput);
    glutSpecialFunc(specialKeyInput);

    glutMainLoop();
}