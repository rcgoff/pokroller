;Monitor for Nicolay Pokrovsky-style controller
;Allows RAM listing and editing by hand, with some services:
;auto-increment mode, listing-time current byte editor,
;And with simple advert at startup

;Leonid Yadrennikov 12.2017-05.2018
;Latest revision Date:12.05.2018, 253 bytes length


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

;remember that F0 is local flag and not saved during int (stored in PSW),
;and F1 is global flag.
;More precisely, value of F0 is saved during jump into int, but if its
;value is modified in interrupt handler, it won't be saved during RETR

ADDRCELL        equ     80h     ;here start listing address must be written

            ORG 00h
            en i
            jmp MOVELED         ;show startup advert, jmp to basic loop here

            ORG 03h             ;/INT interrupt handler - RAM lister
INTPOINT:   jni intpoint
            jmp inthand

;***********************************
;Timer interrupt handler
;***********************************
;probably, /INT interrupt must be disabled during TMRINIT explicitly
;but I cant imagine negative implications of this point (/INT during TMRINIT)
            ORG 07h             ;timer interrupt handler - blinking
            cpl f1
TMRINIT:    mov r2,a            ;acc back-up
            mov a,#0D0h
            mov t,a
            mov a,r2            ;acc restore
            strt t
            retr
;***********************************end of timer int handler

INTHAND:    sel rb1
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
            en i
            jf0 trestore        ;t0=1 means autincr mode and timer is running
            retr
TRESTORE:   en tcnti
            strt t             ;so we must start it in return
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

            call TMRINIT
            en tcnti
EDITLOOP:   dis i               ;this for returning from timer interrupt...
                                ;...handler, where RETR command enables...
                                ;...all interrupts. That lead to conflict
            jf1 LITLOOP
DARK:       anl p1,#00h         ;let data to blink a little:...
            jmp DRKLOOP
LITLOOP:    dec r0              ;addr of DATA SW port at 81c55
            movx a,@r0          ;read addr 02h - data switches,
            outl p1,a           ;lit data up,
            mov r3,a            ;and save it to r3
            inc r0
DRKLOOP:    movx a,@r0          ;read WR switch
            jb5 editwrexit      ;pressing WR causes write and exit
            jt0 editjexit       ;pressing UP causes exit on curr.addr
            jt1 editsee         ;holding DOWN causes display of old data
            jmp EDITLOOP

EDITWREXIT: call memwr          ;now we can write r3@r1 to RAM
            jmp viewloop

EDITJEXIT:  call delayno        ;debounce
            clr a
            movd p4,a           ;set 81c55 as MEMORY
            mov a,r1            ;restore address in acc
            jmp viewloop

EDITSEE:    mov a,r6
            outl p1,a
            jt1 editsee
            jmp EDITLOOP        ;in this case don't exiting from EDIT


;*********************************************
;moving line during start of poll mode
;just for visual effects
;shifting 3 bytes, showing only 2nd and 3rd
;pattern is stored at lowest (non-showing) byte
;*********************************************

MOVELED:    mov r0,#(5+16)d     ;length of pattern+length of two ports
            mov r5,#00011111b   ;the right 5 bits is pattern
            clr a
            mov r6,a
            mov r7,a
;            mov r2,#11111110b   ;delay value (greater->faster, timer counts
;                                ;upward) for old version, timer-based delay
STDLOOP:    mov a,r6
            outl p1,a
            mov a,r7
            outl p2,a
            mov r2,#95d
SFTDEL:     djnz r2,sftdel      ;one-loop delay(full-byte loop is too slow)
;            call THREESFT       ;three-byte shift
;instead of call jump is used to save 1 byte

;*********************************************
;Three-byte cyclic shifting
;r5,r6,r7 stores lower,medium,upper bytes
;acc value is preserved
;*********************************************

