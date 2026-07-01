#include "i2c.h"
#include <Wire.h>

void i2cWriteByte(uint8_t addr, uint8_t reg, uint8_t data) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    Wire.write(data);
    Wire.endTransmission();
}

uint8_t i2cReadByte(uint8_t addr, uint8_t reg) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    Wire.endTransmission(false);
    Wire.requestFrom(addr, (uint8_t)1);
    return Wire.read();
}

void i2cReadBytes(uint8_t addr, uint8_t reg, uint8_t count, uint8_t *buf) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    Wire.endTransmission(false);
    Wire.requestFrom(addr, count);
    for (uint8_t i = 0; i < count && Wire.available(); i++) {
        buf[i] = Wire.read();
    }
}

void i2cBusRecover() {
    pinMode(PIN_SDA, INPUT_PULLUP);
    pinMode(PIN_SCL, INPUT_PULLUP);
    for (int i = 0; i < 9; i++) {
        pinMode(PIN_SCL, OUTPUT);
        digitalWrite(PIN_SCL, LOW);
        delayMicroseconds(5);
        pinMode(PIN_SCL, INPUT_PULLUP);
        delayMicroseconds(5);
    }
    pinMode(PIN_SDA, OUTPUT);
    digitalWrite(PIN_SDA, LOW);
    delayMicroseconds(5);
    digitalWrite(PIN_SDA, HIGH);
    delayMicroseconds(5);
    pinMode(PIN_SDA, INPUT_PULLUP);
    Wire.begin(PIN_SDA, PIN_SCL);
    Wire.setClock(400000);
}
