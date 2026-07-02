#ifndef MPU6050_H
#define MPU6050_H
#include "types.h"

bool mpu6050Init();
void mpu6050ReadAccel(Vector3f *accel);
void mpu6050ReadGyro(Vector3f *gyro);

#endif
