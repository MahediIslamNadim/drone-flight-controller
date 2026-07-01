#ifndef PID_H
#define PID_H
#include "types.h"

void pidInit(PIDController *pid, float kp, float ki, float kd, float i_limit, float d_filter, float output_limit);
float pidUpdate(PIDController *pid, float error, float dt);
void pidReset(PIDController *pid);

#endif