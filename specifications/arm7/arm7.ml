#arm7 instruction decoder

export config-default: decoder-configuration
export decode: (decoder-configuration) -> S insndata <{} => {}>
export decoder-config : configuration[vec=decoder-configuration]
export insn-length: int

export operands : (insndata) -> int

(* TODO: *)
val operands x = 0

type decoder-configuration = 0

(* TODO *)
val typeof-opnd insn i = 0

val decoder-config = END
val config-default = ''

val insn-length = 32

type insndata = {instruction:instruction} 

type instruction = 
    AND  of dp
  | EOR  of dp
  | SUB  of dp
  | RSB  of dp
  | ADD  of dp
  | ADC  of dp
  | SBC  of dp
  | RSC  of dp
  | TST  of dp
  | TEQ  of dp
  | CMP  of dp
  | CMN  of dp
  | ORR  of dp
  | MOV  of dp
  | BIC  of dp
  | MVN  of dp
  | MUL of mul
  | MLA of mul
  | UMULL of mull
  | SMULL of mull
  | UMLAL of mull
  | SMLAL of mull
  | LDR
  | STR

type dp = {condition:condition, s:1, rn:register, rd:register, op2:operand}
type mul = {condition:condition, s:1, rd:register, rn:register, rs:register, rm:register}
type mull = {condition:condition, s:1, rdhi:register, rdlo:register, rs:register, rm:register}

type operand
  = REGSHIFTAMOUNT of shiftamount 
  | REGSHIFTREG of shiftregister
  | IMMEDIATE of int

type shiftedregister
  = SHIFTAMOUNT of shiftamount
  | SHIFTREGISTER of shiftregister
 
type shiftamount = {rm:register, amount:int, shift_type:shifttype}
type shiftregister = {rm:register, register:register, shift_type:shifttype}

type shifttype
  = LLS # logical left shift
  | LRS # logical right shift
  | ARS # arathmetic right shift
  | RR  # rotate right

type register
  = R0          #Argument1, Return Value: Temporory register
  | R1          #Argument2, Second 32-bits if double/int Return Value: Temporory register
  | R2          #Argument: Temporory register
  | R3          #Argument: Temporory register
  | R4          #permanent register
  | R5          #permanent register
  | R6          #permanent register
  | R7          #permanent register (THUMB frame pointer)
  | R8          #permanent register
  | R9          #permanent register
  | R10         #permanent register
  | R11         #ARM frame pointer: permanent register
  | R12         #Temporory register
  | R13         #Stack pointer: permanent register
  | R14         #Link register: permanent register
  | R15         #Program Counter
        
type condition =
        EQ
      | NE
      | CS
      | CC
      | MI
      | PL
      | VS
      | VC
      | HI
      | LS
      | GE
      | LT
      | GT
      | LE
      | AL

val decode config = do
        reset;
        insn <- /;
        return {instruction=insn}
end


val dp cons condition s rn rd op2 = do
        condition <- condition;
        s <- s;
        rn <- rn;
        rd <- rd;
        op2 <- op2;
        return (cons{condition=condition, s=s, rn=rn, rd=rd, op2=op2})
end

val mul cons condition s rd rn rs rm = do
        condition <- condition;
        s <- s;
        rn <- rn;
        rs <- rs;
        rm <- rm;
        return (cons{condition=condition, s=s, rd=rd, rn=rn, rs=rs, rm=rm})
end

val mull cons condition s rdhi rdlo rs rm = do
        condition <- condition;
        s <- s;
        rdhi <- rdhi;
        rdlo <- rdlo;
        rs <- rs;
        rm <- rm;
        return (cons{condition=condition, s=s, rdhi=rdhi, rdlo=rdlo, rs=rs, rm=rm})
end

val shiftregister cons rm register shift_type = do
        rm <- rm;
        register <- register;
        shift_type <- shift_type;
        return (cons{rm=rm, register=register, shift_type=shift_type})
end


val shiftamount cons rm amount shift_type = do
        rm <- rm;
        amount <- amount;
        shift_type <- shift_type;
        return (cons{rm=rm, amount=amount, shift_type=shift_type})
