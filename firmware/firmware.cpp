#include <Adafruit_NeoPixel.h>


#define PIN 6
#define BT0 0
#define LMAX 100
#define RED 0
#define GREEN 1
#define BLUE 2

#define CMD 0xFF

Adafruit_NeoPixel ds = Adafruit_NeoPixel(LMAX, PIN, NEO_GRB + NEO_KHZ800);

float ctab[] = {0.95, 1.0, 0.5};

int   bright_=0;
int   button_=0;

int color(int val, int t) {
  return (int) ((float)val * ctab[t]);
}

void lightbox() {
    int i;
    ds.clear();
    for (i=0 ; i < LMAX ; i++)
      ds.setPixelColor(i, color(bright_,RED), color(bright_,GREEN), color(bright_,BLUE));
    ds.show();
}

void setup() {
  Serial.begin(9600);
  Serial.setTimeout(500);
  Serial.write("lb!");
  ds.begin();
  pinMode(BT0, INPUT);
  digitalWrite(BT0, HIGH);
  lightbox();
}

void command(byte* data) {
  if (data[0] != CMD) return ;
  switch (data[1]) {
   case 0x01: // read pin
     data[2] = button_;
     break; 
   case 0x02: // set lb
     bright_ = data[2];
     lightbox();
   case 0x03:
     data[2] = bright_;
     break;
  }
  Serial.write(data[0]);
  Serial.write(data[1]);
  Serial.write(data[2]);  
}

void serialEvent() {
  static byte c,cmd[3];
  static int  cnt=0;
  while(Serial.available()) {
    c = Serial.read();
    switch(c) {
     case CMD:
       cnt = 0;
     default:
       cmd[cnt++] = c;
       break ;
    }
    if (cnt == sizeof(cmd)) {
      command(cmd);
      cnt = cmd[0] = cmd[1] = cmd[2] = 0;
    }
  }
  
}

void loop() {

  button_ = (analogRead(BT0) == 0);
  delay(50);
  
}
