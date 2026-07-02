#include "pid.h"

void pidInit(PIDController *pid, float kp, float ki, float kd, float i_limit, float d_filter, float output_limit) {
    pid->kp = kp; pid->ki = ki; pid->kd = kd;
    pid->i_limit = i_limit; pid->d_filter = d_filter; pid->output_limit = output_limit;
    pid->integrator = 0.0f; pid->prev_error = 0.0f; pid->d_filtered = 0.0f; pid->output = 0.0f;
}

float pidUpdate(PIDController *pid, float error, float dt) {
    if (dt <= 0.0f) return pid->output;
    float p_term = pid->kp * error;
    pid->integrator += error * dt;
    if (pid->integrator > pid->i_limit) pid->integrator = pid->i_limit;
    if (pid->integrator < -pid->i_limit) pid->integrator = -pid->i_limit;
    float i_term = pid->ki * pid->integrator;
    float d_raw = (error - pid->prev_error) / dt;
    pid->d_filtered = pid->d_filtered * pid->d_filter + d_raw * (1.0f - pid->d_filter);
    float d_term = pid->kd * pid->d_filtered;
    pid->prev_error = error;
    pid->output = p_term + i_term + d_term;
    if (pid->output > pid->output_limit) pid->output = pid->output_limit;
    if (pid->output < -pid->output_limit) pid->output = -pid->output_limit;
    return pid->output;
}

void pidReset(PIDController *pid) {
    pid->integrator = 0.0f; pid->prev_error = 0.0f; pid->d_filtered = 0.0f; pid->output = 0.0f;
}