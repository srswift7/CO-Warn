'----------------------------------------------------------
'
' Software fuer den CO-Warner mit MQ-7
'
' (c) 2018-2020 gruen-design.de
'
' V11.0b
'
' Feinere Messaufloesung
' Glaettung der Messwerte, wir vergleichen mit dem Mittelw der letzten 3 Messungen
' Messungen alle 2 Sekunden
' Auswertefenster zwischen nur in der Messphase
' Intelligentere Beep-Steuerung
' Protokollierung der Messung im EEPROM
'
'----------------------------------------------------------

$prog &HFF , &HE2 , &HDF , &HFF                             ' generated. Take care that the chip supports all fuse bytes.

$regfile = "Attiny45.dat"                                   'ATtiny45-Deklarationen
$crystal = 8000000                                          'No Quarz: 8 MHz

$hwstack = 64                                               ' default use 32 for the hardware stack
$swstack = 64                                               ' default use 10 for the SW stack
$framesize = 96                                             ' default use 40 for the frame space

Declare Sub Beep(byval Dauer As Integer)                    ' Eine Tonausgabe auf PORTB.3
Declare Function Messme() As Byte                           ' Messen am ADC,

Dim Spann As Byte
Dim Bctr As Integer

Dim Mwert As Byte
Dim Memptr As Byte                                          ' Attiny45 hat nur 256 EEPROM Zellen

Dim Z As Integer                                            ' Zaehler fuer den Timer 1,
Dim Testloop As Byte

Dim Kalibrieren As Bit

Dim Iind As Integer
Dim Vergleich As Integer

Dim Sum As Integer

Dim Alarmctr As Byte                                        ' Zaehler, Ob Wir Schon Einen Alarm Hatten , Damit Wir Nicht In Ein Dauerbeep Verfallen

Dim Messdat(256) As Eram Byte

Dim Messf(3) As Integer                                     ' Zwischenspeicher fuer die letzten 3 Messungen

' ======================================
' Einstellwerte
' ======================================

Const Messtoleranz = 5

' Beta
' Osccal = 117                                                ' Kalibrierung des RC Oscillators, Dieser Wert muss hinexperimentiert werden
' Const 5volt = 79
' Const 14volt = 210                                          ' 206 = 1.264

' Prod!
Osccal = 85                                                 ' Kalibrierung des RC Oscillators, Dieser Wert muss hinexperimentiert werden
Const 5volt = 60
Const 14volt = 206                                          ' 206 = 1.264

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

Admux = &B00110010

' Adcsra = &B11100010                                         'Bit7=1:AdcOn,Bit6=1:Start,Bit5=1:Frei
'                      'Bits2+1+0=010: AdcClock=AvrClock/4

Adcsra = &B11100100                                         ' Takt / 16


' Vorwaermen ohne Messen - Ein kompletter Zyklus 60+90 Sekunden

Compare0a = 5volt

Waitms 1000

' Test der LED
' Rot
Portb.1 = 1
Portb.2 = 0

Waitms 300

' Gruen
Portb.1 = 0
Portb.2 = 1

Waitms 300

'  1 Minute Heizspannung

' LED Rot
Portb.1 = 1
Portb.2 = 0

' Portb.3 = 1
Call Beep(100)

Wait 60

'  90 Sekunden Messspannung

' Gruen + Rot = GELB
Portb.1 = 1
Portb.2 = 1
Compare0a = 14volt

Wait 90

' Bereit zur Arbeit!

Kalibrieren = 1
Z = 0
Testloop = 0
Memptr = 0
Alarmctr = 0
Vergleich = 0

' Messfeld zuruecksetzen
Messf(1) = 0
Messf(2) = Adch
Waitms 100
Messf(3) = Adch


' Portb.3 = 0
Portb.1 = 0                                                 ' LED aus
Portb.2 = 0
Compare0a = 5volt


' Die Basis ist ein 1s Grundtakt,
' Dazu braucen wir einen Timer1

' 8MHZ mit prescale 1024 ergibt 7812 Ticks,
' das sind 30 volle Durchläufe pro Sekunde

Config Timer1 = Timer , Prescale = 1024
Enable Timer1
Enable Interrupts

On Timer1 Timer2s

' Endlosschleife
Do                                                          'Hauptschleife
Loop


' Ende des Programms (falls es sowas ueberhaupt gibt)

' ####################################################
' # Unterprogramme und Funktionen
' ####################################################

' ####################################################
' Das hier ist der interrupt 30 mal in der Sekunde.
' ####################################################
Timer2s:

Incr Z                                                      ' Ein Nachteiler um auf die 2 Sekunden zu kommen

