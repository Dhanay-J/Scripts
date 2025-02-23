### **Workaround: Downgrade MinGW64 to 11.2.0**  

Encountered this issue while building a GStreamer application on Windows 11 using MinGW64:  

* `undefined reference to '__mingw_initltsdrot_force'` 
* `undefined reference to '__mingw_app_type'`


After testing multiple MinGW versions, I found that **downgrading to MinGW64 11.2.0** resolves the issue:  

🔗 [MinGW64 11.2.0 (Win32 SJLJ)](https://github.com/niXman/mingw-builds-binaries/releases/download/11.2.0-rt_v9-rev0/x86_64-11.2.0-release-win32-sjlj-rt_v9-rev0.7z)

# Makefile
```
CC = gcc
CFLAGS = \
    -IC:/gstreamer/1.0/mingw_x86_64/include/gstreamer-1.0 \
    -IC:/gstreamer/1.0/mingw_x86_64/include/glib-2.0 \
    -IC:/gstreamer/1.0/mingw_x86_64/lib/glib-2.0/include \
    -IC:/gstreamer/1.0/mingw_x86_64/include

LDFLAGS = -LC:/gstreamer/1.0/mingw_x86_64/lib \
    -LC:D:/mingw64/i686-w64-mingw32/lib \
    -lgstreamer-1.0 -lgobject-2.0 -lglib-2.0 -lintl

SRC = main.c
TARGET = main.exe

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(SRC) -o $(TARGET) $(CFLAGS) $(LDFLAGS)

clean:
	del /F $(TARGET)

```

# Example Code Source
[GStreamer Simple initialization](https://gstreamer.freedesktop.org/documentation/application-development/basics/init.html#simple-initialization)
