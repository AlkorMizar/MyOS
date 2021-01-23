macro readIntoBuff place,LBApl,offOfLBA,seg{
    mov ax,LBApl
    add ax,offOfLBA
    mov dx,place
    push ds
    push seg
    pop ds
    call writeInPlace
    pop ds
}

macro WriteIntoBuff place,LBApl,offOfLBA,seg{
    push ax
    mov ax,LBApl
    add ax,offOfLBA
    mov dx,place
    push ds
    push seg
    pop ds
    call writeInDrive
    pop ds
    pop ax
}


macro translate type,t{
local clearBP,empt,zeroFin,ok,found,checkName,checkS,notDot,writeName,wr8,write3,wr3,end
            mov si,0
            clearBP:
                 mov BYTE[bp+si-11d],' '
                 inc si
                 cmp si,11d
                 jne clearBP
                zeroFin:
                     cmp BYTE[ds:bx],0
                     je  found
                     inc bx
                     jmp zeroFin
           found:
               xor cx,cx
               xor ah,ah
               dec bx
               mov si,0
             checkName:
               mov di,NameOfFileSymb#t   ;table
               mov al,BYTE[ds:bx]
                   checkS:

                       cmp al,BYTE[cs:di]
                       je Erroe1#type
                     ok:
                       inc di
                       cmp BYTE[cs:di],0
                       jne checkS
              cmp al,'.'
              jne notDot
              inc si
              dec bx
              cmp si,1 ;ammount of dots
              je checkName
              cmp BYTE[ds:bx-2],'.'
                  jne Erroe1#type
              cmp WORD[bp-8],0x10
                  je Erroe1#type
              cmp BYTE[ds:bx],'\'
                  je writeName
              dec bx
              cmp bx,[ss:bp+2]
                  je writeName
              jmp Erroe1#type
            notDot:
              call ToUpperCase
              mov BYTE[ds:bx],al
              inc cx
              cmp bx,[ss:bp+2]
              je writeName
              cmp BYTE[ds:bx-1],'\'
              je writeName
              dec bx
              jmp checkName
           writeName:
              cmp BYTE[ds:bx],' '
              jbe Erroe1#type
              cmp BYTE[ds:bx-1],'\'
                  jne empt
                cmp BYTE[ds:bx-2],0
                  je empt
                mov BYTE[ds:bx-1],0
           empt:
              mov si,11d
              wr8:
                mov al,BYTE[ds:bx]
                mov BYTE[ds:bx],0
                inc bx
                cmp al,0
                    je end
                cmp al,'.'
                  je write3
                mov BYTE[ss:bp+si-12d],al
                dec si
                cmp si,3
              jne wr8
              write3:
                cmp WORD[bp-8],0x10
                   je end
                mov si,3
               wr3:

                 mov al,BYTE[ds:bx]
                 mov BYTE[ds:bx],0
                 inc bx
                 cmp al,0
                     je end
                 mov BYTE[ss:bp+si-12d],al
                 dec si
                 cmp si,0
                 jne wr3
            end:

}

macro findEntryInDIR t,type{
local createInDir,wrLBADEFDIR,notRootDirectory,notDefaultDir,checkDirForEmpty,checkEmpty,clear,checkForThatFile,checkInThatFile,notThatFile,creatNewSecForDir,found
      createInDir:
                mov bx,cs
                mov ds,bx
                mov bx,[bp+2]
                cmp BYTE[ds:bx],0
                    jne notDefaultDir
                mov [cs:offseOfDir],0
                readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                jmp checkDirForEmpty
       notDefaultDir:
                mov dx,bx
                push cs
                pop ds
                mov ah,3bh
                int 21h

                jc Erroe2#t
                checkDirForEmpty:
                        mov cx,16d
                        mov bx,BufferForDIR
                        sub bx,0x20
         if type=3ch
                    checkEmpty:
                        add bx,0x20
                        cmp BYTE[cs:bx],0
                        je found ;
         end if

         if type=3dh
                   checkForThatFile:
                        add bx,0x20
         end if
                        mov si,11d
                        mov di,0

                   checkInThatFile:
                        mov ah,BYTE[ss:bp+si-12d]
                        cmp BYTE[cs:bx+di],ah
                        jne notThatFile
                            inc di
                            dec si
                        cmp si,0
                        je found
                        jmp checkInThatFile

                  notThatFile:
         if type=3ch
                    loop checkEmpty
         else
                    loop checkForThatFile
         end if

                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]
                    cmp ax,[cs:First_Data_Sect]
                        jae notRootDirectory
                        inc ax
                        cmp ax,[cs:First_Data_Sect]
                            je Erroe2#type
                            inc [cs:offseOfDir]
                            readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                            jmp checkDirForEmpty
                   notRootDirectory:

                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
                    call findNextCl
                    cmp ax,0xFFFF


         if type=3ch
                    je creatNewSecForDir
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                      mov si,ax
                      sub si,[cs:LBAofDIR]
                      mov [cs:offseOfDir],si
                      readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs

                      jmp checkDirForEmpty
                creatNewSecForDir:
                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
                    call findEmptyCluster
                    cmp ax,0xFFFF
                    je Erroe23ch
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                    mov si,ax
                    sub si,[cs:LBAofDIR]
                    mov [cs:offseOfDir],si

                    pusha
                    mov si,BufferForDIR
                    mov cx,256d
                  clear:
                    mov WORD[cs:si],0x0000
                    add si,2
                    loop clear
                    popa
                    jmp checkDirForEmpty

         else
                    je Erroe23dh
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                    mov si,ax
                    sub si,[cs:LBAofDIR]
                    mov [cs:offseOfDir],si
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],ds
                    jmp checkDirForEmpty

         end if
                   found:

}
org $$
bpbStr:
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
        push 0
        pop ds
        push cs
        pop es
        mov cx,84d
        mov si,0x7c00
        mov di,bpbStr
        rep movsb
        push cs
        pop ds

        mov WORD[DTAAdr+2],cs
        mov ax,DTA
        mov WORD[DTAAdr],ax

        mov ax,[cs:First_Data_Sect]
        sub ax,[cs:RootDirSectors]
        mov [cs:LBAofDIR],ax
        mov WORD[cs:offseOfDir],0
        pusha
        call InteruptsCreator
        popa
        readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs   ;   BufferForFAT
        readIntoBuff BufferForFAT,[cs:BPB_RsvdSecCnt],Word[cs:PT+8],cs
        mov dx,KeenLosdSTR
        mov ah,09h
        int 21h

        ;commandL
   enterComm:

     dontChangePage:
        mov al,0ah
        mov ah,0eh
        int 10h
        mov al,0dh
        mov ah,0eh
        int 10h
  dontEnter:
        mov dx,CDPath
        mov dx,CDPath
        mov bx,CDPath
        mov dx,CDPath
        mov ah,09h
        int 21h
        mov dl,'>'
        mov ah,02h
        int 21h

        mov dx,commandL
        mov ah,0ah
        int 21h
        xchg bx,bx
        clc
        mov bx,commandL
        add bx,2
        xor ax,ax
        xor cx,cx
        dec bx
       whileSpace:
          inc bx
          cmp BYTE[ds:bx],' '
        je whileSpace
    translCom:
        mov al,BYTE[ds:bx]
        call ToUpperCase
        add cx,ax
        inc bx
        cmp BYTE[ds:bx],' '
            je commandReaded
            cmp BYTE[ds:bx],0
                je commandReaded
        jmp translCom
        inc bx
   commandReaded:

        mov ax,cx

        cmp ax,223 ;DIR
          je cd
          jmp near nextCD
          nop
          nop
          nop
          nop
          nop
          nop
      cd:
        push bp
        mov bp,sp
        sub sp,2

        mov al,0ah
        mov ah,0eh
        int 10h
        mov al,0dh
        mov ah,0eh
        int 10h
          dec bx
       whileSpace2:
          inc bx
          cmp BYTE[ds:bx],' '
        je whileSpace2
          mov al,BYTE[ds:bx]
          cmp al,'0'
              jb DIRerror
              cmp BYTE[ds:bx+1],' '
                je readPage
              cmp BYTE[ds:bx+1],0
                je readPage
                jmp DIRerror
         readPage:
              cmp al,'9'
                  ja DIRerror
                  sub al,'0'

          mov cx,16h

          xor ah,ah
          mul cx
          mov cx,ax ;how much skip
          mov [bp-2],cx
          mov dx,0
          mov bx,BufferForDIR
          mov di,0x20 ;dotdot
          mov si,[cs:LBAofDIR]
          cmp si,[cs:First_Data_Sect]
              jae dontSubThis
              sub di,0x20 ;root dir din't habe dotDIR
      dontSubThis:

          cmp WORD[cs:offseOfDir],0
              je dontRead
    readNextClust:
              mov WORD[cs:offseOfDir],dx
              readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs

       dontRead:
          mov cx,[bp-2]
          cmp cx,0
              je KH

          mov ah,BYTE[ds:bx+di]
          cmp ah,0xe5
              je jmpFurth
              cmp ah,0xc1
                  je jmpFurth
                  cmp ah,0
                      je AlldirRead
                      dec cx
      jmpFurth:
          mov [bp-2],cx
          add di,0x20
          cmp cx,0
              je KH
          cmp di,0x200
              jne dontRead
                    xor di,di
                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]
                    ;root
                    cmp ax,[cs:First_Data_Sect]
                        jae notRootDirectoryDIR
                        inc ax
                        cmp ax,[cs:First_Data_Sect]
                            je AlldirRead
                            inc [cs:offseOfDir]
                            jmp generateOff

               notRootDirectoryDIR:
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
              call findNextCl
              cmp ax,0xFFFF
                  je AlldirRead
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
               generateOff:
                  mov dx,ax
                  sub dx,[cs:LBAofDIR]
                  jmp readNextClust
      KH:
      mov cx,22d

      sub di,0x20
      StartWriting:
          mov [bp-2],cx
          add di,0x20
          cmp di,0x200
              jne dontRead2

              mov ax,[cs:LBAofDIR]
              add ax,[cs:offseOfDir]
                  cmp ax,[cs:First_Data_Sect]
                        jae notRootDirectoryDIR2
                        inc ax
                        cmp ax,[cs:First_Data_Sect]
                            je AlldirRead
                            inc [cs:offseOfDir]
                            readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                            jmp generateOff2

                notRootDirectoryDIR2:
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
              call findNextCl
              cmp ax,0xFFFF
                  je AlldirRead                                       ;fileName
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
               generateOff2:
                  mov dx,ax
                  sub dx,[cs:LBAofDIR]
                  mov WORD[cs:offseOfDir],dx
              readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
          mov di,0
       dontRead2:
         ; mov cx,23d
         mov cx,[bp-2]
          mov ah,BYTE[ds:bx+di]
          cmp ah,0xe5
              je StartWriting
              cmp ah,0xc1
                  je StartWriting
                  cmp ah,0
                      je AlldirRead
                      dec cx
                      mov [bp-2],cx
                      mov dx,0
                      mov si,0
                      push di
                      mov BYTE[cs:si+fileName],'|'
                      inc si
                  readNameTowrite:
                      mov BYTE[cs:si+fileName],ah
                      inc si
                      inc di
                      inc dx
                      mov ah,BYTE[ds:bx+di] ;end di+1
                      cmp dx,8d
                        jne d
                        mov BYTE[cs:si+fileName],'|'
                        inc si
                    d:
                        cmp dx,12d
                            jne readNameTowrite


                      ;last read -- atr ;DIRECTORY
                      pop di
                      mov ah,BYTE[ds:bx+di+0xb]
                      mov BYTE[cs:19+fileName],'|'
                      mov BYTE[cs:fileName+13],'|' ;si=13
                        mov si,14d
                      cmp ah,0x10
                          jne NOT_DIR
                          mov si,10d
                          mov BYTE[cs:fileName+10],'D'
                          inc si ;11
                          mov BYTE[cs:fileName+11],'I'
                          inc si ;12
                          mov BYTE[cs:fileName+12],'R'
                          inc si ;13
                          mov BYTE[cs:fileName+13],'|'
                          mov si,14d
                      dirSizeProblem:
                          mov BYTE[cs:si+fileName],0
                          inc si
                          cmp si,19d
                              jne dirSizeProblem
                          mov BYTE[cs:19+fileName],'|'
                          inc si ;si=20
                          jmp DateTimeSet
                  NOT_DIR:

                          mov si,18
                          push si
                        fff:
                           mov BYTE[cs:si+fileName],' '
                           dec si
                           cmp si,13d
                           jne fff
                          pop si
                          push cx  ;!!!!
                          mov ax,[ds:bx+di+0x1C];size low for 16 e
                     ContWrSize:
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:si+fileName],dl
                          dec si
                          cmp ax,0
                              jne ContWrSize

                     DateTimeSet:
                     ;date
                          mov si,29d
                          mov BYTE[cs:30+fileName],'|'
                          mov ax,[ds:bx+di+0x18]  ;0-4 day 5-8 month 9-15 - year
                          mov cl,9d   ;year
                          shr ax,cl
                          add ax,2000d
                      ContWrY:
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:si+fileName],dl
                          dec si
                          cmp ax,0
                              jne ContWrY
                          mov BYTE[cs:25+fileName],'.'
                          dec si

                          mov ax,[ds:bx+di+0x18]  ;0-4 day 5-8 month 9-15 - year
                          mov cl,5d   ;month
                          shr ax,cl
                          and ax,000000000001111b  ;month
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:24+fileName],dl
                          dec si
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:23+fileName],dl
                          dec si
                          mov BYTE[cs:22+fileName],'.'
                          dec si

                          mov ax,[ds:bx+di+0x18]  ;0-4 day 5-8 month 9-15 - year
                          and ax,000000000011111b  ;day
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:21+fileName],dl
                          dec si
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:20+fileName],dl
                          dec si

                           ;time
                          mov si,39d
                          mov BYTE[cs:39+fileName],'|'
                          mov ax,[ds:bx+di+0x16]  ;0-4 sec 5-10 min 11-15 -hours
                          mov cl,11d   ;hours
                          shr ax,cl

                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:32+fileName],dl
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:31+fileName],dl
                          mov BYTE[cs:33+fileName],':'

                          mov ax,[ds:bx+di+0x16]  ;0-4 sec 5-10 min 11-15 -hours
                          mov cx,5d
                          shr ax,cl
                          and ax,111111b  ;min
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:35+fileName],dl
                          dec si
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:34+fileName],dl
                          dec si
                          mov BYTE[cs:36+fileName],':'
                          dec si

                          mov ax,[ds:bx+di+0x16]  ;0-4 sec 5-10 min 11-15 -hours
                          and ax,000000000011111b  ;sec
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:38+fileName],dl
                          dec si
                          xor dx,dx
                          mov cx,10d
                          div cx
                          add dx,'0'
                          mov BYTE[cs:37+fileName],dl
                          dec si


                          mov si,40d
                          mov cx,[bp-2]
                          cmp cx,1
                          je dontWriteOtherEnter
                          mov BYTE[cs:si+fileName],0Ah
                          inc si
                          mov BYTE[cs:si+fileName],0Dh
                          inc si
                  dontWriteOtherEnter:
                          mov BYTE[cs:19+fileName],'|'
                          mov BYTE[cs:si+fileName],'$'
                          mov dx,fileName
                          mov ah,09h
                          int 21h
               cmp cx,0
               jne StartWriting

         AlldirRead:
         jmp enterComm
    DIRerror:
        mov dx,DIRRErrorLine
        jmp nextERROR1

