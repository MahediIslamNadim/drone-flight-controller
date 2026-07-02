#include "motors.h"
#include "config.h"
#include "globals.h"
#include <Arduino.h>

void motorInit() {
    pinMode(PIN_MOTOR1, OUTPUT);
    pinMode(PIN_MOTOR2, OUTPUT);
    pinMode(PIN_MOTOR3, OUTPUT);
    pinMode(PIN_MOTOR4, OUTPUT);
    analogWriteFreq(400);
    analogWriteRange(1023);
    motors.m1 = MOTOR_MINPWM; motors.m2 = MOTOR_MINPWM;
    motors.m3 = MOTOR_MINPWM; motors.m4 = MOTOR_MINPWM;
    motors.armed = false; motors.test_mode = false;
    motorWriteAll(MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM, MOTOR_MINPWM);
}

uint16_t pwmToAnalog(uint16_t pwm) {
    return map(constrain(pwm, 1000, 2000), 1000, 2000, 0, 1023);
}

void motorWriteAll(uint16_t m1, uint16_t m2, uint16_t m3, uint16_t m4) {
    if (!motors.armed && !motors.test_mode) {
        m1 = m2 = m3 = m4 = MOTOR_MINPWM;
    }
    analogWrite(PIN_MOTOR1, pwmToAnalog(m1));
    analogWrite(PIN_MOTOR2, pwmToAnalog(m2));
    analogWrite(PIN_MOTOR3, pwmToAnalog(m3));
    analogWrite(PIN_MOTOR4, pwmToAnalog(m4));
    motors.m1 = m1; motors.m2 = m2; motors.m3 = m3; motors.m4 = m4;
}

void motorMix(float throttle, float roll, float pitch, float yaw) {
    if (motors.test_mode) {
        motorWriteAll(motors.test_values[0], motors.test_values[1], motors.test_values[2], motors.test_values[3]);
        return;
    }
    float t = throttle;
    if (eeprom_data.throttle_expo > 0.0f) {
        t = t * (1.0f - eeprom_data.throttle_expo) + t * t * t * eeprom_data.throttle_expo;
    }
    float m1 = t - roll + pitch - yaw;
    float m2 = t + roll + pitch + yaw;
    float m3 = t - roll - pitch + yaw;
    float m4 = t + roll - pitch - yaw;
    m1 = constrain(m1, (float)MOTOR_MINPWM, (float)MOTOR_MAXPWM);
    m2 = constrain(m2, (float)MOTOR_MINPWM, (float)MOTOR_MAXPWM);
    m3 = constrain(m3, (float)MOTOR_MINPWM, (float)MOTOR_MAXPWM);
    m4 = constrain(m4, (float)MOTOR_MINPWM, (float)MOTOR_MAXPWM);
    if (motors.armed && t < MOTOR_IDLEPWM) {
        m1 = m2 = m3 = m4 = MOTOR_IDLEPWM;
    }
    motorWriteAll((uint16_t)m1, (uint16_t)m2, (uint16_t)m3, (uint16_t)m4);
}