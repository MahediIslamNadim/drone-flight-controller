#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

#define PIN_SDA       4
#define PIN_SCL       5
#define PIN_MOTOR1    0
#define PIN_MOTOR2    14
#define PIN_MOTOR3    12
#define PIN_MOTOR4    13
#define PIN_BATTERY   A0
#define PIN_PPM       16
#define PIN_LED       2

#define MPU6050_ADDR_LOW   0x68
#define MPU6050_ADDR_HIGH  0x69
#define BMP280_ADDR        0x76

#define EEPROM_SIZE         512
#define EEPROM_MAGIC_ADDR   96
#define EEPROM_MAGIC_VALUE  0xABCD
#define EEPROM_DATA_ADDR    100

#define LOOP_FREQ_HZ        500
#define LOOP_PERIOD_US      (1000000 / LOOP_FREQ_HZ)
#define TELEMETRY_FREQ_HZ   50
#define LED_FAST_BLINK_MS   100
#define LED_SLOW_BLINK_MS   500
#define RC_TIMEOUT_MS       500
#define ARM_THROTTLE_MIN    1100
#define ARM_THROTTLE_MAX    1200
#define ARM_YAW_RIGHT       1800
#define ARM_YAW_LEFT        1200
#define ARM_TIME_MS         3000
#define DISARM_TIME_MS      3000
#define MOTOR_MINPWM        1000
#define MOTOR_MAXPWM        2000
#define MOTOR_IDLEPWM       1100
#define BATTERY_VOLTAGE_MIN 3.3
#define BATTERY_VOLTAGE_MAX 4.2
#define CRASH_ACCEL_G       4.0
#define RC_CHANNELS         8

#define MODE_STABILIZE  0
#define MODE_ACRO       1
#define MODE_ALTHOLD    2
#define MODE_RTL        3
#define MODE_LAND       4

#define FAILSAFE_NONE   0
#define FAILSAFE_HOLD   1
#define FAILSAFE_LAND   2
#define FAILSAFE_RTL    3

#define MAVLINK_MSG_ID_HEARTBEAT       0
#define MAVLINK_MSG_ID_SYS_STATUS      1
#define MAVLINK_MSG_ID_BATTERY_STATUS  14
#define MAVLINK_MSG_ID_RADIO_STATUS    101
#define MAVLINK_MSG_ID_GPS_RAW_INT     24
#define MAVLINK_MSG_ID_ATTITUDE        30
#define MAVLINK_MSG_ID_RAW_IMU         27
#define MAVLINK_MSG_ID_SERVO_OUTPUT_RAW 36
#define MAVLINK_MSG_ID_RC_CHANNELS     65
#define MAVLINK_MSG_ID_PARAM_VALUE     22

#endif
