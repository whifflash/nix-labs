# USB hardware catalogue.
#
# One entry per device family. `udev` entries become access rules (an entry
# without `pid` matches the whole vendor); `vm` lists the VID:PID pairs a
# `lab-vm-<env>` runner redirects into the guest by default; `known` is
# documentation only. IDs are lowercase hex without 0x.
{
  sipeed-slogic = {
    description = "Sipeed SLogic Combo8 / SLogic16U3 / SLogic32U3 logic analyzers";
    # libsigrok (Sipeed slogic-dev branch): the 2025-12 revision packaged in
    # nixpkgs uses VID 359f, the 2026 branch head switched to 2b1c. Cover both.
    udev = [
      { vid = "359f"; }
      { vid = "2b1c"; }
    ];
    known = [
      "359f:0300 / 2b1c:0300  SLogic Combo8"
      "359f:3031 / 2b1c:3031  SLogic16U3"
      "359f:3032 / 2b1c:3032  SLogic32U3"
    ];
    vm = [
      "359f:3031"
      "2b1c:3031"
    ];
  };

  limesdr = {
    description = "LimeSDR-USB / LimeSDR-Mini (IDs from LimeSuite's 64-limesuite.rules)";
    udev = [
      {
        vid = "1d50";
        pid = "6108";
      } # LimeSDR-USB
      {
        vid = "04b4";
        pid = "8613";
      } # Cypress FX3 bootloader (unprogrammed LimeSDR-USB)
      {
        vid = "04b4";
        pid = "00f1";
      } # Cypress FX3
      {
        vid = "0403";
        pid = "601f";
      } # LimeSDR-Mini (FT601)
      {
        vid = "0403";
        pid = "6001";
      } # LimeSDR-QPCIe serial
    ];
    known = [
      "1d50:6108  LimeSDR-USB"
      "0403:601f  LimeSDR-Mini"
    ];
    vm = [ "1d50:6108" ];
  };

  rtl-sdr = {
    description = "RTL2832U DVB-T dongles used as SDR receivers";
    udev = [
      {
        vid = "0bda";
        pid = "2838";
      }
      {
        vid = "0bda";
        pid = "2832";
      }
    ];
    known = [ "0bda:2838  RTL2838 (most RTL-SDR dongles)" ];
    vm = [ "0bda:2838" ];
  };

  hackrf = {
    description = "Great Scott Gadgets HackRF One / Jawbreaker";
    udev = [
      {
        vid = "1d50";
        pid = "6089";
      }
      {
        vid = "1d50";
        pid = "604b";
      }
      {
        vid = "1d50";
        pid = "cc15";
      }
    ];
    known = [ "1d50:6089  HackRF One" ];
    vm = [ "1d50:6089" ];
  };

  debug-probes = {
    description = "ST-Link, SEGGER J-Link, CMSIS-DAP / Raspberry Pi Debug Probe, Black Magic Probe";
    # Debug probes and their CDC-ACM consoles look like modems to ModemManager;
    # tell it to keep its hands off (ID_MM_DEVICE_IGNORE).
    mmIgnore = true;
    udev = [
      {
        vid = "0483";
        pid = "3744";
      } # ST-Link/V1
      {
        vid = "0483";
        pid = "3748";
      } # ST-Link/V2
      {
        vid = "0483";
        pid = "374b";
      } # ST-Link/V2-1
      {
        vid = "0483";
        pid = "374d";
      } # ST-Link/V3 (DFU)
      {
        vid = "0483";
        pid = "374e";
      } # ST-Link/V3
      {
        vid = "0483";
        pid = "374f";
      } # ST-Link/V3
      {
        vid = "0483";
        pid = "3752";
      } # ST-Link/V2-1 (no MSD)
      {
        vid = "0483";
        pid = "3753";
      } # ST-Link/V3 (no MSD)
      {
        vid = "0483";
        pid = "3754";
      } # ST-Link/V3 (no MSD, dual VCP)
      { vid = "1366"; } # SEGGER J-Link (all variants, incl. nRF DK on-board)
      {
        vid = "2e8a";
        pid = "000c";
      } # Raspberry Pi Debug Probe (CMSIS-DAP)
      {
        vid = "1d50";
        pid = "6018";
      } # Black Magic Probe
      {
        vid = "1d50";
        pid = "6017";
      } # Black Magic Probe (DFU)
      {
        vid = "0d28";
        pid = "0204";
      } # ARM DAPLink / mbed CMSIS-DAP
    ];
    known = [
      "0483:3748  ST-Link/V2"
      "0483:374b  ST-Link/V2-1 (Nucleo, Discovery)"
      "1366:*     J-Link"
      "2e8a:000c  Pi Debug Probe"
    ];
  };

  bootloaders = {
    description = "USB DFU / BOOTSEL bootloaders: STM32 DFU, RP2040/RP2350 BOOTSEL (picotool), Nordic nRF USB DFU";
    udev = [
      {
        vid = "0483";
        pid = "df11";
      } # STM32 DFU
      {
        vid = "2e8a";
        pid = "0003";
      } # RP2040 BOOTSEL
      {
        vid = "2e8a";
        pid = "000f";
      } # RP2350 BOOTSEL
      { vid = "1915"; } # Nordic Semiconductor (nRF52840 dongle DFU, open bootloader)
      {
        vid = "303a";
        pid = "1001";
      } # Espressif USB-JTAG/serial (ESP32-C3/C6/S3)
      {
        vid = "303a";
        pid = "1002";
      } # Espressif USB DFU
    ];
    known = [
      "0483:df11  STM32 DFU"
      "2e8a:0003  RP2040 BOOTSEL"
      "2e8a:000f  RP2350 BOOTSEL"
      "303a:1001  ESP32 USB-JTAG/serial"
    ];
  };

  usb-serial = {
    description = "USB-serial bridges on dev boards: FTDI, Silicon Labs CP210x, WCH CH34x";
    mmIgnore = true;
    udev = [
      {
        vid = "0403";
        pid = "6001";
      } # FT232R
      {
        vid = "0403";
        pid = "6010";
      } # FT2232 (also JTAG on many boards)
      {
        vid = "0403";
        pid = "6011";
      } # FT4232
      {
        vid = "0403";
        pid = "6014";
      } # FT232H
      {
        vid = "0403";
        pid = "6015";
      } # FT231X
      {
        vid = "10c4";
        pid = "ea60";
      } # CP2102/CP2104
      {
        vid = "10c4";
        pid = "ea70";
      } # CP2105
      {
        vid = "1a86";
        pid = "7523";
      } # CH340
      {
        vid = "1a86";
        pid = "55d4";
      } # CH9102
    ];
    known = [ "serial consoles land in the dialout group by the kernel default rules" ];
  };
}
