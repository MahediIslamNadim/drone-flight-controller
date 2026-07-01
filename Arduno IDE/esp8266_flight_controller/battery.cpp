#include "battery.h"
#include "config.h"
#include "globals.h"
#include <Arduino.h>

void batteryUpdate() {
    static uint32_t bat_sum = 0;
    static uint8_t bat_count = 0;
    bat_sum += analogRead(PIN_BATTERY);
    bat_count++;
    if (bat_count >= 16) {
        float avg_adc = (float)bat_sum / (float)bat_count;
        fd.battery_voltage = (avg_adc / 1023.0f) * 3.3f * 4.0f;
        fd.battery_percent = (uint8_t)map(constrain((long)(fd.battery_voltage * 100), (long)(BATTERY_VOLTAGE_MIN * 100), (long)(BATTERY_VOLTAGE_MAX * 100)), (long)(BATTERY_VOLTAGE_MIN * 100), (long)(BATTERY_VOLTAGE_MAX * 100), 0, 100);
        bat_sum = 0; bat_count = 0;
    }
}
