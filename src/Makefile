CC=gcc
CXX=g++
CFLAGS=-g -Wno-deprecated-declarations

.SUFFIXES:.o .m. .c .h .cpp

FRAMEWORKS=\
	-framework Cocoa \
	-framework Python \
	-framework QuartzCore \
	-framework AVFoundation \
	-framework CoreMedia

SOURCES=\
	main.m \
	NSString+Py.m \
	Runtime.m \
	VideoView.m \
	Application.m

OBJECTS=$(SOURCES:.m=.o)
DEPS=$(SOURCES:.m=.d)

ICONSET=Krumeluren.app/Contents/Resources/Krumeluren.iconset
ICON=$(ICONSET:.iconset=.icns)

TARGET=Krumeluren.app/Contents/MacOS/Krumeluren

all: $(TARGET)

clean:
	@rm -f $(TARGET)
	@rm -f $(OBJECTS)
	@rm -f $(DEPS)
	@rm -f $(ICON)

$(TARGET): $(OBJECTS) $(ICON)
	$(CC) $(LIBS) $(LDFLAGS) $(FRAMEWORKS) -o $(TARGET) $(OBJECTS)
	@touch Krumeluren.app

$(ICON): $(ICONSET)
	@sips -z 16 16     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_16x16.png
	@sips -z 32 32     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_16x16@2x.png
	@sips -z 32 32     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_32x32.png
	@sips -z 64 64     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_32x32@2x.png
	@sips -z 128 128   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_128x128.png
	@sips -z 256 256   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_128x128@2x.png
	@sips -z 256 256   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_256x256.png
	@sips -z 512 512   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_256x256@2x.png
	@iconutil -c icns $< 1>&2 > /dev/null

-include $(DEPS)

.m.o:
	$(CC) -c $(INCLUDE) $(CFLAGS) -MMD -MP -o $@ $<