If Z > 60 Then
   ' 2 Sekunden sind um, die naechste Messung steht an

   Portb.2 = Kalibrieren                                    'waehrend der Kalibrierphase ist die LED grün

   Incr Testloop                                            ' Die Nummer der Messung in der 150-Sekunden Schleife, laeuft von 1 - 75

   ' Spann = Adch                                             'Messen und den Mittelwert berechnen,
   Spann = Messme()

   ' Wir speichern den Testwert ab

   ' Den Bereich von 1-75 überschreiben wir nicht (Kennfeld)
   If Memptr > 250 Then
        Memptr = 75
   End If

   ' Genau jetzt speichern wir die gemessene Spannung im EEPROM
   Incr Memptr
   Messdat(memptr) = Spann

   ' Im Messmodus muessen wir jetzt vergleichen und reagieren,
   If Kalibrieren = 0 Then
     If Testloop > 33 And Testloop < 73 Then                ' Wir betrachten nur die Messungen 34-72
        ' Die Messwerte in der Heizphase sind nicht sehr aussagekraeftig,
        ' Besonders im Umschaltmoment und den folgenden Sekunden auch sehr schwankend
        ' Deshalb betrachten wir sie nicht

        Portb.1 = 0                                         ' LED ROT -  AUS

        ' Mittelwert aus dem Kennfeld
        Mwert = Messdat(testloop)

        Vergleich = Spann - Mwert                           ' Im Alarmfall steigt die Spannung
        ' Vergleich = Abs(vergleich)

     End If
   End If

   If Testloop = 30 Then
     ' =============================================
     ' Umschalten auf Messen
     ' =============================================
     ' Auf Messpannung = 1.4 V stellen
     Compare0a = 14volt
     Alarmctr = 4                                           ' beim Umschalten nach Messen beepen wir noch mal, falls wir vor dem Heizen einen Alarm hattem
   End If


   If Testloop = 75 Then
     ' =============================================
     ' Die 90 Sekunden Messfenster sind rum, wir fangen wieder vorn an
     Testloop = 0
     Compare0a = 5volt
     If Kalibrieren = 1 Then
        Kalibrieren = 0
        Call Beep(50)
        Memptr = 75
        ' Kalibrierphase zuende
     End If
   End If

   ' =============================================
   ' Anzeigen Beep und Rotlicht oder Blinzeln
   ' =============================================
   If Vergleich > Messtoleranz Then                         ' Etwas Toleranz

        ' Alarm. Wie lange / wie laut wir Piepen machen wir nicht vom Vergleich, sondern vom Absolutwert der Spannung abhaengig.

        ' Im Alarmfall speichern wir die Messwerte
        ' Messdat(256) = Spann
        ' Messdat(255) = Mwert
        ' Messdat(254) = Vergleich
        ' Messdat(253) = Testloop
        ' Messdat(252) = Memptr
        ' Messdat(251) = Alarmctr

        ' Die Laenge des Pieptons berechnen wir aus der Spannung
        ' valide Werte sind zwischen 175 (0.05s ) - 255 (2s)
        If Spann > 174 then
           Bctr = Spann - 175
        else
           Bctr = 0
        end if

        Bctr = Bctr * 24

        Bctr = Bctr + 50        .

        Portb.1 = 1                                         ' LED ROT
        If Alarmctr < 6 AND Bctr > 450 Then               ' Wir Beepen nur maximal 6 mal hintereinander     und nur wenn der Schwellwert > 450 d.h. Spann > 190
           Call Beep(bctr)                                  ' kein Dauerton bitte
           Incr Alarmctr
        Else
           Waitms Bctr
        End If

        Portb.1 = 0
   Else                                                     ' Kein Alarm (mehr)
        Alarmctr = 0
        Bctr = Testloop Mod 5

        If Bctr = 0 Then
            Portb.2 = Not Portb.2                           ' Alle 10 s Kurz gruen Blinzeln
            Waitms 25
            Portb.2 = Not Portb.2
        End If
   End If

   Z = 0

End If

Return



' ####################################################
' Messen, wir messen und liefern den Mittelwert der letzten 3 Messungen
' ####################################################
Function Messme() As Byte                                   ' Messen am ADC,
   Sum = Adch                                               'Aktuelles AD-HiByte Lesen

   Messf(1) = Messf(2)
   Messf(2) = Messf(3)
   Messf(3) = Sum

   Sum = Sum + Messf(2)
   Sum = Sum + Messf(1)

   Sum = Sum / 3
   Messme = Sum Mod 256
End Function


' ####################################################
' Ein Beep vorgegebener Laenge
' ####################################################
Sub Beep(byval Dauer As Integer)                            ' Eine Tonausgabe auf PORTB.3
   For Iind = 1 To Dauer
   Portb.3 = Not Portb.3
   Waitms 1
   Next Iind
End Sub Beep