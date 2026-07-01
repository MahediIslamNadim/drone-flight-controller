#ifndef GLOBALS_H
#define GLOBALS_H

#include <Wire.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>
#include "types.h"

extern ESP8266WebServer server;
extern FlightData fd;
extern EEPROMData eeprom_data;
extern PIDController pid_rate_roll, pid_rate_pitch, pid_rate_yaw;
extern PIDController pid_angle_roll, pid_angle_pitch;
extern RCData rc;
extern MotorOutput motors;
extern unsigned long last_loop_time;
extern unsigned long last_telemetry_time;
extern unsigned long last_led_time;
extern unsigned long arm_start_time;
extern unsigned long disarm_start_time;
extern unsigned long loop_count;
extern uint8_t led_state;
extern bool led_on;
extern bool calibration_mode;
extern float accel_cal_sum[3];
extern float gyro_cal_sum[3];
extern float mag_cal_sum[3];
extern uint32_t cal_sample_count;
extern uint8_t mpu_addr;
extern bool mpu_found;
extern bool bmp_found;
extern float bmp_pressure;
extern float bmp_temperature;
extern float bmp_altitude;
extern float bmp_sea_level_pressure;
extern const char* ap_ssid;
extern const char* ap_pass;
extern bool wifi_connected;
extern char serial_cmd_buf[128];
extern uint8_t serial_cmd_len;
extern bool log_enable;
extern bool crash_detected;
extern float home_lat, home_lon;
extern bool home_set;
extern float madgwick_beta;
extern volatile unsigned long ppm_last_pulse;
extern volatile uint8_t ppm_channel_index;
extern volatile uint16_t ppm_buffer[RC_CHANNELS];
extern volatile bool ppm_frame_complete;

#endif
