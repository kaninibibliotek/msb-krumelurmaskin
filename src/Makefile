CC=gcc
CXX=g++
CFLAGS=-g -Wno-deprecated-declarations
LIBS=-lstdc++

.SUFFIXES:.o .os .m .mm .c .h .cpp

PACKAGE=Krumeluren.app

FRAMEWORKS=\
	-F$(PACKAGE)/Contents/Frameworks \
	-framework Cocoa \
	-framework Python \
	-framework QuartzCore \
	-framework AVFoundation \
	-framework CoreMedia \
	-framework ImageCaptureCore \
	-framework Quartz \
	-framework WebKit \
	-framework opencv2

INCLUDE=-F$(PACKAGE)/Contents/Frameworks

OBJC_SOURCES=\
	main.m \
	NSString+Py.m \
	Runtime.m \
	VideoView.m \
	PreView.m \
	PTPCamera.m \
	YVSChromaKeyFilter.m \
	ImageProcessor.m \
	Application.m

OBJECTS=$(OBJC_SOURCES:.m=.o)
DEPS=$(OBJECTS:.o=.d)

ICONSET=$(PACKAGE)/Contents/Resources/Krumeluren.iconset
ICON=$(ICONSET:.iconset=.icns)

TARGET=$(PACKAGE)/Contents/MacOS/Krumeluren

all: $(TARGET)

clean:
	@rm -f $(TARGET)
	@rm -f $(OBJECTS)
	@rm -f $(DEPS)
	@rm -f $(ICON)
	@rm -f *.os
	@rm -f imgprc ptpget

tests: $(TARGET) ImageProcessor.os PTPCamera.os
	@$(CC) $(LIBS) $(LDFLAGS) $(FRAMEWORKS) -o imgprc ImageProcessor.os YVSChromaKeyFilter.o
	@$(CC) $(LIBS) $(LDFLAGS) $(FRAMEWORKS) -o ptpget PTPCamera.os

$(TARGET): $(OBJECTS) $(ICON)
	@echo Linking $(PACKAGE)
	@$(CC) $(LIBS) $(LDFLAGS) $(FRAMEWORKS) -o $(TARGET) $(OBJECTS)
	@touch $(PACKAGE)

$(ICON): $(ICONSET)
	@echo "Updating icon"
	@sips -z 16 16     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_16x16.png > /dev/null
	@sips -z 32 32     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_16x16@2x.png > /dev/null
	@sips -z 32 32     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_32x32.png > /dev/null
	@sips -z 64 64     $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_32x32@2x.png > /dev/null
	@sips -z 128 128   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_128x128.png > /dev/null
	@sips -z 256 256   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_128x128@2x.png > /dev/null
	@sips -z 256 256   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_256x256.png > /dev/null
	@sips -z 512 512   $(ICONSET)/icon_512x512.png --out $(ICONSET)/icon_256x256@2x.png > /dev/null
	@iconutil -c icns $< 1>&2 > /dev/null

-include $(DEPS)

.m.o:
	@echo Compiling C: $@
	@$(CC) -c $(INCLUDE) $(CFLAGS) -MMD -MP -o $@ $<

.m.os:
	@echo Compiling Test: $@
	@$(CXX) -c $(INCLUDE) $(CLFAGS) -D_STANDALONE_TEST_ -o $@ $<
