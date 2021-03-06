export translate: (insndata) -> S sem_stmt_list <{} => {}>

######################################################################
### architecture specific configurations can be set in the mips.ml ###
######################################################################

type signedness =
   Signed
 | Unsigned

val write to from =
   case to of
      GPR r: mov (sizeof-lval to) (semantic-gpr-of r) from
   end

val lval sn x = let
   val from-fcc fcc = 
      case fcc of
         FCC0: var (sem-reg-offset (semantic-fcr-of FCSR) 23)
       | FCC1: var (sem-reg-offset (semantic-fcr-of FCSR) 25)
       | FCC2: var (sem-reg-offset (semantic-fcr-of FCSR) 26)
       | FCC3: var (sem-reg-offset (semantic-fcr-of FCSR) 27)
       | FCC4: var (sem-reg-offset (semantic-fcr-of FCSR) 28)
       | FCC5: var (sem-reg-offset (semantic-fcr-of FCSR) 29)
       | FCC6: var (sem-reg-offset (semantic-fcr-of FCSR) 30)
       | FCC7: var (sem-reg-offset (semantic-fcr-of FCSR) 31)
      end
   val from-c2cc c2cc = 
      case c2cc of
         C2CC0: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 23)
       | C2CC1: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 25)
       | C2CC2: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 26)
       | C2CC3: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 27)
       | C2CC4: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 28)
       | C2CC5: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 29)
       | C2CC6: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 30)
       | C2CC7: var (sem-reg-offset (semantic-reg-of Sem_C2CCREG) 31)
      end
in
   case x of
      GPR r: return (var (semantic-gpr-of r))
    | FPR f: return (var (semantic-fpr-of f))
    | FCC fc: return (from-fcc fc)
    | C2CC c2c: return (from-c2cc c2c)
   end
end

type sem_linear =
   SEM_LIN_TUPLE of {opnd1:sem_linear, opnd2:sem_linear}

val rval sn x = let
   val from-vec sn vec =
      case sn of
         Signed: SEM_LIN_IMM {const=sx vec}
       | Unsigned: SEM_LIN_IMM {const=zx vec}
      end

   val from-imm sn imm =
      case imm of
         IMM5 i: from-vec sn i
       | IMM16 i: from-vec sn i
       | RTRD5 i: from-vec sn i
       | FSCTRL5 i: from-vec sn i
       | OFFSET9 i: from-vec sn i
       | OFFSET16 i: from-vec sn i
       | OFFSET18 i: from-vec sn i
       | SEL i: from-vec sn i
       | IMPL i: from-vec sn i
       | CODE10 i: from-vec sn i
       | CODE19 i: from-vec sn i
       | CODE20 i: from-vec sn i
       | STYPE i: from-vec sn i
       | MSB i: from-vec sn i
       | MSBD i: from-vec sn i
       | LSB i: from-vec sn i
       | HINT i: from-vec sn i
       | INSTRINDEX28 i: from-vec sn i
       | COFUN i: from-vec sn i
       | OP i: from-vec sn i
       | _ : revision/rval-imm sn imm
      end

in
   case x of
      LVALUE lv:
         case lv of
            GPR r:
               case r of
                  ZERO: return (SEM_LIN_IMM {const=0})
                | _: lval sn lv
               end
          | _: lval sn lv 
         end
    | IMM i: return (from-imm sn i)
    | OFFSET/BASE ob: return (SEM_LIN_TUPLE {opnd1=(from-imm sn ob.offset), opnd2=(var (semantic-gpr-of ob.base))})
    | INDEX/BASE ib: return (SEM_LIN_TUPLE {opnd1=(var (semantic-gpr-of ib.index)), opnd2=(var (semantic-gpr-of ib.base))})
    | MSB/LSB ml: return (SEM_LIN_TUPLE {opnd1=(from-imm sn ml.msb), opnd2=(from-imm sn ml.lsb)})
   end
end

val scale i x = SEM_LIN_SCALE{const=i, opnd=x}

val lin-to-int x =
   case x of
      SEM_LIN_IMM li: li.const	
   end

val sizeof-lval x =
   case x of
      GPR r: 32
    | FPR f: 32
    | FCC fcc: 1
    | C2CC c2cc: 1
   end

val sizeof-rval x = 
   case x of
      LVALUE lv: sizeof-lval lv
    | IMM imm:
         case imm of
            IMM5 i: 5
	  | IMM16 i: 16
          | RTRD5 i: 5
          | FSCTRL5 i: 5
          | OFFSET9 i: 9
          | OFFSET16 i: 16
          | OFFSET18 i: 18
          | SEL i: 3
          | IMPL i: 16
          | CODE10 i: 10
          | CODE19 i: 19
          | CODE20 i: 20
          | STYPE i: 5
          | MSB i: 5
          | MSBD i: 5
          | LSB i: 5
          | HINT i: 5
          | INSTRINDEX28 i: 28
          | COFUN i: 25
          | OP i: 5
          | _ : revision/sizeof-imm imm
         end
    | OFFSET/BASE ob: 32
    | INDEX/BASE ib: 32
    | MSB/LSB ml: 5
   end

val mnemonic-with-format insn x = (mnemonic-of insn) +++ "." +++ show/format x.fmt
val mnemonic-with-format-and-cond insn x = (mnemonic-of insn) +++ "." +++ show/condop x.cond +++ "." +++ show/format x.fmt


val sem-default-nullop-generic insn = do
	prim-generic (mnemonic-of insn) varls-none varls-none
end

