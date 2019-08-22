;Monitor for Nicolay Pokrovsky-style controller
;Allows RAM listing and editing by hand

;Leonid Yadrennikov 12.2017-02,04-05.2018


;PORT1 - data LEDs
;PORT2 - address LEDs
;PORT4 bit 0 - IO//M of 81c55 (0=memory, 1=i/o)
;\INT - jump to listing mode and exit from listing mode
;       start address for listing is stored in 81c55 RAM at ADDRCELL
;T0 - list forward
;T1 - list backward
;81c55 PORTA (addr 01h) - address switches
;81c55 PORTB (addr 02h) - data switches
;81c55 PORTC (addr 03h) bit 5 - WRITE button
;T0,T1,WR normally tied to GND, INT normally tied to Vcc
;81c55 on reset (every WORK/EDIT switching) is resetted to input mode,
;port4 bit0 - to memory mode (set to 0)



ADDRCELL        equ     80h

            ORG 00h
            en i
;            jmp POLLSTART
            jmp MOVELED         ;show start-up advert


            ORG 03h             ;interrupt handler - RAM lister
INTPOINT:   jni intpoint
            sel rb1
            mov r2,a            ;saved user prog's ACC value
            mov a,t
            mov r7,a            ;save timer's value
            call delayno          ;debounce
            mov r0, #ADDRCELL   ;address of start address' value in RAM
            clr a
            movd p4,a           ;set 81c55 as RAM
            movx a, @r0         ;read start listing address
            mov r1,a            ;save it to r1
VIEWLOOP:   ;swap a             ;SWAP only for controllers with 4 LEDS on P2
            outl p2,a           ;lit up ADDRESS
            movx a,@r1          ;read data
            outl p1,a           ;lit up DATA
WAITLOOP:   jt0 testup
            jt1 testdown        ;if T0,T1 tied to Vcc here must be jnt0,jnt1
            jni exit
            jmp waitloop
MEMUP:      inc r1              ;now new address is in ACC and r0
            jmp memcom
MEMDOWN:    dec r1
MEMCOM:     mov a,r1
            jmp viewloop
EXIT:       call delayno          ;debounce to prevent re-enter to interrupt
            mov a,#01h
            movd p4,a           ;set 81c55 as ports
            mov a,r2            ;restore user's ACC value
            mov a,r7
            mov t,a             ;restore timer value
            jf0 trestore        ;t0=1 means autincr mode and timer is running
            retr
TRESTORE:   strt t             ;so we must start it in return
            retr

TESTUP:     call delayno          ;debounce
            jt1 both            ;is down button pressed? yes - they're both
            jmp memup           ;no - only up

TESTDOWN:   call delayno          ;debounce
            jt0 both            ;is up button pressed? yes - they're both
            jmp memdown         ;no - only down



;*********************************************
;EDIT mode
;before call, r0 has #ADDRCELL value,
;r1 - curr addr, r2 - user prog's acc value,
;a has data from curr address
;during BOTH,
;r0'll store address of 81c55 port
;r1'll save curr.addr
;r3'll contain data from switches (for MEMWR)
;r4'll contain loop address for delaytm,
;r6'll store old data from curr address
;*********************************************

BOTH:       jt0 both
RELSDWN:    jt1 relsdwn         ;wait for both buttons release
            mov r6,a            ;save curr data
            mov a,#01h
            mov r0,#03h         ; portC (WR switch) address in 81c55
            movd p4,a           ;set 81c55 as port
            mov a,r1
            outl p2,a           ;lit current addres back at P2
DARK:       anl p1,#00h         ;let data to blink a little:...
            mov r4,#DRKLOOPAD
            call delaytm        ;..at 1st,switch p1 off...
SHINE:      mov r4,#LITLOOPAD
            call delaytm        ;...then lit data from switches up...
            jmp dark            ;...and switch off again in loop

LITLOOP:    dec r0              ;addr of DATA SW port at 81c55
            movx a,@r0          ;read addr 02h - data switches,
            outl p1,a           ;lit data up,
            mov r3,a            ;and save it to r3
            inc r0
DRKLOOP:    movx a,@r0          ;read WR switch
            jb5 editwrexit      ;pressing WR causes write and exit
            jt0 editjexit       ;pressing UP causes exit on curr.addr
            jt1 editsee         ;holding DOWN causes display of old data
            jmp tmrret

