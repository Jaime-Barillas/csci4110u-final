// Use glad headers.
#define GLAD_GL_IMPLEMENTATION
#include <glad/gl.h>
#undef GLAD_GL_IMPLEMENTATION

#include <stdexcept>
#include "window.hpp"
#include "shader_manager.hpp"
#include <stumpless.h>
#include "logging.hpp"

struct stumpless_target *log_target_chain;

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
  auto stdout_target = stumpless_open_stderr_target("log");
  auto file_target = stumpless_open_file_target("log.txt");
  log_target_chain = stumpless_new_chain("log-chain");
  stumpless_add_target_to_chain(log_target_chain, stdout_target);
  stumpless_add_target_to_chain(log_target_chain, file_target);

  stump_i_message(log_target_chain, "//-------------------------//");
  stump_i_message(log_target_chain, "//        CSCI4110U        //");
  stump_i_message(log_target_chain, "//-------------------------//");

  Program *window;
  try {
    window = new Program({.width = 1152, .height = 720, .title = "Lab 5"});
    window->run();
  } catch(std::runtime_error &err) {
    return -1;
  }

  stumpless_close_chain_and_contents(log_target_chain);
  stumpless_free_all();
}
