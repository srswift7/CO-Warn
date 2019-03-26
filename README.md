Again and again, accident reports on the dangers of CO haunt the news. For example in aviation. The crash of the famous Aerobatics W.Dallach was then the initial spark. So a small CO sensor should not be too complicated, right?

MQ-7 is the name of the game, first of all, it is important to understand how the CO sensor works.

How does such a gas sensor work? The heart is a metal plate
made of a special alloy. At a well-defined temperature
somewhere beyond 200 ° C, gas molecules attach to the surface
and change the electrical resistance. That can then be measured.
Which gas molecules is determined by material and temperature. For the
correct temperature ensures a built-in heating.

The MQ-7 sensor is available on a small circuit board with some
Built-in components, the manufacturer calls the whole gadget "Flying Fish",
for whatever reason. The circuit evaluates the resistance and switches
at an adjustable threshold a light emitting diode. Dimensions,
Operating voltage and one analog and one digital output.

The data sheet of the MQ-7 sensor, on the other hand, raises a few questions. It
gives a cycle of 60 seconds heating with 5V without measuring (it will
practically the sensor "cleaned") and then 90 seconds heating with 1.4V
(during this time can be measured) before. The "Flying Fish" doesn't run such a complicated scenario. I doubt thet the "Flying Fish" is usable for practical CO detection at all.

A ATtiny is able to control the measurement using a plain MQ-7 sensor following the usage sequence below:

1.) preheat. The sensor is set to the default heating voltage (5.0V) for 90 seconds. LED lights up yellow.

2.) Calibration. The specified (datasheet)  heating / measuring cycle is run once, the resistance values are stored at fixed intervals. This will then be used in later operation as "characteristic". LED lights up green

3.) Operation. The specified heating / measuring cycle is run. The measured values are stored and compared with the "characteristic curve". Deviations are detected and reported according to their size and duration. LED flashes green briefly in a long interval. (Everything OK) or red (deviation from the characteristic found). In the event of deviations above a limit value or an absolute value (according to the characteristic from the data sheet), the LED flashes / lights up red and a warning tone sounds in the headset.

The sensitivity of the circuit is impressive. One lit tea light next to the sensor box is registered.

So, the CO-Warner has been in practical use for a year now in a Skyranger LSA. It has not found CO yet, but gasoline fumes. At a
Overland flight, the device suddenly began to warn. A carburetor gasket had a crack. Fixed, and no warnings any more.

Hardware:

IC2 is the usual 7805. The on-board voltage is nominally 12V, but ever of course this is something between 11.x and 14.x according to load / state of charge Volt. Through the diode D1, the fixed voltage regulator is on output voltage of 5.6..5.7 V pimped. That's me back out the heater voltage can switch from the sensor via transistor T1 and in heating case also arrive 5V. The 1.4V heating voltage during the measuring phase is controlled by the Attiny with PWM. The exact values ​​of the PWM constants have been found by experiment and voltmeter.

The LED2 is actually only required for the experimental phase and indicates whether the sensor is currently being heated or measured.

SV1 is the usual 6-pin programming plug. The same pins are also connected to the 9-pin SUB connector. So the Attiny can be accessed (flashed, data read) from "outside". There are some more sensor voltage pins ​​for diagnostic purposes.

LED1 is the already mentioned bicolour LED. The different serial resistors ensure that in the case of "both on" really yellow
arrives and and no kind of orange. The two R and the diode is natural required only once, either on the PCB or externally behind the SUB-D plug.

The Attiny gets its supply voltage via the D3, that's it again 5V.

PB4 is connected as a voltmeter and with the corresponding sensor pin connected.

IC1 is a 386, it mixes an external signal source (warning signal from FLARM) with a warning sound from the PB3 and puts the whole as an audio signal ready for the intercom.