DIRRErrorLine db "Wrong page$"

  nextCD:

        cmp ax,135 ;CD
          je dir
          jmp near nextEXEC
        dir:
          dec bx
        spaceSpace:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpace
          mov dx,bx
          cmp BYTE[ds:bx],0
              je nextERROR

          mov ah,3bh
          int 21h
          jc ErrorCd

          mov di,0
          mov si,CDPath
          cmp BYTE[ds:bx],'\'
              jne itHardTime
      wrCDp:
            mov ah,BYTE[ds:bx+di]
            mov BYTE[ds:si],ah
            inc si
            inc di
          cmp BYTE[ds:bx+di],0
            jne wrCDp
          mov BYTE[ds:si],'$'
          jmp enterComm
      itHardTime:
             push bx
             mov si,CDPath
             mov di,CDPath
          contThisSh:
                 inc di
             cmp BYTE[di],'$'
                 jne contThisSh
             cmp BYTE[cs:di-1],'\'
             je jmpF
             mov BYTE[cs:di],'\'
             inc di
             jmpF:
             xor al,al
         endAuto:

             mov dh,BYTE[ds:bx]
             mov ah,dh
             inc bx
             call checkType
             call checkState

             cmp al,0
                jne check3
                cmp dh,0
                    je finalyEnd
                mov BYTE[cs:di],dh
                inc di
                jmp endAuto
         check3:
             cmp al,3
                jne check4
                jmp endAuto
         check4:
             cmp al,4
                 jne endAuto
                 mov BYTE[cs:di],'$'
                 dec di
                 mov BYTE[cs:di],'$'
                 dec di
               delThithShi:
                 mov BYTE[cs:di],'$'
                 dec di
                 cmp BYTE[cs:di],'\'
                     jne delThithShi

               cmp BYTE[cs:di-1],0
                   je rootSlash
                   mov BYTE[cs:di],'$'
               rootSlash:
                 cmp dh,0
                     je enterComm
                 dec bx
                 jmp endAuto
        finalyEnd:
         mov BYTE[cs:di],'$'

         jmp enterComm
ErrorCd:

        mov dx,CdRErrorLine

        jmp nextERROR1

CdRErrorLine db "Wrong path$"

  nextEXEC:
        cmp ax,293 ;EXEC
          jne nextHALT
          dec bx            ;FBCTable   adressOfProgramm
    spaceSpaceSpace:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpaceSpace
              cmp BYTE[ds:bx],0
              je nextERROR
          mov dx,bx
          mov al,0x20
          mov ah,3dh
          int 21h
          jc ErrorCantOPen3
          push [LBAofDIR]
          push es
          push ds
          push bx
          push ax
          push bp
          mov bp,sp

          mov [cs:ssForDum],ss
          mov [cs:spForDum],sp

          xor dx,dx
          mov bx,27d
          mul bx
          mov bx,ax
          add bx,FBCTable

          cmp BYTE[cs:bx+8],'C'
              jne EerorWrongName
              cmp BYTE[cs:bx+9],'O'
                  jne EerorWrongName
                  cmp BYTE[cs:bx+10d],'M'
                      je NotErroInExe
                   EerorWrongName:
                      mov bx,[bp+2]
                      mov ah,3eh
                      int 21h
                      pop bp
                      pop ax
                      pop bx
                      pop ds
                      pop es
                      pop [cs:LBAofDIR]
                      mov [cs:offseOfDir],0
                      readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
                      mov bx,ax

        mov dx,EXECRErrorLine

        jmp nextERROR1

EXECRErrorLine db "Can load only .com files$"

       NotErroInExe:
          mov cx,[cs:bx+11d];low
          push 1400h
          pop ds
          mov dx,100h
          mov bx,[bp+2] ;desc
          mov ah,3fh    ;write in
          int 21h
          jc EerorWrongName

          mov ah,3eh
          int 21h

       pusha
          ;setting psp
          xor bx,bx
          mov cx,80h
        clearPSP:
          mov WORD[ds:bx],0
          loop clearPSP
        ;olt 22h
          mov WORD[ds:0x0A],nextHALT
          mov WORD[ds:0x0C],cs

          mov WORD[cs:PSP],1400h

          ;new 22h
          push es
          push 0
          pop es
          mov WORD[es:0x8A],cs
          mov WORD[es:0x88],endOfExec
          pop es

          mov WORD[ds:0x16],0

          mov ax,[cs:ssForDum]
          mov [ds:0x2e],sp
          mov ax,[cs:spForDum]
          mov [ds:0x30],ss

        popa
          mov ax,0003h
          int 10h
          mov ax,1400h
          mov ds,ax
          mov es,ax
          mov sp,1400h
          mov sp,0xFFFF
          xor ax,ax
          xor bx,bx
          xor cx,cx
          xor di,di
          xor si,si
          xor dx,dx
          call 1400h:100h  ;push cs push ip
   endOfExec:

          mov ax,[cs:ssForDum]
          mov ss,ax
          mov ax,[cs:spForDum]
          mov sp,ax
          pop bp
          pop ax
          pop bx
          pop ds
          pop es
          pop [cs:LBAofDIR]
          mov [cs:offseOfDir],0
          readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
          mov ax,003h
          int 10h
          jmp enterComm

ErrorCantOPen3:
        mov dx,EXECRErrorLine2
        jmp nextERROR1

EXECRErrorLine2 db "Can load only .com files$"

ErrorCantOPen:
        mov dx,EXECRErrorLineew
        jmp nextERROR1

EXECRErrorLineew db "Can't load file$"

  nextHALT:
        cmp ax,232 ;HALT
          jne nextMD
int22h:
    mov   ax,5301h
    xor   bx,bx
    int   15h
    mov   ax,530Eh
    xor   bx,bx
    mov   cx,0102h    ; CH = major, CL = minor
    int   15h
    mov   ax,5307h
    mov   bx,1
    mov   cx,3
    int   15h
    ret


  nextMD:
        cmp ax,145 ;MD
          jne nextRD
          dec bx
        spaceSpace2:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpace2
              cmp BYTE[ds:bx],0
              je nextERROR

          mov si,fileSearchName
          xor di,di
   movToCheckEmptyMD:
              mov ah,BYTE[ds:bx+di]
              mov BYTE[cs:si],ah
              inc si
              inc di
          cmp BYTE[ds:bx+di],0
              jne movToCheckEmptyMD
          mov BYTE[cs:si],0
          mov dx,fileSearchName
          mov ah,4eh
          int 21h
             jc dontAlterName
          clc
          call alterName
               jc ToomanySameNamesError
   dontAlterName:
          clc
          mov dx,bx
          mov ah,39h
          int 21h
          jc CantCreateDirectory
         jmp enterComm

CantCreateDirectory:
         cmp ax,1
             jne rtt
             mov dx,MDErrorLine1
             jmp nextERROR1
       rtt:
             mov dx,MDErrorLine2
             jmp nextERROR1

MDErrorLine1 db "Mistake in name of file$"
MDErrorLine2 db "Mistake in path of file$"

  nextRD:
        cmp ax,150 ;RD
          jne nextHELP
          dec bx
        spaceSpace3:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpace3
              cmp BYTE[ds:bx],0
              je nextERROR

          cmp BYTE[ds:bx],'\'
              jne NotAbsError

          mov si,fileSearchName
          xor di,di
   movToCheckEmptyRD:
              mov ah,BYTE[ds:bx+di]
              mov BYTE[cs:si],ah
              inc si
              inc di
          cmp BYTE[ds:bx+di],0
              jne movToCheckEmptyRD
          mov BYTE[cs:si],'\'
          inc si
          mov BYTE[cs:si],'*'
          inc si
          mov BYTE[cs:si],'.'
          inc si
          mov BYTE[cs:si],'*'
          inc si
          mov BYTE[cs:si],0
          inc si
          mov BYTE[cs:si],0
          inc si
          mov BYTE[cs:si],0
          mov dx,fileSearchName
          mov ah,4eh
          int 21h
             jc nextERROR
          mov ah,4fh
          int 21h
             jc nextERROR
          mov ah,4fh
          int 21h
             jnc ItNotEmptyDir
          mov si,CDPath
          mov di,0
  checkDeltStupidArse:
             mov ah,BYTE[ds:bx+di]
             mov al,BYTE[ds:si]
             cmp ah,'.'
                 je nextERROR
             inc si
             inc di

             cmp ah,al
                 je checkDeltStupidArse
          dec si
          cmp ah,0
              jne contAsItWas
              cmp al,'\'
                  je contDelet
              cmp al,'$'
                  je contDelet
                  jmp contAsItWas
                contDelet:

                      mov BYTE[ds:si],0
                      dec si
                  cmp BYTE[ds:si],'\'
                      jne contDelet

                  cmp si,CDPath
                      je dontDelThisS
                      mov BYTE[ds:si],0
                    dontDelThisS:
                      mov dx,CDPath
                      mov ah,3bh
                      int 21h
                  cmp si,CDPath
                      je dontSetThisS
                      mov BYTE[ds:si],'$'
                    dontSetThisS:
                      mov BYTE[ds:si+1],'$'

   contAsItWas:
          mov dx,bx
          mov ah,3ah
          int 21h
          jc cantDelDirError
         jmp enterComm
cantDelDirError:
        mov dx,cantDelDirErrorLine
        jmp nextERROR1

cantDelDirErrorLine db "Can't delet this directory$"

ItNotEmptyDir:
         mov dx,ItNotEmptyDirLine
        jmp nextERROR1

ItNotEmptyDirLine db "It's not empty directory$"

NotAbsError:
        mov dx,NotAbsPLine
        jmp nextERROR1

NotAbsPLine db "It's not absolute path$"

ToomanySameNamesError:
        mov dx,ToomanySameNamesLine
        jmp nextERROR1

ToomanySameNamesLine db "Too many same names$"

  nextHELP:
        cmp ax,297 ;HELP
          jne nextTOOK
        mov al,0ah
        mov ah,0eh
        int 10h
        mov al,0dh
        mov ah,0eh
        int 10h

        mov dx,helper
        mov ah,09h
        int 21h
        jmp enterComm

  nextTOOK:
        cmp ax,387 ;TOOKf
          jne nextCOPY
          mov ax,WORD[cs:flageOfTake] ;desc of orig
          test ax,ax
          jnz pot
          mov [cs:bx+JobTable],0xff
        pot:
          dec bx
        spaceSpace4:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpace4
              cmp BYTE[ds:bx],0
              je nextERROR
          mov dx,bx
          mov al,0x20
          mov ah,3dh
          mov dx,bx
          int 21h
          jc ErrorCantOPen
          mov WORD[cs:flageOfTake],ax ;desc
          jmp enterComm


  nextCOPY:
        cmp ax,0x13b ;copy
          jne nextMOVE
          mov ax,WORD[cs:flageOfTake] ;desc of orig
          test ax,ax
          jz DidntChooseError
          xor dx,dx
          mov di,27d
          mul di
          mov di,ax
          add di,FBCTable
          cmp BYTE[cs:di+15],0x10
          jz YouCantCopyDir
          mov WORD[cs:di+20d],0
          mov WORD[cs:di+22d],0
          mov di,WORD[cs:flageOfTake]

          push [cs:LBAofDIR]
          push [cs:offseOfDir]
          push bp
          mov bp,sp
          sub sp,2 ;-2-ori   -4-copy

          dec bx
        spaceSpacecopy:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpacecopy
           cmp BYTE[ds:bx],0
              je nextERROR

          call alterName
               jc ToomanySameNamesError
          mov cx,0x20
          mov ah,3ch
          mov dx,bx
          int 21h
          mov si,ax ;of copy
          mov [bp-2],ax


    continueCop:
          mov dx,BufferForWrite
          mov cx,512d
          mov ah,3fh
          mov bx,WORD[cs:flageOfTake]
          int 21h
              jc ErrorInReadingDeletFile

          cmp ax,0
          je allCopied

          mov si,BufferForWrite
          mov di,BufferForRead
          mov cx,256d
          rep movsw

          mov dx,BufferForRead
          mov cx,ax
          mov ah,40h
          mov bx,[bp-2]
          int 21h
              jc ErrorInReadingDeletFile

          jmp continueCop

       allCopied:

          mov bx,[bp-2]
          mov sp,bp
          pop bp
          pop [cs:offseOfDir]
          pop [cs:LBAofDIR]
          push ax
          readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
          pop ax
          mov ah,3eh
          int 21h
          jmp enterComm
          mov sp,bp
          pop bp
       ErrorInReadingDeletFile:
          mov sp,bp
          pop bp
          pop [cs:offseOfDir]
          pop [cs:LBAofDIR]
          push ax
          readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
          pop ax
          mov ah,41h
          int 21h
          mov sp,bp
          pop bp
          jmp ErrorDuringReadingFile

