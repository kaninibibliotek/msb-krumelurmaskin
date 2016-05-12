#include <Adafruit_NeoPixel.h>


#define PIN 6
#define LMAX 100
#define RED 0
#define GREEN 1
#define BLUE 2

float ctab[] = {0.95, 1.0, 0.5};

Adafruit_NeoPixel ds = Adafruit_NeoPixel(LMAX, PIN, NEO_GRB + NEO_KHZ800);

int color(int val, int t) {
  return (int) ((float)val * ctab[t]);
}

void lightbox(int brightness) {
    int i;
    ds.clear();
    for (i=0 ; i < LMAX ; i++)
      ds.setPixelColor(i, color(brightness,RED), color(brightness,GREEN), color(brightness,BLUE));
    ds.show();
}


void setup() {
  Serial.begin(9600);
  Serial.setTimeout(500);
  Serial.print("l!b2");
  Serial.flush();
  ds.begin();
  lightbox(0);
}

void serialEvent() {
    while(Serial.available())
        lightbox(Serial.read());
}

void loop() {
    
}