EDITWREXIT: stop tcnt           ;because of asyncro exiting from delay
            mov a,psw
            dec a
            mov psw,a           ;stack skip (quasi-return from delay)
            call memwr          ;now we can write r3@r1 to RAM
            jmp viewloop

EDITJEXIT:  stop tcnt           ;because of asyncro exiting from delay
            call delayno        ;debounce
            mov a,psw
            dec a
            mov psw,a           ;stack skip (quasi-return from delay)
            clr a
            movd p4,a           ;set 81c55 as MEMORY
            mov a,r1            ;restore address in acc
            jmp viewloop

EDITSEE:    mov a,r6
            outl p1,a
            jt1 editsee
            jmp tmrret          ;in this case don't exiting from delay


;*********************************************
;moving string during start of poll mode
;just for visual effects
;shifting 3 bytes, showing only 2nd and 3rd
;pattern is stored at lowest (non-showing) byte
;*********************************************

MOVELED: ; mov r0,#(5+16)d       ;length of pattern+length of two ports
;          mov r1,#00011111b     ;the right 5 bits is pattern
;         clr a
;          mov r2,a
;          mov r3,a
;          mov r7,#11111110b     ;delay value (greater->faster, timer counts
;                                ;upward)
;STDLOOP:  mov a,r2
;          outl p1,a
;          mov a,r3
;          outl p2,a
;          call DELAYVAL
;          call THREESFT         ;three-byte shift
;          djnz r0,STDLOOP
          jmp POLLSTART         ;pollstart is ADDR/DATA sw handler


;*********************************************
;Three-byte cyclic shifting
;r1,r2,r3 stores lower,medium,upper bytes
;acc value is preserved
;*********************************************

THREESFT:  xch a,r1             ;now r1 stores previous a, a<--lower byte
           rrc a                ; shifting lower byte
           xch a,r2             ;r2<--lower-shifted, a<--medium
           rrc a                ; shifting medium byte
           xch a,r3             ;r3<--medium-shifted, a<--upper
           rrc a                ; shifting upper byte
                                ;now r2=lower-s,r3=med-s,a=up-s
           xch a,r3             ;now r2=lower-s,r3=up-s, a=med-s
           xch a,r2             ;now a=lower-s,r2=med-s,r3=up-s                                ;
           anl a,#7fh           ;setting MSB (higher byte) to 0 and...
           jc SET1              ;..then seeting to 1 if was carry from upper
COMMPART:  xch a,r1             ;a<--previous a, r1<--lower-shifted
                                ;now r1=lower,r2=medium,r3=up,a=old acc
           ret
SET1:      orl a,#80h           ;setting Acc's LSB to 1 if Carry=1
           clr c
           jmp  COMMPART


;*********************************************
;AUTO-INCREMENT writing mode
;called from simple polling
;before call, 81c55 already in port mode,
;r0=03h (portC addr),
;r1=address from switches
;r3=data from switches
;*********************************************

AUTINC:
;now we must keep address value and continue to poll data from sw
;and WR button
;every WR pressing causes not just writing but also address incr
;to indicate this mode ADDRESS (port2) must blink
           call delayno         ;debounce
           cpl f0               ;toggle autoincr (f0=1 -  autoincr ON)
           jf0 POLLBLIK         ;autoincr on - handle blinking
           jmp readloop         ;if autoincr now off, just return to simple
                                ;polling mode

;autoincr blinking may be done like EDIT mode:
;lighting phase and blind phase, both inside delay routine
;maybe alternative variant:

POLLBLIK:   mov r4, #RDLOOPAD
            call DELAYTM         ;run READLOOP inside delay
            cpl f1               ;f1 selects blind/light phase
            jmp POLLBLIK

;in this case, standard poll routine must distingush
;--normal call(f0,f1 both off)
;--autoincr light (f0 on, f1 on)
;--autoincr dark (f0 on, f1 off)
;and must be able to switch modes from every given mode
;loop in autoincr mode: f0=0: simple loop, f0=1:jmp to TMRRET
;or simple jf0 tmrret

ADRINC:     inc r1              ;this is end-of-polling-loop in
                                ;autoincr mode, not a strating point
            clr f1              ;after writing first phase always LIGHT
                                ;and go to POLLSTART in natural way

;********************************************
;address/data switches polling
;r0 stores 81c55's port address
;r1 stores ADDRESS being read from switches
;r3 stores DATA being read from switches
;********************************************ÿ

