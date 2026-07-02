#include "mpu6050.h"
#include "i2c.h"
#include "config.h"
#include "globals.h"
#include <Wire.h>

bool mpu6050Init() {
    Wire.beginTransmission(MPU6050_ADDR_LOW);
    if (Wire.endTransmission() == 0) {
        mpu_addr = MPU6050_ADDR_LOW;
        mpu_found = true;
    } else {
        Wire.beginTransmission(MPU6050_ADDR_HIGH);
        if (Wire.endTransmission() == 0) {
            mpu_addr = MPU6050_ADDR_HIGH;
            mpu_found = true;
        } else {
            mpu_found = false;
            return false;
        }
    }
    i2cWriteByte(mpu_addr, 0x6B, 0x80);
    delay(100);
    i2cWriteByte(mpu_addr, 0x6B, 0x01);
    delay(10);
    i2cWriteByte(mpu_addr, 0x1A, 0x03);
    i2cWriteByte(mpu_addr, 0x1B, 0x08);
    i2cWriteByte(mpu_addr, 0x1C, 0x08);
    i2cWriteByte(mpu_addr, 0x37, 0x02);
    return true;
}

void mpu6050ReadAccel(Vector3f *accel) {
    uint8_t buf[6];
    i2cReadBytes(mpu_addr, 0x3B, 6, buf);
    int16_t raw_x = (buf[0] << 8) | buf[1];
    int16_t raw_y = (buf[2] << 8) | buf[3];
    int16_t raw_z = (buf[4] << 8) | buf[5];
    accel->x = (float)raw_x / 8192.0f;
    accel->y = (float)raw_y / 8192.0f;
    accel->z = (float)raw_z / 8192.0f;
    accel->x = accel->x * eeprom_data.accel_scale.x + eeprom_data.accel_offset.x;
    accel->y = accel->y * eeprom_data.accel_scale.y + eeprom_data.accel_offset.y;
    accel->z = accel->z * eeprom_data.accel_scale.z + eeprom_data.accel_offset.z;
}

void mpu6050ReadGyro(Vector3f *gyro) {
    uint8_t buf[6];
    i2cReadBytes(mpu_addr, 0x43, 6, buf);
    int16_t raw_x = (buf[0] << 8) | buf[1];
    int16_t raw_y = (buf[2] << 8) | buf[3];
    int16_t raw_z = (buf[4] << 8) | buf[5];
    gyro->x = (float)raw_x / 65.5f * DEG_TO_RAD;
    gyro->y = (float)raw_y / 65.5f * DEG_TO_RAD;
    gyro->z = (float)raw_z / 65.5f * DEG_TO_RAD;
    gyro->x -= eeprom_data.gyro_offset.x;
    gyro->y -= eeprom_data.gyro_offset.y;
    gyro->z -= eeprom_data.gyro_offset.z;
}
