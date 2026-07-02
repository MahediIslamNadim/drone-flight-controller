#ifndef TYPES_H
#define TYPES_H
#include <stdint.h>
#include "config.h"

struct Quaternion { float w, x, y, z; };
struct Vector3f { float x, y, z; };

struct PIDController {
    float kp, ki, kd;
    float i_limit;
    float d_filter;
    float output_limit;
    float integrator;
    float prev_error;
    float d_filtered;
    float output;
};

struct RCData {
    uint16_t channels[RC_CHANNELS];
    uint16_t raw[RC_CHANNELS];
    uint16_t rc_min[RC_CHANNELS];
    uint16_t rc_max[RC_CHANNELS];
    uint16_t rc_mid[RC_CHANNELS];
    float expo[RC_CHANNELS];
    float deadband[RC_CHANNELS];
    bool valid;
    unsigned long last_update;
};

struct MotorOutput {
    uint16_t m1, m2, m3, m4;
    bool armed;
    bool test_mode;
    uint16_t test_values[4];
};

struct FlightData {
    Quaternion attitude;
    Vector3f accel;
    Vector3f gyro;
    Vector3f mag;
    float roll, pitch, yaw;
    float roll_rate, pitch_rate, yaw_rate;
    float baro_alt;
    float baro_temp;
    float battery_voltage;
    float battery_current;
    uint8_t battery_percent;
    bool gps_valid;
    int32_t gps_lat, gps_lon, gps_alt;
    uint8_t flight_mode;
    bool armed;
    bool failsafe;
    unsigned long timestamp;
};

struct EEPROMData {
    uint16_t magic;
    PIDController pid_rate_roll;
    PIDController pid_rate_pitch;
    PIDController pid_rate_yaw;
    PIDController pid_angle_roll;
    PIDController pid_angle_pitch;
    Vector3f accel_offset;
    Vector3f accel_scale;
    Vector3f gyro_offset;
    Vector3f mag_offset;
    Vector3f mag_scale;
    uint16_t rc_min[RC_CHANNELS];
    uint16_t rc_max[RC_CHANNELS];
    uint16_t rc_mid[RC_CHANNELS];
    float expo[RC_CHANNELS];
    uint16_t failsafe_values[RC_CHANNELS];
    float throttle_expo;
    uint8_t mode_channel;
    float max_altitude;
    float max_distance;
    float bat_voltage_min;
    uint16_t battery_capacity_mah;
    uint8_t failsafe_action;
    float geofence_radius;
};

#endif
