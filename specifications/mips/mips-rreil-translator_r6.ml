val revision/sizeof-imm imm =
   case imm of
      IMM21 i: 21
    | IMM32 i: 32
    | BP i: 2
    | SA2 i: 2
    | OFFSET11 i: 11
    | OFFSET23 i: 23
    | OFFSET28 i: 28
    | C2CONDITION i: 5
    | CODE16 i: 16
   end

val revision/rval-imm sn x = let
   val from-vec sn vec =
      case sn of
         Signed: SEM_LIN_IMM {const=sx vec}
       | Unsigned: SEM_LIN_IMM {const=zx vec}
      end
in
   case x of
      IMM21 i: from-vec sn i
    | IMM32 i: from-vec sn i
    | BP i: from-vec sn i
    | SA2 i: from-vec sn i
    | OFFSET11 i: from-vec sn i
    | OFFSET23 i: from-vec sn i
    | OFFSET28 i: from-vec sn i
    | C2CONDITION i: from-vec sn i
    | CODE16 i: from-vec sn i
   end
end

val sem-addiupc x = do
	im <- rval Signed x.op2;
	size <- return (sizeof-lval x.op1);
	pc <- return (semantic-reg-of Sem_PC);
	
	# im already shifted at decoding
	res <- mktemp;
	add size res (var pc) im;

	write x.op1 (var res)	
end

val sem-align x = do
	rs <- rval Unsigned x.op2;
	rt <- rval Unsigned x.op3;
	bp_op <- rval Unsigned x.op4;
	size <- return (sizeof-rval x.op2);
	
	bp <- return (lin-to-int bp_op);

	left <- mktemp;
	right <- mktemp;
	
	shl size left rt (imm (8 * bp));
	shr size right rs (imm (8 * (4 - bp)));
	
	res <- mktemp;
	orb size res (var left) (var right);

	write x.op1 (var res)	
end

val sem-aluipc x = do
	im <- rval Signed x.op2;
	size <- return (sizeof-lval x.op1);
	pc <- return (semantic-reg-of Sem_PC);

	# im already shifted at decoding
	temp <- mktemp;
	add size temp (var pc) im;

	res <- mktemp;
	mov size res (imm 0);
	mov (size - 16) res (var (at-offset temp 16));

	write x.op1 (var res)	
end

val sem-aui x = do
	rs <- rval Signed x.op2;
	im <- rval Signed x.op3;
	size <- return (sizeof-rval x.op2);

	# im already bitshifted at decoding
	res <- mktemp;
	add size res rs im;

	write x.op1 (var res)	
end

val sem-auipc x = do
	im <- rval Signed x.op2;
	size <- return (sizeof-lval x.op1);
	pc <- return (semantic-reg-of Sem_PC);

	# im already bitshifted at decoding
	res <- mktemp;
	add size res (var pc) im;

	write x.op1 (var res)	
end

val sem-balc x = do
	pc <- return (semantic-reg-of Sem_PC);
	ra <- return (semantic-gpr-of RA);
	
	# pc got incremented already => add 0 instead of 4
	add ra.size ra (var pc) (imm 0);

	sem-bc x
end

val sem-bc x = do
	# offset already shifted at decoding
	off <- rval Signed x.op;
	size <- return (sizeof-rval x.op);
	
	cbranch-rel (imm 1) off
end

val sem-bc1 cmp_op x = do
	ft <- rval Signed x.op1;
	size <- return (sizeof-rval x.op1);
	
	off <- rval Signed x.op2;
	cond <- cmp_op 1 ft (imm 0);

	cbranch-rel cond off
end

val sem-bc1eqz x = sem-bc1 /eq x
val sem-bc1nez x = sem-bc1 /neq x

val sem-bzalc cmp_op x = do
	pc <- return (semantic-reg-of Sem_PC);
	ra <- return (semantic-gpr-of RA);
	
	# pc got incremented already => add 0 instead of 4
	add ra.size ra (var pc) (imm 0);

	sem-bz cmp_op x
end

val sem-blezalc x = sem-bzalc /les x
val sem-bgezalc x = sem-bzalc /ges x
val sem-bgtzalc x = sem-bzalc /gts x
val sem-bltzalc x = sem-bzalc /lts x
val sem-beqzalc x = sem-bzalc /eq x
val sem-bnezalc x = sem-bzalc /neq x