val sem-default-unop-l-generic insn x = do
	dst-sz <- return (sizeof-lval x.op);

	dst <- lval Signed x.op;

	dst-up <- unpack-lin dst-sz dst;

	prim-generic (mnemonic-of insn) varls-none (varls-one (varl dst-sz dst-up))
end

val sem-default-unop-r-tuple-generic insn x = do
	src1-sz <- return (sizeof-rval x.op);
	src2-sz <- return (sizeof-rval x.op);

	one/two <- rval Signed x.op;
	src1 <- return (extract-tuple one/two).opnd1;
	src2 <- return (extract-tuple one/two).opnd2;

	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;

	prim-generic (mnemonic-of insn) varls-none (varls-more (varl src1-sz src1-up) (varls-one (varl src2-sz src2-up)))
end

val sem-default-unop-r-generic insn x = do
	src-sz <- return (sizeof-rval x.op);

	src <- rval Signed x.op;

	src-up <- unpack-lin src-sz src;

	prim-generic (mnemonic-of insn) varls-none (varls-one (varl src-sz src-up))
end

val sem-default-binop-rr-tuple-generic insn x = do
	src1-sz <- return (sizeof-rval x.op1);
	src2-sz <- return (sizeof-rval x.op2);
	src3-sz <- return (sizeof-rval x.op2);

	src1 <- rval Signed x.op1;
	one/two <- rval Signed x.op2;
	src2 <- return (extract-tuple one/two).opnd1;
	src3 <- return (extract-tuple one/two).opnd2;

	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;
	src3-up <- unpack-lin src3-sz src3;

	prim-generic (mnemonic-of insn) varls-none (varls-more (varl src1-sz src1-up) (varls-more (varl src2-sz src2-up) (varls-one (varl src3-sz src3-up))))
end

val sem-default-binop-lr-tuple-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src1-sz <- return (sizeof-rval x.op2);
	src2-sz <- return (sizeof-rval x.op2);

	dst <- lval Signed x.op1;
	one/two <- rval Signed x.op2;
	src1 <- return (extract-tuple one/two).opnd1;
	src2 <- return (extract-tuple one/two).opnd2;

	dst-up <- unpack-lin dst-sz dst;
	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;

	prim-generic (mnemonic-of insn) (varls-one (varl dst-sz dst-up)) (varls-more (varl src1-sz src1-up) (varls-one (varl src2-sz src2-up)))
end

val sem-default-binop-rr-generic insn x = do
	src1-sz <- return (sizeof-rval x.op1);
	src2-sz <- return (sizeof-rval x.op2);

	src1 <- rval Signed x.op1;
	src2 <- rval Signed x.op2;

	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;

	prim-generic (mnemonic-of insn) varls-none (varls-more (varl src1-sz src1-up) (varls-one (varl src2-sz src2-up)))
end

val sem-default-binop-rl-generic insn x = do
	src-sz <- return (sizeof-rval x.op1);
	dst-sz <- return (sizeof-lval x.op2);

	src <- rval Signed x.op1;
	dst <- lval Signed x.op2;

	src-up <- unpack-lin src-sz src;
	dst-up <- unpack-lin dst-sz dst;

	prim-generic (mnemonic-of insn) (varls-one (varl src-sz src-up)) (varls-one (varl dst-sz dst-up))
end

val sem-default-binop-lr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src-sz <- return (sizeof-rval x.op2);

	dst <- lval Signed x.op1;
	src <- rval Signed x.op2;

	dst-up <- unpack-lin dst-sz dst;
	src-up <- unpack-lin src-sz src;

	prim-generic (mnemonic-of insn) (varls-one (varl dst-sz dst-up)) (varls-one (varl src-sz src-up))
end

val sem-default-binop-flr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src-sz <- return (sizeof-rval x.op2);

	dst <- lval Signed x.op1;
	src <- rval Signed x.op2;

	dst-up <- unpack-lin dst-sz dst;
	src-up <- unpack-lin src-sz src;

	prim-generic (mnemonic-with-format insn x) (varls-one (varl dst-sz dst-up)) (varls-one (varl src-sz src-up))
end

val sem-default-ternop-rrr-generic insn x = do
	src1-sz <- return (sizeof-rval x.op1);
	src2-sz <- return (sizeof-rval x.op2);
	src3-sz <- return (sizeof-rval x.op3);

	src1 <- rval Signed x.op1;
	src2 <- rval Signed x.op2;
	src3 <- rval Signed x.op3;

	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;
	src3-up <- unpack-lin src3-sz src3;

	prim-generic (mnemonic-of insn) varls-none (varls-more (varl src1-sz src1-up) (varls-more (varl src2-sz src2-up) (varls-one (varl src3-sz src3-up))))
end

val sem-default-ternop-lrr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src1-sz <- return (sizeof-rval x.op2);
	src2-sz <- return (sizeof-rval x.op3);

	dst <- lval Signed x.op1;
	src1 <- rval Signed x.op2;
	src2 <- rval Signed x.op3;

	dst-up <- unpack-lin dst-sz dst;
	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;

	prim-generic (mnemonic-of insn) (varls-one (varl dst-sz dst-up)) (varls-more (varl src1-sz src1-up) (varls-one (varl src2-sz src2-up)))
end

