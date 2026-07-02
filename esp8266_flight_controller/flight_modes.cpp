#include "flight_modes.h"
#include "config.h"
#include "globals.h"
#include "pid.h"
#include "motors.h"
#include <Arduino.h>

void flightModeUpdate() {
    uint16_t mode_pwm = rc.channels[eeprom_data.mode_channel];
    if (mode_pwm < 1250) fd.flight_mode = MODE_STABILIZE;
    else if (mode_pwm < 1750) fd.flight_mode = MODE_ACRO;
    else if (mode_pwm < 2000) fd.flight_mode = MODE_ALTHOLD;
    else fd.flight_mode = MODE_RTL;
}

void stabilizeControl() {
    float roll_target = map((float)rc.channels[0], 1000.0f, 2000.0f, -30.0f, 30.0f);
    float pitch_target = map((float)rc.channels[1], 1000.0f, 2000.0f, -30.0f, 30.0f);
    float throttle = (float)rc.channels[2];
    float roll_angle_error = roll_target - fd.roll * RAD_TO_DEG;
    float pitch_angle_error = pitch_target - fd.pitch * RAD_TO_DEG;
    float roll_rate_target = pidUpdate(&pid_angle_roll, roll_angle_error, 1.0f / LOOP_FREQ_HZ);
    float pitch_rate_target = pidUpdate(&pid_angle_pitch, pitch_angle_error, 1.0f / LOOP_FREQ_HZ);
    float roll_rate_error = roll_rate_target - fd.gyro.x * RAD_TO_DEG;
    float pitch_rate_error = pitch_rate_target - fd.gyro.y * RAD_TO_DEG;
    float yaw_rate_error = map((float)rc.channels[3], 1000.0f, 2000.0f, -200.0f, 200.0f) - fd.gyro.z * RAD_TO_DEG;
    float roll_output = pidUpdate(&pid_rate_roll, roll_rate_error, 1.0f / LOOP_FREQ_HZ);
    float pitch_output = pidUpdate(&pid_rate_pitch, pitch_rate_error, 1.0f / LOOP_FREQ_HZ);
    float yaw_output = pidUpdate(&pid_rate_yaw, yaw_rate_error, 1.0f / LOOP_FREQ_HZ);
    motorMix(throttle, roll_output, pitch_output, yaw_output);
}

void acroControl() {
    float throttle = (float)rc.channels[2];
    float roll_rate_target = map((float)rc.channels[0], 1000.0f, 2000.0f, -400.0f, 400.0f);
    float pitch_rate_target = map((float)rc.channels[1], 1000.0f, 2000.0f, -400.0f, 400.0f);
    float yaw_rate_target = map((float)rc.channels[3], 1000.0f, 2000.0f, -200.0f, 200.0f);
    float roll_rate_error = roll_rate_target - fd.gyro.x * RAD_TO_DEG;
    float pitch_rate_error = pitch_rate_target - fd.gyro.y * RAD_TO_DEG;
    float yaw_rate_error = yaw_rate_target - fd.gyro.z * RAD_TO_DEG;
    float roll_output = pidUpdate(&pid_rate_roll, roll_rate_error, 1.0f / LOOP_FREQ_HZ);
    float pitch_output = pidUpdate(&pid_rate_pitch, pitch_rate_error, 1.0f / LOOP_FREQ_HZ);
    float yaw_output = pidUpdate(&pid_rate_yaw, yaw_rate_error, 1.0f / LOOP_FREQ_HZ);
    motorMix(throttle, roll_output, pitch_output, yaw_output);
}

static float althold_target = 0.0f;
static bool althold_target_set = false;
static float alt_pid_integrator = 0.0f;
static float alt_pid_prev_error = 0.0f;

