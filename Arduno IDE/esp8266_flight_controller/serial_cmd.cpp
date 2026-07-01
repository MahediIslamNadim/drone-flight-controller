#include "serial_cmd.h"
#include "config.h"
#include "globals.h"
#include "mpu6050.h"
#include "motors.h"
#include "pid.h"
#include "rc.h"
#include "eeprom_params.h"
#include "battery.h"
#include <Arduino.h>
#include <Wire.h>

static unsigned long motor_test_start = 0;
#define MOTOR_TEST_TIMEOUT_MS 5000

static void handleParamSet(char* args) {
    char name[32];
    float val;
    if (sscanf(args, "%s %f", name, &val) != 2) {
        Serial.println("Usage: PARAM_SET NAME VALUE");
        return;
    }
    char upper[32];
    uint8_t len = strlen(name);
    for (uint8_t i = 0; i < len; i++) upper[i] = toupper(name[i]);
    upper[len] = 0;

    if (strcmp(upper, "RATE_ROLL_P") == 0) { pid_rate_roll.kp = val; }
    else if (strcmp(upper, "RATE_ROLL_I") == 0) { pid_rate_roll.ki = val; }
    else if (strcmp(upper, "RATE_ROLL_D") == 0) { pid_rate_roll.kd = val; }
    else if (strcmp(upper, "RATE_PITCH_P") == 0) { pid_rate_pitch.kp = val; }
    else if (strcmp(upper, "RATE_PITCH_I") == 0) { pid_rate_pitch.ki = val; }
    else if (strcmp(upper, "RATE_PITCH_D") == 0) { pid_rate_pitch.kd = val; }
    else if (strcmp(upper, "RATE_YAW_P") == 0) { pid_rate_yaw.kp = val; }
    else if (strcmp(upper, "RATE_YAW_I") == 0) { pid_rate_yaw.ki = val; }
    else if (strcmp(upper, "RATE_YAW_D") == 0) { pid_rate_yaw.kd = val; }
    else if (strcmp(upper, "ANGLE_ROLL_P") == 0) { pid_angle_roll.kp = val; }
    else if (strcmp(upper, "ANGLE_ROLL_I") == 0) { pid_angle_roll.ki = val; }
    else if (strcmp(upper, "ANGLE_ROLL_D") == 0) { pid_angle_roll.kd = val; }
    else if (strcmp(upper, "ANGLE_PITCH_P") == 0) { pid_angle_pitch.kp = val; }
    else if (strcmp(upper, "ANGLE_PITCH_I") == 0) { pid_angle_pitch.ki = val; }
    else if (strcmp(upper, "ANGLE_PITCH_D") == 0) { pid_angle_pitch.kd = val; }
    else if (strcmp(upper, "MAX_ALTITUDE") == 0) { eeprom_data.max_altitude = val; }
    else if (strcmp(upper, "MAX_DISTANCE") == 0) { eeprom_data.max_distance = val; }
    else if (strcmp(upper, "BAT_VOLT_MIN") == 0) { eeprom_data.bat_voltage_min = val; }
    else if (strcmp(upper, "THROTTLE_EXPO") == 0) { eeprom_data.throttle_expo = val; }
    else if (strcmp(upper, "MODE_CHANNEL") == 0) { eeprom_data.mode_channel = (uint8_t)val; }
    else if (strcmp(upper, "BATTERY_CAPACITY") == 0) { eeprom_data.battery_capacity_mah = (uint16_t)val; }
    else if (strcmp(upper, "FAILSAFE_ACTION") == 0) { eeprom_data.failsafe_action = (uint8_t)val; }
    else if (strcmp(upper, "GEOFENCE_RADIUS") == 0) { eeprom_data.geofence_radius = val; }
    else { Serial.printf("Unknown param: %s\n", name); return; }
    Serial.printf("OK: %s = %.4f\n", name, val);
}