val sem-default-ternop-flrr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src1-sz <- return (sizeof-rval x.op2);
	src2-sz <- return (sizeof-rval x.op3);

	dst <- lval Signed x.op1;
	src1 <- rval Signed x.op2;
	src2 <- rval Signed x.op3;

	dst-up <- unpack-lin dst-sz dst;
	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;

	prim-generic (mnemonic-with-format insn x) (varls-one (varl dst-sz dst-up)) (varls-more (varl src1-sz src1-up) (varls-one (varl src2-sz src2-up)))
end

val sem-default-ternop-cflrr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src1-sz <- return (sizeof-rval x.op2);
	src2-sz <- return (sizeof-rval x.op3);

	dst <- lval Signed x.op1;
	src1 <- rval Signed x.op2;
	src2 <- rval Signed x.op3;

	dst-up <- unpack-lin dst-sz dst;
	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;

	prim-generic (mnemonic-with-format-and-cond insn x) (varls-one (varl dst-sz dst-up)) (varls-more (varl src1-sz src1-up) (varls-one (varl src2-sz src2-up)))
end

val sem-default-quadop-lrrr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src1-sz <- return (sizeof-rval x.op2);
	src2-sz <- return (sizeof-rval x.op3);
	src3-sz <- return (sizeof-rval x.op4);

	dst <- lval Signed x.op1;
	src1 <- rval Signed x.op2;
	src2 <- rval Signed x.op3;
	src3 <- rval Signed x.op4;

	dst-up <- unpack-lin dst-sz dst;
	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;
	src3-up <- unpack-lin src3-sz src3;

	prim-generic (mnemonic-of insn) (varls-one (varl dst-sz dst-up)) (varls-more (varl src1-sz src1-up) (varls-more (varl src2-sz src2-up) (varls-one (varl src3-sz src3-up))))
end

val sem-default-quadop-flrrr-generic insn x = do
	dst-sz <- return (sizeof-lval x.op1);
	src1-sz <- return (sizeof-rval x.op2);
	src2-sz <- return (sizeof-rval x.op3);
	src3-sz <- return (sizeof-rval x.op4);

	dst <- lval Signed x.op1;
	src1 <- rval Signed x.op2;
	src2 <- rval Signed x.op3;
	src3 <- rval Signed x.op4;

	dst-up <- unpack-lin dst-sz dst;
	src1-up <- unpack-lin src1-sz src1;
	src2-up <- unpack-lin src2-sz src2;
	src3-up <- unpack-lin src3-sz src3;

	prim-generic (mnemonic-with-format insn x) (varls-one (varl dst-sz dst-up)) (varls-more (varl src1-sz src1-up) (varls-more (varl src2-sz src2-up) (varls-one (varl src3-sz src3-up))))
end


val throw-exception exc = if exceptions_on then throw exc else (return void)

type sem_exception =
   SEM_EXC_OVERFLOW
 | SEM_EXC_VADDR_ERROR
 | SEM_EXC_TRAP
 | SEM_EXC_SYSTEM_CALL
 | SEM_EXC_BREAKPOINT
 | SEM_EXC_DEBUG_BREAKPOINT
 | SEM_EXC_DEBUG_MODE_BREAKPOINT
 | SEM_EXC_RESERVED_INSTRUCTION

#################################
### semantics of instructions ###
#################################

val overflow-add-addi size res rs rt = do
	t1 <- mktemp;
	t2 <- mktemp;
	t3 <- mktemp;

	# overflow computation: mind**** alert
	xorb size t1 (var res) rs;
	xorb size t2 (var res) rt;
	andb size t3 (var t1) (var t2);

	_if (/lts size (var t3) (imm 0)) _then
		throw-exception SEM_EXC_OVERFLOW
end

val overflow-sub size res rs rt = do
	t1 <- mktemp;
	t2 <- mktemp;
	t3 <- mktemp;
	
	# overflow computation: mind**** alert
	cmplts size t1 (var res) (imm 0);
	cmplts size t2 rs rt;

	_if (/xor (return (var t2)) (return (var t1))) _then
		throw-exception SEM_EXC_OVERFLOW
end

val sem-add x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	add size res rs rt;

	overflow-add-addi size res rs rt;

	write x.op1 (var res)	
end

val sem-addu x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	add size res rs rt;

	write x.op1 (var res)
end

val sem-addiu x = do
	rs <- rval Signed x.op2;
	imm <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	add size res rs imm;

	write x.op1 (var res)	
end

val sem-bitwise bit_op x = do
	rs <- rval Unsigned x.op2;
	rt <- rval Unsigned x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	bit_op size res rs rt;
	
	write x.op1 (var res)
end

val sem-bitwise-imm bit_op x = do
	rs <- rval Unsigned x.op2;
	imm <- rval Unsigned x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	bit_op size res rs imm;
	
	write x.op1 (var res)
end

val sem-and x = sem-bitwise andb x
val sem-andi x = sem-bitwise-imm andb x

val sem-or x = sem-bitwise orb x
val sem-ori x = sem-bitwise-imm orb x

val sem-xor x = sem-bitwise xorb x
val sem-xori x = sem-bitwise-imm xorb x

val cbranch-rel cond offset = do
	pc <- return (semantic-reg-of Sem_PC);
	
	new_pc <- mktemp;
	add pc.size new_pc (var pc) offset;

	cbranch cond (address pc.size (var new_pc)) (address pc.size (var pc))
end

########
# offset already shifted left by 2 at decoding
######
val sem-b cmp_op x = do
	rs <- rval Signed x.op1;
	rt <- rval Signed x.op2;
	size <- return (sizeof-rval x.op1);
	
	off <- rval Signed x.op3;
	cond <- cmp_op size rs rt;
	cbranch-rel cond off