ErrorDuringReadingFile:
        mov dx,ErrorDuringReadingFileLine
        jmp nextERROR1

ErrorDuringReadingFileLine db "Something eent wrong while copying a file $"

YouCantCopyDir:
        mov dx,YouCantCopyDirLine
        jmp nextERROR1

YouCantCopyDirLine db "You can't copy directories$"

DidntChooseError:
         mov dx,DidntChooseErrorLine
        jmp nextERROR1

DidntChooseErrorLine db "You haven't selected a file$"

  nextMOVE:
        cmp ax,0x137 ;MOVE
          jne nextDEL

          mov di,WORD[cs:flageOfTake] ;desc of orig
          test di,di
          jz DidntChooseError

          push [cs:LBAofDIR]
          push [cs:offseOfDir]
          mov bp,sp
          sub sp,14d

          dec bx
        spaceSpaceMove:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpaceMove
          cmp BYTE[ds:bx],0
              je nextERROR

          call alterName
               jc ToomanySameNamesError

          mov ax,WORD[cs:flageOfTake]
          mov cx,27d
          xor dx,dx
          mul cx
          mov di,ax
          add di,FBCTable
          mov [bp-6],di

          mov ax,[cs:di+16d] ;old lba

          push ax
          readIntoBuff BufferForRead,ax,0,cs
          mov si,BufferForRead
          add si,[cs:di+18d];off in mem
          mov [bp-12],si

          mov ax,[cs:si+0x1A];cluster
          mov [bp-4],ax
          mov BYTE[cs:si],0xE5
          pop ax
          WriteIntoBuff BufferForRead,ax,0,cs

          mov dx,bx
          cmp BYTE[cs:di+15d],0x10
              jne simpleFile

              mov ah,39h
              int 21h
                  jc CantCreateDirectory
              mov dx,bx
              mov ah,3dh
              int 21h
                  jc ErrorCantOPen
              mov [bp-2],ax ;descr
              jmp dfr
        simpleFile:
              mov cx,0x20
              mov ah,3ch
              int 21h
                  jc nextERROR
              mov [bp-2],ax ;descr
     dfr:
          mov cx,27d
          xor dx,dx
          mul cx
          mov di,ax
          add di,FBCTable
          mov [bp-10d],di;to

          mov ax,[cs:di+16d] ;new LBA

          push ax
          readIntoBuff BufferForDIR,ax,0,cs
          mov si,BufferForDIR
          add si,[cs:di+18d];off in mem

          mov ax,[cs:si+0x1A];cluster
          mov [bp-8],ax  ;new cluster


          mov di,si     ;to
          add di,0xB
          mov si,[bp-12];from
          add si,0xB
          mov cx,21d
          rep movsb

          pop ax
          WriteIntoBuff BufferForDIR,ax,0,cs

          mov di,[bp-6]
          cmp BYTE[cs:di+15d],0x10
              jne simpleFileDontBotherWithSubDir
              mov ax,[bp-8] ;old
              sub ax,0x02;N-2
              push cx
              mov cl,[cs:BPB_SecPerClus]
              dec cl
              shl ax,cl;(N-2)*2
              pop cx
              add ax,Word[cs:First_Data_Sect]
              readIntoBuff BufferForDIR,0,ax,cs    ;ckuster just for fun

              mov ax,[bp-4]  ;new
              sub ax,0x02;N-2
              push cx
              mov cl,[cs:BPB_SecPerClus]
              dec cl
              shl ax,cl;(N-2)*2
              pop cx
              add ax,Word[cs:First_Data_Sect]
              readIntoBuff BufferForRead,ax,0,cs   ;true cluaster

              mov di,BufferForRead+0x20  ;to
              mov si,BufferForDIR+0x20    ;from
              mov cx,0x10
              rep movsw
              WriteIntoBuff BufferForRead,ax,0,cs

  simpleFileDontBotherWithSubDir:
          mov ax,[bp-8]
          call deleteClustersFromThisIncluding

          mov bx,[bp-6]    ;to
          mov di,[bp-10d]   ;from
          mov ax,WORD[cs:di+16d]    ;LBA in new dir
          mov WORD[cs:bx+16d],ax

          mov ax,WORD[cs:di+18d]    ;off in BuffDir
          mov WORD[cs:bx+18d],ax

          mov bx,[bp-2]
          mov [cs:bx+JobTable],0xff

          mov sp,bp
          pop  ax
          pop ax

          mov BYTE[cs:CDPath+1],'$'
          mov [cs:offseOfDir],0
          mov ax,[cs:First_Data_Sect]
          sub ax,[cs:RootDirSectors]
          mov [cs:LBAofDIR],ax
          push ax
          readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
          pop ax

          jmp enterComm
          ErrorDelDir:
          mov dx,bx
              mov ah,3ah
              int 21h
              jmp cantDelDirError

  nextDEL:
        cmp ax,213d ;del
          jne nextRen

          spaceSpace5:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpace5
          mov dx,bx
          cmp BYTE[ds:bx],0
              je nextERROR
          push bx

          mov al,0x20
          mov ah,3dh
          mov dx,bx
          int 21h
          jc ErrorCantOPen

          mov bx,ax
          mov [cs:JobTable+bx],0xff
          xor dx,dx
          mov di,27d
          mul di
          mov di,ax
          add di,FBCTable
          mov ax,150d
          cmp BYTE[cs:di+15],0x10
          jz nextRD
          pop dx
          mov ah,0x41
          int 21h
          jc nextERROR
          jmp enterComm

 nextRen:
        cmp ax,229 ;ren
          jne nextERROR

          mov di,WORD[cs:flageOfTake] ;desc of orig
          test di,di
          jz DidntChooseError

          push [cs:LBAofDIR]
          push [cs:offseOfDir]
          mov bp,sp
          sub sp,16d

          dec bx
        spaceSpaceMove324:
          inc bx
          cmp BYTE[ds:bx],' '
              je spaceSpaceMove324
          cmp BYTE[ds:bx],0
              je nextERROR
          call alterName
               jc  ToomanySameNamesError

          mov [bp-4],bx
          mov dx,bx
          mov ah,3ch
          int 21h
          mov [bp-2],ax

          xor dx,dx
          mov cx,27d
          mul cx
          mov si,ax
          add si,FBCTable

          mov ax,WORD[cs:flageOfTake]
          mov cx,27d
          xor dx,dx
          mul cx
          mov di,ax
          add di,FBCTable

          mov cx,0xB
          rep movsb

          mov dx,[bp-4]
          mov ah,0x41
          int 21h

          mov bx,WORD[cs:flageOfTake]
          mov ah,3eh
          int 21h

          mov bx,WORD[cs:flageOfTake]
          mov [cs:JobTable+bx],0

          mov bx,[bp-2]
          mov [cs:JobTable+bx],0xff
           jmp enterComm

  nextERROR:
        mov dx,errorMassege
  nextERROR1:
        mov al,0ah
        mov ah,0eh
        int 10h
        mov al,0dh
        mov ah,0eh
        int 10h

        mov ah,09h
        int 21h
        jmp enterComm
        jmp $


InteruptsCreator:
        xor ax,ax
        push es
        mov es,ax
        mov WORD[es:0x84],int21h
        mov WORD[es:0x86],cs

        mov WORD[es:0x8A],cs
        mov WORD[es:0x88],int22h

        mov WORD[es:0x82],cs
        mov WORD[es:0x80],int20h

        pop es

        ret

PSP  db 0,0
returnAdr db 0,0,0,0

int20h:
       xchg bx,bx
       pop di
       pop di
       pop di
       mov di,WORD[cs:PSP];seg
       mov si,ds
       cmp si,di
           jne hhh
           pop si
           pop si
    hhh:
       mov ds,di

       mov si,returnAdr
       mov dx,es
       push 0
       pop es

       mov ax,WORD[es:0x8A]
       mov [cs:si+2],ax
       mov ax,WORD[es:0x88]
       mov [cs:si],ax
        ;fix int 22h
       mov ax,[ds:0x0A];0ff of 22
       mov WORD[es:0x88],ax
     ;fix int 22h
       mov ax,[ds:0x0C];seg of 22
       mov WORD[es:0x8A],ax

       mov ax,[ds:0x16]
       mov WORD[cs:PSP],ax

       mov sp,[ds:0x2e]
       push WORD[ds:0x31]
       pop ss

       mov di,18h
       mov si,JobTable

       xor bx,bx          ;JobTable
       mov cx,20d
    contChekF1:
       mov ah,BYTE[ds:di]
       mov al,BYTE[cs:si]
       cmp ah,al
           je contChekF
              pusha
              mov ah,0x3e
              int 21h
              popa
      contChekF:
       inc si
       inc bx
       inc di
       loop contChekF1

       mov es,dx

       jmp DWORD[cs:returnAdr]

int21h:
               cmp ah,01h
               je _ah01h
               cmp ah,07h
               jne _next02h
_ah01h:
                   push dx
                   push ax

                   mov ah,00h
                   int 16h
                 ;check for extendet ASCII
                   test al,al
                   jnz .notExtended
                       mov cl,ah
                       mov ch,al
                       mov ah,05h
                       int 16h
      .notExtended:
                   cmp ah,1ch
                    jne notEnter
                       cmp ah,07h
                           je notEnter
                           mov al,0ah
                           mov ah,0eh
                           int 10h
                           mov al,0dh
                           mov ah,0eh
                           int 10h
          notEnter:
                   mov dl,al
                   pop ax
                   mov al,dl
                   pop dx
                   cmp ah,07h
                   jne _write;write on display
                   iret

_next02h:      cmp ah,02h     ;write symb
               jne _next09h
            _write:
                   push bx
                   push ax
                   push cx
            ;find active page
                   mov ah,0fh
                   int 10h  ;bh - active page

                   mov al,dl ;symbol
                   mov ah,0eh;
                   int 10h

                   cmp al,08h;bakspace
                   jne one
                       mov ah,0ah;
                       mov al,0
                       mov cx,1
                       int 10h
               one:
                   pop cx
                   pop ax
                   pop bx
                   iret

_next09h:      cmp ah,09h    ;write string
               jne _next0ah
               push ax
               push ds
               push dx
               push bx
               push di
               mov di,dx
               mov ah,0fh
               int 10h
                wrSymb09h:
                   mov ah,0eh
                   mov al,[ds:di]
                   int 10h
                   inc di
                cmp BYTE[ds:di],'$'
                jne wrSymb09h
               pop di
               pop bx
               pop dx
               pop ds
               pop ax
               iret


_next0ah:      cmp ah,0ah    ;read string
               jne _next3ch
               push ax
               push ds
               push dx
               push bx
               push cx
               push bp
               mov bp,sp
               mov bx,dx

               xor cx,cx
               mov cl,BYTE[ds:bx]
               add bx,2
               dec cl
             readNext0a:
                   mov ah,00h
                   int 16h
                 ;check for extendet ASCII
                   test al,al
                   jz readNext0a
                   cmp al,08h
                       jne notBacksp
                       cmp ch,0
                           je readNext0a
                           dec bx
                           dec ch
                           mov BYTE[ds:bx],0
                           mov ah,02h
                           mov dl,08h
                           int 21h
                           jmp readNext0a
  notBacksp:       cmp ah,1ch  ;enter
                     je stop0a
                    mov ah,0eh
                    int 10h
                    mov BYTE[ds:bx],al
                    mov BYTE[ds:bx+1],0
                    inc bx
                    inc ch
                   loop readNext0a
                 bella:
                   mov ah,00h
                   int 16h
                   cmp ah,1ch  ;enter
                     je stop0a
                   mov ah,0ah;
                   mov al,07h
                   mov cx,1
                   int 10h
                 jmp bella
            stop0a:

                   mov al,0dh
                   mov ah,0eh
                   int 10h
                   mov bx,[bp+6]
                   mov [ds:bx+1],ch
               pop bp
               pop cx
               pop bx
               pop dx
               pop ds
               pop ax
               iret



