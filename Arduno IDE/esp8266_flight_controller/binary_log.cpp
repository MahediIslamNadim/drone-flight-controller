#include "binary_log.h"
#include "config.h"
#include "globals.h"
#include <Arduino.h>

void binaryLogWrite() {
    if (!log_enable) return;
    Serial.write(0xA3); Serial.write(0x95);
    uint32_t ts = millis();
    Serial.write((uint8_t*)&ts, 4);
    int16_t ax = (int16_t)(fd.accel.x * 1000);
    int16_t ay = (int16_t)(fd.accel.y * 1000);
    int16_t az = (int16_t)(fd.accel.z * 1000);
    int16_t gx = (int16_t)(fd.gyro.x * 1000);
    int16_t gy = (int16_t)(fd.gyro.y * 1000);
    int16_t gz = (int16_t)(fd.gyro.z * 1000);
    int16_t mx = (int16_t)(fd.mag.x * 1000);
    int16_t my = (int16_t)(fd.mag.y * 1000);
    int16_t mz = (int16_t)(fd.mag.z * 1000);
    Serial.write((uint8_t*)&ax, 2); Serial.write((uint8_t*)&ay, 2); Serial.write((uint8_t*)&az, 2);
    Serial.write((uint8_t*)&gx, 2); Serial.write((uint8_t*)&gy, 2); Serial.write((uint8_t*)&gz, 2);
    Serial.write((uint8_t*)&mx, 2); Serial.write((uint8_t*)&my, 2); Serial.write((uint8_t*)&mz, 2);
    float r = fd.roll, p = fd.pitch, y = fd.yaw;
    Serial.write((uint8_t*)&r, 4); Serial.write((uint8_t*)&p, 4); Serial.write((uint8_t*)&y, 4);
    for (uint8_t i = 0; i < 8; i++) { uint16_t ch = rc.channels[i]; Serial.write((uint8_t*)&ch, 2); }
    uint16_t m[4] = {motors.m1, motors.m2, motors.m3, motors.m4};
    for (uint8_t i = 0; i < 4; i++) Serial.write((uint8_t*)&m[i], 2);
    int16_t bv = (int16_t)(fd.battery_voltage * 100);
    int16_t bc = (int16_t)(fd.battery_current * 100);
    Serial.write((uint8_t*)&bv, 2); Serial.write((uint8_t*)&bc, 2);
    uint8_t checksum = 0xA3 ^ 0x95;
    uint8_t* ts_bytes = (uint8_t*)&ts;
    for (uint8_t i = 0; i < 4; i++) checksum ^= ts_bytes[i];
    Serial.write(checksum);
}