val sem-blezc x = sem-bz /les x
val sem-bgezc x = sem-bz /ges x
val sem-bgec x = sem-b /ges x
val sem-bgtzc x = sem-bz /gts x
val sem-bltzc x = sem-bz /lts x
val sem-bltc x = sem-b /lts x
val sem-bgeuc x = sem-b /geu x
val sem-bltuc x = sem-b /ltu x
val sem-beqc x = sem-b /eq x
val sem-bnec x = sem-b /neq x
val sem-beqzc x = sem-bz /eq x
val sem-bnezc x = sem-bz /neq x

val sem-bitswap-byte rt rd byte_num i = do
	if (not (i === 7)) then do
		mov 1 (at-offset rd ((byte_num * 8) + (7-i))) (var (at-offset rt ((byte_num * 8) + i)));
		sem-bitswap-byte rt rd byte_num (i+1)
	end
	else
		mov 1 (at-offset rd ((byte_num * 8) + (7-i))) (var (at-offset rt ((byte_num * 8) + i)))
end

val sem-bitswap-word rt rd byte_num = do
	if (not (byte_num === 3)) then do
		sem-bitswap-byte rt rd byte_num 0;
		sem-bitswap-word rd rd (byte_num + 1)
	end
	else
		sem-bitswap-byte rt rd byte_num 0	
end

val sem-bitswap x = do
	rd <- lval Signed x.op1;
	rt <- rval Signed x.op2;
	size <- return (sizeof-lval x.op1);
	
	rt_in <- mktemp;
	mov size rt_in rt;
	rd_out <- mktemp;
	mov size rd_out (imm 0);
 
	sem-bitswap-word rt_in rd_out 0;

	write x.op1 (var rd_out)
end

val branch-on-overflow x cmp_op = do
	rs <- rval Signed x.op1;
	rt <- rval Signed x.op2;
	off <- rval Signed x.op3;
	size <- return (sizeof-rval x.op1);

	res <- mktemp;
	add size res rs rt;
	
	t1 <- mktemp;
	t2 <- mktemp;
	t3 <- mktemp;

	# overflow computation: mind**** alert
	xorb size t1 (var res) rs;
	xorb size t2 (var res) rt;
	andb size t3 (var t1) (var t2);

	cond <- cmp_op size (var t3) (imm 0);
	cbranch-rel cond off
end 

val sem-bovc x = branch-on-overflow x /lts
val sem-bnvc x = branch-on-overflow x /ges

val sem-div-divu-mod-modu op x = do
	num <- rval Signed x.op2;
	denom <- rval Signed x.op3;
	size <- return (sizeof-rval x.op2);

	res <- mktemp;
	op size res num denom;

	write x.op1 (var res)
end

val sem-div x = sem-div-divu-mod-modu divs x
val sem-divu x = sem-div-divu-mod-modu div x
val sem-mod x = sem-div-divu-mod-modu mods x
val sem-modu x = sem-div-divu-mod-modu mod x

val sem-jialc x = do
	rt <- rval Signed x.op1;
	off <- rval Signed x.op2;
	size <- return (sizeof-rval x.op1);
	pc <- return (semantic-reg-of Sem_PC);
	ra <- return (semantic-gpr-of RA);

	pc_new <- mktemp;
	mov size pc_new rt; 

	add size pc_new (var pc_new) off;
	mov size ra (var pc_new);

	jump (address size (var pc_new))
end

val sem-jic x = do
	rt <- rval Signed x.op1;
	off <- rval Signed x.op2;
	size <- return (sizeof-rval x.op1);
	pc <- return (semantic-reg-of Sem_PC);

	pc_new <- mktemp;
	mov size pc_new rt; 

	add size pc_new (var pc_new) off;

	jump (address size (var pc_new))
end

val sem-lsa x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	sa2 <- rval Signed x.op4;
	size <- return (sizeof-lval x.op1);

	sa <- return (1 + lin-to-int sa2);

	res <- mktemp;
	shl size res rs (imm sa);
	add size res (var res) rt;

	write x.op1 (var res)
end

val sem-mul-muh-mulu-muhu ext_op hi x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	size <- return (sizeof-rval x.op2);

	rs_ext <- mktemp;
	ext_op (size*2) rs_ext size rs;

	rt_ext <- mktemp;
	ext_op (size*2) rt_ext size rt;

	res <- mktemp;
	mul (size*2) res (var rs_ext) (var rt_ext);

	write x.op1 (var (at-offset res (size*hi)))
