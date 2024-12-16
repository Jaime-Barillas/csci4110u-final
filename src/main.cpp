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
#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_opengl3.h>

#include "window.hpp"
#include "shader_manager.hpp"

#define MODE_3D_NONE 0
#define MODE_3D_NAIVE 1
#define MODE_3D_DUBOIS 2

class Program : public Window {
  ImGuiIO *io;
  int scene_id;  // Scene to load and draw.
  int mode_3d;
  bool draw_debug_menu;
  const GLubyte *renderer_name;

  glm::vec3 mouse_pos;
  glm::vec3 resolution;     // Window resolution in pixels.
  double time_start;        // Used to calculate total playback time.
  double time_old;          // Used to calculate time delta.

  GLuint fbo = 0;
  GLuint image_texture = 0;
  GLuint iterations_texture = 0;

  ShaderManager shader_manager;
  GLuint vbo_quad = 0;
  GLuint vbo_tex = 0;
  GLuint vao = 0;
  GLenum draw_buffers[2] {
    GL_COLOR_ATTACHMENT0,
    GL_COLOR_ATTACHMENT1,
  };

  //===== Section: Scene-Quad =====//
  float screen_quad[6 * 3] {
    -1.0f, -1.0f, 0.0f,
     1.0f,  1.0f, 0.0f,
    -1.0f,  1.0f, 0.0f,

    -1.0f, -1.0f, 0.0f,
     1.0f, -1.0f, 0.0f,
     1.0f,  1.0f, 0.0f,
  };
  //===== Section: Scene-Quad =====//

  float screen_texcoords[6 * 2] {
    0.0f, 0.0f,
    1.0f, 1.0f,
    0.0f, 1.0f,

    0.0f, 0.0f,
    1.0f, 0.0f,
    1.0f, 1.0f,
  };

  static void framebufferResized(GLFWwindow *window, int width, int height) {
    auto prog = (Program*)glfwGetWindowUserPointer(window);
    glViewport(0, 0, width, height);
    prog->resolution.x = width;
    prog->resolution.y = height;
    prog->setUpTextures();
  }

public:
  Program() : Window() {};
  Program(WindowOpts opts) : Window(opts) {
    resolution = glm::vec3(opts.width, opts.height, 0.0f);
    time_start = glfwGetTime();
    time_old = glfwGetTime();

    glfwSetWindowUserPointer(ptr, this);
    glfwSetFramebufferSizeCallback(ptr, framebufferResized);

    renderer_name = glGetString(GL_RENDERER);
    glViewport(0, 0, opts.width, opts.height);

    glGenBuffers(1, &vbo_quad);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quad);
    glBufferData(GL_ARRAY_BUFFER, sizeof(screen_quad), screen_quad, GL_STATIC_DRAW);

