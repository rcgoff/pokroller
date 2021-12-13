;RAM lister for Blue Pokroller
;L.Yadrennikov 16.09,03.10.2019
;to be burned in single 155RE3 (32x8 PROM)

;r1 holds initial address
;r0 stores current address
;r3 is inner delay variable
;r2 is outter delay variable

;t0 lists upwards
;t1 lists downwards

STARTADDR       equ     0ffh            ;address in RAM where starting address
                                        ;for listing is stored
DELVAL          equ     0B0h            ;debouncing delay value

ORG     100h
        mov r1,#STARTADDR
        movx a,@r1              ;read start addr
        mov r0,a                ;place it to r0
VIEWLOOP:
        swap a
        outl p2,a               ;out addr
        anl p2,#11111110b       ;force P2.0/A8 to 0 to provide /CS RAM
        movx a,@r0              ;read data @addr
        outl p1,a               ;out data
WAITLOOP:
        jnt0 MEMUP
        jnt1 MEMDOWN
        jmp WAITLOOP
MEMUP:  inc r0
        jmp MEMCOM
MEMDOWN:dec r0
MEMCOM: mov a,r0
        call BOUNCDLY
        jmp VIEWLOOP


BOUNCDLY:
        mov r2,#DELVAL
INNER:  djnz r3,inner
        djnz r2,inner
        ret