THREESFT:   xch a,r5            ;now r5 stores previous a, a<--lower byte
            rrc a               ; shifting lower byte
            xch a,r6            ;r6<--lower-shifted, a<--medium
            rrc a               ; shifting medium byte
            xch a,r7            ;r7<--medium-shifted, a<--upper
            rrc a               ; shifting upper byte
                                ;now r6=lower-s,r7=med-s,a=up-s
            xch a,r7            ;now r6=lower-s,r7=up-s, a=med-s
            xch a,r6            ;now a=lower-s,r6=med-s,r3=up-s                                ;
            anl a,#7fh          ;setting MSB (higher byte) to 0 and...
            jc SET1             ;..then seeting to 1 if was carry from upper
COMMPART:   xch a,r5            ;a<--previous a, r5<--lower-shifted
                                ;now r5=lower,r6=medium,r7=up,a=old acc
            jmp SDLPCONT        ;instead of ret:StandarD LooP CONTinuation
SET1:       orl a,#80h          ;setting Acc's LSB to 1 if Carry=1
            clr c
            jmp  COMMPART
;*****************************end of THREESFT

SDLPCONT:   djnz r0,STDLOOP
;            ret                 ;instead of "CALL MOVELED" and "RET",...
            jf0 POLLBLIK        ;...to save bytes, cond.jmp is used, ...
            jmp POLLSTART       ;...depending on two cases of MOVELED usage,
                                ;f0=1 means autoincrement ON


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
            call delayno        ;debounce
            cpl f0              ;toggle autoincr (f0=1 -  autoincr ON)
            jf0 POLLBLIKD       ;autoincr on - handle blinking
            jmp readloop        ;if autoincr now off, just return to simple
                                ;polling mode
POLLBLIKD:  mov a,r1
            jz moveled          ;to indicate autoincr on when curr address=0
POLLBLIK:   call TMRINIT        ;autoincr blinking initialize
            en tcnti
            jmp READLOOP

;in this case, standard poll routine must distingush
;--normal call(f0,f1 both off)
;--autoincr light (f0 on, f1 on)
;--autoincr dark (f0 on, f1 off)
;and must be able to switch modes from every given mode

ADRINC:     inc r1              ;this is end-of-polling-loop in
                                ;autoincr mode, not a strating point
            clr f1              ;after writing first phase is always LIGHT
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
            jmp readloop        ;return to standard loop
MEMWRPOLL:  call memwr
            jf0 adrinc          ;if auto-incr,modify address
            jmp pollstart       ;after memory writing, jmp to init-and-poll

;dark phase handler
ADRSKIP:    jf1 p1dark          ;in DARK phase P1 must be switched off
            mov a,r1            ;restore address in acc to display
            JMP adrnorm         ;if light phase,just return back
P1DARK:     anl p2,#0h          ;if dark phase, switch off p2
            jmp aincskip


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
;and r7 as delay length (and/or internally), its value is destroyed
;with explicit delay time call DELAYVAL
;in general case call DELAYNO
;**************************************************************************

;DELAYNO:    mov r7,#0D0h       ;tmr-delay value equivalent to 03h...
;                               ;;...in dbl-loop delay
;DELAYVAL:   dis tcnti
;            stop tcnt
;            jtf DELAYVAL       ;clear T-flag to prevent...
;                               ;...conflict with timer interrupt (even in
;                               ;stopped timer & disabled INTs flag m.b. set)
;            xch a,r7           ;acc back-up and delay length load
;            mov t,a
;            strt t
;TMRLOOP:    jtf tmrexit
;            jmp tmrloop
;TMREXIT:    stop tcnt
;            xch a,r7           ;acc restore
;            ret

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


;very obsolete (1st version)
;delay subroutine
DELAYNO:    mov r7,#03h
DELAYVAL:   mov r6,#00h
INNER:      djnz r6,INNER
            djnz r7,DELAYVAL
            ret

;author and firmware info out of stand's ROM address space
            ORG 100h
            DB '12-05-18 Nicolay Pokrovsky stand by Leonid Yadrennikov,below RAR'