end

val sem-bz cmp_op x = do
	rs <- rval Signed x.op1;
	size <- return (sizeof-rval x.op1);

	off <- rval Signed x.op2;

	cond <- cmp_op size rs (imm 0);
	cbranch-rel cond off
end

val sem-bz-link cmp_op x = do
	pc <- return (semantic-reg-of Sem_PC);
	ra <- return (semantic-gpr-of RA);

	# 4 instead of 8 since pc got incremented already
	add ra.size ra (var pc) (imm 4);

	sem-bz cmp_op x
end

val sem-beq x = sem-b /eq x
val sem-bgez x = sem-bz /ges x
val sem-bgtz x = sem-bz /gts x
val sem-blez x = sem-bz /les x
val sem-bltz x = sem-bz /lts x
val sem-bne x = sem-b /neq x

val sem-break x = throw-exception SEM_EXC_BREAKPOINT

val sem-cl bit x = do
	rs <- rval Unsigned x.op2;
	size <- return (sizeof-rval x.op2);
	
	amount <- mktemp;
	mov size amount (imm 32);
	
	i <- mktemp;
	mov size i (imm 31);

	shifted <- mktemp;
	_while (/neq size (var i) (imm 0)) __ do
		shr size shifted rs (var i);

		_if (/neq 1 (var shifted) (imm bit)) _then do
			sub size amount (imm 31) (var i);
			mov size i (imm 0)
		end _else
			sub size i (var i) (imm 1)
		
	end
	;
	write x.op1 (var amount)
end

val sem-deret = do
	dm <- return fDM;
	iexi <- return fIEXI;
	mov 1 dm (imm 0);
	mov 1 iexi (imm 0);

	depc <- return (semantic-reg-of Sem_DEPC);
	pc <- return (semantic-reg-of Sem_PC);
	if (isMIPS16Implemented == '1') then do
		isa_mode <- return (semantic-reg-of Sem_ISA_MODE);
	
		mov 1 isa_mode (var depc);
		mov pc.size pc (var depc);
		mov 1 pc (imm 0)
	end
	else do
		c3_isa <- return fISA;
		_if (/gts 2 (var c3_isa) (imm 0)) _then do
			isa_mode <- return (semantic-reg-of Sem_ISA_MODE);
	
			mov 1 isa_mode (var depc);
			mov pc.size pc (var depc);
			mov 1 pc (imm 0)
		end _else
			mov pc.size pc (var depc)
	end
end

val sem-di x = do
	sreg <- return (semantic-reg-of Sem_SREG);
	
	temp <- mktemp;
	mov sreg.size temp (var sreg);
	
	ie <- return fIE;
	mov 1 ie (imm 0);

	write x.op (var temp)
end

val sem-ei x = do
	sreg <- return (semantic-reg-of Sem_SREG);
	
	temp <- mktemp;
	mov sreg.size temp (var sreg);
	
	ie <- return fIE;
	mov 1 ie (imm 1);

	write x.op (var temp)
end

val sem-eret = do
	erl <- return fERL;
	temp <- mktemp;

	_if (/eq 1 (var erl) (imm 1)) _then do
		err_epc <- return (semantic-reg-of Sem_ERROR_EPC);
		mov err_epc.size temp (var err_epc);
		mov 1 erl (imm 0)
	end _else do
		epc <- return (semantic-reg-of Sem_EPC);
		exl <- return fEXL;
		mov epc.size temp (var epc);
		mov 1 exl (imm 0);

		if (architectureRevision >= 2) then do
			hss <- return fHSS;
			bev <- return fBEV;
			cond1 <- /gts 4 (var hss) (imm 0);
			cond2 <- /eq 1 (var bev) (imm 0);
			cond <- mktemp;
			andb 1 cond cond1 cond2;
			
			_if (/eq 1 (var cond) (imm 1)) _then do
				pss <- return fPSS;
				css <- return fCSS;
				mov 4 css (var pss)
			end
		end
		else
			return void
	end
	;
	
	pc <- return (semantic-reg-of Sem_PC);
	if (isMIPS16Implemented == '1') then do
		isa_mode <- return (semantic-reg-of Sem_ISA_MODE);
	
		mov 1 isa_mode (var temp);
		mov pc.size pc (var temp);
		mov 1 pc (imm 0)
	end
	else do
		c3_isa <- return fISA;
		_if (/gts 2 (var c3_isa) (imm 0)) _then do
			isa_mode <- return (semantic-reg-of Sem_ISA_MODE);
	
			mov 1 isa_mode (var temp);
			mov pc.size pc (var temp);
			mov 1 pc (imm 0)
		end _else
			mov pc.size pc (var temp)
	end
	;

	llbit <- return (semantic-reg-of Sem_LLBIT);
	mov 1 llbit (imm 0)	
end

val sem-ext x = do
	rs <- rval Unsigned x.op2;
	msbd <- rval Unsigned x.op3;
	lsb <- rval Unsigned x.op4;
	size <- return (sizeof-rval x.op2);

	ps <- return (lin-to-int lsb);
	sz <- return (1 + lin-to-int msbd);

	temp <- mktemp;
	mov size temp rs;

	res <- mktemp;
	mov size res (imm 0);
	mov sz res (var (at-offset temp ps));

	write x.op1 (var res)
end