_next3ch:      cmp ah,3ch ;create and open file ; set size of file to 0 ; create file on disk (create information in directory)
               jne _next3dh
               cmp cx,0x10
                  je Erroe53ch
               cmp cx,0x01
                  je Erroe53ch
    markForDIRCr:
               push ds          ;22
               push dx          ;20
               push [cs:LBAofDIR]  ;18
               push [cs:offseOfDir];16
               push bx          ;14
               push si  ;12
               push di  ;10
               push cx  ;8 attr of file

               mov bx,dx
               mov si,fileName
             writeFname:
                   mov cl,BYTE[ds:bx]
                   inc bx
                   mov BYTE[cs:si],cl
                   cmp cl,0
                 je cont3ch
                   inc si
                 jmp writeFname
            cont3ch:
               mov dx,fileName
               push ds
               pop  ds
               push ax          ;bp+6
               push cs          ;bp+4,5
               push fileName  ;bp+2,3                              num Entr  num of decoder
               push bp ;sp=bp new bp->bp-1->bp-2->...bp-11->bp-12,13  ->bp-15,16
               mov bp,sp
               sub sp,16d ;bp-13 if push sp->bp-14
               mov di,dx
               mov dx,fileName
               mov bx,dx
               mov si,0
               cmp cx,0x01 ;readOnly
               je Erroe43ch

               mov si,fileSearchName
          xor di,di
   copyName:
              mov ah,BYTE[ds:bx+di]
              mov BYTE[cs:si],ah
              inc si
              inc di
          cmp BYTE[ds:bx+di],0
              jne copyName
          mov BYTE[cs:si],0
          mov dx,fileSearchName
          mov ah,4eh
          int 21h
          jnc Erroe13ch

               atr3chCh:
               ;macro
               translate 3ch,3ch
               findEntryInDIR 3ch,3ch

               push bx
               sub bx,BufferForDIR
               mov WORD[ss:bp-13d],bx
               pop bx
                 cmp BYTE[cs:bx],0
                 je notExist
                 mov ax,WORD[cs:bx+0x1A] ;firstCl
                 call deleteClustersFromThisIncluding
            notExist:
                    mov si,11d
                 movSymb3ch:
                       mov al,BYTE[ss:bp+si-12d]
                       mov BYTE[cs:bx],al
                       dec si
                       inc bx
                       test si,si
                       jne movSymb3ch
                    mov ax,WORD[ss:bp+8]   ;attr
                    mov BYTE[cs:bx],al
                    xor ax,ax
                    call findEmptyCluster
                    mov WORD[cs:bx+0xF],ax
                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]
                    push ds
                    push cs
                    pop ds
                    mov dx,BufferForDIR
                    ;
                      call writeInDrive
                    pop ds


                    add di,5
                    mov cx,15d
                searchForFreeFCB3ch:
                    cmp BYTE[cs:di+JobTable],0xff
                    je foundFCBdec3ch
                      inc di
                    loop searchForFreeFCB3ch
                 jmp Erroe33ch
                 foundFCBdec3ch:
                    mov si,11d
                    mov BYTE[cs:di+JobTable],0x00
                    mov ax,di
                    mov WORD[ss:bp-15d],di ;decoder
                    xor dx,dx
                    mov cl,27d
                    mul cl
                    add ax,FBCTable
                    mov di,ax
                  wrNameInFCB:
                        mov ah,BYTE[ss:bp+si-12d]
                        mov BYTE[cs:di],ah
                        inc di
                        dec si
                        cmp si,0
                  jne wrNameInFCB
                  mov ax,WORD[ss:bp+8]
                  mov BYTE[cs:di+4],0x20 ;attr    ;r/w
                  mov WORD[cs:di+0],0  ;sizeL
                  mov WORD[cs:di+2],0;sizeH
                  mov ax,[LBAofDIR]
                  add ax,[offseOfDir]
                  mov WORD[cs:di+5],ax
                  mov ax,WORD[ss:bp-13d] ;num
                  mov WORD[cs:di+7],ax
                  mov WORD[cs:di+9],0 ;pointerL
                  mov WORD[cs:di+11d],0;pointerH
                  mov BYTE[cs:di+13d],0;dateisSetle

                mov ax,WORD[ss:bp-15d]
                jmp reloadSteck3ch

                    ;создать описсатель
                    ; 0-4-size  4-1-attr 5-2-segm_Dir  7-2-num_inDir  9-4-pointer
;13-1-dateisSetle

          Erroe13ch:;mistake in name
            mov ax,01

            jmp reloadSteck3chE
          Erroe23ch:;misteke in path
            mov ax,02
            stc
            jmp reloadSteck3chE
          Erroe33ch:;to many open files
            mov ax,03
            stc
            jmp reloadSteck3chE
          Erroe53ch:
            mov ax,05
            stc
            iret
          Erroe43ch: ;wrong attr
            mov ax,04
            stc
            reloadSteck3chE:
               stc
               mov sp,bp
               pop bp
               pop dx
               pop ds
               pop cx
               pop cx
               pop di
               pop si
               pop bx
               cmp cx,0x10
              jne cont3chE
              stc
              jmp DIRCreated

               pop [cs:offseOfDir]
               pop [cs:LBAofDIR]
               pop dx
               pop ds
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
          ;;;;
                    push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

          reloadSteck3ch:

               mov sp,bp
               pop bp
               pop dx
               pop ds
               pop cx
               pop cx
               pop di
               pop si
               pop bx
               cont3chE:
            cmp cx,0x10
              je DIRCreated
               pop [cs:offseOfDir]
               pop [cs:LBAofDIR]
               pop dx
               pop ds
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
          ;;;;

                    iret


_next3dh:      cmp ah,3dh
               jne _next3eh
               cmp cx,0x10
                  je Erroe53dh
               cmp cx,0x01
                  je Erroe53dh
    markForDIRDel:
               push ds
               push dx
               push [cs:LBAofDIR]
               push bx
               push [cs:offseOfDir]
               push si
               push di
               push cx

               mov bx,dx
               mov si,fileName
             writeFname3dh:
                   mov cl,BYTE[ds:bx]
                   inc bx

                   mov BYTE[cs:si],cl
                   cmp cl,0
                 je cont3dh
                   inc si
                 jmp writeFname3dh
            cont3dh:
               push cs
               pop ds
               mov dx,fileName
               xor ah,ah
               push ax  ;bp+6
               push cs  ;bp+4
               push fileName   ;bp+2,3                              num Entr  num of decoder
               push bp ;sp=bp new bp->bp-1->bp-2->...bp-11->bp-12,13  ->bp-15,16
               mov bp,sp
               sub sp,16d ;bp-13 if push sp->bp-14
               mov di,dx
               mov bx,dx
               mov si,0

               ;macro
               translate 3dh,3ch
               findEntryInDIR 3dh,3dh
               ;macro
               push bx
                    sub bx,BufferForDIR
                    mov WORD[ss:bp-13d],bx
               pop bx
                    mov si,11d
                    mov di,5d
                    mov cx,15d
                searchForFreeFCB3dh:
                    mov ah,BYTE[cs:di+JobTable]
                    cmp BYTE[cs:di+JobTable],0xff
                    je foundFCBdec3dh
                      inc di
                    loop searchForFreeFCB3dh
                 jmp Erroe33dh
                 foundFCBdec3dh:
                    mov BYTE[cs:di+JobTable],0x00
                    mov si,11d
                    mov ax,di
                    mov WORD[ss:bp-15d],di
                    xor dx,dx
                    mov cl,27d
                    mul cl
                    add ax,FBCTable
                    mov di,ax
                 wrNameInFCB3dh:
                        mov ah,BYTE[ss:bp+si-12d]
                        mov BYTE[cs:di],ah
                        inc di
                        dec si
                        cmp si,0
                 jne wrNameInFCB3dh
                 mov bx,WORD[ss:bp-13d]
                 add bx,BufferForDIR
                 ;check atr
                  mov ax,[ss:bp+8]
                      cmp BYTE[cs:bx+0x0B],0x01
                      jne notReadOnly
                          cmp ax,0x01
                          jne Erroe43dh
               notReadOnly:

                  mov ax,[cs:bx+0xb]
                  mov BYTE[cs:di+4],al ;attr
                  mov ax,WORD[cs:bx+0x1C]
                  mov WORD[cs:di+0],ax  ;sizeL
                  mov ax,WORD[cs:bx+0x1E]
                  mov WORD[cs:di+2],ax;sizeH
                  mov ax,[LBAofDIR]
                  add ax,[offseOfDir]
                  mov WORD[cs:di+5],ax  ;full DIRLBA
                  mov ax,WORD[ss:bp-13d]
                  mov WORD[cs:di+7],ax ;num_inDir
                  mov WORD[cs:di+9],0 ;pointerL
                  mov WORD[cs:di+11d],0;pointerH
                  mov BYTE[cs:di+13d],0xff;Date

                mov ax,WORD[ss:bp-15d]
                jmp reloadSteck3dh

                    ;создать описсатель
                   ;0-4-size  4-1-attr 5-2-segm_Dir  7-2-num_inDir  9-4-pointer
;13-1-dateisSetle

          Erroe13dh:;mistake in name
            mov ax,01
            stc
            jmp reloadSteck3dhE
          Erroe23dh:;misteke in path
            mov ax,02
            stc
            jmp reloadSteck3dhE
          Erroe33dh:;to many open files
            mov ax,03
            stc
            jmp reloadSteck3dhE
          Erroe53dh :
            mov ax,5
            stc
                    push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret
          Erroe43dh: ;wrong attr
            mov di,WORD[ss:bp-15d]
            mov BYTE[cs:di+JobTable],0xff
            mov ax,04
            stc
                    reloadSteck3dhE:

               mov sp,bp
               pop bp
               pop dx
               pop ds
               pop cx
               pop cx ;attr of creatFile
               pop di
               pop si

                cmp cx,0x10
              jne cont3dhE
              stc
              jmp DIRDel
           cont3dhE:
               pop [cs:offseOfDir]
               pop bx
               pop [cs:LBAofDIR]
               pop dx
               pop ds
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
                    push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret
          reloadSteck3dh:
                clc
               mov sp,bp
               pop bp
               pop dx
               pop ds
               pop cx
               pop cx ;attr of creatFile
               pop di
               pop si

               cmp cx,0x10
                   je DIRDel
               pop [cs:offseOfDir]
               pop bx
               pop [cs:LBAofDIR]
               pop dx
               pop ds
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
          ;;;;
              ; cmp cx,0x10
              ; je DIRdeleter
                    iret

;close file
_next3eh:      cmp ah,3eh;;close file
               jne _next3bh
               cmp bx,20d
                   jae Erroe13eh  ; no such desc
               cmp BYTE[cs:bx+JobTable],0
                   jne Erroe13eh
               push [cs:LBAofDIR]  ;18
               push bx          ;16
               push [cs:offseOfDir];14
               push si  ;12
               push di  ;10
               push cx  ;8
               push ax  ;bp+6
               push ds  ;bp+4,5
               push dx  ;bp+2,3
               push bp ;  bp-1,-2-DATE bp-3,-4-TIME
               mov bp,sp
               sub sp,4;sp-3<=>bp-3

               mov BYTE[cs:bx+JobTable],0xff
               mov ax,bx
               xor dx,dx
               mov cx,27d
               mul cx
               mov di,ax
               add di,FBCTable

               push ax
               readIntoBuff BufferForDIR,WORD[cs:di+16d],0,cs
               pop ax

               mov ax,WORD[cs:di+16d]
               mov [cs:LBAofDIR],ax
               mov [cs:offseOfDir],0
               ;0-10-name  11-4-size  15-1-attr 16-2-segm_Dir  18-2-num_inDir  20-4-pointer
;26-1-dateisSetle

               mov si,BufferForDIR
               add si,WORD[cs:di+18d]

               xor bx,bx
               rename:
                     mov ah,BYTE[cs:di+bx]
                     mov BYTE[cs:si+bx],ah
                     inc bx
               cmp bx,11d
                   jne rename
             cmp BYTE[cs:di],0xE5
               je justDeleteinGfile
               mov ax,WORD[cs:di+11d] ;sizaL
               mov WORD[cs:si+0x1C],ax
               mov ax,WORD[cs:di+13d] ;sizaH
               mov WORD[cs:si+0x1E],ax
               ;set date and time
                         mov al,0bh
                         out 70h,al
                         xor ax,ax
                         in al,71h
                         push ax  ;
                         or al,00000100b ;set not DBC
                         push ax
                         mov al,0bh
                         out 70h,al      ;conf reg
                         pop ax
                         out 71h,al      ;set register
                     ;year  last 2
                         xor ax,ax
                         mov al,09h
                         out 70h,al
                         in al,71h      ;read year
                         mov [ss:bp-2],ax
                    ;month
                         xor ax,ax
                         mov al,08h
                         out 70h,al
                         in al,71h      ;read month
                         mov cl,0x4
                         shl WORD[ss:bp-2],cl
                         add WORD[ss:bp-2],ax
                    ;day
                         xor ax,ax
                         mov al,07h
                         out 70h,al
                         in al,71h      ;read day
                         mov cl,0x5
                         shl WORD[ss:bp-2],cl
                         add WORD[ss:bp-2],ax

                     ;hour
                         xor ax,ax
                         mov al,04h
                         out 70h,al
                         in al,71h      ;read hour
                         mov WORD[ss:bp-4],ax
                    ;min
                         xor ax,ax
                         mov al,02h
                         out 70h,al
                         in al,71h      ;read min
                         mov cl,0x6
                         shl WORD[ss:bp-4],cl
                         add WORD[ss:bp-4],ax
                    ;sec
                         xor ax,ax
                         mov al,00h
                         out 70h,al
                         in al,71h      ;read sec
                         mov cl,0x5
                         shl WORD[ss:bp-4],cl
                         add WORD[ss:bp-4],ax

                        mov al,0bh
                        out 70h,al      ;conf reg
                        pop ax
                        out 71h,al      ;reset register
               ;set date and time
               cmp BYTE[cs:di+26d],0
               jne CreateTimeSeted
                   mov ax,WORD[ss:bp-2]
                   mov WORD[cs:si+0x10],ax
                   mov ax,WORD[ss:bp-4]
                   mov WORD[cs:si+0x0E],ax
               CreateTimeSeted:
                   mov ax,WORD[ss:bp-2] ;DATE
                   mov WORD[cs:si+0x12],ax  ;Last access
                   cmp BYTE[cs:di+15d],0x01
                       je timeSeted
                   mov WORD[cs:si+0x18],ax
                   mov ax,WORD[ss:bp-4]
                   mov WORD[cs:si+0x16],ax
                 timeSeted:
         justDeleteinGfile:
                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]
                    push ds
                    push cs
                    pop ds
                    mov dx,BufferForDIR
                      call writeInDrive
                    pop ds
                    jmp reloadSteck3eh
               Erroe13eh: ;no such desc
                 stc
                 mov ax,1
                     push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret
         reloadSteck3eh:

               mov sp,bp
               pop bp
               pop dx
               pop ds
               pop cx
               pop cx
               pop di
               pop si
               pop [cs:offseOfDir]
               pop bx
               pop [cs:LBAofDIR]
                readIntoBuff BufferForDIR,[cs:offseOfDir],[cs:LBAofDIR],cs
          ;;;;
                    iret


