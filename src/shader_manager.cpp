#include <fstream>
#include <sstream>

#include <FileWatch.hpp>
#include <spdlog/spdlog.h>

#include "shader_manager.hpp"


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
  GLint shader_param;

  spdlog::info("  Compiling {}", shader.path.c_str());
  shader_id = glCreateShader(shader.type);
  glShaderSource(shader_id, 1, &source, NULL);
  glCompileShader(shader_id);

  glGetShaderiv(shader_id, GL_COMPILE_STATUS, &shader_param);
  if (shader_param == GL_FALSE) {
    auto logger = spdlog::get("logger");
    std::string shader_log;
    glGetShaderiv(shader_id, GL_INFO_LOG_LENGTH, &shader_param);

    shader_log.resize(shader_param);
    glGetShaderInfoLog(shader_id, shader_param, nullptr, shader_log.data());
    spdlog::error("  {} {}", shader.path.c_str(), shader_log);
    logger->flush();
  } else {
    // _Flag_ shader for deletion.
    glDeleteShader(shader.id);
    shader.id = shader_id;
  }
}

void ShaderManager::compileProgram(ShaderProgram &program) {
  GLuint program_id = 0;
  GLint program_param;

  spdlog::info("Compiling {} shaders:", program.name.c_str());
  program_id = glCreateProgram();

  for(auto &shader : program.shaders) {
    compileShader(shader);
    glAttachShader(program_id, shader.id);
  }

  glLinkProgram(program_id);

  glGetProgramiv(program_id, GL_LINK_STATUS, &program_param);
  if (program_param == GL_FALSE) {
    auto logger = spdlog::get("logger");
    std::string program_log;
    glGetProgramiv(program_id, GL_INFO_LOG_LENGTH, &program_param);

    program_log.resize(program_param);
    glGetProgramInfoLog(program_id, program_param, nullptr, program_log.data());
    spdlog::error("{} {}", program.name.c_str(), program_log);
    logger->flush();
  } else {
    glDeleteProgram(program.id);
    program.id = program_id;
  }
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