static void handleParamGet(char* args) {
    char name[32] = {0};
    sscanf(args, "%31s", name);
    char upper[32];
    uint8_t len = strlen(name);
    for (uint8_t i = 0; i < len; i++) upper[i] = toupper(name[i]);
    upper[len] = 0;

    if (len == 0 || strcmp(upper, "ALL") == 0) {
        Serial.printf("RATE_ROLL_P %.4f\n", pid_rate_roll.kp);
        Serial.printf("RATE_ROLL_I %.4f\n", pid_rate_roll.ki);
        Serial.printf("RATE_ROLL_D %.4f\n", pid_rate_roll.kd);
        Serial.printf("RATE_PITCH_P %.4f\n", pid_rate_pitch.kp);
        Serial.printf("RATE_PITCH_I %.4f\n", pid_rate_pitch.ki);
        Serial.printf("RATE_PITCH_D %.4f\n", pid_rate_pitch.kd);
        Serial.printf("RATE_YAW_P %.4f\n", pid_rate_yaw.kp);
        Serial.printf("RATE_YAW_I %.4f\n", pid_rate_yaw.ki);
        Serial.printf("RATE_YAW_D %.4f\n", pid_rate_yaw.kd);
        Serial.printf("ANGLE_ROLL_P %.4f\n", pid_angle_roll.kp);
        Serial.printf("ANGLE_ROLL_I %.4f\n", pid_angle_roll.ki);
        Serial.printf("ANGLE_ROLL_D %.4f\n", pid_angle_roll.kd);
        Serial.printf("ANGLE_PITCH_P %.4f\n", pid_angle_pitch.kp);
        Serial.printf("ANGLE_PITCH_I %.4f\n", pid_angle_pitch.ki);
        Serial.printf("ANGLE_PITCH_D %.4f\n", pid_angle_pitch.kd);
        Serial.printf("MAX_ALTITUDE %.1f\n", eeprom_data.max_altitude);
        Serial.printf("MAX_DISTANCE %.1f\n", eeprom_data.max_distance);
        Serial.printf("BAT_VOLT_MIN %.2f\n", eeprom_data.bat_voltage_min);
        Serial.printf("THROTTLE_EXPO %.2f\n", eeprom_data.throttle_expo);
        Serial.printf("MODE_CHANNEL %d\n", eeprom_data.mode_channel);
        Serial.printf("BATTERY_CAPACITY %d\n", eeprom_data.battery_capacity_mah);
        Serial.printf("FAILSAFE_ACTION %d\n", eeprom_data.failsafe_action);
        Serial.printf("GEOFENCE_RADIUS %.1f\n", eeprom_data.geofence_radius);
        return;
    }

    float val = 0;
    bool found = true;
    if (strcmp(upper, "RATE_ROLL_P") == 0) val = pid_rate_roll.kp;
    else if (strcmp(upper, "RATE_ROLL_I") == 0) val = pid_rate_roll.ki;
    else if (strcmp(upper, "RATE_ROLL_D") == 0) val = pid_rate_roll.kd;
    else if (strcmp(upper, "RATE_PITCH_P") == 0) val = pid_rate_pitch.kp;
    else if (strcmp(upper, "RATE_PITCH_I") == 0) val = pid_rate_pitch.ki;
    else if (strcmp(upper, "RATE_PITCH_D") == 0) val = pid_rate_pitch.kd;
    else if (strcmp(upper, "RATE_YAW_P") == 0) val = pid_rate_yaw.kp;
    else if (strcmp(upper, "RATE_YAW_I") == 0) val = pid_rate_yaw.ki;
    else if (strcmp(upper, "RATE_YAW_D") == 0) val = pid_rate_yaw.kd;
    else if (strcmp(upper, "ANGLE_ROLL_P") == 0) val = pid_angle_roll.kp;
    else if (strcmp(upper, "ANGLE_ROLL_I") == 0) val = pid_angle_roll.ki;
    else if (strcmp(upper, "ANGLE_ROLL_D") == 0) val = pid_angle_roll.kd;
    else if (strcmp(upper, "ANGLE_PITCH_P") == 0) val = pid_angle_pitch.kp;
    else if (strcmp(upper, "ANGLE_PITCH_I") == 0) val = pid_angle_pitch.ki;
    else if (strcmp(upper, "ANGLE_PITCH_D") == 0) val = pid_angle_pitch.kd;
    else if (strcmp(upper, "MAX_ALTITUDE") == 0) val = eeprom_data.max_altitude;
    else if (strcmp(upper, "MAX_DISTANCE") == 0) val = eeprom_data.max_distance;
    else if (strcmp(upper, "BAT_VOLT_MIN") == 0) val = eeprom_data.bat_voltage_min;
    else if (strcmp(upper, "THROTTLE_EXPO") == 0) val = eeprom_data.throttle_expo;
    else if (strcmp(upper, "MODE_CHANNEL") == 0) val = eeprom_data.mode_channel;
    else if (strcmp(upper, "BATTERY_CAPACITY") == 0) val = eeprom_data.battery_capacity_mah;
    else if (strcmp(upper, "FAILSAFE_ACTION") == 0) val = eeprom_data.failsafe_action;
    else if (strcmp(upper, "GEOFENCE_RADIUS") == 0) val = eeprom_data.geofence_radius;
    else { Serial.printf("Unknown param: %s\n", name); found = false; }

    if (found) Serial.printf("%s = %.4f\n", name, val);
}

