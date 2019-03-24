'----------------------------------------------------------
'
' Software fuer den CO-Warner mit MQ-7
'
' (c) 2018 gruen-design.de
'
' V4.0
'
'----------------------------------------------------------

$prog &HFF , &HE2 , &HDF , &HFF                             ' generated. Take care that the chip supports all fuse bytes.

$regfile = "Attiny45.dat"                                   'ATtiny45-Deklarationen
$crystal = 8000000                                          'No Quarz: 8 MHz

$hwstack = 64                                               ' default use 32 for the hardware stack
$swstack = 64                                               ' default use 10 for the SW stack
$framesize = 64                                             ' default use 40 for the frame space


Declare Sub Beep(byval Dauer As Integer)                    ' Eine Tonausgabe auf PORTB.3

Dim Spann As Byte

Dim Memcount As Byte
Dim Mempointer As Byte                                      ' Attiny45 hat nur 256 EEPROM Zellen

Dim Z As Integer
Dim Testloop As Integer

Dim 5volt As Byte
Dim 14volt As Byte

Dim Kalibrieren As Bit
Dim Ind As Integer
Dim Iind As Integer
Dim Vergleich As Byte

Dim Kennfeld(31) As Byte                                    ' Kennfeldansatz, wir speichern das erst mal nur im Speicher
Dim Permanent(256) As Eram Byte


Dim Delta As Integer

Spann = Adch                                                ' Schon mal auslesen aber erst mal ignorieren


Ddrb = &B00001111                                           'PB0-3 Ausgang, ...PB4..: Eingang

' HIer das gleich noch mal einzeln
' Ddrb.0 = 1                     ' PWM
' Ddrb.1 = 1                     ' rot
' Ddrb.2 = 1                     ' gruen
' Ddrb.3 = 1                     ' Beep


' Timer0 verwenden wir als PWM für die 5V/1.4V
' Das ganze kommt dann am B0 an (Pin5)
Config Timer0 = Pwm , Prescale = 1 , Compare A Pwm = Clear Down

'
' Tccr0a = &B10000001                                         'Pin OC1A nicht invertiert, 8-Bit-
' Tccr0b = &B00000010                                         '...PWM phasenkorrekt, Timer1 1/8


' Definitionen fuer den AD-Wandler an B4 (Pin3)
'----------------------------------------------------------

' Admux = &B01100010                                          'Bits7+6=01: Aref ist intern verbunden
'                      'Bit5=1: LeftAdjust, nur 8 Bit in ADCH
'                     'Bits1...0=0010: Pin ADB4 als Input  wählen

Admux = &B10110010

' Adcsra = &B11100010                                         'Bit7=1:AdcOn,Bit6=1:Start,Bit5=1:Frei
'                      'Bits2+1+0=010: AdcClock=AvrClock/4

Adcsra = &B11100100                                         ' Takt / 16


' Dmemcount = 0
Mempointer = 0

Z = 0
Testloop = 0

' Konstanten fuer den PWM Timer
5volt = 38
14volt = 200                                                ' 206 = 1.264

Compare0a = 5volt

' Vorwaermen ohne Messen - Ein kompletter Zyklus 60+90 Sekunden
' zuallererst brauchen wir 1 Minute Ruhe
' Rot
Portb.1 = 1
Portb.2 = 0

Waitms 300

' Gruen
Portb.1 = 0
Portb.2 = 1

Waitms 300

' Rot
Portb.1 = 1
Portb.2 = 0

' Portb.3 = 1
Call Beep(100)

Wait 60

' Gruen + Rot = GELB
Portb.1 = 1
Portb.2 = 1
Compare0a = 14volt

Wait 90

' Portb.3 = 0
Portb.1 = 0                                                 ' LED aus
Portb.2 = 0
Compare0a = 5volt

Kalibrieren = 1
' Summeheiz = 0
' Summemess = 0

' Die Basis ist ein 5s Grundtakt,
' Dazu braucen wir einen Timer1

' 8MHZ mit prescale 1024 ergibt 7812 Ticks,
' das sind 30 volle Durchläufe pro Sekunde oder 153 Durchläufe für 5 Sekunden

Config Timer1 = Timer , Prescale = 1024
Enable Timer1
Enable Interrupts

On Timer1 Timer5s

' Endlosschleife
Do                                                          'Hauptschleife
Loop


' Das hier ist der interrupt 3600/256 mal in der Sekunde.
Timer5s:

Incr Z

Portb.2 = Kalibrieren                                       'waehrend der Kalibrierphase ist die LED grün

If Z > 152 Then
   ' 5 Sekunden sind um

   Spann = Adch                                             'Aktuelles AD-HiByte Lesen

   Incr Testloop

   ' Genau jetzt speichern wir die gemessene Spannung im EEPROM
   If Mempointer > 251 Then
        Mempointer = 0
   End If

   Incr Mempointer
   Permanent(mempointer) = Spann
   Permanent(256) = Mempointer


   ' Kennfeldansatz, wir speichern beim Kalibrieren alle gemessenen Werte im Kennfeld
   ' Und im Scharfen einsatz vergleichen wir damit
   If Kalibrieren = 1 Then
      Kennfeld(testloop) = Spann
   Else

     ' Hier vergleichen wir jetzt
     Vergleich = Kennfeld(testloop)
     Vergleich = Vergleich + 1                              ' Etwas Toleranz
     If Spann < 2 Or Spann < Vergleich Then
         ' Kein Alarm, alles gut
         Portb.1 = 0
     Else
         ' hier koennte ein Alarm passieren, 20 Stufen (Wir haben am Ende 5 Sekunden)
         ' wir haben ein Delta von X, 20 bedeutet Weltuntergang
         Delta = Spann - Vergleich
         For Ind = 1 To 20
             Delta = Delta - 1
             If Delta > 0 Then
                Portb.1 = 1                                 ' LED ROT
                Call Beep(240)
                ' Waitms 200
             Else
                Portb.1 = 0
             End If
         Next Ind
      End If
      Portb.1 = 0                                           ' LED ROT -  AUS
   End If


   If Testloop = 12 Then
     ' =============================================
     ' Umschalten auf Messen
     ' =============================================
     ' Auf Messpannung = 1.4 V stellen
     Compare0a = 14volt
   End If


   If Testloop = 31 Then
     ' =============================================
     ' Die 90 Sekunden Messfenster sind rum, wir fangen wieder vorn an
     Testloop = 0
     Compare0a = 5volt
     If Kalibrieren = 1 Then
           Call Beep(50)
           Kalibrieren = 0
           Portb.2 = 0
           ' Kalibrierphase zuende
     End If
     ' Markieren - Ende des Zyklus im EEPROM
     Incr Mempointer
     Permanent(mempointer) = 0

   End If

   Z = 0
   Portb.2 = Not Portb.2                                    ' Kurz gruen Blinzeln
   Waitms 5
   Portb.2 = Not Portb.2

End If

Return

Sub Beep(byval Dauer As Integer)                            ' Eine Tonausgabe auf PORTB.3
   For Iind = 1 To Dauer
   Portb.3 = Not Portb.3
   Waitms 1
   Next Iind
End Sub Beep