val sem-ins x = do
	rs <- rval Unsigned x.op2;
	msb/lsb <- rval Unsigned x.op3;
	msb <- return (extract-tuple msb/lsb).opnd1;
	lsb <- return (extract-tuple msb/lsb).opnd2;
	size <- return (sizeof-rval x.op2);
	rt <- lval Unsigned x.op1;

	ps <- return (lin-to-int lsb);
	sz <- return (1 - ps + lin-to-int msb);

	temp <- mktemp;
	mov size temp rs;

	res <- mktemp;
	mov size res rt;
	mov sz res (var (at-offset temp ps));

	write x.op1 (var res)
end

val sem-j x = do
	index <- rval Unsigned x.op;
	size <- return (sizeof-rval x.op);

	pc <- return (semantic-reg-of Sem_PC);

	addr <- mktemp;
	mov 32 addr (var pc);
	mov (size+2) addr index;

	jump (address pc.size (var addr))
end

val sem-jal x = do
	pc <- return (semantic-reg-of Sem_PC);
	ra <- return (semantic-gpr-of RA);

	# 4 instead of 8 since pc got incremented already
	add ra.size ra (var pc) (imm 4);

	sem-j x
end

val sem-jalr x =  do
	pc <- return (semantic-reg-of Sem_PC);
	size <- return (sizeof-lval x.op1);

	# 4 instead of 8 since pc got incremented already
	temp <- mktemp;
	add size temp (var pc) (imm 4);
	write x.op1 (var temp);

	rs <- rval Signed x.op2;
	size <- return (sizeof-rval x.op2);
	pc <- return (semantic-reg-of Sem_SREG);

	pc_true <- mktemp;
	mov size pc_true rs; 

	pc_false <- mktemp;
	mov size pc_false rs;
	mov 1 pc_false (imm 0);

	config1CA <- return (fCA);
	cond <- /eq 1 (var config1CA) (imm 0);

	isamode <- return (semantic-reg-of Sem_ISA_MODE);
	_if (/neq 1 (var config1CA) (imm 0)) _then
		mov isamode.size isamode rs;
	
	cbranch cond (address pc.size (var pc_true)) (address pc.size (var pc_false))	
end

val sem-jalr-hb x = sem-jalr x

val is-user-mode = do
	dm <- return fDM;
	ksu <- return fKSU;
	exl <- return fEXL;
	erl <- return fERL;

	res <- mktemp;
	mov 2 res (var ksu);
	orb 1 res (var res) (var dm);
	orb 1 res (var res) (var exl);
	orb 1 res (var res) (var erl); 

	/eq 2 (var res) (imm 2)
end

val is-reverse-endian = do
	um <- is-user-mode;
	re <- return fRE;

	res <- mktemp;
	andb 1 res um (var re);

	/eq 1 (var res) (imm 1)
end

val is-big-endian-mem = do
	res <- mktemp;
	if (bigendian_mem) then
		mov 1 res (imm 1)
	else
		mov 1 res (imm 0)
	;
	return (var res)
end

val is-big-endian-cpu = do
	re <- is-reverse-endian;
	if (bigendian_mem) then
		/eq 1 re (imm 0)
	else
		/eq 1 re (imm 1)
end

val extract-tuple x =
   case x of
      SEM_LIN_TUPLE t: t
   end

val sem-lb-lbu ext_op x = do
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op2);

	vaddr <- mktemp;
	add size vaddr base off;

	memword <- mktemp;
	load 32 memword size (var vaddr);

	bcpu <- is-big-endian-cpu;
	bcpu2 <- mktemp;
	movsx 2 bcpu2 1 bcpu;

	# get depending on the endianness the correct byte out of the word
	byte <- mktemp;
	mov 30 (at-offset byte 2) (imm 0);
	xorb 2 byte (var vaddr) (var bcpu2);
	shl 32 byte (var byte) (imm 3);
	shr 32 memword (var memword) (var byte);

	res <- mktemp;
	ext_op size res 8 (var memword);

	write x.op1 (var res)
end

val sem-lb x = sem-lb-lbu movsx x
val sem-lbu x = sem-lb-lbu movzx x

val sem-lh-lhu ext_op x = do
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op2);

	vaddr <- mktemp;
	add size vaddr base off;

	_if (/neq 1 (var vaddr) (imm 0)) _then
		throw-exception SEM_EXC_VADDR_ERROR;

	memword <- mktemp;
	load 32 memword size (var vaddr);

	bcpu <- is-big-endian-cpu;
	bcpu2 <- mktemp;
	shl 2 bcpu2 bcpu (imm 1);

	# get depending on the endianness the correct halfword out of the word
	byte <- mktemp;
	mov 30 (at-offset byte 2) (imm 0);
	xorb 2 byte (var vaddr) (var bcpu2);
	shl 32 byte (var byte) (imm 3);
	shr 32 memword (var memword) (var byte);

	res <- mktemp;
	ext_op size res 16 (var memword);

	write x.op1 (var res)
end

val sem-lh x = sem-lh-lhu movsx x
val sem-lhu x = sem-lh-lhu movzx x

val sem-lw x = do
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op2);

	vaddr <- mktemp;
	add size vaddr base off;

	_if (/neq 2 (var vaddr) (imm 0)) _then
		throw-exception SEM_EXC_VADDR_ERROR;

	memword <- mktemp;
	load 32 memword size (var vaddr);

	write x.op1 (var memword)
end

val sem-ll x = do
	llbit <- return (semantic-reg-of Sem_LLBIT);
	mov 1 llbit (imm 1);

	sem-lw x
end

val sem-nor x = do
	s1 <- rval Unsigned x.op2;
	s2 <- rval Unsigned x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	orb size res s1 s2;
	xorb size res (var res) (imm (0-1));
	
	write x.op1 (var res)