void handleSerialCommand(char* cmd) {
    char upper[128];
    uint8_t len = strlen(cmd);
    for (uint8_t i = 0; i < len; i++) upper[i] = toupper(cmd[i]);
    upper[len] = 0;
    if (strncmp(upper, "HELP", 4) == 0) {
        Serial.println("=== ESP8266 Flight Controller ===");
        Serial.println("Commands: HELP, STATUS, I2C_SCAN, RAW, CALIBRATE, ARM, DISARM");
        Serial.println("  MOTOR x x x x, SET_PID, GET_PID, RESET, LOG, SAVE, LOAD, LEARN, BETA");
        Serial.println("  PARAM_SET NAME VALUE, PARAM_GET [NAME|ALL], PARAM_SAVE, PARAM_LOAD, PARAM_RESET");
    }
    else if (strncmp(upper, "STATUS", 6) == 0) {
        Serial.printf("Armed: %s  Mode: %d  RC: %s  FS: %s\n", motors.armed ? "YES" : "NO", fd.flight_mode, rc.valid ? "YES" : "NO", fd.failsafe ? "YES" : "NO");
        Serial.printf("Batt: %.2fV (%d%%)  R/P/Y: %.1f/%.1f/%.1f\n", fd.battery_voltage, fd.battery_percent, fd.roll * RAD_TO_DEG, fd.pitch * RAD_TO_DEG, fd.yaw * RAD_TO_DEG);
        Serial.printf("MPU: %s  BMP: %s  FS_Act: %d\n", mpu_found ? "OK" : "NO", bmp_found ? "OK" : "NO", eeprom_data.failsafe_action);
    }
    else if (strncmp(upper, "I2C_SCAN", 8) == 0) {
        Serial.println("=== I2C Scan ===");
        for (uint8_t addr = 1; addr < 127; addr++) {
            Wire.beginTransmission(addr);
            if (Wire.endTransmission() == 0) Serial.printf("  Found 0x%02X\n", addr);
        }
    }
    else if (strncmp(upper, "RAW", 3) == 0) {
        Serial.printf("Accel: %.4f %.4f %.4f\n", fd.accel.x, fd.accel.y, fd.accel.z);
        Serial.printf("Gyro: %.6f %.6f %.6f\n", fd.gyro.x, fd.gyro.y, fd.gyro.z);
        Serial.printf("Baro: %.2f hPa, %.2fC, %.2f m\n", bmp_pressure, bmp_temperature, bmp_altitude);
    }
    else if (strncmp(upper, "CALIBRATE", 9) == 0) {
        Serial.println("Calibrating...");
        calibration_mode = true; cal_sample_count = 0;
        accel_cal_sum[0] = accel_cal_sum[1] = accel_cal_sum[2] = 0;
        gyro_cal_sum[0] = gyro_cal_sum[1] = gyro_cal_sum[2] = 0;
        for (uint32_t i = 0; i < 1000; i++) {
            Vector3f a, g;
            mpu6050ReadAccel(&a); mpu6050ReadGyro(&g);
            accel_cal_sum[0] += a.x; accel_cal_sum[1] += a.y; accel_cal_sum[2] += a.z;
            gyro_cal_sum[0] += g.x + eeprom_data.gyro_offset.x;
            gyro_cal_sum[1] += g.y + eeprom_data.gyro_offset.y;
            gyro_cal_sum[2] += g.z + eeprom_data.gyro_offset.z;
            cal_sample_count++; delay(2);
        }
        eeprom_data.accel_offset.x = -(accel_cal_sum[0] / cal_sample_count);
        eeprom_data.accel_offset.y = -(accel_cal_sum[1] / cal_sample_count);
        eeprom_data.accel_offset.z = -(accel_cal_sum[2] / cal_sample_count - 1.0f);
        eeprom_data.accel_scale = {1, 1, 1};
        eeprom_data.gyro_offset.x = gyro_cal_sum[0] / cal_sample_count;
        eeprom_data.gyro_offset.y = gyro_cal_sum[1] / cal_sample_count;
        eeprom_data.gyro_offset.z = gyro_cal_sum[2] / cal_sample_count;
        Serial.printf("Done. Accel: %.4f %.4f %.4f  Gyro: %.6f %.6f %.6f\n",
            eeprom_data.accel_offset.x, eeprom_data.accel_offset.y, eeprom_data.accel_offset.z,
            eeprom_data.gyro_offset.x, eeprom_data.gyro_offset.y, eeprom_data.gyro_offset.z);
        calibration_mode = false;
    }
    else if (strncmp(upper, "ARM", 3) == 0) {
        if (rc.channels[2] < ARM_THROTTLE_MAX) { motors.armed = true; fd.armed = true; Serial.println("ARMED"); }
        else Serial.println("Cannot arm: throttle not low");
    }
    else if (strncmp(upper, "DISARM", 6) == 0) {
        motors.armed = false; fd.armed = false; motors.test_mode = false;
        motorWriteAll(MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM);
        Serial.println("DISARMED");
    }
    else if (strncmp(upper, "MOTOR", 5) == 0) {
        int m1, m2, m3, m4;
        if (sscanf(cmd + 6, "%d %d %d %d", &m1, &m2, &m3, &m4) == 4) {
            if (rc.channels[2] > ARM_THROTTLE_MAX) {
                Serial.println("Safety: throttle must be low for motor test");
                return;
            }
            motors.test_mode = true; motors.armed = true;
            motor_test_start = millis();
            motors.test_values[0] = constrain(m1, 1000, 2000);
            motors.test_values[1] = constrain(m2, 1000, 2000);
            motors.test_values[2] = constrain(m3, 1000, 2000);
            motors.test_values[3] = constrain(m4, 1000, 2000);
            motorWriteAll(motors.test_values[0], motors.test_values[1], motors.test_values[2], motors.test_values[3]);
            Serial.printf("Motors: %d %d %d %d (auto-off in %ds)\n", m1, m2, m3, m4, MOTOR_TEST_TIMEOUT_MS / 1000);
        } else {
            motors.test_mode = false; motor_test_start = 0;
            motorWriteAll(MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM);
            Serial.println("Motor test OFF");
        }
    }
    else if (strncmp(upper, "SET_PID", 7) == 0) {
        char target[32]; float kp, ki, kd;
        if (sscanf(cmd + 8, "%s %f %f %f", target, &kp, &ki, &kd) == 3) {
            PIDController *pid = NULL;
            if (strcmp(target, "rate_roll") == 0) pid = &pid_rate_roll;
            else if (strcmp(target, "rate_pitch") == 0) pid = &pid_rate_pitch;
            else if (strcmp(target, "rate_yaw") == 0) pid = &pid_rate_yaw;
            else if (strcmp(target, "angle_roll") == 0) pid = &pid_angle_roll;
            else if (strcmp(target, "angle_pitch") == 0) pid = &pid_angle_pitch;
            if (pid) { pid->kp = kp; pid->ki = ki; pid->kd = kd; Serial.printf("PID %s: %.3f %.3f %.3f\n", target, kp, ki, kd); }
        }
    }
    else if (strncmp(upper, "GET_PID", 7) == 0) {
        Serial.printf("Rate R: %.4f %.4f %.4f\n", pid_rate_roll.kp, pid_rate_roll.ki, pid_rate_roll.kd);
        Serial.printf("Rate P: %.4f %.4f %.4f\n", pid_rate_pitch.kp, pid_rate_pitch.ki, pid_rate_pitch.kd);
        Serial.printf("Rate Y: %.4f %.4f %.4f\n", pid_rate_yaw.kp, pid_rate_yaw.ki, pid_rate_yaw.kd);
        Serial.printf("Ang R:  %.4f %.4f %.4f\n", pid_angle_roll.kp, pid_angle_roll.ki, pid_angle_roll.kd);
        Serial.printf("Ang P:  %.4f %.4f %.4f\n", pid_angle_pitch.kp, pid_angle_pitch.ki, pid_angle_pitch.kd);
    }
    else if (strncmp(upper, "RESET", 5) == 0) { eepromLoadDefaults(); eepromSave(); Serial.println("Reset done"); }
    else if (strncmp(upper, "LOG", 3) == 0) { int e; if (sscanf(cmd + 4, "%d", &e) == 1) { log_enable = (e != 0); Serial.printf("Log %s\n", log_enable ? "ON" : "OFF"); } }
    else if (strncmp(upper, "SAVE", 4) == 0) {
        eeprom_data.pid_rate_roll = pid_rate_roll; eeprom_data.pid_rate_pitch = pid_rate_pitch;
        eeprom_data.pid_rate_yaw = pid_rate_yaw; eeprom_data.pid_angle_roll = pid_angle_roll;
        eeprom_data.pid_angle_pitch = pid_angle_pitch;
        eepromSave(); Serial.println("Saved");
    }
    else if (strncmp(upper, "LOAD", 4) == 0) { eepromLoad(); Serial.println("Loaded"); }
    else if (strncmp(upper, "LEARN", 5) == 0) {
        Serial.println("Learning RC (10s)...");
        uint16_t rc_min_l[RC_CHANNELS], rc_max_l[RC_CHANNELS];
        for (uint8_t i = 0; i < RC_CHANNELS; i++) { rc_min_l[i] = 65535; rc_max_l[i] = 0; }
        unsigned long start = millis();
        while (millis() - start < 10000) {
            rcUpdate();
            for (uint8_t i = 0; i < RC_CHANNELS; i++) {
                if (rc.raw[i] < rc_min_l[i]) rc_min_l[i] = rc.raw[i];
                if (rc.raw[i] > rc_max_l[i]) rc_max_l[i] = rc.raw[i];
            }
            delay(10);
        }
        for (uint8_t i = 0; i < RC_CHANNELS; i++) {
            eeprom_data.rc_min[i] = rc_min_l[i]; eeprom_data.rc_max[i] = rc_max_l[i];
            Serial.printf("CH%d: %d-%d\n", i + 1, rc_min_l[i], rc_max_l[i]);
        }
    }
    else if (strncmp(upper, "BETA", 4) == 0) {
        float b; if (sscanf(cmd + 5, "%f", &b) == 1) { madgwick_beta = b; Serial.printf("Beta: %.4f\n", b); }
    }
    else if (strncmp(upper, "PARAM_SET", 9) == 0) {
        handleParamSet(cmd + 10);
    }
    else if (strncmp(upper, "PARAM_GET", 9) == 0) {
        handleParamGet(cmd + 10);
    }
    else if (strncmp(upper, "PARAM_SAVE", 10) == 0) {
        eeprom_data.pid_rate_roll = pid_rate_roll;
        eeprom_data.pid_rate_pitch = pid_rate_pitch;
        eeprom_data.pid_rate_yaw = pid_rate_yaw;
        eeprom_data.pid_angle_roll = pid_angle_roll;
        eeprom_data.pid_angle_pitch = pid_angle_pitch;
        eepromSave();
        Serial.println("Params saved to EEPROM");
    }
    else if (strncmp(upper, "PARAM_LOAD", 10) == 0) {
        eepromLoad();
        Serial.println("Params loaded from EEPROM");
    }
    else if (strncmp(upper, "PARAM_RESET", 11) == 0) {
        eepromLoadDefaults();
        eepromSave();
        Serial.println("Params reset to defaults");
    }
    else if (strlen(cmd) > 0) {
        Serial.printf("Unknown: %s\n", cmd);
    }
}

void handleSerial() {
    while (Serial.available()) {
        char c = Serial.read();
        if (c == '\n' || c == '\r') {
            if (serial_cmd_len > 0) {
                serial_cmd_buf[serial_cmd_len] = 0;
                handleSerialCommand(serial_cmd_buf);
                serial_cmd_len = 0;
            }
        } else if (serial_cmd_len < sizeof(serial_cmd_buf) - 1) {
            serial_cmd_buf[serial_cmd_len++] = c;
        }
    }
    if (motors.test_mode && motor_test_start > 0 && millis() - motor_test_start > MOTOR_TEST_TIMEOUT_MS) {
        motors.test_mode = false; motor_test_start = 0;
        motorWriteAll(MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM);
        Serial.println("Motor test: auto-timeout");
    }
}
