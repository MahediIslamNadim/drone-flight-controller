#ifndef RC_H
#define RC_H
#include "config.h"

void rcInit();
void rcUpdate();
float applyExpo(float input, float expo);
float applyDeadband(float input, float deadband);

#endif