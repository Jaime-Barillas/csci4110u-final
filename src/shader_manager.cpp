#include "shader_manager.hpp"
#include "FileWatch.hpp"
#include "src/logging.hpp"
#include <fstream>
#include <sstream>
#include <stumpless.h>

std::string ShaderManager::slurp(const std::string &path) const {
  std::ifstream file{path};
  std::ostringstream str_stream;
  std::string source;

  str_stream << file.rdbuf();
  source = str_stream.str();

  return source;
}

GLuint ShaderManager::get(const std::string &key) const {
  return programs.at(key).id;
}

void ShaderManager::compileShader(Shader &shader) {
  std::string source_str = slurp(shader.path);
  const char *source = source_str.c_str();
  GLuint shader_id = 0;

  stump_d_message(log_target_chain, "  Compiling %s", shader.path.c_str());
  shader_id = glCreateShader(shader.type);
  glShaderSource(shader_id, 1, &source, NULL);
  glCompileShader(shader_id);

  // _Flag_ shader for deletion.
  if (shader.id != 0) {
    glDeleteShader(shader.id);
  }

  shader.id = shader_id;
}

void ShaderManager::compileProgram(ShaderProgram &program) {
  GLuint program_id = 0;

  stump_d_message(log_target_chain, "Compiling %s shaders:", program.name.c_str());
  program_id = glCreateProgram();

  for(auto &shader : program.shaders) {
    compileShader(shader);
    glAttachShader(program_id, shader.id);
  }

  glLinkProgram(program_id);

  if (program.id != 0) {
    glDeleteProgram(program.id);
  }
  program.id = program_id;
}

// TODO: FileWatcher runs twice per modification.
void ShaderManager::compileAndWatch(ShaderProgram program_desc) {
  // Store copy of `program_desc` first, then grab _reference_ to stored copy.
  programs[program_desc.name] = program_desc;
  ShaderProgram &program = programs.at(program_desc.name);

  compileProgram(program);

  for (auto &shader : program.shaders) {
     auto watcher = new filewatch::FileWatch<std::string>(
      shader.path,
      [this, &program](const std::string &path, const filewatch::Event ev){
        if (ev != filewatch::Event::modified) return;

        mutex.lock();
        out_of_date_programs.push(program.name);
        mutex.unlock();
      }
    );
    watchers.push_back(watcher);
  }
}

void ShaderManager::recompilePending() {
  if (!mutex.try_lock()) return;

  if (out_of_date_programs.size() > 0) {
    std::string &program_name = out_of_date_programs.front();
    ShaderProgram &program = programs.at(program_name);
    out_of_date_programs.pop();

    compileProgram(program);
  }

  mutex.unlock();
}
