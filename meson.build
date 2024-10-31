project('lab5', 'cpp',
  version : '0.1',
  default_options : ['warning_level=3', 'cpp_std=c++20', 'default_library=static']
)

glfw = subproject('glfw')
glad = subproject('glad')
FileWatch = subproject('FileWatch')
spdlog = subproject('spdlog')
glm = subproject('glm')

deps = [
  glfw.get_variable('glfw_dep'),
  glad.get_variable('glad_dep'),
  FileWatch.get_variable('FileWatch_dep'),
  spdlog.get_variable('spdlog_dep'),
  glm.get_variable('glm_dep'),
]

executable('lab5',
   'src/main.cpp',
   'src/window.cpp',
   'src/shader_manager.cpp',
   dependencies: deps,
   install: true,
)