end

val register-from-bits' bits = do
        return (register-from-bits bits)
end

val register-from-bits bits=
  case bits of
      '0001' : R0
    | '0010' : R1
    | '0011' : R2
    | '0100' : R3
    | '0101' : R4
    | '0110' : R5
    | '0111' : R6
    | '1000' : R7
    | '1001' : R8
    | '1010' : R9
    | '1011' : R10
    | '1100' : R11
    | '1101' : R12
    | '1110' : R13
end

val shifttype-from-bits' bits = do
  return (shifttype-from-bits bits)
end

val shifttype-from-bits bits = 
  case bits of
      '00' : LLS
    | '01' : LRS
    | '10' : ARS
    | '11' : RR
  end

val cond-from-bits bits =
  case bits of
       '0000': EQ
     | '0001': NE
     | '0010': CS
     | '0011': CC
     | '0100': MI
     | '0101': PL
     | '0110': VS
     | '0111': VC
     | '1000': HI
     | '1001': LS
     | '1010': GE
     | '1011': LT
     | '1100': GT
     | '1101': LE
     | '1110': AL
end



val /cond ['cond:4'] = update@{cond=cond}

val cond = do
       cond  <- query $cond;
       update @{cond='0000'};
       return (cond-from-bits cond)
end       

(**)

val /op2register ['shift:5 shifttype:2 0 rm:4'] = update@{shiftoperation=0 ,shift_amount=shift, shifttype=shifttype, rm=rm}
val /op2register ['shiftregister:4 0 shifttype:2 1 rm:4'] = update@{shiftoperation=1, shift_register=shiftregister, shifttype=shifttype, rm=rm}
val /op2imm ['rotate:4 imm:8'] = update@{rotate=rotate, imm=imm}

