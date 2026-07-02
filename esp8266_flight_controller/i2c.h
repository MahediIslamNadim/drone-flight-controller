#ifndef I2C_H
#define I2C_H
#include <Arduino.h>
#include "config.h"

void i2cWriteByte(uint8_t addr, uint8_t reg, uint8_t data);
uint8_t i2cReadByte(uint8_t addr, uint8_t reg);
void i2cReadBytes(uint8_t addr, uint8_t reg, uint8_t count, uint8_t *buf);
void i2cBusRecover();

#endif