end

val sem-mul x = sem-mul-muh-mulu-muhu movsx 0 x
val sem-muh x = sem-mul-muh-mulu-muhu movsx 1 x
val sem-mulu x = sem-mul-muh-mulu-muhu movzx 0 x
val sem-muhu x = sem-mul-muh-mulu-muhu movzx 1 x

val sem-nal = do
	pc <- return (semantic-reg-of Sem_PC);
	ra <- return (semantic-gpr-of RA);

	add ra.size ra (var pc) (imm 4)
end

val sem-sel cmp_op x = do
	rs <- rval Signed x.op2;
	rt <- rval Signed x.op3;
	size <- return (sizeof-rval x.op2);

	_if (cmp_op size rt (imm 0)) _then
		write x.op1 rs
	_else
		write x.op1 (imm 0)
end

val sem-seleqz x = sem-sel /eq x
val sem-selnez x = sem-sel /neq x

val sem-sigrie x = throw-exception SEM_EXC_RESERVED_INSTRUCTION

val revision/semantics i =
   case i of
      ADDIUPC x: sem-addiupc x
    | ALIGN x: sem-align x
    | ALUIPC x: sem-aluipc x
    | AUI x: sem-aui x
    | AUIPC x: sem-auipc x
    | BALC x: sem-balc x
    | BC x: sem-bc x
    | BC1EQZ x: sem-bc1eqz x
    | BC1NEZ x: sem-bc1nez x
    | BC2EQZ x: sem-default-binop-rr-generic i x
    | BC2NEZ x: sem-default-binop-rr-generic i x
    | BLEZALC x: sem-blezalc x
    | BGEZALC x: sem-bgezalc x
    | BGTZALC x: sem-bgtzalc x
    | BLTZALC x: sem-bltzalc x
    | BEQZALC x: sem-beqzalc x
    | BNEZALC x: sem-bnezalc x
    | BLEZC x: sem-blezc x
    | BGEZC x: sem-bgezc x
    | BGEC x: sem-bgec x
    | BGTZC x: sem-bgtzc x
    | BLTZC x: sem-bltzc x
    | BLTC x: sem-bltc x
    | BGEUC x: sem-bgeuc x
    | BLTUC x: sem-bltuc x
    | BEQC x: sem-beqc x
    | BNEC x: sem-bnec x
    | BEQZC x: sem-beqzc x
    | BNEZC x: sem-bnezc x
    | BITSWAP x: sem-bitswap x
    | BOVC x: sem-bovc x
    | BNVC x: sem-bnvc x
    | CLASS-fmt x: sem-default-binop-flr-generic i x
    | CMP-condn-fmt x: sem-default-ternop-cflrr-generic i x
    | DIV x: sem-div x
    | MOD x: sem-mod x
    | DIVU x: sem-divu x
    | MODU x: sem-modu x
    | DVP x: sem-default-unop-l-generic i x
    | EVP x: sem-default-unop-l-generic i x
    | JIALC x: sem-jialc x
    | JIC x: sem-jic x
    | LSA x: sem-lsa x
    | MADDF-fmt x: sem-default-ternop-flrr-generic i x
    | MSUBF-fmt x: sem-default-ternop-flrr-generic i x
    | MAX-fmt x: sem-default-ternop-flrr-generic i x
    | MAXA-fmt x: sem-default-ternop-flrr-generic i x
    | MIN-fmt x: sem-default-ternop-flrr-generic i x
    | MINA-fmt x: sem-default-ternop-flrr-generic i x
    | MUL x: sem-mul x
    | MUH x: sem-muh x
    | MULU x: sem-mulu x
    | MUHU x: sem-muhu x
    | NAL: sem-nal
    | RINT-fmt x: sem-default-binop-flr-generic i x
    | SEL-fmt x: sem-default-ternop-flrr-generic i x
    | SELEQZ x: sem-seleqz x
    | SELNEZ x: sem-selnez x
    | SELEQZ-fmt x: sem-default-ternop-flrr-generic i x
    | SELNEQZ-fmt x: sem-default-ternop-flrr-generic i x
    | SIGRIE x: sem-sigrie x
   end
