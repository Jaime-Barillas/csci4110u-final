project('glad', 'c')

includes = include_directories(['include'])

glad_dep = declare_dependency(
  include_directories: includes,
)

# The DearImGui meson build file requires the 'gl' dependency to enable the
# opengl3 backend. Tell meson to use this subproject whenever 'gl' is requested
# by other subprojects.
meson.override_dependency('gl', glad_dep)

