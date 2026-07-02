#include "mavlink_send.h"
#include "config.h"
#include "globals.h"
#include <Arduino.h>

void mavSendHeader(uint8_t msg_id, uint8_t length) {
    Serial.write(0xFE);
    Serial.write(length);
    Serial.write(0x00);
    Serial.write(0xFF);
    Serial.write(0xBE);
    Serial.write(msg_id);
}

uint8_t mavChecksum(uint8_t *buf, uint8_t len) {
    uint8_t sum = 0;
    for (uint8_t i = 0; i < len; i++) sum ^= buf[i];
    return sum;
}

void sendHeartbeat() {
    uint8_t buf[9];
    buf[0] = 0; buf[1] = 0; buf[2] = 0;
    buf[3] = 0; buf[4] = 0; buf[5] = 0; buf[6] = 0;
    buf[7] = motors.armed ? 4 : 0;
    buf[8] = 3;
    mavSendHeader(MAVLINK_MSG_ID_HEARTBEAT, 9);
    Serial.write(buf, 9);
    Serial.write(mavChecksum(buf, 9));
}

void sendAttitude() {
    uint8_t buf[28];
    uint32_t boot_ms = millis();
    memcpy(buf + 0, &boot_ms, 4);
    float roll = fd.roll, pitch = fd.pitch, yaw = fd.yaw;
    float rollspeed = fd.gyro.x, pitchspeed = fd.gyro.y, yawspeed = fd.gyro.z;
    memcpy(buf + 4, &roll, 4); memcpy(buf + 8, &pitch, 4); memcpy(buf + 12, &yaw, 4);
    memcpy(buf + 16, &rollspeed, 4); memcpy(buf + 20, &pitchspeed, 4); memcpy(buf + 24, &yawspeed, 4);
    mavSendHeader(MAVLINK_MSG_ID_ATTITUDE, 28);
    Serial.write(buf, 28);
    Serial.write(mavChecksum(buf, 28));
}

void sendRawIMU() {
    uint8_t buf[26];
    uint64_t usec = (uint64_t)micros();
    memcpy(buf + 0, &usec, 8);
    int16_t xacc = (int16_t)(fd.accel.x * 1000);
    int16_t yacc = (int16_t)(fd.accel.y * 1000);
    int16_t zacc = (int16_t)(fd.accel.z * 1000);
    int16_t xgyro = (int16_t)(fd.gyro.x * 1000);
    int16_t ygyro = (int16_t)(fd.gyro.y * 1000);
    int16_t zgyro = (int16_t)(fd.gyro.z * 1000);
    int16_t xmag = (int16_t)(fd.mag.x * 1000);
    int16_t ymag = (int16_t)(fd.mag.y * 1000);
    int16_t zmag = (int16_t)(fd.mag.z * 1000);
    memcpy(buf + 8, &xacc, 2); memcpy(buf + 10, &yacc, 2); memcpy(buf + 12, &zacc, 2);
    memcpy(buf + 14, &xgyro, 2); memcpy(buf + 16, &ygyro, 2); memcpy(buf + 18, &zgyro, 2);
    memcpy(buf + 20, &xmag, 2); memcpy(buf + 22, &ymag, 2); memcpy(buf + 24, &zmag, 2);
    mavSendHeader(MAVLINK_MSG_ID_RAW_IMU, 26);
    Serial.write(buf, 26);
    Serial.write(mavChecksum(buf, 26));
}

void sendBattery() {
    uint8_t buf[10];
    int16_t voltage = (int16_t)(fd.battery_voltage * 1000);
    int16_t current = (int16_t)(fd.battery_current * 100);
    buf[0] = 0; buf[1] = 0;
    memcpy(buf + 2, &voltage, 2); memcpy(buf + 4, &current, 2);
    buf[6] = fd.battery_percent; buf[7] = 0; buf[8] = 0; buf[9] = 0;
    mavSendHeader(MAVLINK_MSG_ID_BATTERY_STATUS, 10);
    Serial.write(buf, 10);
    Serial.write(mavChecksum(buf, 10));
}

void sendRCChannels() {
    uint8_t buf[21];
    uint32_t boot_ms = millis();
    memcpy(buf + 0, &boot_ms, 4);
    for (uint8_t i = 0; i < 8; i++) {
        uint16_t ch = rc.channels[i];
        memcpy(buf + 4 + i * 2, &ch, 2);
    }
    buf[20] = 0;
    mavSendHeader(MAVLINK_MSG_ID_RC_CHANNELS, 21);
    Serial.write(buf, 21);
    Serial.write(mavChecksum(buf, 21));
}

void sendServoOutput() {
    uint8_t buf[16];
    buf[0] = 0;
    uint16_t servo_out[8] = {motors.m1, motors.m2, motors.m3, motors.m4, 0, 0, 0, 0};
    for (uint8_t i = 0; i < 8; i++) {
        memcpy(buf + 1 + i * 2, &servo_out[i], 2);
    }
    mavSendHeader(MAVLINK_MSG_ID_SERVO_OUTPUT_RAW, 16);
    Serial.write(buf, 16);
    Serial.write(mavChecksum(buf, 16));
}

void sendSysStatus() {
    uint8_t buf[19];
    int16_t voltage = (int16_t)(fd.battery_voltage * 1000);
    int16_t current = (int16_t)(fd.battery_current * 100);
    uint16_t load = (uint16_t)(loop_count / 100);
    memcpy(buf + 0, &voltage, 2);
    memcpy(buf + 2, &current, 2);
    buf[4] = fd.battery_percent;
    buf[5] = motors.armed ? 4 : 0;
    memset(buf + 6, 0, 10);
    memcpy(buf + 16, &load, 2);
    buf[18] = fd.failsafe ? 1 : 0;
    mavSendHeader(MAVLINK_MSG_ID_SYS_STATUS, 19);
    Serial.write(buf, 19);
    Serial.write(mavChecksum(buf, 19));
}

void sendGPSRaw() {
    uint8_t buf[28];
    uint64_t usec = (uint64_t)micros();
    memcpy(buf + 0, &usec, 8);
    int32_t lat = home_set ? (int32_t)(home_lat * 1e7) : 0;
    int32_t lon = home_set ? (int32_t)(home_lon * 1e7) : 0;
    int32_t alt = (int32_t)(fd.baro_alt * 1000);
    memcpy(buf + 8, &lat, 4); memcpy(buf + 12, &lon, 4); memcpy(buf + 16, &alt, 4);
    memset(buf + 20, 0, 8);
    mavSendHeader(MAVLINK_MSG_ID_GPS_RAW_INT, 28);
    Serial.write(buf, 28);
    Serial.write(mavChecksum(buf, 28));
}
