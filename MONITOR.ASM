;Monitor for Nicolay Pokrovsky-style controller
;Allows RAM listing and editing by hand

;Leonid Yadrennikov december 2017


;PORT1 - data LEDs
;PORT2 - address LEDs
;PORT4 bit 0 - IO//M of 81c55 (0=memory, 1=i/o)
;\INT - jump to listing mode and exit from listing mode
;       start address for listing is stored in 81c55 RAM at FFh
;T0 - list forward
;T1 - list backward
;81c55 PORTA (addr 01h) - address switches
;81c55 PORTB (addr 02h) - data switches
;81c55 PORTC (addr 03h) bit 5 - WRITE button
;T0,T1,WR normally tied to GND, INT normally tied to Vcc
;81c55 on reset (every WORK/EDIT switching) is resetted to input mode,
;port4 bit0 - to memory mode (set to 0)



            ORG 00h
            en i
            jmp POLLSTART       ;pollstart is ADDR/DATA sw handler


            ORG 03h             ;interrupt handler - RAM lister
INTPOINT:   jni intpoint
            sel rb1
            mov r2,a            ;saved user prog's ACC value
            call delay          ;debounce
            mov r1, #80h        ;address of start address' value in RAM
            clr a
            movd p4,a           ;set 81c55 as RAM
            movx a, @r1         ;read start listing address
            mov r0,a            ;save it to r0
VIEWLOOP:   ;swap a             ;SWAP only for controllers with 4 LEDS on P2
            outl p2,a           ;lit up ADDRESS
            movx a,@r0          ;read data
            outl p1,a           ;lit up DATA
WAITLOOP:   jt0 memup
            jt1 memdown         ;if T0,T1 tied to Vcc here must be jnt0,jnt1
            jni exit
            jmp waitloop
MEMUP:      inc r0              ;now new address is in ACC and r0
            jmp memcom
MEMDOWN:    dec r0
MEMCOM:     mov a,r0
            call delay          ;debounce
            jmp viewloop
EXIT:       call delay          ;debounce to prevent re-enter to interrupt
            mov a,#01h
            movd p4,a           ;set 81c55 as ports
            mov a,r2            ;restore user's ACC value
            retr


;address/data switches polling

POLLSTART:  mov a, #01h
            movd p4,a           ;set 81c55 as port
            mov a,r1            ;restore previous address at P2 to shorten
            outl p2,a           ;parasite blinking if A.0=P2.0=0 after movd
READLOOP:   mov a,#01h
            mov r0,a            ;port address for modification
            movx a,@r0          ;read PORTA of 81c55 (address)
            outl p2,a           ;and lit ADDRESS up
            mov r1,a
            inc r0
            movx a,@r0          ;read  PORTB of 81c55 (data)
            outl p1,a           ;lit DATA up
            mov r3,a            ;save DATA in R3
            inc r0
            movx a,@r0          ;read PORTC of 81c55 (WR button)
            jb5 memwr           ;did button pressed? (if pressed, A.5=PC.5=1)
            jmp readloop        ;no-contiue polling

;write-button handler

MEMWR:      movx a,@r0
            jb5 MEMWR           ;yes - wait for button release
            call delay          ;and later debounce
            clr a
            movd p4,a           ;set 81c55 as MEMORY
            mov a,r3
            movx @r1,a          ;write data R3 @R1 to RAM
            anl p1,#0h          ;let ports to blink a little
            anl p2,#0h
            call delay
            outl p1,a           ;restore data
            mov a,r1
            outl p2,a           ;restore addr
            jmp POLLSTART


;delay subroutine
            ORG 60h
DELAY:      mov r6,#03h
OUTTER:     mov r7,#0ffh
INNER:      djnz r7,INNER
            djnz r6,OUTTER
            ret

            ORG 100h
            DB '30-12-17 Nicolay Pokrovsky-style stand by Leonid Yadrennikov'