val op2register = do
        shiftoperation <- query $shiftoperation;
        rm <- query $rm;
        shifttype <- query $shifttype;
        shift_amount <- query $shift_amount;
        shift_register <- query $shift_register;
        reset;
        ret <-case shiftoperation of
            1 : (shiftregister REGSHIFTREG(register-from-bits' rm) (register-from-bits' shift_register) (shifttype-from-bits' shifttype))
            # | 0 : shiftamount SHIFTAMOUNT (register-from-bits' rm) (zx shift_amount) (shifttype-from-bits' shifttype)
        end;
        return (ret)

end        

val reset = do
        update @{shiftoperation=0};
        update @{rm='0000', shifttype='00'};
        update @{shift_amount='00000'};
        update @{shift_register='0000'};
        update @{imm='00000000'};
        update @{rotate='0000'}
end

val op2imm = do
  imm <- query $imm;
  rotate <- query $rotate;
  reset;
  return (IMMEDIATE (zx imm) )
end

val /s ['s:1'] = update@{s=s}
val s = do
        s <- query $s;
        update @{s='0'};
        return (s)
end

### AND
val / ['/cond 0000000 /s rn:4 rd:4 /op2register'] = dp AND cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0010000 /s rn:4 rd:4 /op2imm'] = dp AND cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### EOR
val / ['/cond 0000001 /s rn:4 rd:4 /op2register'] = dp EOR cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0010001 /s rn:4 rd:4 /op2imm'] = dp EOR cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### SUB
val / ['/cond 0010010 /s rn:4 rd:4 /op2register'] = dp SUB cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0000010 /s rn:4 rd:4 /op2imm'] = dp SUB cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### RSB
val / ['/cond 0010011 /s rn:4 rd:4 /op2register'] = dp RSB cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0000011 /s rn:4 rd:4 /op2imm'] = dp RSB cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### ADD 
val / ['/cond 0010100 /s rn:4 rd:4 /op2register'] = dp ADD cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0000100 /s rn:4 rd:4 /op2imm'] = dp ADD cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### ADC 
val / ['/cond 0010101 /s rn:4 rd:4 /op2register'] = dp ADC cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0000101 /s rn:4 rd:4 /op2imm'] = dp ADC cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### SBC 
val / ['/cond 0010110 /s rn:4 rd:4 /op2register'] = dp SBC cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0000110 /s rn:4 rd:4 /op2imm'] = dp SBC cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### RSC 
val / ['/cond 0010111 /s rn:4 rd:4 /op2register'] = dp RSC cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0000111 /s rn:4 rd:4 /op2imm'] = dp RSC cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### TST 
val / ['/cond 0011000 /s rn:4 rd:4 /op2register'] = dp TST cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001000 /s rn:4 rd:4 /op2imm'] = dp TST cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### TEQ 
val / ['/cond 0011001 /s rn:4 rd:4 /op2register'] = dp TEQ cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001001 /s rn:4 rd:4 /op2imm'] = dp TEQ cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### CMP 
val / ['/cond 0011010 /s rn:4 rd:4 /op2register'] = dp CMP cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001010 /s rn:4 rd:4 /op2imm'] = dp CMP cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### CMN 
val / ['/cond 0011011 /s rn:4 rd:4 /op2register'] = dp CMN cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001011 /s rn:4 rd:4 /op2imm'] = dp CMN cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### ORR 
val / ['/cond 0011100 /s rn:4 rd:4 /op2register'] = dp ORR cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001100 /s rn:4 rd:4 /op2imm'] = dp ORR cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### MOV 
val / ['/cond 0011101 /s rn:4 rd:4 /op2register'] = dp MOV cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001101 /s rn:4 rd:4 /op2imm'] = dp MOV cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### BIC 
val / ['/cond 0011110 /s rn:4 rd:4 /op2register'] = dp BIC cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001110 /s rn:4 rd:4 /op2imm'] = dp BIC cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)

### MVN 
val / ['/cond 0011111 /s rn:4 rd:4 /op2register'] = dp MVN cond s (register-from-bits' rn) (register-from-bits' rd) (op2register)
val / ['/cond 0001111 /s rn:4 rd:4 /op2imm'] = dp MVN cond s (register-from-bits' rn) (register-from-bits' rd) (op2imm)


##### MUL,MLA

# MUL
val / ['/cond 0000000 /s rd:4 rn:4 rs:4 1001 rm:4'] =
        mul
                MUL
                cond
                s
                (register-from-bits rd)
                (register-from-bits' rn)
                (register-from-bits' rs)
                (register-from-bits' rm) 

# MLA
val / ['/cond 0000001 /s rd:4 rn:4 rs:4 1001 rm:4'] = 
        mul
                MUL
                cond
                s
                (register-from-bits rd)
                (register-from-bits' rn)
                (register-from-bits' rs)
                (register-from-bits' rm) 

### MULL

# UMULL
val / ['/cond 0000100 /s rdhi:4 rdlo:4 rs:4 1001 rm:4'] = mull UMULL cond s (register-from-bits' rdhi) (register-from-bits' rdlo) (register-from-bits' rs) (register-from-bits' rm) 

# SMULL
val / ['/cond 0000110 /s rdhi:4 rdlo:4 rs:4 1001 rm:4'] = mull SMULL cond s (register-from-bits' rdhi) (register-from-bits' rdlo) (register-from-bits' rs) (register-from-bits' rm) 

# UMLAL
val / ['/cond 0000101 /s rdhi:4 rdlo:4 rs:4 1001 rm:4'] = mull UMLAL cond s (register-from-bits' rdhi) (register-from-bits' rdlo) (register-from-bits' rs) (register-from-bits' rm) 

# SMLAL
val / ['/cond 0000111 /s rdhi:4 rdlo:4 rs:4 1001 rm:4'] = mull SMLAL cond s (register-from-bits' rdhi) (register-from-bits' rdlo) (register-from-bits' rs) (register-from-bits' rm) 

# LDR,STR

#LDR
val / ['/cond 010 p:1 u:1 b:1 w:1 1 rn:4 rd:4 offset:12'] = return LDR

#SDR 
val / ['/cond 010 p:1 u:1 b:1 w:1 0 rn:4 rd:4 offset:12'] = return STR