POLLSTART:  mov a, #01h
            movd p4,a           ;set 81c55 as port
            mov a,r1            ;restore previous address at P2 to shorten
                                ;parasite blinking if A.0=P2.0=0 after movd

            outl p2,a
            jf0 POLLBLIK        ;after writing in autoincr we can't simply
                                ;continue but must re-initialize delay at 1st
READLOOP:   mov a,#01h
            mov r0,a            ;81c55 port address for modification
            jf0 ADRSKIP         ;in auto-incr mode address doesn't readed
            movx a,@r0          ;read PORTA of 81c55 (address)
ADRNORM:    outl p2,a           ;and lit ADDRESS up
            mov r1,a
AINCSKIP:   inc r0
            movx a,@r0          ;read  PORTB of 81c55 (data)
            outl p1,a           ;lit DATA up
            mov r3,a            ;save DATA in R3
            inc r0
            movx a,@r0          ;read PORTC of 81c55 (WR button)
            jb5 memwrpoll       ;did button pressed? (if pressed, A.5=PC.5=1)
            jt0 autinc          ;if UP pressed - toggle normal/auto-increment
                                ;no buttons - continue polling
                                ;two cases:
            jf0 tmrret          ;auto-incr mode - return into delay
            jmp readloop        ;std mode - simple loop
MEMWRPOLL:  jf0 sksp            ;in autoincr we're inside delay, special exit
MEMWRAINC:  call memwr
            jf0 adrinc          ;if auto-incr,modify address
            jmp pollstart       ;after memory writing, jmp to init-and-poll

;dark phase handler
ADRSKIP:    jf1 p1dark          ;in DARK phase P1 must be switched off
            mov a,r1            ;restore address in acc to display
            JMP adrnorm         ;if light phase,just return back
P1DARK:     anl p2,#0h          ;if dark phase, switch off p2
            jmp aincskip

;delay exiting
;exiting from READLOOP by pressing WR must leave DELAY routine!
;and STOP timer!
SKSP:       stop tcnt
            mov a,psw
            dec a
            mov psw,a
            jmp memwrainc


;**************************************
;write-button handler - writing r3@r1
;**************************************

MEMWR:      movx a,@r0
            jb5 MEMWR           ;yes - wait for button release
            call delayno          ;and later debounce
            clr a
            movd p4,a           ;set 81c55 as MEMORY
            mov a,r3
            movx @r1,a          ;write data R3 @R1 to RAM
            anl p1,#0h          ;let ports to blink a little
            anl p2,#0h
            call delayno
            outl p1,a           ;restore data
            mov a,r1
            outl p2,a           ;restore addr
            ret


;**************************************************************************
;timer-delay subroutine
;uses r5 (internally) and r4 as input data (or internally)
;and r7 as delay length (or internally)
;with doing something else during delay call DELAYTM
;with explicit delay time call DELAYVAL
;with explicit time and doing something call DELAY
;address of "something else" must be at r4 and return to TMRRET must occur
;if nothing to do, r4 must contain TMRRET address, then call DELAYNO
;**************************************************************************

DELAYTM:    mov r7,#0D0h
            jmp DELAY
DELAYNO:    mov r7,#0D0h       ;tmr-delay value equivalent to 03h...
                               ;;...in dbl-loop delay
DELAYVAL:   mov r4,#TMRRETAD
DELAY:      xch a,r5           ;acc back-up
            mov a,r7
            mov t,a
            strt t
TMRLOOP:    jtf tmrexit
            mov a,r4
            jmpp @a
TMRRET:     jmp tmrloop
TMREXIT:    stop tcnt
            xch a,r5
            ret


;addresses for JMPP @A command
TMRRETAD:   DB TMRRET
LITLOOPAD:  DB LITLOOP
DRKLOOPAD:  DB DRKLOOP
;POLLOOPAD:  DB POLLSTART
RDLOOPAD:   DB READLOOP


;obsolete
;The drawback of this approach is different delay time
;for procedures called by JMPP with different length.
;DELAYNO time will be shortest
;************************************************************
;when delay was simple two-loop, there was 03h at outter loop
;delay subroutine with quasi-multitasking
;look at comments in delay-by-timer routine
;************************************************************
;DELAYNO:    mov r4,#TMRRETAD
;DELAYTM:    xch a,r5
;            mov r7,#0ffh
;DELOOP:     mov a,r4
;            jmpp @a
;TMRRET:     djnz r7,DELOOP
;            xch a,r5
;            ret

;author and firmware info out of stand's ROM address space
            ORG 100h
            DB '02-05-18 Nicolay Pokrovsky-style stand by Leonid Yadrennikov'