    glGenBuffers(1, &vbo_tex);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_tex);
    glBufferData(GL_ARRAY_BUFFER, sizeof(screen_texcoords), screen_texcoords, GL_STATIC_DRAW);

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quad);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);

    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_tex);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, NULL);

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    setUpTextures();

    //===== Section: Shaders =====//
    shader_manager.compileAndWatch({
      .name = "gundam",
      .shaders = {
        Shader{.path = "shaders/util/vert.glsl",        .type = GL_VERTEX_SHADER},
        Shader{.path = "shaders/util/sdf.glsl",         .type = GL_FRAGMENT_SHADER},
        Shader{.path = "shaders/util/ray_marcher.glsl", .type = GL_FRAGMENT_SHADER},
        Shader{.path = "shaders/gundam.glsl",           .type = GL_FRAGMENT_SHADER}
      }
    });
    shader_manager.compileAndWatch({
      .name = "magnemite",
      .shaders = {
        Shader{.path = "shaders/util/vert.glsl",        .type = GL_VERTEX_SHADER},
        Shader{.path = "shaders/util/sdf.glsl",         .type = GL_FRAGMENT_SHADER},
        Shader{.path = "shaders/util/ray_marcher.glsl", .type = GL_FRAGMENT_SHADER},
        Shader{.path = "shaders/magnemite.glsl",        .type = GL_FRAGMENT_SHADER}
      }
    });
    shader_manager.compileAndWatch({
      .name = "screen",
      .shaders = {
        Shader{.path = "shaders/util/screen-vert.glsl", .type = GL_VERTEX_SHADER},
        Shader{.path = "shaders/util/screen-frag.glsl", .type = GL_FRAGMENT_SHADER},
      }
    });
    //===== Section: Shaders =====//

    // Debug Menu.
    scene_id = 0;
    mode_3d = MODE_3D_NONE;
    draw_debug_menu = false;
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    io = &ImGui::GetIO();
    io->ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui_ImplGlfw_InitForOpenGL(ptr, true);
    ImGui_ImplOpenGL3_Init();
  }

  ~Program() {
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
  }

  void setUpTextures() {
    //===== Section: setUpTextures =====//
    // Safe since 0's and non-existant textures are silently ignored.
    glDeleteTextures(1, &image_texture);
    glDeleteTextures(1, &iterations_texture);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glGenTextures(1, &image_texture);
    glBindTexture(GL_TEXTURE_2D, image_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, resolution.x, resolution.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenTextures(1, &iterations_texture);
    glBindTexture(GL_TEXTURE_2D, iterations_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, resolution.x, resolution.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, image_texture, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, iterations_texture, 0);
    //===== Section: setUpTextures =====//
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
      spdlog::critical("glCheckFramebufferStatus: Framebuffer is incomplete!");
    }
  }

  void handleInput(int key, int action) override {
    if (key == GLFW_KEY_SPACE && action == GLFW_PRESS) {
      draw_debug_menu = !draw_debug_menu;
    }
  }

  void draw() override {
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

    GLuint scene = 0;
    switch (scene_id) {
      case 0:
        scene = shader_manager.get("gundam");
        break;
      case 1:
        scene = shader_manager.get("magnemite");
        break;
      default:
        scene = shader_manager.get("gundam");
    }

    // Render scene to FBO
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(scene);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    GLuint imouse = glGetUniformLocation(scene, "imouse");
    GLuint iresolution = glGetUniformLocation(scene, "iresolution");
    GLuint itime = glGetUniformLocation(scene, "itime");
    GLuint itime_delta = glGetUniformLocation(scene, "itime_delta");
    GLuint ianaglyph = glGetUniformLocation(scene, "ianaglyph");
    glUniform3fv(imouse, 1, glm::value_ptr(mouse_pos));
    glUniform3fv(iresolution, 1, glm::value_ptr(resolution));
    glUniform1f(itime, time);
    glUniform1f(itime_delta, time_delta);
    glUniform1i(ianaglyph, mode_3d);

    glBindVertexArray(vao);
    glDrawBuffers(2, draw_buffers);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    // Render FBO to screen.
    auto screen = shader_manager.get("screen");
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glUseProgram(screen);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (draw_debug_menu) {
      ImGui_ImplOpenGL3_NewFrame();
      ImGui_ImplGlfw_NewFrame();
      ImGui::NewFrame();
      {
        auto image_size = ImVec2(resolution.x / 6, resolution.y / 6);

        ImGui::SetNextWindowSize(ImVec2(0.0f, 0.0f));
        ImGui::Begin("Debug");
        ImGui::Text("Device: %s", renderer_name);
        ImGui::Text("Resolution: %.0fx%.0f", resolution.x, resolution.y);
        ImGui::Text("Fps: %.0f (%.3f)", io->Framerate, 1000.0f / io->Framerate);
        ImGui::Image((ImTextureID)(intptr_t)iterations_texture, image_size, ImVec2(0, 1), ImVec2(1, 0));

        ImGui::SeparatorText("Scene");
        ImGui::RadioButton("Gundam", &scene_id, 0); ImGui::SameLine();
        ImGui::RadioButton("Magnemite", &scene_id, 1);

        ImGui::SeparatorText("Anaglyph 3D");
        ImGui::RadioButton("None", &mode_3d, MODE_3D_NONE); ImGui::SameLine();
        ImGui::RadioButton("Naive", &mode_3d, MODE_3D_NAIVE); ImGui::SameLine();
        ImGui::RadioButton("Dubois Revised", &mode_3d, MODE_3D_DUBOIS);
      }
      ImGui::End();
    }

    glBindTexture(GL_TEXTURE_2D, image_texture);
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    if (draw_debug_menu) {
      ImGui::Render();
      ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    }
  }
};

int main() {
  auto console_target = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
  spdlog::sinks_init_list targets = {console_target};
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
