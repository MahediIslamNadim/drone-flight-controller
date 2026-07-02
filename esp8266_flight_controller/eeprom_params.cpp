#include "eeprom_params.h"
#include "config.h"
#include "globals.h"
#include "pid.h"
#include <EEPROM.h>

void eepromLoadDefaults() {
    eeprom_data.magic = EEPROM_MAGIC_VALUE;
    pidInit(&eeprom_data.pid_rate_roll, 1.0f, 0.0f, 0.01f, 50.0f, 0.8f, 500.0f);
    pidInit(&eeprom_data.pid_rate_pitch, 1.0f, 0.0f, 0.01f, 50.0f, 0.8f, 500.0f);
    pidInit(&eeprom_data.pid_rate_yaw, 1.5f, 0.0f, 0.0f, 50.0f, 0.8f, 500.0f);
    pidInit(&eeprom_data.pid_angle_roll, 2.0f, 0.0f, 0.0f, 20.0f, 0.8f, 200.0f);
    pidInit(&eeprom_data.pid_angle_pitch, 2.0f, 0.0f, 0.0f, 20.0f, 0.8f, 200.0f);
    eeprom_data.accel_offset = {0, 0, 0};
    eeprom_data.accel_scale = {1, 1, 1};
    eeprom_data.gyro_offset = {0, 0, 0};
    eeprom_data.mag_offset = {0, 0, 0};
    eeprom_data.mag_scale = {1, 1, 1};
    for (uint8_t i = 0; i < RC_CHANNELS; i++) {
        eeprom_data.rc_min[i] = 1000; eeprom_data.rc_max[i] = 2000; eeprom_data.rc_mid[i] = 1500;
        eeprom_data.expo[i] = 0.0f;
    }
    eeprom_data.max_altitude = 50.0f; eeprom_data.max_distance = 0.0f;
    eeprom_data.bat_voltage_min = 3.3f; eeprom_data.throttle_expo = 0.3f; eeprom_data.mode_channel = 4;
    eeprom_data.battery_capacity_mah = 2200;
    eeprom_data.failsafe_action = 1;
    eeprom_data.geofence_radius = 100.0f;
}

void eepromSave() {
    EEPROM.put(EEPROM_DATA_ADDR, eeprom_data);
    EEPROM.commit();
}

void eepromLoad() {
    EEPROM.get(EEPROM_DATA_ADDR, eeprom_data);
    if (eeprom_data.magic != EEPROM_MAGIC_VALUE) {
        Serial.println("[EEPROM] Invalid magic, loading defaults");
        eepromLoadDefaults();
        eepromSave();
    } else {
        Serial.println("[EEPROM] Loaded valid data");
    }
    pid_rate_roll = eeprom_data.pid_rate_roll;
    pid_rate_pitch = eeprom_data.pid_rate_pitch;
    pid_rate_yaw = eeprom_data.pid_rate_yaw;
    pid_angle_roll = eeprom_data.pid_angle_roll;
    pid_angle_pitch = eeprom_data.pid_angle_pitch;
}
