#include "wifi_ap.h"
#include "config.h"
#include "globals.h"
#include "serial_cmd.h"
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

const char WEB_PAGE[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<title>ESP8266 FC</title>
<style>
body{font-family:monospace;background:#1a1a2e;color:#0f0;margin:20px}
h1{color:#0ff}
.card{background:#16213e;border:1px solid #0f3;padding:10px;margin:5px;display:inline-block;min-width:200px}
.val{font-size:1.2em;color:#0ff}
button{background:#0f3;color:#000;border:none;padding:5px 15px;cursor:pointer;margin:2px}
button:hover{background:#0ff}
#log{background:#000;padding:5px;max-height:200px;overflow-y:auto}
</style>
</head>
<body>
<h1>ESP8266 Flight Controller</h1>
<div class="card"><b>Armed:</b> <span id="armed" class="val">NO</span></div>
<div class="card"><b>Mode:</b> <span id="mode" class="val">0</span></div>
<div class="card"><b>Battery:</b> <span id="batt" class="val">0.0V</span></div>
<div class="card"><b>Roll:</b> <span id="roll" class="val">0</span>&deg;</div>
<div class="card"><b>Pitch:</b> <span id="pitch" class="val">0</span>&deg;</div>
<div class="card"><b>Yaw:</b> <span id="yaw" class="val">0</span>&deg;</div>
<h2>Commands</h2>
<button onclick="cmd('ARM')">ARM</button>
<button onclick="cmd('DISARM')">DISARM</button>
<button onclick="cmd('STATUS')">STATUS</button>
<button onclick="cmd('SAVE')">SAVE</button>
<h2>Log</h2>
<div id="log"></div>
<script>
function $(id){return document.getElementById(id)}
function cmd(c){fetch('/cmd?c='+c).then(r=>r.text()).then(t=>{addLog('CMD: '+c);addLog(t)})}
function addLog(t){var l=$('log');l.innerHTML+=t+'<br>';l.scrollTop=l.scrollHeight}
function update(){
fetch('/data').then(r=>r.json()).then(d=>{
$('armed').textContent=d.armed?'YES':'NO';
$('mode').textContent=['STABILIZE','ACRO','ALT_HOLD','RTL'][d.mode]||d.mode;
$('batt').textContent=d.voltage.toFixed(2)+'V';
$('roll').textContent=(d.roll*57.3).toFixed(1);
$('pitch').textContent=(d.pitch*57.3).toFixed(1);
$('yaw').textContent=(d.yaw*57.3).toFixed(1);
}).catch(e{})}
setInterval(update,200);
</script>
</body>
</html>
)rawliteral";

void handleRoot() { server.send_P(200, "text/html", WEB_PAGE); }

void handleData() {
    String json = "{";
    json += "\"armed\":" + String(fd.armed ? "true" : "false") + ",";
    json += "\"mode\":" + String(fd.flight_mode) + ",";
    json += "\"failsafe\":" + String(fd.failsafe ? "true" : "false") + ",";
    json += "\"voltage\":" + String(fd.battery_voltage, 2) + ",";
    json += "\"batt_pct\":" + String(fd.battery_percent) + ",";
    json += "\"roll\":" + String(fd.roll, 6) + ",";
    json += "\"pitch\":" + String(fd.pitch, 6) + ",";
    json += "\"yaw\":" + String(fd.yaw, 6) + ",";
    json += "\"ax\":" + String(fd.accel.x, 4) + ",";
    json += "\"ay\":" + String(fd.accel.y, 4) + ",";
    json += "\"az\":" + String(fd.accel.z, 4) + ",";
    json += "\"gx\":" + String(fd.gyro.x, 6) + ",";
    json += "\"gy\":" + String(fd.gyro.y, 6) + ",";
    json += "\"gz\":" + String(fd.gyro.z, 6) + ",";
    json += "\"alt\":" + String(fd.baro_alt, 2) + ",";
    json += "\"temp\":" + String(fd.baro_temp, 1) + ",";
    json += "\"m1\":" + String(motors.m1) + ",\"m2\":" + String(motors.m2);
    json += ",\"m3\":" + String(motors.m3) + ",\"m4\":" + String(motors.m4) + ",";
    json += "\"rc\":[";
    for (uint8_t i = 0; i < 8; i++) { json += String(rc.channels[i]); if (i < 7) json += ","; }
    json += "]}";
    server.send(200, "application/json", json);
}

void handleCmd() {
    if (server.hasArg("c")) {
        String cmd = server.arg("c");
        handleSerialCommand((char*)cmd.c_str());
        server.send(200, "text/plain", "OK: " + cmd);
    } else { server.send(400, "text/plain", "Missing c"); }
}

void handleParams() {
    String json = "{";
    json += "\"rate_roll\":{\"kp\":" + String(pid_rate_roll.kp, 4) + ",\"ki\":" + String(pid_rate_roll.ki, 4) + ",\"kd\":" + String(pid_rate_roll.kd, 4) + "},";
    json += "\"rate_pitch\":{\"kp\":" + String(pid_rate_pitch.kp, 4) + ",\"ki\":" + String(pid_rate_pitch.ki, 4) + ",\"kd\":" + String(pid_rate_pitch.kd, 4) + "},";
    json += "\"rate_yaw\":{\"kp\":" + String(pid_rate_yaw.kp, 4) + ",\"ki\":" + String(pid_rate_yaw.ki, 4) + ",\"kd\":" + String(pid_rate_yaw.kd, 4) + "},";
    json += "\"angle_roll\":{\"kp\":" + String(pid_angle_roll.kp, 4) + ",\"ki\":" + String(pid_angle_roll.ki, 4) + ",\"kd\":" + String(pid_angle_roll.kd, 4) + "},";
    json += "\"angle_pitch\":{\"kp\":" + String(pid_angle_pitch.kp, 4) + ",\"ki\":" + String(pid_angle_pitch.ki, 4) + ",\"kd\":" + String(pid_angle_pitch.kd, 4) + "}";
    json += "}";
    server.send(200, "application/json", json);
}

void handleSet() {
    if (server.hasArg("pid") && server.hasArg("val")) {
        String pid_name = server.arg("pid");
        float val = server.arg("val").toFloat();
        PIDController *pid = NULL;
        if (pid_name == "rate_roll") pid = &pid_rate_roll;
        else if (pid_name == "rate_pitch") pid = &pid_rate_pitch;
        else if (pid_name == "rate_yaw") pid = &pid_rate_yaw;
        else if (pid_name == "angle_roll") pid = &pid_angle_roll;
        else if (pid_name == "angle_pitch") pid = &pid_angle_pitch;
        if (pid) { pid->kp = val; server.send(200, "text/plain", "OK: " + pid_name + " kp=" + String(val, 4)); }
        else { server.send(400, "text/plain", "Unknown PID"); }
    } else { server.send(400, "text/plain", "Missing params"); }
}

void wifiInit() {
    WiFi.mode(WIFI_AP);
    WiFi.softAP(ap_ssid, ap_pass);
    Serial.printf("WiFi AP: %s  IP: %s\n", ap_ssid, WiFi.softAPIP().toString().c_str());
    server.on("/", handleRoot);
    server.on("/data", handleData);
    server.on("/cmd", handleCmd);
    server.on("/params", handleParams);
    server.on("/set", handleSet);
    server.begin();
    Serial.println("Web server started");
    wifi_connected = true;
}
