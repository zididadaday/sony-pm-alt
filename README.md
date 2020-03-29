# sony-pm-alt (BNutz Edition)
Transfer pictures wirelessly for Sony cameras without using PlayMemories (Sony PM Alternative)

BACKGROUND:
-----------
For a full technical breakdown - please see the readme in the original repo this project was forked from. It has an excellent write-up on how everything works and communicates together:
* https://github.com/falk0069/sony-pm-alt 


In my situation - although I was able to register my cameras to the PlayMemories app on my Windows PC - I was never able to get the Wi-Fi Import / "Send to Computer" functions to work. 

The cameras would always time-out with the message:
> Connected to the access point. Cannot connect to the computer to be saved.

This project allows me to bypass PlayMemories Home completely and directly send photos from my cameras to my docker-enabled NAS as soon as I get home.

This "BNutz Edition" adds some extra Docker environment params to more easily set the python script options inside the container.

Tested with:
* DSC-RX100M4 (Firmware 2.0)
* ILCE-7M3 (α7III - Firmware 3.10)

PREREQUISITES:
--------------
As described in the original [Linking The Camera And The PTP-GUID](https://github.com/falk0069/sony-pm-alt#linking-the-camera-and-the-ptp-guid) section - you first need to register the GUID of a PC or Mac against the camera(s) so that the cameras know who to accept connections from.

Once registered, you can then emulate this GUID to "trick" the cameras into sending the photos to your target destination instead via `gphoto2`.

To register a GUID onto the camera, you can either compile and use the `sony-guid-setter` tool (i.e. [Method 2](https://github.com/falk0069/sony-pm-alt#cool-new-sony-guid-setter)), or extract the GUID after linking the camera to an existing PlayMemories Home installation (PM Home can be uninstalled after the GUID is retrieved).

Since [Method 1]((https://github.com/falk0069/sony-pm-alt#linking-the-camera-and-the-ptp-guid)) in the guide didn't work for me, I ended up using Method 3; using Wireshark:

### STEPS
1. Install PlayMemories Home desktop application and connect the camera via USB as normal.
2. When the camera appears in the app, click into its menu and select the **Wi-Fi Import Settings** option 
3. Follow the prompts to get the camera registered.
   * For a proper step-by-step on this bit, see the official PlayMemories guides:
   * [How to use (Windows) - Import Section](https://support.d-imaging.sony.co.jp/www/disoft/int/playmemories-home/en/guide/windows/)
   * [Importing images to your Mac (Wi-Fi)](https://support.d-imaging.sony.co.jp/www/disoft/int/playmemories-home/en/guide/mac/import/wi-fi.html)
4. Once registered, disconnect the camera off the USB and make sure its Wi-Fi settings are set up to join your network properly as well.
5. On the computer, start up Wireshark and set it to monitor port 15740.
6. On the camera, run the "Send to Computer" option and let it run.
7. If all is well, you should see some activity in Wireshark after a few moments. Look in the first few packets for an entry that resolves to:
`Init Command Request GUID: (0000 hex string ffff) Name: COMPUTER-NAME`

   Where ***COMPUTER-NAME*** is the name of your computer on the network, and ***(0000 hex string ffff)*** is the registered GUID of your computer. Save the hex string for use below.

DOCKER:
-------

```
docker create \
    --name=sony-pm-alt \
    --net=host \
    -e PTP_GUID=<computer GUID in hex format> \
    -e GPHOTO_ARGS=<gphoto2 arguments, comma-separated> \
    -e PUID=1000 \
    -e PGID=1000 \
    -e SAVE_TO_DATE_FOLDERS=false \
    -e DEBUG=false \
    -v <path to incoming photos folder>:/var/lib/Sony \
    bnutz/sony-pm-alt
```

DOCKER PARAMETERS:
------------------

| Default Parameters | Function |
| ------------------ | -------- |
| `-e PTP_GUID="ff:ff:52:54:00:b6:fd:a9:ff:ff:52:3c:28:07:a9:3a"` | Computer GUID in hex format. Default is the value set by the `sony-guid-setter` tool |
| `-e GPHOTO_ARGS=--get-all-files,--skip-existing` | Comma-separated arguments to pass to `gphoto2`. See the [gphoto2 manpages](http://www.gphoto.org/doc/manual/ref-gphoto2-cli.html) for more |
| `-e PUID=1000`   | Set UID for downloaded files |
| `-e PGID=1000`   | Set GID for downloaded files |
| `-e SAVE_TO_DATE_FOLDERS=false`   | Move downloaded photos into folders sorted by date taken (yyyy-mm-dd) |
| `-e DEBUG=false` | Set debug logging |
| `-v /path/to/incoming/photo/folder:/var/lib/Sony` | Path to photo download folder on host machine |
| `-p 15740/tcp` | PTP/IP port (only needed if using bridge networking) |
| `-p 15740/udp` | PTP/IP port (only needed if using bridge networking) |
| `-p 1900/udp`  | SSDP port (only needed if using bridge networking) |


TROUBLESHOOTING:
----------------
### SSDP
* Check that your container is able to receive SSDP packets - run the container with the param `-e DEBUG=true` and then monitor its log output by running:
```
docker logs -f sony-pm-alt
```

* With the log running, run "Send to Computer" on your camera and see if the log produces any output after the camera connects (You may need to wait several minutes for anything to happen).

* TIP: As a control - it's worth also checking with another device on the network to see what SSDP packets we should be seeing.
  * In my case I installed the [SSDPTester](https://play.google.com/store/apps/details?id=com.bergin_it.ssdptester&hl=en) Android app on my phone to verify the SSDP broadcasts bouncing around my network (I'm guessing iOS should also have similar apps available).
  * If all is well, the debug log output from the Docker container should generally match the packets seen from the control device.

* If the container is unable to see any SSDP packets, try running the container on a different machine, or use a different Docker network profile such as `macvlan` to make your container appear like it's a separate device on the network. See the [Docker docs](https://docs.docker.com/network/) for more.

### GPHOTO2
* Check that `gphoto2` inside the container is able to connect and download from your camera; run the container as normal and then enter the container shell by running:
```
docker exec -it sony-pm-alt /bin/sh
```

* Once the container shell is ready, run "Send to Computer" on your camera and wait for it to connect to your network. Once the camera is connected, you have 2 minutes to do the following steps:

   1. Find the IP address of the camera (Should be able to get this from your router logs, or try the [Angry IP Scanner](https://angryip.org/) app)
   2. Once you have the IP, go to the container shell and pass it through to the test script:
```
./gphoto_connect_test.sh x.x.x.x
```
(Where **x.x.x.x** is the IP address of your camera)

* If it fails, validate that the `PTP_GUID` param has been entered correctly and the value has been successfully copied to the settings file in the container under `~/.gphoto/setting` (Can check the sample [`gphoto-settings`](https://github.com/bnutz/sony-pm-alt/blob/master/gphoto-settings) file to see how this should normally look).

* See the [Troubleshooting Section](https://github.com/falk0069/sony-pm-alt#troubleshooting) in the original repo for additional `gphoto2` checks.

### PYTHON SCRIPT
* The main script is `sony-pm-alt.py`, which is just a basic python server that will listen for the correct UPNP broadcast. Once detected, it will trigger `gphoto2` with the given arguments. For any script-specific issues, please check the [Troubleshooting Section](https://github.com/falk0069/sony-pm-alt#troubleshooting) and the [issue tracker](https://github.com/falk0069/sony-pm-alt/issues) in the original repo.

* For any docker-related issues, feel free to raise them [here](https://github.com/bnutz/sony-pm-alt/issues).