_next3bh:     cmp ah,3bh;cd
              jne _next3fh
                  push [cs:LBAofDIR]
                  push [cs:offseOfDir]
                  push bx
                  push ax
                  push ds
                  push dx;bp+8
                  push si;bp+6
                  push di;bp+4
                  push cx;bp+2
                  push bp;new bp
                  ;nex bp-1->bp-2->...bp-11
                  mov bp,sp
                  sub sp,11d
                  mov si,dx

                readPAth:
                     cmp BYTE[ds:si],'\'
                     jne notRoot

                        mov ax,[cs:First_Data_Sect]
                        sub ax,[cs:RootDirSectors]
                        mov [cs:LBAofDIR],ax
                        mov [cs:offseOfDir],0
                        readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs

                        cmp BYTE[ds:si+1],0
                          je endOf3bh
                          jmp itStart
                  notRoot:
                     dec si
                     cmp [cs:offseOfDir],0
                     je itStart
                        mov [cs:offseOfDir],0
                        push ax
                        readIntoBuff BufferForDIR,[cs:LBAofDIR],0 ,cs
                        pop ax


                  itStart:
                     inc si
                     mov di,0
                     clear:
                        mov BYTE[bp+di-11d],' '
                        inc di
                     cmp di,11d
                         jne clear
                     ;dec di
                     readNSym:
                        mov al,BYTE[ds:si]
                        call ToUpperCase
                        inc si
                        cmp al,'\'
                            je go1
                        cmp al,0
                            je go1
                        mov BYTE [ss:bp+di-12d],al
                        dec di
                     jmp readNSym
                  go1:
                     dec si
                     push si
                     push di
                     go:
                        mov cx,16d

                        mov bx,BufferForDIR
                        sub bx,0x20
                    chekAllDir:
                        add bx,0x20
                        mov si,0
                        push cx
                        mov cx,11d
                        mov di,11d
                        check:
                              mov al,BYTE[cs:bx+si]
                              mov ah,BYTE[ss:bp+di-12d]
                              cmp al,0
                                  je ERRORDirPath
                              cmp al,ah
                                  jne shift
                                 inc si
                                 dec di
                        loop check
                        mov ax,[cs:bx+0x1a];si--11  cluster
                        cmp ax,0
                            jne NotRootAgain
                            mov ax,[cs:First_Data_Sect]
                            sub ax,[cs:RootDirSectors]
                            jmp gg
                    NotRootAgain:
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                      gg:
                        mov [cs:LBAofDIR],ax
                        readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
                        mov [cs:offseOfDir],0
                        pop cx
                        pop di
                        pop si

                        cmp BYTE[ds:si],0
                        jne itStart
                endOf3bh:
                        mov sp, bp
                        pop bp
                        pop cx
                        pop di
                        pop si
                        pop dx
                        pop ds
                        pop ax
                        pop bx
                        pop ax
                        pop ax
                        clc
                        iret



               shift:
                        pop cx
                        loop chekAllDir

                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]

                  cmp ax,[cs:First_Data_Sect]
                        jae notRootDirectory3bh
                        inc ax
                        cmp ax,[cs:First_Data_Sect]
                            je  ERRORDirPath
                            inc [cs:offseOfDir]
                            readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                            jmp go
                   notRootDirectory3bh:
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
                    call findNextCl
                    cmp ax,0xFFFF
                    je ERRORDirPath
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                    mov si,ax
                    sub si,[cs:LBAofDIR]
                    mov [offseOfDir],si
                    push ax
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                    pop ax
                    jmp go
              ERRORDirPath:
                    mov sp, bp
                        pop bp
                        pop cx
                        pop di
                        pop si
                        pop dx
                        pop ds
                        pop ax
                        pop bx
                    pop [cs:offseOfDir]
                    pop [cs:LBAofDIR]
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                    mov ax,01
                    stc
                    push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

              iret

;set DEF dir
;create DIR
;delet DIR

;start programm

_next3fh:  cmp ah,3fh; read from file
           jne _next40h
           cmp bx,20d
                   jae Erroe13fh  ; no such desc
               cmp BYTE[cs:bx+JobTable],0
                   jne Erroe13fh
           push [cs:LBAofDIR]
           push [cs:offseOfDir]
           push bx ;bp+A
           push ds ;bp+8
           push dx ;bp+6
           push ax ;bp+4
           push cx ;bp+2
           push bp ;bp
           mov bp,sp
           sub sp,20


           mov WORD[ss:bp-2],cx
           mov di,dx
           mov [ss:bp-16],dx
   ;0-10-name  11-4-size  15-1-attr 16-2-segm_Dir  18-2-num_inDir  20-4-pointer
           xor dx,dx
           mov ax,bx
           mov cx,27d
           mul cx
           mov bx,ax
           add bx,FBCTable
           mov [bp-20],bx
           cmp BYTE[cs:bx+15d],0x10
               je Erroe23fh

           mov ax,[ss:bp+2]                    ;ax
           mov si,WORD[cs:bx+20d];l
           mov di,WORD[cs:bx+22d];h

           add si,ax
           adc di,0

           cmp di,WORD[cs:bx+13d]
               jb NotOverFlow
               cmp si,WORD[cs:bx+11d]
                   jbe NotOverFlow
                     mov cx,WORD[cs:bx+13d];h
                     mov dx,WORD[cs:bx+11d];l
                     sub si,dx
                     sbb di,cx
                     sub ax,si ;cut part
                     cmp ax,0
                         je endOf3fd
                     mov WORD[ss:bp-2],ax ;new size of read byts        ;ax
           NotOverFlow:
           ;ax
             xor dx,dx
             mov cx,512d
             div cx
             mov WORD[ss:bp-4],ax   ;full
             mov WORD[ss:bp-12],dx  ;part
             ;count first cluster
             ;bp-8-x bp-7-H  bp-6-H  bp-5-L
             mov WORD[ss:bp-8],0
             mov WORD[ss:bp-6],0
             mov ax,WORD[cs:bx+22d]   ;H size
             cmp ax,0
             je countLowPart
       ;-8 -7 -- L
       ;-6 -5 -- H
                ;size H/512
                mov BYTE[ss:bp-7],al
                shr WORD[ss:bp-8],1
                mov WORD[ss:bp-7],ax
                shr WORD[ss:bp-7],1
          countLowPart:
                 ;size L/512   dx - left
                 mov ax,WORD[cs:bx+20d]
                 xor dx,dx
                 mov cx,0x200
                 div cx
                 add WORD[ss:bp-8],ax
                 adc WORD[ss:bp-6],0
                 mov WORD[ss:bp-10],dx ;what left after /
             push ax
             readIntoBuff BufferForDIR,WORD[cs:bx+16d],0,cs
             pop ax
             mov si,WORD[cs:bx+18d]
             add si,BufferForDIR
             mov ax,WORD[cs:si+0x1A];readFirstCl


             mov cx,WORD[ss:bp-8] ;-8 -7 -- L

         findNext:
             cmp cx,0
             je subH
                 call findNextCl
                 cmp ax,0xFFFF
                   je Erroe23fh
                 dec cx
             jmp findNext
           subH:
             cmp WORD[ss:bp-6],0   ;-6 -5 -- H
                 je GoneToCl
                 dec WORD[ss:bp-6]
                 mov cx,0xFFFF
                 call findNextCl
                 cmp ax,0xFFFF
                     je Erroe23fh
                 jmp findNext
          GoneToCl:
                mov WORD[ss:bp-14],ax   ;cluster
                cmp WORD[ss:bp-10],0
                    je readInLoop
                sub ax,0x02;N-2
                push cx
                mov cl,[cs:BPB_SecPerClus]
                dec cl
                shl ax,cl;(N-2)*2^0
                pop cx
                add ax,Word[cs:First_Data_Sect]   ;lba
                mov cx,WORD[ss:bp-10] ;left address
                mov dx,0x200
                sub dx,cx
                mov cx,dx  ;ammount of left read bytes

                    readIntoBuff BufferForRead,ax,0,cs
                    sub WORD[ss:bp-12],cx ;
                    sbb WORD[ss:bp-4],0
                    mov si,BufferForRead ;from
                    add si,WORD[ss:bp-10];from which byte
                    mov di,WORD[ss:bp-16];to
                    push es
                    push ds

                    push WORD[ss:bp+8]
                    pop es ;to

                    push cs
                    pop ds ;from

                    rep movsb ;removing
                    pop ds
                    pop es
                    mov WORD[ss:bp-16],di
                    mov ax,WORD[ss:bp-14]
                    call findNextCl
                   ; jmp
                readInLoop:
                    mov cx,WORD[ss:bp-4]
                    mov bx,WORD[ss:bp-16]
                    push WORD[ss:bp+8]
                    pop ds
                readWritLoop:
                    cmp cx,0
                      je readLastPart
                        mov WORD[ss:bp-14],ax
                        ;push ax
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                        readIntoBuff bx,ax,0,ds
                        add bx,0x200
                        mov ax,WORD[ss:bp-14]
                       ; pop ax
                        call findNextCl
                        dec cx
                        add WORD[ss:bp-16],0x200
                        jmp readWritLoop
                 readLastPart:
                    mov WORD[ss:bp-14],ax
                    sub ax,0x02;N-2
                    push cx
                    mov cl,[cs:BPB_SecPerClus]
                    dec cl
                    shl ax,cl;(N-2)*2
                    pop cx
                    add ax,Word[cs:First_Data_Sect]
                    cmp WORD[ss:bp-12], 0
                     je nothingLeft
                      readIntoBuff BufferForRead,ax,0,cs
                      mov cx,WORD[ss:bp-12]
                      mov si,BufferForRead
                      mov di,WORD[ss:bp-16]
                      push es
                      push ds

                      push WORD[ss:bp+8]
                      pop es ;to

                      push cs
                      pop ds ;from

                      rep movsb ;removing
                      pop ds
                      pop es
               nothingLeft:
                     mov bx,[bp-20]
                     mov ax,WORD[ss:bp-2] ;real read bytes
                     add WORD[cs:bx+20d],ax
                     adc WORD[cs:bx+22d],0
                     jmp endOf3fd
        Erroe13fh:;  file open write only
               mov ax,1
               stc
                    push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

        Erroe23fh:  ;wrong attr
               mov ax,2
               stc
               push bp
                    mov sp,bp
                    pop bp ;bp
                    pop cx ;bp+2
                    pop dx ;bp+6
                    pop dx ;bp+4
                    pop ds ;bp+8
                    pop bx ;bp+A
                    pop [cs:offseOfDir]
                    pop [cs:LBAofDIR]
                    push ax
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                    pop ax
                    push bp
                    mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret
                endOf3fd:

                    mov sp,bp
                    pop bp ;bp
                    pop cx ;bp+2
                    pop dx ;bp+6
                    pop dx ;bp+4
                    pop ds ;bp+8
                    pop bx ;bp+A
                    pop [cs:offseOfDir]
                    pop [cs:LBAofDIR]
                    push ax
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                    pop ax
                iret

