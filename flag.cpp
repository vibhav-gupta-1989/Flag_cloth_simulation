////////////////////////////////////////////////////////////////      
// flag.cpp
//
// This program draws a fluttering flag.
//
// Interaction:
// Press space to toggle between animation on and off.
// Press the up/down arrow keys to speed up/slow down animation.
// Press the x, X, y, Y, z, Z keys to rotate the scene.
//
// Sumanta Guha.
////////////////////////////////////////////////////////////////   

#define _USE_MATH_DEFINES 

#include <iostream>

#include <GL/glew.h>
#include <GL/freeglut.h>
#include <chrono>

// Globals.
static float s = 0.0; // Amount of shift of the piece of the sine curve.
static int p = 1000; // Number of segments along the  length (i.e., sine curve section) of the flag.
static int q = 1000; // Number of segments along the width of the flag.
static float *vertices = NULL; // Vertex array containing vertices on the flag.
static float Xangle = 60.0, Yangle = 0.0, Zangle = 0.0; // Angles to rotate scene.
static int isAnimate = 0; // Animated?
static int animationPeriod = 1; // Time interval between frames.

GLuint textureID;
float* texCoords = NULL;

unsigned char* loadBMP(const char* filename, int& width, int& height)
{
	FILE* file = fopen(filename, "rb");
	if (!file)
	{
		std::cout << "Cannot open file\n";
		return nullptr;
	}

	unsigned char header[54];
	fread(header, 1, 54, file);

	width = *(int*)&header[18];
	height = *(int*)&header[22];

	int size = 3 * width * height;
	unsigned char* data = new unsigned char[size];

	fread(data, 1, size, file);
	fclose(file);

	// Convert BGR → RGB
	for (int i = 0; i < size; i += 3)
		std::swap(data[i], data[i + 2]);

	return data;
}

// Routine to fill the vertex array with co-ordinates of vertices of the flag.
void fillVertexArray(void)
{
	int k = 0;
	for (int j = 0; j <= q; j++)
		for (int i = 0; i <= p; i++)
		{
			vertices[k++] = -20.0 + 40.0 * (float)i / p;
			vertices[k++] = 5.0 * sin(s + (float)i / p * 1.8 * M_PI) - 5.0 * sin(s);
			vertices[k++] = -10.0 + 20.0 * (float)j / q;
		}
}

// Drawing routine.
void drawScene(void)
{
	int i, j;

	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glLoadIdentity();
	glTranslatef(0.0, 0.0, -35.0);

	// Rotate scene.
	glRotatef(Zangle, 0.0, 0.0, 1.0);
	glRotatef(Yangle, 0.0, 1.0, 0.0);
	glRotatef(Xangle, 1.0, 0.0, 0.0);

	auto start = std::chrono::high_resolution_clock::now();
	// Fill the vertex array.
	fillVertexArray();
	auto end = std::chrono::high_resolution_clock::now();

	double ms = std::chrono::duration<double, std::milli>(end - start).count();
	std::cout << "Time taken (CPU): " << ms << " ms\n";

	// Flag.
	//glColor3f(0.0, 0.0, 0.0);

	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, textureID);
	glColor3f(1.0, 1.0, 1.0);

	for (j = 0; j < q; j++)
	{
		glBegin(GL_TRIANGLE_STRIP);
		for (i = 0; i <= p; i++)
		{
			int idx1 = (j + 1) * (p + 1) + i;
			int idx2 = j * (p + 1) + i;

			// Top vertex
			glTexCoord2f(texCoords[2 * idx1], texCoords[2 * idx1 + 1]);
			glArrayElement(idx1);

			// Bottom vertex
			glTexCoord2f(texCoords[2 * idx2], texCoords[2 * idx2 + 1]);
			glArrayElement(idx2);
		}
		glEnd();
	}

	// Flag pole.
	glLineWidth(5.0);
	glBegin(GL_LINES);
	glVertex3f(-20.0, 0.0, -10.0);
	glVertex3f(-20.0, 0.0, 20.0);
	glEnd();
	glLineWidth(1.0);


	glutSwapBuffers();
}

