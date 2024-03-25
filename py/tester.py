import os, subprocess, time, serial, struct
import pyftdi.serialext

# ser = serial.Serial('/dev/ttyUSB0', 115200, bytesize=serial.EIGHTBITS)
ser = pyftdi.serialext.serial_for_url('ftdi://ftdi:2232h/2', baudrate=115200, timeout=0.1)
dev = serial.Serial('/dev/ttyUSB2', 115200)

def set_holdoff(v):
    v0, v1, v2, v3 = struct.Struct('<I').pack(v & 0xFFFFFFFF)
    ser.write([0x52, v3, v2, v1, v0])

def set_pulse_width(v):
    v0, v1, v2, v3 = struct.Struct('<I').pack(v & 0xFFFFFFFF)
    ser.write([0x53, v3, v2, v1, v0])

def engage():
    ser.write([0xfa])

def disengage():
    ser.write([0xfb])

def glitcher_is_present():
    ser.write([0xfc])
    v = ser.read(1)
    return True if v[0] == 0xde else False

def check_target():
    l = dev.readlines(16)
    # s = ''.join([str(i)[2:-3] for i in l])
    s = ''.join([i.decode("utf-8", 'ignore') for i in l])
    print(s)
    if 'rea' in s:
        return s
    return None


if __name__ == "__main__":
    """ 196MHz - glitcher """

    if not glitcher_is_present():
        print('Glitcher does not reply!')
        exit()

    # pattern = int('01010101010101010101010101010101', 2)
    # pattern = int('00000000000000010000000000000000', 2)
    # set_pulse_width(pattern)
    # pattern = int('00011000101010010100100001000101', 2)

    print('Glitcher OK')
    for hf in range(10, 2048):
        with open('results.txt', 'a') as f:
            f.write('%d:\n' % hf)
        #hf = 8
        set_holdoff(hf)

        for pw in range(0xffff):
            print(hf, pw)
            pattern = 0x00000fff
            pattern |= (pw << 16)

            set_pulse_width(pattern)

            engage()
            #time.sleep(0.01)
            reply = check_target()
            disengage()

            #time.sleep(0.01)

            if reply:
                print("Found something! hf = %d, pw = %d" % (hf, pw))
                with open('results.txt', 'a') as f:
                    f.write('hf = %d, pw = %d\n%s\n' % (hf, pw, reply))

    print("ok")

