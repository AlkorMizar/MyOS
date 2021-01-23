org 0x7c00
    jmp near start
    BS_OEMName db "MSWIN4.1"
    BPB_BytsPerSec dw 0x0200
    BPB_SecPerClus db 0x01
    BPB_RsvdSecCnt dw 0x0001
    BPB_NumFATs db 0x02
    BPB_RootEntCnt dw 0x0080
    BPB_TotSec16 dw 65472d
    BPB_Media db 0F0h
    BPB_FATSz16 dw 256d
    BPB_SecPerTrk dw  63d
    BPB_NumHeads dw 16d
    BPB_HiddSec dd 0x00000000
    BPB_TotSec32 dd 0x00000000

    BS_DrvNum db 80h
    BS_Reserved1 db 0h
    BS_BootSig db 0x0
    BS_VolID dd 0x00000000
    BS_VolLab db 11 dup '&'
    BS_FilSysType  db  8 dup 0

    PT  db 16 dup 0xAA
    bootDrive dw 0xBBBB
    First_Data_Sect dw 0xCCCC
    RootDirSectors dw 0xCCCC

start:
    xor dh,dh
    mov [bootDrive],dx

    ;copy Partition
    mov cx, 8d
    mov di, PT
    rep movsw

    mov ax,0x0003
    int 10h
    mov bp,bootLSTR
    call .WriteString

    ;RootDirSectors  ((BPB_RootEntCnt * 32) + (BPB_BytsPerSec – 1)) / BPB_BytsPerSec
    mov ax,[BPB_RootEntCnt]
    mov cl,0x05
    shl ax,cl
    add ax,[BPB_BytsPerSec]
    dec ax
    xor dx,dx
    div [BPB_BytsPerSec]
    mov bx,ax
    mov [RootDirSectors],bx

    ;rootDirectoryStart
    mov ax,[BPB_FATSz16]
    add ax,ax    ;mul ax,[BPB_NumFATs]
    add ax,[BPB_RsvdSecCnt]
    add ax,Word[PT+8]
    add bx,ax
    mov [First_Data_Sect],bx
    mov cx,[RootDirSectors]


.ContSearch:
    push cx;iterator
    push ax;LBA
    mov word[place],0x07e00
    xor dx,dx
    mov dl,[BPB_SecPerClus]
    mov [count_],dx
    mov word[LBA],ax
    ;push 0x07e00;addres
    call .ReadSeg
   ; pop ax
    pop ax
    pop cx
    inc ax
    push ax
    push cx
    mov cx,16
    mov si,0x07e00
  .ViewRootDir:
        mov di,NameOfKernel
        push cx
        push si
        mov cx,6
        repe cmpsw
        je .foundKernel
        pop si
        add si,0x20
        pop cx
   loop .ViewRootDir
    pop cx
    pop ax
 loop .ContSearch
 jmp .halt


.foundKernel:
   mov ax,word[si+16]
   xor dx,dx
   mov bx,200h
   div bx
   cmp dx,0
   je .next
   inc ax
.next:
   pusha
   mov bp,kernelSTR
   call .WriteString
   popa
   push ax ;ammount of sec
   mov cl,5;if ax=1 -> offset 0x20(0x200==512)
   shl ax,cl
   pop cx
   mov bx,0x7ff0;es:bx == 7ff00
   sub bx,ax ;adress
   mov WORD[adr+2],bx;es:bx(7xx0:0000) of kernel,es-part
   mov ax,word[si+14];first  cluster
   sub ax,0x02;N-2
   push cx
   mov cl,[BPB_SecPerClus]
   dec cl
   shl ax,cl;(N-2)*2
   pop cx
   add ax,Word[First_Data_Sect]
   mov word[place],0;offset
   .writeKernel:
        pusha
        mov word[place+2],bx;segment
        mov word[LBA],ax
        call .ReadSeg
        popa
        push ax
        mov ax,0x20
        mul [BPB_SecPerClus]
        add bx,ax ;+32*[BPB_SecPerClus]
        pop ax
        inc ax
   loop .writeKernel
   push 0x150
   pop ss
   mov sp,0x1500
   jmp DWORD[adr]

.halt:
        mov bp,haltSTR
        call .WriteString
        jmp $


.ReadSeg:
        mov ah,0x41
        mov bx, 0x55AA
        mov dx,[bootDrive]
        int 13h
        jb .halt ;.chs
        mov ah,0x42
        mov si,extBiosRead
        int 13h
        jb .halt
        ret
    .chs:
       ; push bp
       ; mov bp,sp; bp->sp->old bp
       ; sub sp,6
       ; xor dx,dx
       ; div [BPB_SecPerTrk];(dx)s=LBA mod S  ax= LBA / S
       ; inc dx ;(dx)s=LBA mod S + 1
       ; mov [bp-2],dx;sector
       ; xor dx,dx
       ;div [BPB_NumHeads];dx=( LBA / S )mod H   ax= ( LBA / S ) / H
        ;mov [bp-4],dx;head
       ; mov [bp-6],ax ;cilynder
       ; mov dx,[bootDrive]
       ; mov dh,BYTE[bp-4]
       ; mov ah,0x02
        ;xor cx,cx
       ;mov cx,[bp-6]
       ; shl cx,1
       ; shl cx,1
        ;shl cx,1
       ; shl cx,1
       ; shl cx,1
       ;add cl,BYTE[bp-2]
       ; mov al,[BPB_SecPerClus]
       ; mov bx,[bp+4]
       ; int 13h
       ; jb .halt
       ; mov sp,bp
       ; pop bp
        ret

.WriteString:
     mov si,bp
     mov ah,0x0e
     xor bx,bx
     wr:
        mov al,[si]
        cmp al,'$'
        je .end
        int 10h
        inc si
        jmp wr
   .end:
     mov cx,0x4c
     mov bx,0x4b40
     mov ax,0x0086
     int 15h
     ret


NameOfKernel db "SYSTEM  BIN",0x04 ;12
bootLSTR db "Bootloader loaded",0x0A,0x0D,'$'
kernelSTR db "Start loading kernel",0x0A,0x0D,'$'
haltSTR db "Can't load kernel$"
adr dd 0x00000000
extBiosRead db 0x10,0
      count_ dw 0x1
      place dd 0x7e00
        LBA dq 511d

times (510 - ($-$$)) nop
dw 0xAA55
