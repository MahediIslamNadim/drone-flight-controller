#ifndef MOTORS_H
#define MOTORS_H
#include "config.h"

void motorInit();
void motorWriteAll(uint16_t m1, uint16_t m2, uint16_t m3, uint16_t m4);
void motorMix(float throttle, float roll, float pitch, float yaw);
uint16_t pwmToAnalog(uint16_t pwm);

#endif