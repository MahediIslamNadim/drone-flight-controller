# NexCore Drone Flight Controller

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-ESP8266-orange)
![Arduino](https://img.shields.io/badge/Arduino-IDE-00979D)
![Python](https://img.shields.io/badge/Python-3.8%2B-blue)

ESP8266-based quadcopter flight controller with real-time ground station GUI. Features full PID control, MAVLink telemetry, Wi-Fi AP mode, and sensor fusion via Madgwick filter.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Ground Station (Python GUI)                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ 3D View  │ │  Graphs  │ │ Compass  │ │  Data Logger   │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───────┬────────┘  │
│       └────────────┴────────────┴────────────────┘           │
│                         │ Serial/Wi-Fi                        │
├─────────────────────────┼─────────────────────────────────────┤
│                Flight Controller (ESP8266)                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ MPU6050  │ │  BMP280  │ │  Madgwick│ │  PID Control   │  │
│  │ IMU      │ │ Barometer│ │  Filter  │ │  (Rate+Angle)  │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───────┬────────┘  │
│       └────────────┴────────────┴────────────────┘           │
│                         │ PPM / PWM                            │
│                    ┌────┴────┐                                 │
│                    │ Motors  │  (4x PWM)                       │
│                    └─────────┘                                 │
└─────────────────────────────────────────────────────────────┘
```

## Features

### Flight Controller (ESP8266)
- **Sensor Fusion**: MPU6050 (accel/gyro) + BMP280 (barometer) via Madgwick filter
- **PID Control**: Cascaded rate + angle PID on roll/pitch, rate-only on yaw
- **Flight Modes**: Stabilize, Altitude Hold, RTL (Return-to-Launch)
- **MAVLink Telemetry**: Full MAVLink v1 protocol over serial
- **Wi-Fi AP Mode**: Built-in web interface for configuration
- **Safety**: Arm/disarm, failsafe detection, geofence, low battery cutoff
- **EEPROM**: Persistent parameter storage
- **Binary Logging**: Black box flight data recording
- **PPM Receiver**: Support for standard RC receivers

### Ground Station (Python GUI)
- **3D Attitude Visualization**: Real-time aircraft orientation
- **Sensor Graphs**: Live accelerometer, gyroscope, and altitude plots
- **Calibration Wizard**: Step-by-step accel/gyro calibration
- **MAVLink Telemetry**: Parameter read/write, mission planning
- **Data Export**: JSON, CSV, and MAVLink log formats
- **Serial Auto-Detect**: Automatic port detection and connection

## Hardware Requirements

| Component | Specification |
|-----------|---------------|
| MCU | ESP8266 (NodeMCU, Wemos D1 Mini, etc.) |
| IMU | MPU6050 (accelerometer + gyroscope) |
| Barometer | BMP280 (optional, for altitude hold) |
| ESC | 4x PWM-controlled ESCs |
| Frame | Any 250mm+ quadcopter frame |
| Receiver | PPM-compatible RC receiver |

## Wiring

| MPU6050 | ESP8266 |
|---------|---------|
| VCC | 3.3V |
| GND | GND |
| SDA | D2 (GPIO4) |
| SCL | D1 (GPIO5) |

| BMP280 | ESP8266 |
|--------|---------|
| VCC | 3.3V |
| GND | GND |
| SDA | D2 (GPIO4) |
| SCL | D1 (GPIO5) |

## Getting Started

### 1. Upload Firmware

Open `esp8266_flight_controller/esp8266_flight_controller.ino` in Arduino IDE:

1. Install ESP8266 board support (Boards Manager: `esp8266 by ESP8266 Community`)
2. Install required libraries: `Wire`, `EEPROM`, `ESP8266WebServer`, `ESP8266WiFi`
3. Select board: `NodeMCU 1.0 (ESP-12E)` or your specific variant
4. Set flash size: `4MB (1MB SPIFFS)`
5. Upload via USB

### 2. Install Ground Station

```bash
pip install -r requirements.txt
```

### 3. Run Ground Station

```bash
python drone_calibration.py
```

### 4. Calibrate Sensors

1. Select serial port and click **CONNECT**
2. Place the drone on a level surface
3. Click **CALIBRATE ACCEL** and wait
4. Keep the drone perfectly still, click **CALIBRATE GYRO**
5. Save calibration profile

## Project Structure

```
├── esp8266_flight_controller/
│   ├── esp8266_flight_controller.ino   # Main firmware entry point
│   ├── config.h                        # Configuration parameters
│   ├── types.h                         # Data structures
│   ├── globals.h                       # Global variables
│   ├── mpu6050.cpp/.h                  # MPU6050 IMU driver
│   ├── bmp280.cpp/.h                   # BMP280 barometer driver
│   ├── madgwick.cpp/.h                 # Madgwick orientation filter
│   ├── pid.cpp/.h                      # PID controller
│   ├── motors.cpp/.h                   # Motor mixing and output
│   ├── rc.cpp/.h                       # RC input (PPM)
│   ├── flight_modes.cpp/.h             # Flight mode logic
│   ├── safety.cpp/.h                   # Safety checks and failsafe
│   ├── battery.cpp/.h                  # Battery monitoring
│   ├── mavlink_send.cpp/.h             # MAVLink telemetry output
│   ├── serial_cmd.cpp/.h               # Serial command parser
│   ├── eeprom_params.cpp/.h            # EEPROM parameter storage
│   ├── binary_log.cpp/.h               # Binary flight logging
│   ├── led.cpp/.h                      # LED indicators
│   ├── wifi_ap.cpp/.h                  # Wi-Fi access point mode
│   └── i2c.cpp/.h                      # I2C bus manager
├── drone_calibration.py                # Ground station GUI
├── esp8266_mpu6050.ino                 # Standalone IMU test sketch
├── test_ports.py                       # Serial port diagnostics
├── requirements.txt                    # Python dependencies
├── LICENSE                             # MIT License
└── README.md                           # This file
```

## Serial Commands

| Command | Description |
|---------|-------------|
| `CALIBRATE` | Run full IMU calibration |
| `RESET` | Reset calibration offsets to zero |
| `STATUS` | Display current sensor offsets |
| `SET_ACCEL_OFFSET:x,y,z` | Set accelerometer offsets |
| `SET_GYRO_OFFSET:x,y,z` | Set gyroscope offsets |
| `ARM` | Arm the motors |
| `DISARM` | Disarm the motors |
| `HELP` | List available commands |

## Configuration

Edit `esp8266_flight_controller/config.h` to tune:

- **PID gains**: `PID_RATE_ROLL_P`, `PID_RATE_ROLL_I`, `PID_RATE_ROLL_D`, etc.
- **RC ranges**: `RC_MIN`, `RC_MAX`, `RC_MID`
- **Battery**: `BATTERY_CELL_FULL`, `BATTERY_CELL_EMPTY`
- **Safety**: `ARM_TIMEOUT_MS`, `FAILSAFE_THROTTLE_US`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
