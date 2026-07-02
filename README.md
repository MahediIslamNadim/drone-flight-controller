# NexCore Drone Flight Controller

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-ESP8266-orange)
![Arduino](https://img.shields.io/badge/Arduino-IDE-00979D)

ESP8266-based quadcopter flight controller firmware with full PID control, sensor fusion, MAVLink telemetry, and safety features.

> **Ground Station GUI** available at: [github.com/MahediIslamNadim/ground-station-gui](https://github.com/MahediIslamNadim/ground-station-gui)

## Features

- **Sensor Fusion**: MPU6050 (accel/gyro) + BMP280 (barometer) via Madgwick filter
- **PID Control**: Cascaded rate + angle PID on roll/pitch, rate-only on yaw
- **Flight Modes**: Stabilize, Altitude Hold, RTL (Return-to-Launch)
- **MAVLink**: Full MAVLink v1 telemetry over serial
- **Wi-Fi AP**: Built-in web interface for configuration
- **Safety**: Arm/disarm, failsafe detection, geofence, low battery cutoff
- **EEPROM**: Persistent parameter storage
- **Binary Logging**: Black box flight data recording
- **PPM Receiver**: Standard RC receiver support

## Hardware

| Component | Specification |
|-----------|---------------|
| MCU | ESP8266 (NodeMCU, Wemos D1 Mini) |
| IMU | MPU6050 |
| Barometer | BMP280 (optional) |
| ESC | 4x PWM-controlled |
| Frame | 250mm+ quadcopter |
| Receiver | PPM-compatible |

## Wiring

| MPU6050 | ESP8266 | BMP280 | ESP8266 |
|---------|---------|--------|---------|
| VCC | 3.3V | VCC | 3.3V |
| GND | GND | GND | GND |
| SDA | D2 (GPIO4) | SDA | D2 (GPIO4) |
| SCL | D1 (GPIO5) | SCL | D1 (GPIO5) |

## Build & Upload

1. Install **ESP8266** board support in Arduino IDE
2. Install libraries: `Wire`, `EEPROM`, `ESP8266WebServer`, `ESP8266WiFi`
3. Select `NodeMCU 1.0 (ESP-12E)`, flash size `4MB (1MB SPIFFS)`
4. Open `esp8266_flight_controller.ino` and upload

## Project Structure

```
├── config.h                  # Configuration parameters
├── types.h                   # Data structures
├── globals.h                 # Global state
├── mpu6050.cpp/.h            # IMU driver
├── bmp280.cpp/.h             # Barometer driver
├── madgwick.cpp/.h           # Orientation filter
├── pid.cpp/.h                # PID controller
├── motors.cpp/.h             # Motor mixing & output
├── rc.cpp/.h                 # PPM input
├── flight_modes.cpp/.h       # Flight mode logic
├── safety.cpp/.h             # Failsafe & checks
├── battery.cpp/.h            # Battery monitor
├── mavlink_send.cpp/.h       # MAVLink output
├── serial_cmd.cpp/.h         # Serial command parser
├── eeprom_params.cpp/.h      # Parameter storage
├── binary_log.cpp/.h         # Flight logging
├── led.cpp/.h                # Status LEDs
├── wifi_ap.cpp/.h            # Wi-Fi access point
└── i2c.cpp/.h                # I2C bus manager
```

## Serial Commands

| Command | Description |
|---------|-------------|
| `CALIBRATE` | Run IMU calibration |
| `RESET` | Reset offsets |
| `STATUS` | Show sensor offsets |
| `SET_ACCEL_OFFSET:x,y,z` | Set accel offsets |
| `SET_GYRO_OFFSET:x,y,z` | Set gyro offsets |
| `ARM` | Arm motors |
| `DISARM` | Disarm motors |
| `HELP` | List commands |

## Configuration

Edit `config.h` to tune PID gains, RC ranges, battery thresholds, and safety parameters.

## License

MIT License - see [LICENSE](LICENSE).
