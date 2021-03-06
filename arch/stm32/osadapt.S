;*******************************************************************************
;* Author                : Garry
;* Date                  : Feb 15,2014
;* Last modified date    : Feb 15,2014
;* Last modified content :
;*                1.
;*                2.
;* Purpuse description:
;*     This file contains hardware level initialization or low level wraping code
;*   for operating system,before the entry of OS.
;*     All this routines are dedicated for STM32 chip,and certainly,Hello China
;*   Operating system.
;*
;*******************************************************************************


; Constants used in this file.
NVIC_INT_CTRL     EQU  0xE000ED04
NVIC_PENDSVSET    EQU  0x10000000
NVIC_PENDSV_PRI   EQU  0xFF        ;Set PendSV exception as lowest priority.
NVIC_SYSPRI14     EQU  0xE000ED22  ;System priority register.


; Code section.
                PRESERVE8
                THUMB
                AREA    |.text|, CODE, READONLY


; Hardware initialization code,this routine should be called in Reset_Handler before
; any other initialization or application code.
System_Hard_Init PROC
                 EXPORT System_Hard_Init
				 LDR R0,=NVIC_SYSPRI14
				 LDR R1,=NVIC_PENDSV_PRI
				 STRB R1,[R0]
				 BX LR
				 ENDP


; Interrupt entry wrapper for Hello China OS.
; A single entry point is adopted by Hello China operating system,which is GeneralIntHandler
; in C language.This routine will dispatch each interrupt or exception to it's handler
; according to it's vector.This abstracted mechanism can fit different hardwares.
; But this mechanism is a little difference with STM32's implementation,as call exception vector
; directly.So any startup exception hander should call this routine first.
; Here is the path of exception dispatch:
;   Hardware -> NVIC -> STM32 Core -> Exception Handler -> Int_Entry_Wrapper -> Actual Handler
; The pro-type of GeneralIntHandler is:
;   void GeneralIntHandler(UCHAR ucVector,LPVOID lpESP);
; Int_Entry_Wrapper routine must transfer these 2 parameters to GeneralIntHandler.
;
Int_Entry_Wrapper    PROC
                     EXPORT  Int_Entry_Wrapper
					 IMPORT  GeneralIntHandler   ;Implemented in C file.
					 MRS R0,IPSR
					 AND R0,R0,#0xFF
					 MRS R1,MSP
					 LDR R2,=GeneralIntHandler
					 BX  R2    ;Exception return will be performed in GeneralIntHandler routine,
					           ;since BX(not BLX) is adopted here.
					 ENDP
					 
; Critical Section operation routines.They almost same as the implementation in x86 chip,
; these 2 routines are refered by __ENTER_CRITICAL_SECTION and __LEAVE_CRITICAL_SECTION
; macros.
Enter_Critical_Section  PROC
                        EXPORT Enter_Critical_Section
						MRS R0,PRIMASK
						CPSID I
						BX LR
						ENDP
						
Leave_Critical_Section  PROC
                        EXPORT Leave_Critical_Section
                        MSR PRIMASK,R0
						BX LR
						ENDP	


; Interrupt enable and disable operation,which may used by OS kernel or hardware device.
EnableInterrupt    PROC
                   EXPORT EnableInterrupt
				   CPSIE I
				   BX LR
				   ENDP
				   
DisableInterrupt   PROC
                   EXPORT DisableInterrupt
				   CPSID I
				   BX LR
				   ENDP


; Kernel thread schedule primatives,which are called by OS kernel to lead kernel thread
; re-schedule.
; ScheduleFromInt is called under interrupt or exception context,and as the name meaning,
; ScheduleFromProc is called under normal execution context.
ScheduleFromInt PROC
                EXPORT ScheduleFromInt
				PUSH {R4,R5}
				LDR R4,=NVIC_INT_CTRL
				LDR R5,=NVIC_PENDSVSET ;Generate a PendSV exception.
				STR R5,[R4]
				POP {R4,R5}
				BX LR
				NOP
				ENDP


ScheduleFromProc PROC
                 EXPORT ScheduleFromProc
				 PUSH {R4,R5}
				 LDR R4,=NVIC_INT_CTRL
				 LDR R5,=NVIC_PENDSVSET ;Generate a PendSV exception.
				 STR R5,[R4]
				 POP {R4,R5}
				 BX LR
				 ENDP
				 
; Handler of PendSV exception.All thread context saveing and restoring
; are performed in this handler,kernel thread schedule also executed
; under this routine.
; ** NOTE **:
;   This handler will replace the one created by compiler in Startup file,
; since that one is marked as weak.
PendSV_Handler PROC
               EXPORT PendSV_Handler
			   IMPORT UniSchedule    ;UniSchedule is implemented in C file.
			   PUSH {R4-R11}    ;Save un-saved registers.
			   MOV R4,LR
			   MRS R0,MSP       ;Should be modified to KernelThreadManager.
			   MRS R1,MSP
			   LDR R2,=UniSchedule
			   BLX R2           ;Now R0 contains the new thread to switch to.
			   MOV LR,R4
			   MSR MSP,R0
			   POP {R4-R11}
			   BX LR
			   ENDP
			   
;Customized system reset hander,to replace the one generated by compiler.
;Use this one will avoid the need to modify startup.S file.
;Please be noted this routine is declared as "STRONG"(without [WEAK] directive).
Reset_Handler  PROC
               EXPORT  Reset_Handler
               IMPORT  __main
               IMPORT  SystemInit
                 LDR     R0, =SystemInit
                 BLX     R0
				 LDR     R0, =System_Hard_Init
				 BLX     R0
                 LDR     R0, =__main
                 BLX      R0
                 ENDP


;Customized system tick handler,to replace the one generated by compiler,since
;it is not described by [WEAK] directive.
SysTick_Handler PROC
                EXPORT  SysTick_Handler
				LDR R2,=Int_Entry_Wrapper
				BX R2
				B       .
                ENDP
			   
			   ALIGN
			   
			   END
;***************************** END OF FILE**************************************
