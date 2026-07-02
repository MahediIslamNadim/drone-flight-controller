# Drone Calibration Tool

ESP8266 + MPU6050 drone calibration GUI tool for Python.

## Features

- Real-time sensor data visualization (3D view, graphs, compass)
- Accelerometer and gyroscope calibration
- Save/load calibration profiles
- Export calibration data to JSON
- Serial port auto-detection
- Works with any ESP8266 + MPU6050 setup

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### 1. Upload Firmware

Upload `esp8266_mpu6050.ino` to your ESP8266 using Arduino IDE.

### 2. Run GUI

```bash
python drone_calibration.py
```

### 3. Connect

1. Select your serial port from the dropdown
2. Click **CONNECT**
3. Click **SCAN** to auto-detect ESP8266

### 4. Calibrate

**Accelerometer:**
1. Place sensor FLAT on a level surface
2. Click **CALIBRATE ACCEL**
3. Wait for calibration to complete

**Gyroscope:**
1. Keep sensor COMPLETELY STILL
2. Click **CALIBRATE GYRO**
3. Wait for calibration to complete

### 5. Save Profile

1. Click **Save** to save calibration
2. Click **Load** to restore saved calibration
3. Click **Export** to export as JSON file

## Wiring

| MPU6050 | ESP8266 |
|---------|---------|
| VCC     | 3.3V    |
| GND     | GND     |
| SDA     | D2 (GPIO4) |
| SCL     | D1 (GPIO5) |

## Serial Commands

Send these commands via the GUI or serial terminal:

| Command | Description |
|---------|-------------|
| `CALIBRATE` | Run full calibration |
| `RESET` | Reset offsets to zero |
| `STATUS` | Show current offsets |
| `SET_ACCEL_OFFSET:x,y,z` | Set accelerometer offsets |
| `SET_GYRO_OFFSET:x,y,z` | Set gyroscope offsets |
| `HELP` | Show available commands |

## File Structure

```
Arduno IDE/
├── drone_calibration.py    # Main GUI application
├── esp8266_mpu6050.ino     # Arduino firmware
├── requirements.txt        # Python dependencies
└── README.md              # This file
```

## Troubleshooting

**No serial port found:**
- Install CH340/CP2102 drivers
- Check USB cable supports data transfer

**No data showing:**
- Verify wiring (SDA/SCL)
- Check baud rate matches (115200)
- Send `HELP` command to test connection

**Calibration not working:**
- Keep sensor perfectly still during calibration
- For accel, ensure surface is level
- Wait for progress to reach 100%
