#include "config.h"
#include "types.h"
#include "globals.h"
#include "i2c.h"
#include "mpu6050.h"
#include "bmp280.h"
#include "madgwick.h"
#include "pid.h"
#include "rc.h"
#include "motors.h"
#include "flight_modes.h"
#include "safety.h"
#include "battery.h"
#include "mavlink_send.h"
#include "serial_cmd.h"
#include "eeprom_params.h"
#include "binary_log.h"
#include "led.h"
#include "wifi_ap.h"
#include <Wire.h>
#include <EEPROM.h>

ESP8266WebServer server(80);
FlightData fd;
EEPROMData eeprom_data;
PIDController pid_rate_roll, pid_rate_pitch, pid_rate_yaw;
PIDController pid_angle_roll, pid_angle_pitch;
RCData rc;
volatile unsigned long ppm_last_pulse = 0;
volatile uint8_t ppm_channel_index = 0;
volatile uint16_t ppm_buffer[RC_CHANNELS];
volatile bool ppm_frame_complete = false;
MotorOutput motors;
unsigned long last_loop_time = 0;
unsigned long last_telemetry_time = 0;
unsigned long last_led_time = 0;
unsigned long arm_start_time = 0;
unsigned long disarm_start_time = 0;
unsigned long loop_count = 0;
uint8_t led_state = 0;
bool led_on = false;
bool calibration_mode = false;
float accel_cal_sum[3] = {0, 0, 0};
float gyro_cal_sum[3] = {0, 0, 0};
float mag_cal_sum[3] = {0, 0, 0};
uint32_t cal_sample_count = 0;
uint8_t mpu_addr = 0;
bool mpu_found = false;
bool bmp_found = false;
float bmp_pressure = 0;
float bmp_temperature = 0;
float bmp_altitude = 0;
float bmp_sea_level_pressure = 101325.0;
const char* ap_ssid = "DroneCal-AP";
const char* ap_pass = "12345678";
bool wifi_connected = false;
char serial_cmd_buf[128];
uint8_t serial_cmd_len = 0;
bool log_enable = false;
bool crash_detected = false;
float home_lat = 0, home_lon = 0;
bool home_set = false;
float madgwick_beta = 0.1;

void setup() {
    Serial.begin(115200);
    Serial.println("\n=== ESP8266 Flight Controller ===");
    pinMode(PIN_LED, OUTPUT);
    digitalWrite(PIN_LED, HIGH);
    Wire.begin(PIN_SDA, PIN_SCL);
    Wire.setClock(400000);
    Serial.println("[I2C] OK");
    EEPROM.begin(EEPROM_SIZE);
    eepromLoad();
    if (mpu6050Init()) Serial.printf("[MPU6050] 0x%02X\n", mpu_addr);
    else Serial.println("[MPU6050] NOT FOUND");
    if (bmp280Init()) Serial.println("[BMP280] OK");
    else Serial.println("[BMP280] NOT FOUND");
    motorInit();
    rcInit();
    wifiInit();
    quaternionInit(&fd.attitude);
    pid_rate_roll = eeprom_data.pid_rate_roll;
    pid_rate_pitch = eeprom_data.pid_rate_pitch;
    pid_rate_yaw = eeprom_data.pid_rate_yaw;
    pid_angle_roll = eeprom_data.pid_angle_roll;
    pid_angle_pitch = eeprom_data.pid_angle_pitch;
    Serial.println("[System] Ready!");
    last_loop_time = micros();
}

void loop() {
    unsigned long now = micros();
    if (now - last_loop_time < LOOP_PERIOD_US) return;
    float dt = (now - last_loop_time) / 1000000.0f;
    last_loop_time = now;
    loop_count++;
    server.handleClient();
    handleSerial();
    readSensors();
    sensorFusion();
    rcUpdate();
    flightModeUpdate();
    safetyUpdate();
    if (motors.armed && !fd.failsafe && !motors.test_mode && !crash_detected) {
        switch (fd.flight_mode) {
            case MODE_STABILIZE: stabilizeControl(); break;
            case MODE_ACRO:      acroControl();      break;
            case MODE_ALTHOLD:   altholdControl();    break;
            case MODE_RTL:       rtlControl();        break;
            default:             stabilizeControl();  break;
        }
    } else if (!motors.armed || fd.failsafe || crash_detected) {
        motorWriteAll(MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM);
        pidReset(&pid_rate_roll); pidReset(&pid_rate_pitch); pidReset(&pid_rate_yaw);
        pidReset(&pid_angle_roll); pidReset(&pid_angle_pitch);
    }
    ledUpdate();
    if (now - last_telemetry_time >= (1000000 / TELEMETRY_FREQ_HZ)) {
        last_telemetry_time = now;
        sendHeartbeat(); sendAttitude(); sendRawIMU();
        sendBattery(); sendRCChannels(); sendServoOutput();
        sendSysStatus(); sendGPSRaw();
    }
    binaryLogWrite();
    if (motors.armed && !home_set) { home_set = true; home_lat = 0; home_lon = 0; }
    static unsigned long crash_time = 0;
    if (crash_detected && crash_time == 0) crash_time = millis();
    if (crash_detected && millis() - crash_time > 1000) { crash_detected = false; crash_time = 0; }
}

void readSensors() {
    static uint8_t zero_count = 0;
    static unsigned long last_retry = 0;
    if (!mpu_found) {
        if (millis() - last_retry > 2000) {
            last_retry = millis();
            i2cBusRecover();
            if (mpu6050Init()) Serial.println("[MPU6050] Reinitialized");
        }
        return;
    }
    mpu6050ReadAccel(&fd.accel);
    mpu6050ReadGyro(&fd.gyro);
    float mag = sqrt(fd.accel.x * fd.accel.x + fd.accel.y * fd.accel.y + fd.accel.z * fd.accel.z);
    if (mag < 0.01f) { zero_count++; if (zero_count > 10) { zero_count = 0; mpu_found = false; return; } }
    else zero_count = 0;
    fd.mag.x = 0; fd.mag.y = 0; fd.mag.z = 1.0f;
    bmp280Read();
    fd.baro_alt = bmp_altitude;
    fd.baro_temp = bmp_temperature;
    batteryUpdate();
}

void sensorFusion() {
    static unsigned long last_fusion_time = 0;
    unsigned long now = micros();
    float dt = (now - last_fusion_time) / 1000000.0f;
    last_fusion_time = now;
    if (dt <= 0.0f || dt > 0.1f) dt = 1.0f / LOOP_FREQ_HZ;
    madgwickUpdate(&fd.attitude, &fd.accel, &fd.gyro, &fd.mag, dt);
    quaternionToEuler(&fd.attitude, &fd.roll, &fd.pitch, &fd.yaw);
    fd.roll_rate = fd.gyro.x;
    fd.pitch_rate = fd.gyro.y;
    fd.yaw_rate = fd.gyro.z;
}