void altholdControl() {
    float current_alt = fd.baro_alt;

    if (rc.channels[2] > 1200) {
        althold_target = current_alt;
        althold_target_set = true;
        stabilizeControl();
        return;
    }

    if (!althold_target_set) {
        althold_target = current_alt;
        althold_target_set = true;
        alt_pid_integrator = 0;
        alt_pid_prev_error = 0;
    }

    float alt_error = althold_target - current_alt;
    alt_pid_integrator += alt_error * (1.0f / LOOP_FREQ_HZ);
    alt_pid_integrator = constrain(alt_pid_integrator, -500.0f, 500.0f);
    float alt_d = (alt_error - alt_pid_prev_error) * LOOP_FREQ_HZ;
    alt_pid_prev_error = alt_error;
    float throttle_output = 1500.0f + 2.0f * alt_error + 0.5f * alt_pid_integrator + 0.1f * alt_d;
    throttle_output = constrain(throttle_output, 1100.0f, 2000.0f);

    float roll_target = map((float)rc.channels[0], 1000.0f, 2000.0f, -30.0f, 30.0f);
    float pitch_target = map((float)rc.channels[1], 1000.0f, 2000.0f, -30.0f, 30.0f);
    float roll_angle_error = roll_target - fd.roll * RAD_TO_DEG;
    float pitch_angle_error = pitch_target - fd.pitch * RAD_TO_DEG;
    float roll_rate_target = pidUpdate(&pid_angle_roll, roll_angle_error, 1.0f / LOOP_FREQ_HZ);
    float pitch_rate_target = pidUpdate(&pid_angle_pitch, pitch_angle_error, 1.0f / LOOP_FREQ_HZ);
    float roll_rate_error = roll_rate_target - fd.gyro.x * RAD_TO_DEG;
    float pitch_rate_error = pitch_rate_target - fd.gyro.y * RAD_TO_DEG;
    float yaw_rate_error = map((float)rc.channels[3], 1000.0f, 2000.0f, -200.0f, 200.0f) - fd.gyro.z * RAD_TO_DEG;
    float roll_output = pidUpdate(&pid_rate_roll, roll_rate_error, 1.0f / LOOP_FREQ_HZ);
    float pitch_output = pidUpdate(&pid_rate_pitch, pitch_rate_error, 1.0f / LOOP_FREQ_HZ);
    float yaw_output = pidUpdate(&pid_rate_yaw, yaw_rate_error, 1.0f / LOOP_FREQ_HZ);
    motorMix(throttle_output, roll_output, pitch_output, yaw_output);
}

void rtlControl() {
    if (rc.channels[2] > 1200) {
        althold_target_set = false;
        stabilizeControl();
        return;
    }

    if (!althold_target_set) {
        althold_target = fd.baro_alt;
        althold_target_set = true;
        alt_pid_integrator = 0;
        alt_pid_prev_error = 0;
    }

    float alt_error = althold_target - fd.baro_alt;
    alt_pid_integrator += alt_error * (1.0f / LOOP_FREQ_HZ);
    alt_pid_integrator = constrain(alt_pid_integrator, -500.0f, 500.0f);
    float alt_d = (alt_error - alt_pid_prev_error) * LOOP_FREQ_HZ;
    alt_pid_prev_error = alt_error;
    float throttle_output = 1500.0f + 2.0f * alt_error + 0.5f * alt_pid_integrator + 0.1f * alt_d;
    throttle_output = constrain(throttle_output, 1100.0f, 1600.0f);

    float roll_output = pidUpdate(&pid_rate_roll, -fd.gyro.x * RAD_TO_DEG, 1.0f / LOOP_FREQ_HZ);
    float pitch_output = pidUpdate(&pid_rate_pitch, -fd.gyro.y * RAD_TO_DEG, 1.0f / LOOP_FREQ_HZ);
    float yaw_output = pidUpdate(&pid_rate_yaw, -fd.gyro.z * RAD_TO_DEG, 1.0f / LOOP_FREQ_HZ);
    motorMix(throttle_output, roll_output, pitch_output, yaw_output);
}
