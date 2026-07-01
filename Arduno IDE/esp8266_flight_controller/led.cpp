#include "led.h"
#include "config.h"
#include "globals.h"
#include <Arduino.h>

void ledUpdate() {
    unsigned long now = millis();
    uint16_t blink_interval = LED_FAST_BLINK_MS;
    if (!motors.armed && !rc.valid) {
        blink_interval = LED_FAST_BLINK_MS;
    } else if (motors.armed && !motors.test_mode) {
        if (motors.m1 > MOTOR_IDLEPWM || motors.m2 > MOTOR_IDLEPWM || motors.m3 > MOTOR_IDLEPWM || motors.m4 > MOTOR_IDLEPWM) {
            digitalWrite(PIN_LED, HIGH); return;
        }
        blink_interval = LED_SLOW_BLINK_MS;
    } else if (fd.failsafe) {
        static uint8_t failsafe_blink = 0;
        static unsigned long last_failsafe_blink = 0;
        if (now - last_failsafe_blink > 200) {
            last_failsafe_blink = now;
            failsafe_blink++;
            if (failsafe_blink >= 4) failsafe_blink = 0;
        }
        digitalWrite(PIN_LED, (failsafe_blink == 0 || failsafe_blink == 1) ? HIGH : LOW);
        return;
    } else {
        blink_interval = LED_FAST_BLINK_MS;
    }
    if (now - last_led_time > blink_interval) {
        last_led_time = now;
        led_on = !led_on;
        digitalWrite(PIN_LED, led_on ? HIGH : LOW);
    }
}
