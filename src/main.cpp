#include <memory>
#include <stdexcept>

// Use glad headers.
#define GLAD_GL_IMPLEMENTATION
#include <GL/gl.h>
#undef GLAD_GL_IMPLEMENTATION
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>  // glm::value_ptr
#include <spdlog/spdlog.h>
#include <spdlog/logger.h>
#include <spdlog/common.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_opengl3.h>

#include "window.hpp"
#include "shader_manager.hpp"

class Program : public Window {
  glm::vec3 mouse_pos;
  glm::vec3 resolution;     // Window resolution in pixels.
  double time_start;        // Used to calculate total playback time.
  double time_old;          // Used to calculate time delta.

  ShaderManager shader_manager;
  GLuint vbo = 0;
  GLuint vao = 0;

  float screen_quad[6 * 3] {
    -1.0f, -1.0f, 0.0f,
     1.0f,  1.0f, 0.0f,
    -1.0f,  1.0f, 0.0f,

    -1.0f, -1.0f, 0.0f,
     1.0f, -1.0f, 0.0f,
     1.0f,  1.0f, 0.0f,
};

  static void framebufferResized(GLFWwindow *window, int width, int height) {
    auto prog = (Program*)glfwGetWindowUserPointer(window);
    prog->resolution.x = width;
    prog->resolution.y = height;
    glViewport(0, 0, width, height);
  }

public:
  Program() : Window() {};
  Program(WindowOpts opts) : Window(opts) {
    glfwSetWindowUserPointer(ptr, this);
    glfwSetFramebufferSizeCallback(ptr, framebufferResized);

    glViewport(0, 0, opts.width, opts.height);

    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(screen_quad), screen_quad, GL_STATIC_DRAW);

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);

    shader_manager.compileAndWatch({
      .name = "scene",
      .shaders = {
        Shader{.path = "shaders/vert.glsl", .type = GL_VERTEX_SHADER},
        Shader{.path = "shaders/frag.glsl", .type = GL_FRAGMENT_SHADER}
      }
    });

    resolution = glm::vec3(opts.width, opts.height, 0.0f);
    time_start = glfwGetTime();
    time_old = glfwGetTime();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui_ImplGlfw_InitForOpenGL(ptr, true);
    ImGui_ImplOpenGL3_Init();
  };

  ~Program() {
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
  }

  void handleInput(int key) override {

  }

  void draw() override {

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();
    ImGui::ShowDemoWindow();

    shader_manager.recompilePending();

    double x, y;
    int mouse_left_down = glfwGetMouseButton(ptr, GLFW_MOUSE_BUTTON_LEFT);
    glfwGetCursorPos(ptr, &x, &y);
    y = resolution.y - y;  // Invert y-axis to make positive up.
    mouse_pos.x = x;
    mouse_pos.y = y;
    mouse_pos.z = mouse_left_down == GLFW_PRESS ? 1 : 0;

    auto time_now = glfwGetTime();
    float time = (float)(time_now - time_start);
    float time_delta = (float)(time_now - time_old);
    time_old = time_now;

    auto scene = shader_manager.get("scene");
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glUseProgram(scene);

    GLuint imouse = glGetUniformLocation(scene, "imouse");
    GLuint iresolution = glGetUniformLocation(scene, "iresolution");
    GLuint itime = glGetUniformLocation(scene, "itime");
    GLuint itime_delta = glGetUniformLocation(scene, "itime_delta");
    glUniform3fv(imouse, 1, glm::value_ptr(mouse_pos));
    glUniform3fv(iresolution, 1, glm::value_ptr(resolution));
    glUniform1f(itime, time);
    glUniform1f(itime_delta, time_delta);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
  }
};

int main() {
  auto console_target = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
  auto file_target = std::make_shared<spdlog::sinks::basic_file_sink_mt>("log.txt", true);
  spdlog::sinks_init_list targets = {file_target, console_target};
  auto logger = std::make_shared<spdlog::logger>("logger", targets);
  logger->set_level(spdlog::level::trace);
  spdlog::register_logger(logger);
  spdlog::set_default_logger(logger);

  spdlog::info("//-------------------------//");
  spdlog::info("//        CSCI4110U        //");
  spdlog::info("//-------------------------//");

  Program *window;
  try {
    window = new Program({.width = 1152, .height = 720, .title = "RayMarcher - SDF"});
    window->run();
  } catch(std::runtime_error &err) {
    return -1;
  }
}
