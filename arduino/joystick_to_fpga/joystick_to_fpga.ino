const int PIN_VRX = A0;
const int PIN_VRY = A1;

const int OUT_UP    = 4; // Active LOW output for FPGA UP
const int OUT_DOWN  = 5; // Active LOW output for FPGA DOWN
const int OUT_LEFT  = 6; // Active LOW output for FPGA LEFT
const int OUT_RIGHT = 7; // Active LOW output for FPGA RIGHT

// --- Deadzone & Hysteresis Settings (distance from resting center) ---
const int DEADZONE_ENTER = 180; // Push past this to start moving
const int DEADZONE_EXIT  = 130; // Return inside this to stop (prevents jitter)
const int AXIS_LOCK_BIAS = 30;  // Extra margin required to switch between X and Y

int centerX = 512;
int centerY = 512;

enum Direction { IDLE, UP, DOWN, LEFT, RIGHT };
Direction activeDir = IDLE;

unsigned long lastPrintTime = 0;

void setup() {
  Serial.begin(9600); // Keeps your existing Serial Monitor baud rate

  pinMode(OUT_UP, OUTPUT);
  pinMode(OUT_DOWN, OUTPUT);
  pinMode(OUT_LEFT, OUTPUT);
  pinMode(OUT_RIGHT, OUTPUT);

  // Default HIGH (idle state for active-low FPGA inputs)
  digitalWrite(OUT_UP, HIGH);
  digitalWrite(OUT_DOWN, HIGH);
  digitalWrite(OUT_LEFT, HIGH);
  digitalWrite(OUT_RIGHT, HIGH);

  // Auto-calibrate resting center (absorbs Y-axis idle drift automatically)
  long sumX = 0;
  long sumY = 0;
  for (int i = 0; i < 32; i++) {
    sumX += analogRead(PIN_VRX);
    sumY += analogRead(PIN_VRY);
    delay(2);
  }
  centerX = constrain(sumX / 32, 320, 700);
  centerY = constrain(sumY / 32, 320, 700);
}

void loop() {
  int xVal = analogRead(PIN_VRX);
  int yVal = analogRead(PIN_VRY);

  // Offset from calibrated resting position
  int dx = xVal - centerX;
  int dy = yVal - centerY;
  int absX = abs(dx);
  int absY = abs(dy);

  // Hysteresis: easier to hold a direction than to trigger a new one
  int deadzone = (activeDir == IDLE) ? DEADZONE_ENTER : DEADZONE_EXIT;

  if (absX < deadzone && absY < deadzone) {
    activeDir = IDLE;
  } else {
    // 4-Way Dominant Axis Lock: strictly ONE direction active at a time
    if (absY > absX + AXIS_LOCK_BIAS) {
      activeDir = (dy < 0) ? UP : DOWN;
    } else if (absX > absY + AXIS_LOCK_BIAS) {
      activeDir = (dx < 0) ? LEFT : RIGHT;
    }
    // If near an exact 45-degree diagonal, hold the current activeDir
  }

  bool upPressed    = (activeDir == UP);
  bool downPressed  = (activeDir == DOWN);
  bool leftPressed  = (activeDir == LEFT);
  bool rightPressed = (activeDir == RIGHT);

  // Output Active-LOW signals to FPGA
  digitalWrite(OUT_UP,    upPressed    ? LOW : HIGH);
  digitalWrite(OUT_DOWN,  downPressed  ? LOW : HIGH);
  digitalWrite(OUT_LEFT,  leftPressed  ? LOW : HIGH);
  digitalWrite(OUT_RIGHT, rightPressed ? LOW : HIGH);

  // --- NON-BLOCKING SERIAL DEBUG PRINT (every 100ms so polling stays fast) ---
  if (millis() - lastPrintTime >= 100) {
    lastPrintTime = millis();

    Serial.print("Raw X: ");
    Serial.print(xVal);
    Serial.print("\t| Raw Y: ");
    Serial.print(yVal);
    Serial.print("\t| Direction: ");

    if (upPressed)         Serial.print("UP   ");
    else if (downPressed)  Serial.print("DOWN ");
    else if (leftPressed)  Serial.print("LEFT ");
    else if (rightPressed) Serial.print("RIGHT");
    else                   Serial.print("IDLE ");

    Serial.print("\t| Active-LOW Out [U,D,L,R]: [");
    Serial.print(upPressed ? 0 : 1);
    Serial.print(",");
    Serial.print(downPressed ? 0 : 1);
    Serial.print(",");
    Serial.print(leftPressed ? 0 : 1);
    Serial.print(",");
    Serial.print(rightPressed ? 0 : 1);
    Serial.println("]");
  }

  delay(2); // ~500Hz responsive polling
}