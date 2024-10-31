#include <stdexcept>

#include <spdlog/spdlog.h>

#include "gl_errors.hpp"
#include "window.hpp"

void Window::logError(int error_code, const char *description) {
  spdlog::info("GLFW: {}", description);
}

void Window::glError(void *ret, const char *name, GLADapiproc proc, int len_args, ...) {
  GLenum error = glad_glGetError();
  if (error == GL_NO_ERROR) return;

  spdlog::error("{}[{}]: {}", name, getGLErrorCodeString(error), getGLErrorString(name, error));
}

Window::Window(WindowOpts opts) {
  glfwSetErrorCallback(Window::logError);

  if (!glfwInit()) {
    throw std::runtime_error("glfwInit");
  }

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, opts.glMajor);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, opts.glMinor);
  glfwWindowHint(GLFW_OPENGL_PROFILE, opts.glProfile);

  ptr = glfwCreateWindow(
    opts.width,
    opts.height,
    opts.title,
    nullptr,
    nullptr
  );

  if (!ptr) {
    glfwTerminate();
    throw std::runtime_error("glfwCreateWindow");
  }

  glfwMakeContextCurrent(ptr);

  if (!gladLoadGL(glfwGetProcAddress)) {
    glfwDestroyWindow(ptr);
    glfwTerminate();
    throw std::runtime_error("gladLoadGL");
  }

  gladSetGLPostCallback(&glError);

  glfwSwapInterval(1);
}

Window::~Window() {
  glfwDestroyWindow(ptr);
  glfwTerminate();
}

void Window::run() {
  while (!glfwWindowShouldClose(ptr)) {
    glfwPollEvents();

    handleInput(1);
    draw();

    glfwSwapBuffers(ptr);
  }
}
