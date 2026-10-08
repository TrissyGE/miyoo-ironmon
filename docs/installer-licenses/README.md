# Windows installer runtime notices

The Windows installer embeds an unmodified CPython 3.11.15 runtime from
[Python Build Standalone 20260510](https://github.com/astral-sh/python-build-standalone/tree/20260510).
Its component notices come from that pinned project's LICENSE files, plus the
actual installed CPython/Tk licenses. OpenSSL is 3.5.6; Tcl/Tk uses the Windows
8.6 runtime. PyInstaller 6.22.0 is unmodified; its license exception is retained.

These notices cover CPython and runtime components that can be included by the
frozen standard-library dependencies: OpenSSL, Tcl/Tk, bzip2, zlib, liblzma, libffi,
Expat, mpdecimal and SQLite. Component source/version definitions are in
[downloads.py](https://github.com/astral-sh/python-build-standalone/blob/20260510/pythonbuild/downloads.py).
Not every noticed component is necessarily present in the final executable.

Microsoft Visual C runtime DLLs supplied with the Windows Python distribution
retain Microsoft's copyright and are redistributable runtime components; they
are not part of this project's GPL code. See the upstream
[Windows build](https://github.com/astral-sh/python-build-standalone/blob/20260510/cpython-windows/build.py)
and [Visual C redistribution documentation](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files).

The application license, native Lua notice, upstream device dependencies and
AI-use disclosure are documented separately in the release's LICENSE,
LUA-LICENSE.txt, THIRD_PARTY_NOTICES.md, SOURCES.md and AI_USAGE.md.
