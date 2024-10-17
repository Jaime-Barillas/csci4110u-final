#ifndef CSCI_4110U_SHADER_MANAGER_H
#define CSCI_4110U_SHADER_MANAGER_H

#include <glad/gl.h>
#include <map>
#include <string>
#include <vector>
#include <queue>
#include <mutex>
#include "FileWatch.hpp"

/* It is assumed that there is a _one-to-one_ correspondence between shader
   files, shader objects, and shader programs. ShaderManager will not work
   with shaders that belong to multiple programs or shader objects made from
   multiple files.
*/

struct Shader {
  std::string path;
  GLint type = GL_VERTEX_SHADER;
  GLuint id = 0;
};

struct ShaderProgram {
  std::string name;
  std::vector<Shader> shaders{};
  GLuint id = 0;
};

struct ShaderManager {
  GLuint get(const std::string &key) const;
  void compileAndWatch(ShaderProgram program_desc);
  void recompilePending();

  ~ShaderManager() {
    for (auto watcher : watchers) {
      delete watcher;
    }
  }

  private:
    std::map<std::string, ShaderProgram> programs{};
    std::vector<filewatch::FileWatch<std::string>*> watchers;
    std::queue<std::string> out_of_date_programs{};
    std::mutex mutex;

    std::string slurp(const std::string &path) const;
    void compileShader(Shader &shader);
    void compileProgram(ShaderProgram &program);
};

#endif