_next40h:
           cmp ah,40h; write in file
           jne _next42h
           cmp bx,20d
                   jae Erroe140h  ; no such desc
               cmp BYTE[cs:bx+JobTable],0
                   jne Erroe140h
           push [cs:LBAofDIR]
           push [cs:offseOfDir]
           push bx ;bp+A
           push ds ;bp+8
           push dx ;bp+6
           push ax ;bp+4
           push cx ;bp+2
           push bp ;bp
           mov bp,sp
           sub sp,20

           mov WORD[ss:bp-2],cx
           mov di,dx
           mov [ss:bp-16],dx
   ;0-10-name  11-4-size  15-1-attr 16-2-segm_Dir  18-2-num_inDir  20-4-pointer
           xor dx,dx
           mov ax,bx
           mov cx,27d
           mul cx
           mov bx,ax
           add bx,FBCTable
           mov [bp-20],bx
           cmp BYTE[cs:bx+15d],0x10
               je Erroe240h

           mov ax,[ss:bp+2]                    ;ax
           mov si,WORD[cs:bx+20d];l
           mov di,WORD[cs:bx+22d];h

           add si,ax
           adc di,0

           cmp WORD[ss:bp+2],0
               jne dontCheckCutting
               cmp di,WORD[cs:bx+13d]
                   ja dontCheckCutting
                   cmp si,WORD[cs:bx+11d]
                       jae dontCheckCutting
                       mov WORD[cs:bx+13d],di;h
                       mov WORD[cs:bx+11d],si;l
                       mov WORD[ss:bp-2],ax
                       jmp NotOverFlow40h
    dontCheckCutting:
           cmp di,WORD[cs:bx+13d]
               jb NotOverFlow40h
               cmp si,WORD[cs:bx+11d]
                   jbe NotOverFlow40h
                     mov WORD[cs:bx+13d],di;h
                     mov WORD[cs:bx+11d],si;l
                     mov WORD[ss:bp-2],ax
           NotOverFlow40h:
           ;ax
             xor dx,dx
             mov cx,512d
             div cx
             mov WORD[ss:bp-4],ax
             mov WORD[ss:bp-12],dx
             ;count first cluster
             ;bp-8-x bp-7-H  bp-6-H  bp-5-L
             mov WORD[ss:bp-8],0
             mov WORD[ss:bp-6],0
             mov ax,WORD[cs:bx+22d]   ;H size
             cmp ax,0
             je countLowPart40h
       ;-8 -7 -- L
       ;-6 -5 -- H
                ;size H/512
                mov BYTE[ss:bp-7],al
                shr WORD[ss:bp-8],1
                mov WORD[ss:bp-7],ax
                shr WORD[ss:bp-7],1
          countLowPart40h:
                 ;size L/512   dx - left
                 mov ax,WORD[cs:bx+20d]
                 xor dx,dx
                 mov cx,0x200
                 div cx
                 add WORD[ss:bp-8],ax
                 adc WORD[ss:bp-6],0
                 mov WORD[ss:bp-10],dx ;what left after /
             push ax
             readIntoBuff BufferForDIR,WORD[cs:bx+16d],0,cs
             pop ax
             mov si,WORD[cs:bx+18d]
             add si,BufferForDIR

             mov ax,WORD[cs:si+0x1A];readFirstCl
             mov WORD[ss:bp-14],ax

             mov cx,WORD[ss:bp-8] ;-8 -7 -- L
         findNext40h:
             cmp cx,0
             je subH40h
                 mov WORD[ss:bp-14],ax
                 call findNextCl
                 cmp ax,0xFFFF
                   jne readNextCl40h
                   mov ax,WORD[ss:bp-14]
                   call findEmptyCluster
              readNextCl40h:
                 dec cx
             jmp findNext40h
           subH40h:
             cmp WORD[ss:bp-6],0   ;-6 -5 -- H
                 je GoneToCl40h
                 dec WORD[ss:bp-6]
                 mov cx,0xFFFF
                 mov WORD[ss:bp-14],ax
                 call findNextCl
                 cmp ax,0xFFFF
                   jne readNextCl240h
                   mov ax,WORD[ss:bp-14]
                   call findEmptyCluster
              readNextCl240h:
                 jmp findNext40h
          GoneToCl40h:
                cmp WORD[ss:bp+2],0
                   je cutClusterthAfter40h
                mov WORD[ss:bp-14],ax
                cmp WORD[ss:bp-10], 0
                     je WriteInLoop40h
                sub ax,0x02;N-2
                push cx
                mov cl,[cs:BPB_SecPerClus]
                dec cl
                shl ax,cl;(N-2)*2
                pop cx
                add ax,Word[cs:First_Data_Sect]
                mov cx,WORD[ss:bp-10] ;left address
                mov dx,0x200
                sub dx,cx
                mov cx,dx


                    readIntoBuff BufferForWrite,ax,0,cs
                    sub WORD[ss:bp-12],cx
                    sbb WORD[ss:bp-4],0
                    mov di,BufferForWrite;to
                    add di,WORD[ss:bp-10]
                    mov si,WORD[ss:bp-16] ;from

                    push es ;to
                    push ds ;from

                    push WORD[ss:bp+8]
                    pop ds ;from

                    push cs
                    pop es

                    rep movsb ;removing

                    pop ds
                    pop es

                    WriteIntoBuff BufferForWrite,ax,0,cs

                    mov WORD[ss:bp-16],si ;nev address
                    mov ax,WORD[ss:bp-14]
                    mov WORD[ss:bp-14],ax
                    call findNextCl
                     cmp ax,0xFFFF
                         jne readNextCl340h
                         mov ax,WORD[ss:bp-14]
                         call findEmptyCluster
                         mov WORD[ss:bp-14],ax
              readNextCl340h:
                   ; jmp
                WriteInLoop40h:

                    mov cx,WORD[ss:bp-4]
                    mov bx,WORD[ss:bp-16]
                    push WORD[ss:bp+8]
                    pop ds
                readWritLoop40h:
                    mov WORD[ss:bp-14],ax
                    cmp cx,0
                      je writLastPart40h
                        mov WORD[ss:bp-14],ax
                      ;  push ax
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                        WriteIntoBuff bx,ax,0,ds
                        add bx,0x200
                        mov WORD[ss:bp-16],bx
                        mov ax,WORD[ss:bp-14]
                       ; pop ax
                        mov WORD[ss:bp-14],ax
                        call findNextCl
                             cmp ax,0xFFFF
                             jne readNextCl440h
                             mov ax,WORD[ss:bp-14]
                             call findNextCl
                             mov WORD[ss:bp-14],ax
              readNextCl440h:
                        dec cx
                        jmp readWritLoop40h
                 writLastPart40h:
                        mov ax,WORD[ss:bp-14]
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                    readIntoBuff BufferForWrite,ax,0,cs
                    readIntoBuff BufferForWrite,ax,0,cs
                    mov cx,WORD[ss:bp-12]
                    mov di,BufferForWrite
                    mov si,WORD[ss:bp-16]

                    push es ;to
                    push ds ;from

                    push WORD[ss:bp+8]
                    pop ds ;from

                    push cs
                    pop es

                    rep movsw ;removing
                    pop ds
                    pop es

                    WriteIntoBuff BufferForWrite,ax,0,cs

                    mov bx,[bp-20]
                    mov ax,WORD[ss:bp-2] ;readed
                    add WORD[cs:bx+20d],ax
                    adc WORD[cs:bx+22d],0
                    jmp endOf40h
        cutClusterthAfter40h:
                  ;clear part of cluster
                  ;delet everything after thist cluster
                  ;return zero
                mov WORD[ss:bp-14],ax
                sub ax,0x02;N-2
                push cx
                mov cl,[cs:BPB_SecPerClus]
                dec cl
                shl ax,cl;(N-2)*2
                pop cx
                add ax,Word[cs:First_Data_Sect]
                mov cx,WORD[ss:bp-10] ;left address
                mov dx,0x200
                sub dx,cx
                mov cx,dx
                cmp WORD[ss:bp-10], 0
                    je WriteInLoop40h
                    readIntoBuff BufferForWrite,ax,0,cs
                    sub WORD[ss:bp-12],cx
                    sbb WORD[ss:bp-4],0
                    add di,WORD[ss:bp-10]
                  clearLeft:
                        mov BYTE[cs:di+BufferForWrite],0
                        inc di
                        cmp di,0x200
                            jne clearLeft
                    WriteIntoBuff BufferForWrite,ax,0,cs

                    mov ax,WORD[ss:bp-14]
                    call findNextCl
                 cmp ax,0xFFFF
                    je ALLdone
                    mov ax,WORD[ss:bp-14]
                    call deleteClustersFromThisIncluding
                 ALLdone:
                     mov ax,0
                     jmp endOf40h
        Erroe140h:;  file open write only
               mov ax,1
               stc
               push bp
               mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

        Erroe240h:  ;wrong attr
               mov ax,2
               stc
               mov sp,bp
                    pop bp ;bp
                    pop cx ;bp+2
                    pop dx ;bp+6
                    pop dx ;bp+4
                    pop ds ;bp+8
                    pop bx ;bp+A
                    pop [cs:offseOfDir]
                    pop [cs:LBAofDIR]
                    push ax
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                    pop ax
                    push bp
               mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

                endOf40h:

                    mov sp,bp
                    pop bp ;bp
                    pop cx ;bp+2
                    pop dx ;bp+6
                    pop dx ;bp+4
                    pop ds ;bp+8
                    pop bx ;bp+A
                    pop [cs:offseOfDir]
                    pop [cs:LBAofDIR]
                    push ax
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                    pop ax
                iret


_next42h:
           cmp ah,42h; lseek
           jne _next41h
           cmp bx,20d
                   jae Erroe13fh  ; no such desc
               cmp BYTE[cs:bx+JobTable],0
                   jne Erroe142h

           push bx ;bp+A
           push ds ;bp+8
           push dx ;bp+6
           push ax ;bp+4
           push cx ;bp+2
           push bp ;bp
           mov bp,sp

           ;0-10-name  11-4-size  15-1-attr 16-2-segm_Dir  18-2-num_inDir  20-4-pointer
           xor dx,dx
           mov ax,bx
           mov cx,27d
           mul cx
           mov bx,ax
           mov ax,WORD[ss:bp+4]
           cmp al,0
            jne cmp42_1
            mov WORD[cs:bx+FBCTable+20d],0
            mov WORD[cs:bx+FBCTable+22d],0
            jmp addTime
         cmp42_1:
             cmp al,1
             jmp addTime
              jne cmp42_2
             cmp42_2:
                 cmp al,2
                 ;setting last address
                 mov ax,WORD[cs:bx+FBCTable+11d]
                 mov WORD[cs:bx+FBCTable+20d],ax
                 mov ax,WORD[cs:bx+FBCTable+13d]
                 mov WORD[cs:bx+FBCTable+22d],ax
                 sub WORD[cs:bx+FBCTable+20d],1
                 sbb WORD[cs:bx+FBCTable+22d],0
                 jmp addTime
                 jne Erroe142h
        addTime:
            mov ax,WORD[bp+6]
            mov cx,WORD[bp+2]
            add WORD[cs:bx+FBCTable+20d],ax
            adc WORD[cs:bx+FBCTable+22d],cx
            mov ax,WORD[cs:bx+FBCTable+20d]
            mov dx,WORD[cs:bx+FBCTable+22d]
            jmp end42h
      Erroe142h:  ;wrong al
            mov ax,1
             mov bp,sp
           pop bp
           pop cx
           pop ds
           pop ds
           pop ds
           pop bx
                mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret
       end42h:
           mov bp,sp
           pop bp
           pop cx
           pop ds
           pop ds
           pop ds
           pop bx
           iret

_next41h:
           cmp ah,41h; delet file
               jne _next39h
           push bx
           push ds
           push [cs:LBAofDIR]  ;12
           push [cs:offseOfDir];10
           push cx ;8
           push ax ;6
           push si ;4
           push dx ;2
           push bp ;
           mov bp,sp
           sub sp,10

           mov ah,3dh
           mov al,0x01
           int 21h
               jc Erroe141h

               mov WORD[ss:bp-2],ax ;descr
               mov bx,ax
               mov BYTE[cs:bx+JobTable],0xff

               mov di,BufferForDIR
               mov ax,27d   ;fbc
               xor dx,dx
               mul bx
               mov bx,ax ;desc
               add bx,FBCTable
               mov ax,[cs:bx+16d]
               mov [bp-4],ax
               readIntoBuff BufferForDIR,ax,0,cs
               add di,[cs:bx+18d] ;num in Dir

               mov ax,[cs:di+0x1A] ;cluster   in parent
               mov BYTE[cs:di],0xE5

               call deleteClustersFromThisIncluding
               mov ax,[bp-4]
               WriteIntoBuff BufferForDIR,ax,0,cs
            end41h:
               mov sp,bp
               pop bp
               pop dx
               pop si
               pop cx
               pop cx
               pop [cs:LBAofDIR];off
               pop [cs:LBAofDIR]
               pop ds
               pop bx
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
               iret
            Erroe141h:
                pop cx
                pop cx
                pop cx
                pop cx
                pop cx
                readIntoBuff BufferForDIR,[ss:bp+12],0,cs
                stc
                mov ax,1
                mov sp,bp
               pop bp
               pop dx
               pop si
               pop cx
               pop cx
               pop [cs:LBAofDIR];off
               pop [cs:LBAofDIR]
               pop ds
               pop bx
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
                  push bp
                  mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

_next39h:
           cmp ah,39h; Create Dir
           jne _next3ah
           push bx
           push ds
           push [cs:LBAofDIR]  ;11
           push [cs:offseOfDir];10
           push cx ;8
           push ax ;6
           push si ;4
           push dx ;2
           push bp ;
           mov bp,sp
           sub sp,10
           mov cx,0x10

           jmp markForDIRCr ;return ax  - descr  ,in steck old LBA and OFF
        DIRCreated:
               jc Erroe139h

               pop cx;off
               pop cx;LBA
               pop dx
               pop ds

               mov WORD[ss:bp-2],ax ;descr
               mov bx,ax
               mov BYTE[cs:bx+JobTable],0xff
               mov ax,[cs:LBAofDIR]  ;where locatad dir in par dir
               mov WORD[ss:bp-4],ax
               mov ax,[offseOfDir]
               mov WORD[ss:bp-6],ax

               mov si,BufferForWrite
               mov cx,256
           clearCluster:
                 mov WORD[cs:si],0
                 add si,2
                 loop clearCluster
               mov si,BufferForWrite  ; child dir
               mov ax,27d   ;fbc
               xor dx,dx
               mul bx
               mov bx,ax ;desc
               add bx,FBCTable
               mov di,[cs:bx]
               mov di,[cs:bx+18d] ;num in Dir
               add di,BufferForDIR
               mov BYTE[cs:si],'.' ;name in new dir
               push si
               push cx
               mov cx,10d
               spaceDotN:
                   mov BYTE[cs:si+1],' '
                   inc si
                   loop spaceDotN
               pop cx
               pop si
               mov ax,[cs:di+0x1A] ;cluster   in parent
               mov [cs:si+0x1A],ax  ;cl in dot
               mov BYTE[cs:si+0xB],0x10 ;atr
               mov BYTE[cs:si+0x2B],0x10
                ;set date and time
                         mov al,0bh
                         out 70h,al
                         xor ax,ax
                         in al,71h
                         push ax  ;
                         or al,00000100b ;set not DBC
                         push ax
                         mov al,0bh
                         out 70h,al      ;conf reg
                         pop ax
                         out 71h,al      ;set register
                     ;year  last 2
                         xor ax,ax
                         mov al,09h
                         out 70h,al
                         in al,71h      ;read year
                         mov [ss:bp-8],ax
                    ;month
                         xor ax,ax
                         mov al,08h
                         out 70h,al
                         in al,71h      ;read month
                         mov cl,0x4
                         shl WORD[ss:bp-8],cl
                         add WORD[ss:bp-8],ax
                    ;day
                         xor ax,ax
                         mov al,07h
                         out 70h,al
                         in al,71h      ;read day
                         mov cl,0x5
                         shl WORD[ss:bp-8],cl
                         add WORD[ss:bp-8],ax

                     ;hour
                         xor ax,ax
                         mov al,04h
                         out 70h,al
                         in al,71h      ;read hour
                         mov WORD[ss:bp-10d],ax
                    ;min
                         xor ax,ax
                         mov al,02h
                         out 70h,al
                         in al,71h      ;read min
                         mov cl,0x6
                         shl WORD[ss:bp-10d],cl
                         add WORD[ss:bp-10d],ax
                    ;sec
                         xor ax,ax
                         mov al,00h
                         out 70h,al
                         in al,71h      ;read sec
                         mov cl,0x5
                         shl WORD[ss:bp-10d],cl
                         add WORD[ss:bp-10d],ax

                        mov al,0bh
                        out 70h,al      ;conf reg
                        pop ax
                        out 71h,al      ;reset register
               ;set date and time
               mov ax,WORD[ss:bp-8]
               ;in Parent DIR
               mov [cs:di+0x10],ax
               mov [cs:di+0x12],ax
               mov [cs:di+0x18],ax
               ;in new DIR
               mov [cs:si+0x10],ax
               mov [cs:si+0x12],ax
               mov [cs:si+0x18],ax

               mov ax,WORD[ss:bp-10d]
               ;in Parent DIR
               mov [cs:di+0x0e],ax
               mov [cs:di+0x16],ax
               ;in new DIR
               mov [cs:si+0x0e],ax
               mov [cs:si+0x16],ax

               ;parent cluster in new cluster
               mov BYTE[cs:si+0x20],'.'
               mov BYTE[cs:si+0x21],'.'
               push si
               push cx
               mov cx,9d
               spaceDotN23:
                   mov BYTE[cs:si+0x22],' '
                   inc si
                   loop spaceDotN23
               pop cx
               pop si

               WriteIntoBuff BufferForDIR ,[cs:LBAofDIR],[cs:offseOfDir],cs ;rewhrite in parent
               mov WORD[offseOfDir],0
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs ; read parent 1 cluster
               pop ax
               mov ax,[cs:LBAofDIR]
             cmp ax,[cs:First_Data_Sect]
                 jae tt
                 mov WORD[cs:si+0x30],0x298C
                 mov WORD[cs:si+0x32],0x298C
                 mov WORD[cs:si+0x38],0x298C
                 mov WORD[cs:si+0x2e],0x9DF0
                 mov WORD[cs:si+0x36],0x9DF0
                 mov WORD[cs:si+0x3A],0
                 jmp ttt

            tt:                                 ;
               mov di,BufferForDIR
               mov ax,[cs:di+0x10];date
               mov [cs:si+0x30],ax
               mov [cs:si+0x32],ax
               mov [cs:si+0x38],ax

               mov ax,[cs:di+0x0e];time
               mov [cs:si+0x2e],ax
               mov [cs:si+0x36],ax

               mov BYTE[cs:si+0x2B],0x10 ;atr

               mov ax,[cs:LBAofDIR]
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
               mov [cs:si+0x3A],ax
            ttt:
               mov ax,[cs:si+0x1A]
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]

               WriteIntoBuff BufferForWrite,ax,0,cs
               readIntoBuff BufferForDIR,[ss:bp+12],0,cs

         end39h:
               mov sp,bp
               pop bp
               pop dx
               pop si
               pop cx
               pop cx
               pop [cs:LBAofDIR];off
               pop [cs:LBAofDIR]
               pop ds
               pop bx
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
               iret



         Erroe139h:
              pop cx
              pop cx
              pop cx
              pop cx
              stc
              mov sp,bp
               pop bp
               pop dx
               pop si
               pop cx
               pop cx
               pop [cs:LBAofDIR];off
               pop [cs:LBAofDIR]
               pop ds
               pop bx
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
              push bp
              mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