// Timer function.
void animate(int value)
{
	if (isAnimate)
	{
		s += 1.8*M_PI / p;
		if (s > 2.0*M_PI) s -= 2.0*M_PI;

		glutPostRedisplay();
		glutTimerFunc(animationPeriod, animate, 1);
	}
}

// Initialization routine.
void setup(void)
{
	glClearColor(1.0, 1.0, 1.0, 0.0);
	glEnable(GL_DEPTH_TEST);
	glEnableClientState(GL_VERTEX_ARRAY);

	// Allocate vertices
	vertices = new float[3 * (p + 1) * (q + 1)];

	// Allocate texture coordinates
	texCoords = new float[2 * (p + 1) * (q + 1)];

	for (int j = 0; j <= q; j++)
	{
		for (int i = 0; i <= p; i++)
		{
			int idx = j * (p + 1) + i;

			texCoords[2 * idx + 0] = (float)i / p; // u
			texCoords[2 * idx + 1] = (float)j / q; // v
		}
	}

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

	glEnable(GL_TEXTURE_2D);

	delete[] image;
}

// OpenGL window reshape routine.
void resize(int w, int h)
{
	glViewport(0, 0, w, h);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glFrustum(-5.0, 5.0, -5.0, 5.0, 5.0, 100.0);

	glMatrixMode(GL_MODELVIEW);
}

// Keyboard input processing routine.
void keyInput(unsigned char key, int x, int y)
{
	switch (key)
	{
	case 27:
		exit(0);
		break;
	case ' ':
		if (isAnimate) isAnimate = 0;
		else
		{
			isAnimate = 1;
			animate(1);
		}
		break;
	case 'x':
		Xangle += 5.0;
		if (Xangle > 360.0) Xangle -= 360.0;
		glutPostRedisplay();
		break;
	case 'X':
		Xangle -= 5.0;
		if (Xangle < 0.0) Xangle += 360.0;
		glutPostRedisplay();
		break;
	case 'y':
		Yangle += 5.0;
		if (Yangle > 360.0) Yangle -= 360.0;
		glutPostRedisplay();
		break;
	case 'Y':
		Yangle -= 5.0;
		if (Yangle < 0.0) Yangle += 360.0;
		glutPostRedisplay();
		break;
	case 'z':
		Zangle += 5.0;
		if (Zangle > 360.0) Zangle -= 360.0;
		glutPostRedisplay();
		break;
	case 'Z':
		Zangle -= 5.0;
		if (Zangle < 0.0) Zangle += 360.0;
		glutPostRedisplay();
		break;
	default:
		break;
	}
}

// Callback routine for non-ASCII key entry.
void specialKeyInput(int key, int x, int y)
{
	if (key == GLUT_KEY_DOWN) animationPeriod += 5;
	if (key == GLUT_KEY_UP) if (animationPeriod > 5) animationPeriod -= 5;
	glutPostRedisplay();
}

// Routine to output interaction instructions to the C++ window.
void printInteraction(void)
{
	std::cout << "Interaction:" << std::endl;
	std::cout << "Press space to toggle between animation on and off." << std::endl
		<< "Press the up/down arrow keys to speed up/slow down animation." << std::endl
		<< "Press the x, X, y, Y, z, Z keys to rotate the scene." << std::endl;
}

// Main routine.
int main(int argc, char **argv)
{
	printInteraction();
	glutInit(&argc, argv);

	glutInitContextVersion(4, 3);
	glutInitContextProfile(GLUT_COMPATIBILITY_PROFILE);

	glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);
	glutInitWindowSize(500, 500);
	glutInitWindowPosition(100, 100);
	glutCreateWindow("flag.cpp");
	glutDisplayFunc(drawScene);
	glutReshapeFunc(resize);
	glutKeyboardFunc(keyInput);
	glutSpecialFunc(specialKeyInput);

	glewExperimental = GL_TRUE;
	glewInit();

	setup();

	glutMainLoop();
}

