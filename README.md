# Compiling

Windows:
+ Python must be installed (version 3.12.2)
  - Needs pip, venv
+ Microsoft C++ compiler

Run:
1. `python -m venv .venv`
2. `.\.venv\Scripts\activate`
3. `.\build.bat`
4. Run the program at `.\build\final.exe`

## Common Dependencies
+ GLAD:
  - Language: C/C++
  - API
    * gl: 4.6 Core Profile
  - Extensions: None
  - Options:
    * Header only
    * Debug
  - https://gen.glad.sh/#generator=c&api=gl%3D4.6&profile=gl%3Dcore%2Cgles1%3Dcommon&options=HEADER_ONLY
+ GLFW 3.3.10

System Dependencies:
+ Ubuntu: `sudo apt install libxkbcommon-dev xorg-dev`.
+ Fedora: `sudo dnf install libxkbcommon-devel libXcursor-devel libXi-devel libXinerama-devel libXrandr-devel`.