end

val sem-pause = do
	llbit <- return (semantic-reg-of Sem_LLBIT);

	_while (/eq 1 (var llbit) (imm 0)) __ do
		return void
	end
	;

	epc <- return (semantic-reg-of Sem_EPC);
	pc <- return (semantic-reg-of Sem_PC);

	# 0 instead of 4 since pc got incremented already
	add pc.size epc (var pc) (imm 0)
end

val hwr-reg-of x =
   case x of
      0: (semantic-reg-of Sem_CPUNUM)
    | 1: (semantic-reg-of Sem_SYNCI_STEP)
    | 2: (semantic-reg-of Sem_CC)
    | 3: (semantic-reg-of Sem_CCRES)
    | 29: (semantic-reg-of Sem_ULR)
   end

val sem-rdhwr x = do
	rd <- rval Unsigned x.op2;
	i <- return (lin-to-int rd);

	if (i >= 4) then
		if (i === 29) then do
			reg <- return (hwr-reg-of i);
			write x.op1 (var reg)		
		end else
			throw-exception SEM_EXC_RESERVED_INSTRUCTION
	else do
		reg <- return (hwr-reg-of i);
		write x.op1 (var reg)
	end
end

val sem-rotr x = do
	rt <- rval Signed x.op2;
	sa <- rval Unsigned x.op3;
	size <- return (sizeof-rval x.op2);
	amount <- return (lin-to-int sa);

	res <- mktemp;
	shr size res rt sa;
	mov amount (at-offset res (32-amount)) rt;

	write x.op1 (var res)
end

val sem-rotrv x = do
	rt <- rval Signed x.op2;
	rs <- rval Unsigned x.op3;
	size <- return (sizeof-rval x.op2);

	left <- mktemp;
	shr size left rt rs;

	amount <- mktemp;
	sub size amount (imm 32) rs;

	right <- mktemp;
	shl size right rt (var amount);

	res <- mktemp;
	orb size res (var left) (var right);

	write x.op1 (var res)
end

val sem-se sz x = do
	rt <- rval Signed x.op2;
	size <- return (sizeof-rval x.op2);

	res <- mktemp;
	movsx size res sz rt;

	write x.op1 (var res)
end

val sem-seb x = sem-se 8 x
val sem-seh x = sem-se 16 x

val sem-slt-sltu cmp_op x = do
	s1 <- rval Signed x.op2;
	s2 <- rval Signed x.op3;
	size <- return (sizeof-rval x.op2);

	res <- mktemp;
	cmp_op size res s1 s2;
	movzx size res 1 (var res);

	write x.op1 (var res)
end

val sem-slt x = sem-slt-sltu cmplts x
val sem-sltu x = sem-slt-sltu cmpltu x

val sem-slti-sltiu mov_op cmp_op x = do
	rt <- rval Signed x.op2;
	imm <- rval Signed x.op3;
	size <- return (sizeof-rval x.op2);
	size_imm <- return (sizeof-rval x.op3);

	imm_ext <- mktemp;
	mov_op size imm_ext size_imm imm;
 
	res <- mktemp;
	cmp_op size res rt (var imm_ext);
	movzx size res 1 (var res);

	write x.op1 (var res)
end

val sem-slti x = sem-slti-sltiu movsx cmplts x
val sem-sltiu x = sem-slti-sltiu movzx cmpltu x

val sem-sub x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	sub size res rs rt;
	
	overflow-sub size res rs rt;

	write x.op1 (var res)
end

val sem-subu x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);

	res <- mktemp;
	sub size res rs rt;
	
	write x.op1 (var res)
end

val sem-sb x = do
	rt <- rval Signed x.op1;
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op1);

	vaddr <- mktemp;
	add size vaddr base off;

	bcpu <- is-big-endian-cpu;
	bcpu2 <- mktemp;
	movsx 2 bcpu2 1 bcpu;

	byte <- mktemp;
	mov 30 (at-offset byte 2) (imm 0);
	xorb 2 byte (var vaddr) (var bcpu2);
	shl 32 byte (var byte) (imm 3);

	memword <- mktemp;
	shl 32 memword rt (var byte);

	store 32 (address size (var vaddr)) (var memword)
end

val sem-sh x = do
	rt <- rval Signed x.op1;
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op1);

	vaddr <- mktemp;
	add size vaddr base off;

	_if (/neq 1 (var vaddr) (imm 0)) _then
		throw-exception SEM_EXC_VADDR_ERROR;

	bcpu <- is-big-endian-cpu;
	bcpu2 <- mktemp;
	shl 2 bcpu2 bcpu (imm 1);

	byte <- mktemp;
	mov 30 (at-offset byte 2) (imm 0);
	xorb 2 byte (var vaddr) (var bcpu2);
	shl 32 byte (var byte) (imm 3);

	memword <- mktemp;
	shl 32 memword rt (var byte);

	store 32 (address size (var vaddr)) (var memword)
end

val sem-sw x = do
	rt <- rval Signed x.op1;
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op1);

	vaddr <- mktemp;
	add size vaddr base off;

	_if (/neq 2 (var vaddr) (imm 0)) _then
		throw-exception SEM_EXC_VADDR_ERROR;

	store 32 (address size (var vaddr)) rt
end