_next3ah:
           cmp ah,3ah; Delete Dir
           jne _next4eh
           push bx
           push ds
           push [cs:LBAofDIR]  ;12
           push [cs:offseOfDir];10
           push cx ;8
           push ax ;6
           push si ;4
           push dx ;2
           push bp ;
           mov bp,sp
           sub sp,10
           mov cx,0x10

           jmp markForDIRDel ;return ax  - descr  ,in steck old LBA and OFF
           DIRDel:
               jc Erroe13ah

               pop cx;off
               pop bx
               pop cx;LBA
               pop dx
               pop ds

               mov WORD[ss:bp-2],ax ;descr
               mov bx,ax
               mov BYTE[cs:bx+JobTable],0xff
               mov ax,[LBAofDIR]  ;where locatad dir in par dir
               mov WORD[ss:bp-4],ax
               mov ax,[offseOfDir]
               mov WORD[ss:bp-6],ax


               mov di,BufferForDIR
               mov ax,27d   ;fbc
               xor dx,dx
               mul bx
               mov bx,ax ;desc
               add bx,FBCTable
               add di,[cs:bx+18d] ;num in Dir

               mov ax,[cs:di+0x1A] ;cluster   in parent
               mov BYTE[cs:di],0xE5
               push ax
               call deleteClustersFromThisIncluding
               pop ax
               WriteIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
            end3ah:
               mov sp,bp
               pop bp
               pop dx
               pop si
               pop cx
               pop cx
               pop [cs:LBAofDIR];off
               pop [cs:LBAofDIR]
               pop ds
               pop bx
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
               iret
            Erroe13ah:
                pop cx
                pop cx
                pop cx
                pop cx
                pop cx
                stc
                mov ax,1
                mov sp,bp
               pop bp
               pop dx
               pop si
               pop cx
               pop cx
               pop [cs:LBAofDIR];off
               pop [cs:LBAofDIR]
               pop ds
               pop bx
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],0,cs
               push bp
                   mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

_next4eh:
           cmp ah,4eh; find first like
           jne _next4fh
               push ds
               push dx
               push [cs:LBAofDIR]
               push bx
               push [cs:offseOfDir]
               push si
               push di
               push cx

               mov bx,dx
               mov si,fileSearchName4eaf
             writeFname4eh:
                   mov cl,BYTE[ds:bx]
                   inc bx
                   mov BYTE[cs:si],cl
                 cmp cl,0
                 je cont4eh
                   inc si
                 jmp writeFname4eh
            cont4eh:
               push cs
               pop  ds
               xor ah,ah
               push ax  ;bp+6
               push cs  ;bp+4
               push fileSearchName4eaf   ;bp+2,3                              num Entr  num of decoder
               push bp ;sp=bp new bp->bp-1->bp-2->...bp-11->bp-12,13  ->bp-15,16
               mov bp,sp
               mov dx,fileSearchName4eaf
               sub sp,16d ;bp-13 if push sp->bp-14
               mov di,dx
               mov bx,dx
               mov si,0

               ;macro
               translate 4eh,4eh
               mov bx,[bp+2]
                cmp BYTE[ds:bx],0
                jne notDefaultDir
                mov bx,0
                mov ax,[cs:LBAofDIR]
                cmp [cs:offseOfDir],0
                jne wrLBADEFDIR
                jmp checkDirForEmpty

              wrLBADEFDIR:
                mov [cs:LBAofDIR],ax
                mov [cs:offseOfDir],0
                readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                jmp checkDirForEmpty
       notDefaultDir:
                mov dx,fileSearchName4eaf
                push cs
                pop ds
                mov ah,3bh
                int 21h
                mov bx,0

                jc Erroe24eh
                checkDirForEmpty:
                        mov cx,16d
                        add bx,BufferForDIR
                        sub bx,0x20


                   checkForThatFile:
                        add bx,0x20
                        mov si,11d
                        mov di,0                     ;check zero,c1,e5
                        cmp BYTE[cs:bx+di],0xc1
                            je notThatFile
                            cmp BYTE[cs:bx+di],0xE5
                                  je notThatFile
                              cmp BYTE[cs:bx+di],0
                                  je Erroe24eh
                   checkInThatFile:

                        mov ah,BYTE[ss:bp+si-12d]
                        cmp ah,'*'
                            jne c
                            cmp si,11
                              jne a
                              mov si,3
                              mov di,8
                              jmp checkInThatFile
                            a:
                              jmp found

                   c:
                        cmp ah,'?'
                            jne cmpWNext
                            inc di
                            dec si
                            cmp si,0
                                je found
                                jmp checkInThatFile

                   cmpWNext:
                        cmp BYTE[cs:bx+di],ah
                        jne notThatFile
                            inc di
                            dec si
                        cmp si,0
                        je found
                        jmp checkInThatFile

                  notThatFile:
                    loop checkForThatFile

                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]

                       cmp ax,[cs:First_Data_Sect]
                        jae notRootDirectory4eh
                        inc ax
                        cmp ax,[cs:First_Data_Sect]
                            je  Erroe24eh
                            inc [cs:offseOfDir]
                            readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                            mov bx,0
                            jmp checkDirForEmpty
                  notRootDirectory4eh:
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
                    call findNextCl
                    cmp ax,0xFFFF
                    je Erroe24eh
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]
                    mov si,ax
                    sub si,[cs:LBAofDIR]
                    mov [cs:offseOfDir],si
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],ds
                    mov bx,0
                    jmp checkDirForEmpty

                   found:
                        mov ax,WORD[cs:DTAAdr+2]
                        mov ds,ax
                        mov di,WORD[cs:DTAAdr]

                        mov WORD[ds:di],bx ;adr in dir
                        mov si,11d
                     writeSearchNINDTA:
                        mov ah,BYTE[ss:bp+si-12d]
                        mov BYTE[ds:di+2],ah
                        dec si
                        inc di
                        cmp si,0
                          jne writeSearchNINDTA

                        mov di,WORD[cs:DTAAdr]
                        mov si,0d

                     writeNFINDTA:
                        mov ah,BYTE[cs:bx+si]
                        cmp ah,' '
                        je writedNF
                        mov BYTE[ds:di+15],ah
                        inc si
                        inc di
                        cmp si,8
                          jne writeNFINDTA
                     writedNF:
                        mov BYTE[ds:di+15],'.'
                        inc di
                        mov si,8
                     writeNSINDTA:
                        mov ah,BYTE[cs:bx+si]
                        cmp ah,' '
                            je writedNS
                            mov BYTE[ds:di+15],ah
                            inc si
                            inc di
                            cmp si,11
                                jne writeNSINDTA
                      writedNS:
                        mov BYTE[ds:di+15],0
                        inc si
                        inc di
                        cmp si,11
                                jb writedNS

                        mov di,WORD[cs:DTAAdr]

                        mov ax,[cs:LBAofDIR]
                        add ax,[cs:offseOfDir]
                        mov WORD[ds:di+13d],ax  ;LBA
                        mov ah,BYTE[cs:bx+0xB];atr
                        mov BYTE[ds:di+28d],ah
                        mov ax,WORD[cs:bx+0x10]  ;date
                        mov WORD[ds:di+29d],ax
                        mov ax,WORD[cs:bx+0x0E]  ;time
                        mov WORD[ds:di+31d],ax
                        mov ax,WORD[cs:bx+0x1C]  ;sizeL
                        mov WORD[ds:di+33d],ax
                        mov ax,WORD[cs:bx+0x1E]  ;sizeH
                        mov WORD[ds:di+35d],ax

               clc


         end4ef:
               mov sp,bp
               pop bp ;
               pop ax ; fname
               pop ax ; cs
               pop ax ;
               pop cx ;
               pop di;
               pop si
               pop [cs:offseOfDir]
               pop bx
               pop [cs:LBAofDIR]
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
               pop dx
               pop ds
               iret
             Erroe14eh:
               nop
               stc

             Erroe24eh:;dont exist
               stc
               mov sp,bp
               pop bp
               pop ax
               pop ax
               pop ax
               pop cx
               pop di
               pop si
               pop [cs:offseOfDir]
               pop bx
               pop [cs:LBAofDIR]
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
               pop dx
               pop ds
               push bp
               mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret

;0-2- num in dir 2-11-name;13-LBA of search dir-2 ;15-13-name;28-1-atr ;29-2-date ; 31-2-time ; 33-4-size  ;

