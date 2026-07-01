#ifndef MAVLINK_SEND_H
#define MAVLINK_SEND_H
#include <Arduino.h>

void mavSendHeader(uint8_t msg_id, uint8_t length);
uint8_t mavChecksum(uint8_t *buf, uint8_t len);
void sendHeartbeat();
void sendAttitude();
void sendRawIMU();
void sendBattery();
void sendRCChannels();
void sendServoOutput();
void sendSysStatus();
void sendGPSRaw();

#endif