val sem-sc-sw x = do
	rt <- lval Signed x.op1;
	off/base <- rval Signed x.op2;
	base <- return (extract-tuple off/base).opnd1;
	off <- return (extract-tuple off/base).opnd2;
	size <- return (sizeof-rval x.op2);

	vaddr <- mktemp;
	add size vaddr base off;

	_if (/neq 2 (var vaddr) (imm 0)) _then
		throw-exception SEM_EXC_VADDR_ERROR;

	store 32 (address size (var vaddr)) rt
end

val sem-sc x = do
	llbit <- return (semantic-reg-of Sem_LLBIT);
	size <- return (sizeof-lval x.op1);

	_if (/eq llbit.size (var llbit) (imm 1)) _then
		sem-sc-sw x;
	
	temp <- mktemp;
	movzx size temp llbit.size (var llbit);
	
	write x.op1 (var temp)
end


val sem-sdbbp x = do
	debugDM <- return (fDM);
	
	_if (/eq debugDM.size (var debugDM) (imm 0)) _then
		throw-exception SEM_EXC_DEBUG_BREAKPOINT
	_else
		throw-exception SEM_EXC_DEBUG_MODE_BREAKPOINT 
end

val sem-sll-sra-srl shift_op x = do
	rt <- rval Signed x.op2;
	amount <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);

	temp <- mktemp;
	shift_op size temp rt amount;
	
	write x.op1 (var temp)
end

val sem-sll x = sem-sll-sra-srl shl x
val sem-sra x = sem-sll-sra-srl shrs x
val sem-srl x = sem-sll-sra-srl shr x

val sem-sllv-srav-srlv shift_op x = do
	rt <- rval Signed x.op2;
	rs <- rval Signed x.op3;
	size <- return (sizeof-lval x.op1);
	
	amount <- mktemp;
	mov 5 amount rs;

	temp <- mktemp;
	shift_op size temp rt (var amount);

	write x.op1 (var temp)
end

val sem-sllv x = sem-sllv-srav-srlv shl x
val sem-srav x = sem-sllv-srav-srlv shrs x
val sem-srlv x = sem-sllv-srav-srlv shr x

val sem-syscall = throw-exception SEM_EXC_SYSTEM_CALL
val sem-t cmp_op x = do
	rs <- rval Signed x.op1;
	rt <- rval Signed x.op2;
	size <- return (sizeof-rval x.op1);

	_if (cmp_op size rs rt) _then
		throw-exception SEM_EXC_TRAP
end

val sem-teq x = sem-t /eq x
val sem-tge x = sem-t /ges x
val sem-tgeu x = sem-t /geu x
val sem-tlt x = sem-t /lts x
val sem-tltu x = sem-t /ltu x
val sem-tne x = sem-t /neq x

val sem-wsbh x = do
	rt <- rval Unsigned x.op2;
	size <- return (sizeof-rval x.op2);

	temp <- mktemp;
	mov size temp rt;
 
	p1 <- mktemp;
	p2 <- mktemp;
	p3 <- mktemp;
	p4 <- mktemp;
	
	mov 8 p1 rt;
	shr size temp (var temp) (imm 8);
	mov 8 p2 rt;
	shr size temp (var temp) (imm 8);
	mov 8 p3 rt;
	shr size temp (var temp) (imm 8);
	mov 8 p4 rt;
	
	res <- mktemp;
	mov 8 res (var p3);
	shl size res (var res) (imm 8);
	mov 8 res (var p4);
	shl size res (var res) (imm 8);
	mov 8 res (var p1);
	shl size res (var res) (imm 8);
	mov 8 res (var p2);

	write x.op1 (var res)	
end

val sem-undefined = return void

