#include "rc.h"
#include "config.h"
#include "globals.h"
#include <Arduino.h>

void IRAM_ATTR ppmISR() {
    unsigned long now = micros();
    unsigned long elapsed = now - ppm_last_pulse;
    ppm_last_pulse = now;
    if (elapsed > 3000) {
        if (ppm_channel_index > 0 && ppm_channel_index <= RC_CHANNELS) {
            for (uint8_t i = 0; i < ppm_channel_index && i < RC_CHANNELS; i++) {
                rc.raw[i] = ppm_buffer[i];
            }
            if (ppm_channel_index >= RC_CHANNELS) {
                ppm_frame_complete = true;
            }
        }
        ppm_channel_index = 0;
    } else if (elapsed > 500 && elapsed < 3000) {
        if (ppm_channel_index < RC_CHANNELS) {
            ppm_buffer[ppm_channel_index] = elapsed;
            ppm_channel_index++;
        }
    }
}

void rcInit() {
    pinMode(PIN_PPM, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(PIN_PPM), ppmISR, RISING);
    for (uint8_t i = 0; i < RC_CHANNELS; i++) {
        rc.channels[i] = 1500; rc.raw[i] = 1500;
        rc.rc_min[i] = 1000; rc.rc_max[i] = 2000; rc.rc_mid[i] = 1500;
        rc.expo[i] = 0.0f; rc.deadband[i] = 30.0f;
    }
    rc.valid = false; rc.last_update = 0;
    eeprom_data.failsafe_values[0] = 1500; eeprom_data.failsafe_values[1] = 1500;
    eeprom_data.failsafe_values[2] = 1000; eeprom_data.failsafe_values[3] = 1500;
    eeprom_data.failsafe_values[4] = 1000; eeprom_data.failsafe_values[5] = 1500;
    eeprom_data.failsafe_values[6] = 1500; eeprom_data.failsafe_values[7] = 1500;
    eeprom_data.mode_channel = 4;
}

float applyExpo(float input, float expo) {
    if (expo == 0.0f) return input;
    float abs_input = fabs(input);
    float sign = (input >= 0.0f) ? 1.0f : -1.0f;
    return sign * (abs_input * (1.0f - expo) + abs_input * abs_input * abs_input * expo);
}

float applyDeadband(float input, float deadband) {
    if (fabs(input) < deadband) return 0.0f;
    if (input > 0.0f) return (input - deadband) / (1.0f - deadband);
    return (input + deadband) / (1.0f - deadband);
}

void rcUpdate() {
    if (ppm_frame_complete) {
        ppm_frame_complete = false;
        rc.last_update = millis();
        rc.valid = true;
    }
    if (rc.valid && (millis() - rc.last_update > RC_TIMEOUT_MS)) {
        rc.valid = false;
        fd.failsafe = true;
        for (uint8_t i = 0; i < RC_CHANNELS; i++) {
            rc.channels[i] = eeprom_data.failsafe_values[i];
        }
    } else if (rc.valid) {
        fd.failsafe = false;
    }
    for (uint8_t i = 0; i < RC_CHANNELS; i++) {
        uint16_t raw = rc.raw[i];
        uint16_t min_val = eeprom_data.rc_min[i];
        uint16_t max_val = eeprom_data.rc_max[i];
        if (raw < min_val) raw = min_val;
        if (raw > max_val) raw = max_val;
        float normalized = (float)(raw - min_val) / (float)(max_val - min_val);
        float output = 1000.0f + normalized * 1000.0f;
        if (i == 0 || i == 1 || i == 3) {
            float centered = (output - 1500.0f) / 500.0f;
            centered = applyExpo(centered, eeprom_data.expo[i]);
            centered = applyDeadband(centered, 0.05f);
            output = 1500.0f + centered * 500.0f;
        }
        rc.channels[i] = (uint16_t)constrain(output, 1000.0f, 2000.0f);
    }
}