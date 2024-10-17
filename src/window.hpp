#ifndef CSCI_4110U_WINDOW_H
#define CSCI_4110U_WINDOW_H

#ifdef _WIN32
#defin GLFW_DLL
#endif

#define GLFW_INCLUDE_NONE
#include <glad/gl.h>
#include <GLFW/glfw3.h>

struct WindowOpts {
  /* Window Opts */
  int width;
  int height;
  const char *title;

  /* GL Context */
  int glMajor = 3;
  int glMinor = 3;
  int glProfile = GLFW_OPENGL_CORE_PROFILE;
};

class Window {
  static void logError(int error_code, const char *description);

  protected:
    GLFWwindow *ptr = nullptr;

    Window();
    Window(WindowOpts opts);

  public:
    ~Window();
    void run();
    virtual void handleInput(int key) = 0;
    virtual void draw() = 0;
};

#endif
