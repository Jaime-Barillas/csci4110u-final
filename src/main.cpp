// Use glad headers.
#define GLAD_GL_IMPLEMENTATION
#include <glad/gl.h>
#undef GLAD_GL_IMPLEMENTATION

#include <stdexcept>
#include "window.hpp"
#include "shader_manager.hpp"


class Program : public Window {
public:
  Program() : Window() {};
  Program(WindowOpts opts) : Window(opts) {
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, 9 * sizeof(float), points, GL_STATIC_DRAW);

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);

    //shader_manager = new ShaderManager();
    shader_manager.compileAndWatch({
      .name = "shader",
      .shaders = {
        Shader{.path = "src/vert.glsl", .type = GL_VERTEX_SHADER},
        Shader{.path = "src/frag.glsl", .type = GL_FRAGMENT_SHADER}
      }
    });
  };

  float points[9] {
   0.0f,  0.5f,  0.0f,
   0.5f, -0.5f,  0.0f,
  -0.5f, -0.5f,  0.0f
};
  GLuint vbo = 0;
  GLuint vao = 0;
ShaderManager shader_manager;

  void handleInput(int key) override {

  }
  void draw() override {
    shader_manager.recompilePending();

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glUseProgram(shader_manager.get("shader"));
    glBindVertexArray(vao);
    // draw points 0-3 from the currently bound VAO with current in-use shader
    glDrawArrays(GL_TRIANGLES, 0, 3);
  }
};

int main() {
  Program *window;
  try {
    window = new Program({.width = 1152, .height = 720, .title = "Lab 5"});
    window->run();
  } catch(std::runtime_error &err) {
    return -1;
  }
}