_next4fh:
           cmp ah,4fh; find next Like
           jne _next1ah
               push ds
               push dx
               push [cs:LBAofDIR]
               push bx
               push [cs:offseOfDir]
               push si
               push di
               push cx

               push cs
               pop  ds

               xor ah,ah
               push ax  ;bp+6
               push cs  ;bp+4
               push fileSearchName4eaf   ;bp+2,3                              num Entr  num of decoder
               push bp ;sp=bp new bp->bp-1->bp-2->...bp-11->bp-12,13  ->bp-15,16
               mov bp,sp
               sub sp,16d ;bp-13 if push sp->bp-14
               mov di,dx
               mov bx,dx
               mov si,0

               ;macro
               ;copy text from DTA
                mov ax,WORD[cs:DTAAdr+2]
                mov ds,ax
                mov di,WORD[cs:DTAAdr]
                mov si,11d
            readSNameDTA:
                mov ah,BYTE[ds:di+2]
                mov [ss:bp+si-12d],ah
                dec si
                inc di
               cmp si,0
               jne readSNameDTA
               mov di,WORD[cs:DTAAdr]
               mov ax,WORD[ds:di+13d]
               mov [cs:LBAofDIR],ax
               mov [cs:offseOfDir],0
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               mov bx,WORD[ds:di]
               add bx,0x20;in dir +  BufferForDIR
                checkDirForEmpty4f:

                   checkForThatFile4f:
                        mov si,11d
                        mov di,0
                        cmp BYTE[cs:bx+di],0xc1
                            je notThatFile4f
                            cmp BYTE[cs:bx+di],0xE5
                                  je notThatFile4f
                              cmp BYTE[cs:bx+di],0
                                  je Erroe24fh
                   checkInThatFile4f:

                        mov ah,BYTE[ss:bp+si-12d]
                        cmp ah,'*'
                            jne c4f
                            cmp si,11
                              jne a4f
                              mov si,3
                              mov di,8
                              jmp checkInThatFile4f
                            a4f:
                              jmp found4f

                   c4f:
                        cmp ah,'?'
                            jne cmpWNext4f
                            inc di
                            dec si
                            cmp si,0
                                je found4f
                                jmp checkInThatFile4f

                   cmpWNext4f:
                        cmp BYTE[cs:bx+di],ah
                        jne notThatFile4f
                            inc di
                            dec si
                        cmp si,0
                        je found4f
                        jmp checkInThatFile4f

                  notThatFile4f:
                    add bx,0x20
                    cmp bx,(BufferForDIR+0x200)
                    jb checkForThatFile4f
                    mov bx,BufferForDIR
                    mov ax,[cs:LBAofDIR]
                    add ax,[cs:offseOfDir]
                        cmp ax,[cs:First_Data_Sect]
                        jae notRootDirectory4fh
                        inc ax
                        cmp ax,[cs:First_Data_Sect]
                            je  Erroe24fh
                            inc [cs:offseOfDir]
                            readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
                            add bx,BufferForDIR
                            mov bx,BufferForDIR
                            jmp checkDirForEmpty4f

                notRootDirectory4fh:
                        sub ax,Word[cs:First_Data_Sect]  ;(N-2)*1+offset
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shr ax,cl
                        add ax,0x02
                        pop cx
                    call findNextCl
                    cmp ax,0xFFFF
                     je Erroe24fh
                        sub ax,0x02;N-2
                        push cx
                        mov cl,[cs:BPB_SecPerClus]
                        dec cl
                        shl ax,cl;(N-2)*2
                        pop cx
                        add ax,Word[cs:First_Data_Sect]

                    mov si,ax
                    sub si,[cs:LBAofDIR]
                    mov [cs:offseOfDir],si
                    readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],ds
                    mov bx,BufferForDIR
                    jmp checkDirForEmpty4f

                   found4f:
                        mov ax,WORD[cs:DTAAdr+2]
                        mov ds,ax
                        mov di,WORD[cs:DTAAdr]
                        mov WORD[ds:di],bx ;adr in dir
                        mov si,11d
                     writeSearchNINDTA4f:
                        mov ah,BYTE[ss:bp+si-12d]
                        mov BYTE[ds:di+2],ah
                        dec si
                        inc di
                        cmp si,0
                          jne writeSearchNINDTA4f

                        mov di,WORD[cs:DTAAdr]
                        mov si,0d

                     writeNFINDTA4f:
                        mov ah,BYTE[cs:bx+si]
                        cmp ah,' '
                        je writedNF4f
                        mov BYTE[ds:di+15],ah
                        inc si
                        inc di
                        cmp si,8
                          jne writeNFINDTA4f
                     writedNF4f:
                        mov BYTE[ds:di+15],'.'
                        inc di
                        mov si,8
                     writeNSINDTA4f:
                        mov ah,BYTE[cs:bx+si]
                        cmp ah,' '
                        je writedNS4f
                        mov BYTE[ds:di+15],ah
                        inc si
                        inc di
                        cmp si,11
                          jne writeNSINDTA4f

                writedNS4f:
                        mov BYTE[ds:di+15],0
                        inc si
                        inc di
                        cmp si,11
                                jb writedNS
                        mov di,WORD[cs:DTAAdr]

                        mov ax,[cs:LBAofDIR]
                        add ax,[cs:offseOfDir]
                        mov WORD[ds:di+13d],ax  ;LBA
                        mov ah,BYTE[cs:bx+0xB];atr
                        mov BYTE[ds:di+28d],ah
                        mov ax,WORD[cs:bx+0x10]  ;date
                        mov WORD[ds:di+29d],ax
                        mov ax,WORD[cs:bx+0x0E]  ;time
                        mov WORD[ds:di+31d],ax
                        mov ax,WORD[cs:bx+0x1C]  ;sizeL
                        mov WORD[ds:di+33d],ax
                        mov ax,WORD[cs:bx+0x1E]  ;sizeH
                        mov WORD[ds:di+35d],ax

               clc
         end4fh:
               mov sp,bp
               pop bp
               pop ax
               pop ax
               pop ax
               pop cx
               pop di
               pop si
               pop [offseOfDir]
               pop bx
               pop [LBAofDIR]
               pop dx
               pop ds
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
               iret
             Erroe24fh:;dont exist
               stc
               mov sp,bp
               pop bp
               pop ax
               pop ax
               pop ax
               pop cx
               pop di
               pop si
               pop [offseOfDir]
               pop bx
               pop [LBAofDIR]
               pop dx
               pop ds
               push ax
               readIntoBuff BufferForDIR,[cs:LBAofDIR],[cs:offseOfDir],cs
               pop ax
               push bp
                   mov bp,sp
                    or WORD[bp+6],1
                    pop bp
                    iret


_next1ah:
           cmp ah,1ah; set DTA adr
          ; jne _next1ah
          mov WORD[cs:DTAAdr],dx
          mov WORD[cs:DTAAdr+2],ds
          iret


deleteClustersFromThisIncluding:
        push dx
        push cx
        push bx
        push si
        push ax
     contDelCl:
        shl ax,1
        mov cx,0x200
        xor dx,dx
        div cx
        push dx
        cmp ax,[cs:FATpartNum]
            je findCl
            mov si,[cs:FATpartNum]
            add si,[cs:BPB_RsvdSecCnt]
            WriteIntoBuff BufferForFAT,si,Word[cs:PT+8],cs

            mov [cs:FATpartNum],ax
            add ax,[cs:BPB_RsvdSecCnt]
            add ax,Word[cs:PT+8]

            push ds
            push cs
            pop ds
            mov bx,BufferForFAT
            call writeInPlace
            pop ds
        findCl:
            mov bx,BufferForFAT
            pop dx
            add bx,dx
            mov ax,WORD[cs:bx]
            mov WORD[cs:bx],0x0

            cmp ax,0xFFFF
            jne contDelCl
    endOfFile:
        mov si,[cs:FATpartNum]
        add si,[cs:BPB_RsvdSecCnt]
        WriteIntoBuff BufferForFAT,si,Word[cs:PT+8],cs

        pop ax
        pop si
        pop bx
        pop cx
        pop dx
        ret





findNextCl:
        push dx
        push cx
        push bx

        shl ax,1
        mov cx,0x200
        xor dx,dx
        div cx
        push dx
        cmp ax,[cs:FATpartNum]
        je findClINfindNextCl

        mov [cs:FATpartNum],ax
        add ax,[cs:BPB_RsvdSecCnt]
        add ax,Word[cs:PT+8]

        push ds
        push cs
        pop ds
        mov bx,BufferForFAT
        call writeInPlace
        pop ds
        findClINfindNextCl:
                mov bx,BufferForFAT
                pop dx
                add bx,dx
                mov ax,WORD[cs:bx]
        pop bx
        pop cx
        pop dx
        ret

;readSeg:

;ds-seg dx-off ax-LBA
writeInPlace:

        mov word[cs:place+2],ds;segment
        mov word[cs:place],dx
        mov word[cs:LBA],ax
        pusha
        mov ah,0x41
        mov bx, 0x55AA
        mov dx,[cs:bootDrive]
        int 13h
        ;jb .halt ;.chs
        push cs
        pop ds
        mov ah,0x42
        mov si,extBiosRead
        int 13h
        ;jb .halt
        popa
        ret

ToUpperCase:
        cmp al,'a'
        jnae notAlph
        cmp al,'z'
        ja notAlph
        sub al,0x20
     notAlph:
        ret

findEmptyCluster:
        push bx
        push ax;-8
        push dx;-6
        push si;-4
        push cx;bp+2 bp+3
        push bp;bp bp+1
        mov bp,sp
        sub sp,4
        mov ax,Word[cs:PT+8]
        add ax,[cs:BPB_RsvdSecCnt]
        ;add ax,2
        mov cx,[cs:BPB_FATSz16]
        mov [cs:FATpartNum],-1
        mov si,6
  readNextFatSec:
        ;readIntoBuff BufferForFAT
        push ds
        push cs
        pop ds
        mov dx,BufferForFAT
        call writeInPlace
        pop ds
        inc [cs:FATpartNum]
   findEmpty :
       ; push cx
       ; mov cx,255d
        mov bx,BufferForFAT

         cont:
            cmp WORD[cs:bx+si],0
            je foundEmpyCl
            add si,2
         cmp si,512d
          jne cont
       inc ax
     ;  pop cx
       xor si,si
       loop readNextFatSec
       mov ax,0xFFFF
       ret
     foundEmpyCl:
        mov WORD[cs:bx+si],0xFFFF
        pusha

        WriteIntoBuff BufferForFAT,ax,0,cs

        popa

        mov bx,[cs:FATpartNum]
        mov cl,8 ;!!!!! 256
        shl bx,cl
        shr si,1
        add bx,si ;cluster
        ;shr bx
        mov cx,bx
        mov [bp-2],cx
     ;clear
         pusha
         mov si,BufferForWrite
          mov cx,256
           clearCluster_findEmptyCluster:
            mov WORD[cs:si],0
            loop clearCluster_findEmptyCluster

          mov ax,[bp-2]
          sub ax,0x02;N-2
          push cx
          mov cl,[BPB_SecPerClus]
          dec cl
          shl ax,cl;(N-2)*2
          pop cx
          add ax,Word[cs:First_Data_Sect]
          WriteIntoBuff BufferForWrite,ax,0,cs
          popa
      ;clear
        cmp WORD[bp+8],0  ;is first or not
         je firstCl
        mov ax,[bp+8]
        shl ax,1
        mov cx,0x200
        xor dx,dx
        div cx
        push dx

        mov [cs:FATpartNum],ax
        add ax,[cs:BPB_RsvdSecCnt]
        add ax,Word[cs:PT+8]
        push ds
        push cs
        pop ds
        mov dx,BufferForFAT
        call writeInPlace
        pop ds

        wrIndCl:

                mov bx,BufferForFAT
                pop dx
                add bx,dx
                mov cx,[bp-2]
                mov WORD[cs:bx],cx

                WriteIntoBuff BufferForFAT,ax,0,cs
     firstCl:
        mov ax,cx
        mov sp,bp
        pop bp
        pop cx
        pop si
        pop dx
        pop bx
        pop bx
        ret

;ax -LBA ds - seg  dx-off
writeInDrive:
        push ax
        mov word[cs:place+2],ds;segment
        mov word[cs:place],dx
        mov word[cs:LBA],ax
        pusha
        ;jb .halt ;.chs
        mov ah,0x43
        mov al,0x01
        mov dx,[cs:bootDrive]
        mov si,extBiosRead
        int 13h
        ;jb .halt
        popa
        pop ax
        ret

checkType:
        cmp ah,'.'
        jne notDotType
            mov ah,1
            ret
        notDotType:
            mov ah,0
            ret

checkState:
        ;ah - type  ;al -state

        push si
        push dx
        xor dx,dx
        mov dl,ah

        xor ah,ah
        mov dh,2
        mul dh
        add al,dl
        mov si,ax
        mov al,BYTE[cs:si+stateTable]

        pop dx
        pop si

        ret

alterName:
        push cx
        push dx

          mov si,fileSearchName
          xor di,di
   copyFNAme:
              mov ah,BYTE[ds:bx+di]
              mov BYTE[cs:si],ah
              inc si
              inc di
          cmp BYTE[ds:bx+di],0
              jne copyFNAme
          mov BYTE[cs:si],0

          mov dx,fileSearchName
          mov ah,4eh
          int 21h
             jc DontChangeName
         xor cx,cx
        findStartOfName:
             dec di
             dec si
             cmp BYTE[ds:bx+di-1],'\'
                 je placeNum
             cmp di,0
                 je placeNum
             jmp findStartOfName
        placeNum:
               inc di
               inc si
               inc cx
               cmp BYTE[ds:bx+di+1],'.'
                 je fgh
               cmp BYTE[ds:bx+di+1],0
                 je fgh
               jmp placeNum
              fgh:
               cmp cx,9
                 je overflowname

               xor cx,cx
               mov dh,[ds:bx+di+1]
           tryu:
               mov dl,dh
               inc di
               inc si
               mov dh,[ds:bx+di+1]
               mov [ds:bx+di+1],dl
               mov [ds:si+1],dl
               inc cx
             cmp cx,4
               jne tryu
               sub di,4
               sub si,4
             overflowname:
               mov BYTE[cs:si+1],'?'

       findinDir:
          mov ch,'1'
          mov dx,fileSearchName
          mov ah,4eh
          int 21h
             jc GoAndChange



       contF:
          mov ah,4fh
          inc ch
          clc
          int 21h
              jnc contF

          cmp ch,'9'
              jbe GoAndChange
              stc
              pop dx
              pop cx
              ret
       GoAndChange:
          mov BYTE[ds:bx+di+1],ch
          clc
       DontChangeName:
          clc
          pop dx
          pop cx
        ret

errorMassege db "ERROR$"
helper db "CD(cd)-Changes directories.",0ah,0dh,"DIR(dir) N-List the contents of directory,N-num of page(0-9).",0ah,0dh,"MD(md)-Command to create a new directory.",0ah,0dh,"RD(rd)-  Removes an empty directory,works only with absolute path.",0ah,0dh,"HLT-Shutdown the computer from the MS-DOS prompt.",0ah,0dh,"EXEC(exec)-run programm,works only with .com files",0ah,0dh,"DEL - delete file",0ah,0dh,"TOOKF(tookf)-choose file for next 3 comands:",0ah,0dh,"   COPY-copy file(not directories) in writen directory with writen name",0ah,0dh,"   MOVE-place file/directory in writen directory with writen name",0ah,0dh,"   REN-rename file$"
db '$'
dw 0
CDPath db '\','$',78 dup 0

stateTable db 0,1,  3,2,  4,0,  0,0,  0,0
commandL db 81,81 dup 0
dw 0
ssForDum dw 0
spForDum dw 0
flageOfTake dw 0

KeenLosdSTR db "Kernel is loaded",'$'
NameOfFileSymb3ch db "|\/<>:?*=,:+[]",34,0xE5,0 ;16
NameOfFileSymb4eh db "|\/<>:=,:+[]",34,0xE5,0 ;16
adressOfProgramm dw 1400
extBiosRead db 0x10,0
      count_ dw 0x1
      place dd 0
        LBA dq 0
JobTable db 5 dup 0, 15 dup 0xff
;0-10-name  11-4-size  15-1-attr 16-2-segm_Dir  18-2-num_inDir  20-4-pointer
;26-1-dateissetle
FBCTable db  20d*27d dup 0
offseOfDir dw 0
LBAofDIR dw 0
DTAAdr db "ra9>"
;0-2- num in dir 2-11-name;13-LBA of search dir-2 ;15-13-name;28-1-atr ;29-2-date ; 31-2-time ; 33-4-size  ;
DTA db  37 dup 0
FATpartNum dw 0
db 0
fileName db 81d dup 0
db 0
fileSearchName db 81d dup 0
db 0
fileSearchName4eaf db 81d dup 0
BufferForWrite db 512d dup '-'
BufferForRead db 512d dup 0
BufferForDIR db 512d dup 0
db 16 dup 'f'
BufferForFAT db 512d dup 0