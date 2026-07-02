#ifndef MADGWICK_H
#define MADGWICK_H
#include "types.h"

void quaternionInit(Quaternion *q);
void quaternionNormalize(Quaternion *q);
void quaternionToEuler(Quaternion *q, float *roll, float *pitch, float *yaw);
void madgwickUpdate(Quaternion *q, Vector3f *accel, Vector3f *gyro, Vector3f *mag, float dt);
float invSqrt(float x);

#endif
