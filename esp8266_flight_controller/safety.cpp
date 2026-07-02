#include "safety.h"
#include "config.h"
#include "globals.h"
#include "motors.h"
#include "pid.h"
#include <Arduino.h>
#include <math.h>

void safetyUpdate() {
    uint16_t throttle = rc.channels[2];
    uint16_t yaw = rc.channels[3];
    if (!motors.armed) {
        if (throttle < ARM_THROTTLE_MAX && yaw > ARM_YAW_RIGHT) {
            if (arm_start_time == 0) {
                arm_start_time = millis();
            } else if (millis() - arm_start_time > ARM_TIME_MS) {
                motors.armed = true; fd.armed = true; arm_start_time = 0;
                pidReset(&pid_rate_roll); pidReset(&pid_rate_pitch); pidReset(&pid_rate_yaw);
                pidReset(&pid_angle_roll); pidReset(&pid_angle_pitch);
            }
        } else { arm_start_time = 0; }
    } else {
        if (throttle < ARM_THROTTLE_MAX && yaw < ARM_YAW_LEFT) {
            if (disarm_start_time == 0) {
                disarm_start_time = millis();
            } else if (millis() - disarm_start_time > DISARM_TIME_MS) {
                motors.armed = false; fd.armed = false; disarm_start_time = 0;
            }
        } else { disarm_start_time = 0; }
    }

    bool bat_warning = (fd.battery_voltage < eeprom_data.bat_voltage_min && fd.battery_voltage > 1.0f);
    bool alt_warning = (eeprom_data.max_altitude > 0.0f && fd.baro_alt > eeprom_data.max_altitude);
    bool rc_lost = !rc.valid;
    bool geofence_hit = false;

    if (eeprom_data.geofence_radius > 0.0f && home_set) {
        float dx = fd.baro_alt * 0.01f;
        float dy = fd.baro_alt * 0.01f;
        float dist = sqrt(dx * dx + dy * dy);
        if (dist > eeprom_data.geofence_radius) geofence_hit = true;
    }

    if (bat_warning || alt_warning || rc_lost || geofence_hit) {
        if (!fd.failsafe) {
            fd.failsafe = true;
            switch (eeprom_data.failsafe_action) {
                case FAILSAFE_HOLD:
                    Serial.println("[FS] HOLD - maintaining altitude");
                    break;
                case FAILSAFE_LAND:
                    Serial.println("[FS] LAND - controlled descent");
                    break;
                case FAILSAFE_RTL:
                    Serial.println("[FS] RTL - returning home");
                    fd.flight_mode = MODE_RTL;
                    break;
                default:
                    Serial.println("[FS] NONE - failsafe flag only");
                    break;
            }
        }
    } else {
        if (fd.failsafe) {
            fd.failsafe = false;
            Serial.println("[FS] Cleared");
        }
    }

    float total_accel = sqrt(fd.accel.x * fd.accel.x + fd.accel.y * fd.accel.y + fd.accel.z * fd.accel.z);
    if (total_accel > CRASH_ACCEL_G && motors.armed) {
        crash_detected = true; motors.armed = false; fd.armed = false;
        motorWriteAll(MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM);
    }
}
