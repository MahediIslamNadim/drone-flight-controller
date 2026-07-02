#include "bmp280.h"
#include "i2c.h"
#include "config.h"
#include "globals.h"
#include <math.h>

static uint16_t bmp280_dig_T1;
static int16_t  bmp280_dig_T2, bmp280_dig_T3;
static uint16_t bmp280_dig_P1;
static int16_t  bmp280_dig_P2, bmp280_dig_P3, bmp280_dig_P4, bmp280_dig_P5;
static int16_t  bmp280_dig_P6, bmp280_dig_P7, bmp280_dig_P8, bmp280_dig_P9;
static int32_t  bmp280_t_fine;

static uint32_t bmp280_compensate_T(int32_t adc_T) {
    int32_t var1, var2, T;
    var1 = ((((adc_T >> 3) - ((int32_t)bmp280_dig_T1 << 1))) * ((int32_t)bmp280_dig_T2)) >> 11;
    var2 = (((((adc_T >> 4) - ((int32_t)bmp280_dig_T1)) * ((adc_T >> 4) - ((int32_t)bmp280_dig_T1))) >> 12) * ((int32_t)bmp280_dig_T3)) >> 14;
    bmp280_t_fine = var1 + var2;
    T = (bmp280_t_fine * 5 + 128) >> 8;
    return T;
}

static uint32_t bmp280_compensate_P(int32_t adc_P) {
    int64_t var1, var2, p;
    var1 = ((int64_t)bmp280_t_fine) - 128000;
    var2 = var1 * var1 * (int64_t)bmp280_dig_P6;
    var2 = var2 + ((var1 * (int64_t)bmp280_dig_P5) << 17);
    var2 = var2 + (((int64_t)bmp280_dig_P4) << 35);
    var1 = ((var1 * var1 * (int64_t)bmp280_dig_P3) >> 8) + ((var1 * (int64_t)bmp280_dig_P2) << 12);
    var1 = (((((int64_t)1) << 47) + var1)) * ((int64_t)bmp280_dig_P1) >> 33;
    if (var1 == 0) return 0;
    p = 1048576 - adc_P;
    p = (((p << 31) - var2) * 3125) / var1;
    var1 = (((int64_t)bmp280_dig_P9) * (p >> 13) * (p >> 13)) >> 25;
    var2 = (((int64_t)bmp280_dig_P8) * p) >> 19;
    p = ((p + var1 + var2) >> 8) + (((int64_t)bmp280_dig_P7) << 4);
    return (uint32_t)p;
}

bool bmp280Init() {
    Wire.beginTransmission(BMP280_ADDR);
    if (Wire.endTransmission() != 0) {
        bmp_found = false;
        return false;
    }
    uint8_t id = i2cReadByte(BMP280_ADDR, 0xD0);
    if (id != 0x58 && id != 0x60) {
        bmp_found = false;
        return false;
    }
    uint8_t cal[26];
    i2cReadBytes(BMP280_ADDR, 0x88, 26, cal);
    bmp280_dig_T1 = (cal[1] << 8) | cal[0];
    bmp280_dig_T2 = (cal[3] << 8) | cal[2];
    bmp280_dig_T3 = (cal[5] << 8) | cal[4];
    bmp280_dig_P1 = (cal[7] << 8) | cal[6];
    bmp280_dig_P2 = (cal[9] << 8) | cal[8];
    bmp280_dig_P3 = (cal[11] << 8) | cal[10];
    bmp280_dig_P4 = (cal[13] << 8) | cal[12];
    bmp280_dig_P5 = (cal[15] << 8) | cal[14];
    bmp280_dig_P6 = (cal[17] << 8) | cal[16];
    bmp280_dig_P7 = (cal[19] << 8) | cal[18];
    bmp280_dig_P8 = (cal[21] << 8) | cal[20];
    bmp280_dig_P9 = (cal[23] << 8) | cal[22];
    i2cWriteByte(BMP280_ADDR, 0xF4, 0x27);
    i2cWriteByte(BMP280_ADDR, 0xF5, 0x90);
    bmp_found = true;
    return true;
}

void bmp280Read() {
    if (!bmp_found) return;
    uint8_t data[6];
    i2cReadBytes(BMP280_ADDR, 0xF7, 6, data);
    int32_t adc_T = ((int32_t)data[3] << 12) | ((int32_t)data[4] << 4) | ((int32_t)data[5] >> 4);
    int32_t adc_P = ((int32_t)data[0] << 12) | ((int32_t)data[1] << 4) | ((int32_t)data[2] >> 4);
    bmp280_compensate_T(adc_T);
    uint32_t raw_p = bmp280_compensate_P(adc_P);
    bmp_temperature = (float)bmp280_t_fine / 256.0f;
    bmp_pressure = (float)raw_p / 256.0f;
    bmp_altitude = 44330.0f * (1.0f - pow(bmp_pressure / bmp_sea_level_pressure, 0.1903f));
}