val semantics i =
   case i of
      UNPREDICTABLE: sem-default-nullop-generic i
    | UNDEFINED: sem-undefined
    | ABS-fmt x: sem-default-binop-flr-generic i x
    | ADD x: sem-add x
    | ADD-fmt x: sem-default-ternop-flrr-generic i x
    | ADDIU x: sem-addiu x
    | ADDU x: sem-addu x
    | AND x: sem-and x
    | ANDI x: sem-andi x
    | BEQ x: sem-beq x
    | BGEZ x: sem-bgez x
    | BGTZ x: sem-bgtz x
    | BLEZ x: sem-blez x
    | BLTZ x: sem-bltz x
    | BNE x: sem-bne x
    | BREAK x: sem-break x
    | CACHE x: sem-default-binop-rr-tuple-generic i x
    | CACHEE x: sem-default-binop-rr-tuple-generic i x
    | CEIL-L-fmt x: sem-default-binop-flr-generic i x
    | CEIL-W-fmt x: sem-default-binop-flr-generic i x
    | CFC1 x: sem-default-binop-lr-generic i x
    | CFC2 x: sem-default-binop-lr-generic i x
    | CLO x: sem-cl 1 x
    | CLZ x: sem-cl 0 x
    | COP2 x: sem-default-unop-r-generic i x
    | CTC1 x: sem-default-binop-rr-generic i x
    | CTC2 x: sem-default-binop-rr-generic i x
    | CVT-D-fmt x: sem-default-binop-flr-generic i x
    | CVT-L-fmt x: sem-default-binop-flr-generic i x
    | CVT-S-fmt x: sem-default-binop-flr-generic i x
    | CVT-W-fmt x: sem-default-binop-flr-generic i x
    | DERET: sem-deret
    | DI x: sem-di x
    | DIV-fmt x: sem-default-ternop-flrr-generic i x
    | EI x: sem-ei x
    | ERET: sem-eret
    | EXT x: sem-ext x
    | FLOOR-L-fmt x: sem-default-binop-flr-generic i x
    | FLOOR-W-fmt x: sem-default-binop-flr-generic i x
    | INS x: sem-ins x
    | J x: sem-j x
    | JAL x: sem-jal x
    | JALR x: sem-jalr x
    | JALR-HB x: sem-jalr-hb x
    | LB x: sem-lb x
    | LBE x: sem-lb x
    | LBU x: sem-lbu x
    | LBUE x: sem-lbu x
    | LDC1 x: sem-default-binop-lr-tuple-generic i x
    | LH x: sem-lh x
    | LHE x: sem-lh x
    | LHU x: sem-lhu x
    | LHUE x: sem-lhu x
    | LL x: sem-ll x
    | LLE x: sem-ll x
    | LW x: sem-lw x
    | LWC1 x: sem-default-binop-lr-tuple-generic i x
    | LWE x: sem-lw x
    | MFC0 x: sem-default-ternop-lrr-generic i x
    | MFC1 x: sem-default-binop-lr-generic i x
    | MFC2 x: sem-default-binop-lr-generic i x
    | MFHC1 x: sem-default-binop-lr-generic i x
    | MFHC2 x: sem-default-binop-lr-generic i x
    | MOV-fmt x: sem-default-binop-flr-generic i x
    | MTC0 x: sem-default-ternop-rrr-generic i x
    | MTC1 x: sem-default-binop-rl-generic i x
    | MTC2 x: sem-default-binop-rr-generic i x
    | MTHC1 x: sem-default-binop-rl-generic i x
    | MTHC2 x: sem-default-binop-rr-generic i x
    | MUL-fmt x: sem-default-ternop-flrr-generic i x
    | NEG-fmt x: sem-default-binop-flr-generic i x
    | NOR x: sem-nor x
    | OR x: sem-or x
    | ORI x: sem-ori x
    | PAUSE: sem-pause
    | PREF x: sem-default-binop-rr-tuple-generic i x
    | PREFE x: sem-default-binop-rr-tuple-generic i x
    | RDHWR x: sem-rdhwr x
    | RDPGPR x: sem-default-binop-lr-generic i x
    | RECIP-fmt x: sem-default-binop-flr-generic i x
    | ROTR x: sem-rotr x
    | ROTRV x: sem-rotrv x
    | ROUND-L-fmt x: sem-default-binop-flr-generic i x
    | ROUND-W-fmt x: sem-default-binop-flr-generic i x
    | RSQRT-fmt x: sem-default-binop-flr-generic i x
    | SB x: sem-sb x
    | SBE x: sem-sb x
    | SC x: sem-sc x
    | SCE x: sem-sc x
    | SDBBP x: sem-sdbbp x
    | SDC1 x: sem-default-binop-rr-tuple-generic i x
    | SDC2 x: sem-default-binop-rr-tuple-generic i x
    | SEB x: sem-seb x
    | SEH x: sem-seh x
    | SH x: sem-sh x
    | SHE x: sem-sh x
    | SLL x: sem-sll x
    | SLLV x: sem-sllv x
    | SLT x: sem-slt x
    | SLTI x: sem-slti x
    | SLTIU x: sem-sltiu x
    | SLTU x: sem-sltu x
    | SQRT-fmt x: sem-default-binop-flr-generic i x
    | SRA x: sem-sra x
    | SRAV x: sem-srav x
    | SRL x: sem-srl x
    | SRLV x: sem-srlv x
    | SUB x: sem-sub x
    | SUB-fmt x: sem-default-ternop-flrr-generic i x
    | SUBU x: sem-subu x
    | SW x: sem-sw x
    | SWC1 x: sem-default-binop-rr-tuple-generic i x
    | SWC2 x: sem-default-binop-rr-tuple-generic i x
    | SWE x: sem-sw x
    | SYNC x: sem-default-unop-r-generic i x
    | SYNCI x: sem-default-unop-r-tuple-generic i x
    | SYSCALL x: sem-syscall
    | TEQ x: sem-teq x
    | TGE x: sem-tge x
    | TGEU x: sem-tgeu x
    | TLBINV: sem-default-nullop-generic i
    | TLBINVF: sem-default-nullop-generic i
    | TLBP: sem-default-nullop-generic i
    | TLBR: sem-default-nullop-generic i
    | TLBWI: sem-default-nullop-generic i
    | TLBWR: sem-default-nullop-generic i
    | TLT x: sem-tlt x
    | TLTU x: sem-tltu x
    | TNE x: sem-tne x
    | TRUNC-L-fmt x: sem-default-binop-flr-generic i x
    | TRUNC-W-fmt x: sem-default-binop-flr-generic i x
    | WAIT x: sem-default-unop-r-generic i x
    | WRPGPR x: sem-default-binop-rr-generic i x
    | WSBH x: sem-wsbh x
    | XOR x: sem-xor x
    | XORI x: sem-xori x
    | _: revision/semantics i
   end

# -> sftl

# <- sutl

val translate-mips insn = semantics insn.insn

val translate insn = do
  update@{stack=SEM_NIL,tmp=0,lab=0};
  
  translate-mips insn;
  
  stack <- query $stack;
  return (rreil-stmts-rev stack)
end

val translate-block-single insn = do
   ic <- query $ins_count;
   update@{tmp=0,ins_count=ic+1};
   
   translate-mips insn
end

val relative-next stmts = let
  val is_sem_ip x = case x of
     Sem_PC: '1'
   | _: '0'
  end
in
  relative-next-generic is_sem_ip stmts
end
