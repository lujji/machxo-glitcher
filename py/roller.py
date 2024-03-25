import os, subprocess, time, struct
import pyftdi.serialext

ser = pyftdi.serialext.serial_for_url('ftdi://ftdi:2232h/2', baudrate=115200)

def set_holdoff(v):
    """
    Glitcher is running @120MHz
    holdoff_time = (hf + 1) * 8.33ns
    hf = 11 -> 100ns
    """
    v0, v1, v2, v3 = struct.Struct('<I').pack(v & 0xFFFFFFFF)
    ser.write([0x52, v3, v2, v1, v0])

def set_glitch_pattern(v):
    """
    pattern is drawn right-to-left
    pattern = int('11111111110000000000000000000000', 2)
    in pulsed mode: 4.17ns/step (v = 12 -> 50ns)
    """
    ser.write([0x53] + [*struct.Struct('<Q').pack(v & 0xFFFFFFFFFFFFFFFF)][::-1])

def engage():
    """
    DIPSW[0]: glitch line idle (disengaged) state
    DIPSW[1]: glitch line active sate
    DIPSW[3]: reset line active state
    set = LOW/OFF
    """
    ser.write([0xfa])

def disengage():
    ser.write([0xfb])

def glitcher_is_present():
    ser.write([0xfc])
    v = ser.read(1)
    return v[0] == 0xde

def gray_codes(n):
    for i in range(1<<n):
        gray =i^(i>>1)
        print ("{0:0{1}b}".format(gray,n))

if __name__ == "__main__":
    if not glitcher_is_present():
        print('Glitcher does not reply!')
        exit()


    set_holdoff(0)
    while True:
        print('.')
        # set_glitch_pattern(int('111111', 2)) # 111111
        #set_glitch_pattern(int('111111111', 2)) # 111111
        set_glitch_pattern(int('11111111', 2)) # 111111
        engage()
        disengage()
        time.sleep(0.1)

    #6000 - 8800
    success = 0
    for i in range(6590, 9800, 10):
        for tries in range(10):
            print('%d:%d [%3d]' % (i, success, tries))
            set_holdoff(i)

            engage()

            cmd = 'stm8flash -c stlinkv2 -p stm8s003f3 -s flash -b 4 -r dump.bin'
            return_code = subprocess.call(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if return_code == 0:
                with open('dump.bin', 'rb') as f:
                    if f.read(4) != b'\x71\x71\x71\x71':
                        success += 1
                        print('Got mismatch! holdoff[%d] Trying to dump..' % i)
                        # cmd = 'stm8flash -c stlinkv2 -p stm8s003f3 -s flash -r dump_%d_%d.bin' % (i, tries)
                        cmd = 'stm8flash -c stlinkv2 -p stm8s003f3 -s opt -w opt.bin'
                        subprocess.call(cmd, shell=True)

            disengage()

    print("ok")

