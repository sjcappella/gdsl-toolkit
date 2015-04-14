val uarity-of insn = let
  val f a b = b
in
  traverse f insn
end

val mnemonic-of insn = let
  val f a b = a
in
  traverse f insn
end

type uarity =
   NULLOP
 | UNOP_R of unop-r
 | UNOP_L of unop-l
 | BINOP_RR of binop-rr
 | BINOP_RL of binop-rl
 | BINOP_LR of binop-lr
 | BINOP_FLR of binop-flr
 | TERNOP_RRR of ternop-rrr
 | TERNOP_LRR of ternop-lrr
 | TERNOP_FLRR of ternop-flrr
 | TERNOP_CFLRR of ternop-cflrr
 | QUADOP_LRRR of quadop-lrrr
 | QUADOP_FLRRR of quadop-flrrr


val traverse f insn = 
   case insn of
      UNPREDICTABLE: f "UNPREDICTABLE" (NULLOP)
    | UNDEFINED: f "UNDEFINED" (NULLOP)
    | ABS-fmt x: f "ABS" (BINOP_FLR x)
    | ADD x: f "ADD" (TERNOP_LRR x)
    | ADD-fmt x: f "ADD" (TERNOP_FLRR x)
    | ADDIU x: f "ADDIU" (TERNOP_LRR x)
    | ADDU x: f "ADDU" (TERNOP_LRR x)
    | AND x: f "AND" (TERNOP_LRR x)
    | ANDI x: f "ANDI" (TERNOP_LRR x)
    | BEQ x: f "BEQ" (TERNOP_RRR x)
    | BGEZ x: f "BGEZ" (BINOP_RR x)
    | BGTZ x: f "BGTZ" (BINOP_RR x)
    | BLEZ x: f "BLEZ" (BINOP_RR x)
    | BLTZ x: f "BLTZ" (BINOP_RR x)
    | BNE x: f "BNE" (TERNOP_RRR x)
    | BREAK x: f "BREAK" (UNOP_R x)
    | CACHE x: f "CACHE" (BINOP_RR x)
    | CACHEE x: f "CACHEE" (BINOP_RR x)
    | CEIL-L-fmt x: f "CEIL.L" (BINOP_FLR x)
    | CEIL-W-fmt x: f "CEIL.W" (BINOP_FLR x)
    | CFC1 x: f "CFC1" (BINOP_LR x)
    | CFC2 x: f "CFC2" (BINOP_LR x)
    | CLO x: f "CLO" (BINOP_LR x)
    | CLZ x: f "CLZ" (BINOP_LR x)
    | COP2 x: f "COP2" (UNOP_R x)
    | CTC1 x: f "CTC1" (BINOP_RR x)
    | CTC2 x: f "CTC2" (BINOP_RR x)
    | CVT-D-fmt x: f "CVT.D" (BINOP_FLR x)
    | CVT-L-fmt x: f "CVT.L" (BINOP_FLR x)
    | CVT-S-fmt x: f "CVT.S" (BINOP_FLR x)
    | CVT-W-fmt x: f "CVT.W" (BINOP_FLR x)
    | DERET: f "DERET" (NULLOP)
    | DI x: f "DI" (UNOP_L x)
    | DIV-fmt x: f "DIV" (TERNOP_FLRR x)
    | EI x: f "EI" (UNOP_L x)
    | ERET: f "ERET" (NULLOP)
    | EXT x: f "EXT" (QUADOP_LRRR x)
    | FLOOR-L-fmt x: f "FLOOR.L" (BINOP_FLR x)
    | FLOOR-W-fmt x: f "FLOOR.W" (BINOP_FLR x)
    | INS x: f "INS" (TERNOP_LRR x)
    | J x: f "J" (UNOP_R x)
    | JAL x: f "JAL" (UNOP_R x)
    | JALR x: f "JALR" (BINOP_LR x)
    | JALR-HB x: f "JALR.HB" (BINOP_LR x)
    | LB x: f "LB" (BINOP_LR x)
    | LBE x: f "LBE" (BINOP_LR x)
    | LBU x: f "LBU" (BINOP_LR x)
    | LBUE x: f "LBUE" (BINOP_LR x)
    | LDC1 x: f "LDC1" (BINOP_LR x)
    | LH x: f "LH" (BINOP_LR x)
    | LHE x: f "LHE" (BINOP_LR x)
    | LHU x: f "LHU" (BINOP_LR x)
    | LHUE x: f "LHUE" (BINOP_LR x)
    | LL x: f "LL" (BINOP_LR x)
    | LLE x: f "LLE" (BINOP_LR x)
    | LW x: f "LW" (BINOP_LR x)
    | LWC1 x: f "LWC1" (BINOP_LR x)
    | LWE x: f "LWE" (BINOP_LR x)
    | MFC0 x: f "MFC0" (TERNOP_LRR x)
    | MFC1 x: f "MFC1" (BINOP_LR x)
    | MFC2 x: f "MFC2" (BINOP_LR x)
    | MFHC1 x: f "MFHC1" (BINOP_LR x)
    | MFHC2 x: f "MFHC2" (BINOP_LR x)
    | MOV-fmt x: f "MOV" (BINOP_FLR x)
    | MTC0 x: f "MTC0" (TERNOP_RRR x)
    | MTC1 x: f "MTC1" (BINOP_RL x)
    | MTC2 x: f "MTC2" (BINOP_RR x)
    | MTHC1 x: f "MTHC1" (BINOP_RL x)
    | MTHC2 x: f "MTHC2" (BINOP_RR x)
    | MUL-fmt x: f "MUL" (TERNOP_FLRR x)
    | NEG-fmt x: f "NEG" (BINOP_FLR x)
    | NOR x: f "NOR" (TERNOP_LRR x)
    | OR x: f "OR" (TERNOP_LRR x)
    | ORI x: f "ORI" (TERNOP_LRR x)
    | PAUSE: f "PAUSE" (NULLOP)
    | PREF x: f "PREF" (BINOP_RR x)
    | PREFE x: f "PREFE" (BINOP_RR x)
    | RDHWR x: f "RDHWR" (BINOP_LR x)
    | RDPGPR x: f "RDPGPR" (BINOP_LR x)
    | RECIP-fmt x: f "RECIP" (BINOP_FLR x)
    | ROTR x: f "ROTR" (TERNOP_LRR x)
    | ROTRV x: f "ROTRV" (TERNOP_LRR x)
    | ROUND-L-fmt x: f "ROUND.L" (BINOP_FLR x)
    | ROUND-W-fmt x: f "ROUND.W" (BINOP_FLR x)
    | RSQRT-fmt x: f "RSQRT" (BINOP_FLR x)
    | SB x: f "SB" (BINOP_RR x)
    | SBE x: f "SBE" (BINOP_RR x)
    | SC x: f "SC" (BINOP_LR x)
    | SCE x: f "SCE" (BINOP_LR x)
    | SDBBP x: f "SDBBP" (UNOP_R x)
    | SDC1 x: f "SDC1" (BINOP_RR x)
    | SDC2 x: f "SDC2" (BINOP_RR x)
    | SEB x: f "SEB" (BINOP_LR x)
    | SEH x: f "SEH" (BINOP_LR x)
    | SH x: f "SH" (BINOP_RR x)
    | SHE x: f "SHE" (BINOP_RR x)
    | SLL x: f "SLL" (TERNOP_LRR x)
    | SLLV x: f "SLLV" (TERNOP_LRR x)
    | SLT x: f "SLT" (TERNOP_LRR x)
    | SLTI x: f "SLTI" (TERNOP_LRR x)
    | SLTIU x: f "SLTIU" (TERNOP_LRR x)
    | SLTU x: f "SLTU" (TERNOP_LRR x)
    | SQRT-fmt x: f "SQRT" (BINOP_FLR x)
    | SRA x: f "SRA" (TERNOP_LRR x)
    | SRAV x: f "SRAV" (TERNOP_LRR x)
    | SRL x: f "SRL" (TERNOP_LRR x)
    | SRLV x: f "SRLV" (TERNOP_LRR x)
    | SUB x: f "SUB" (TERNOP_LRR x)
    | SUB-fmt x: f "SUB" (TERNOP_FLRR x)
    | SUBU x: f "SUBU" (TERNOP_LRR x)
    | SUXC1 x: f "SUXC1" (BINOP_RR x)
    | SW x: f "SW" (BINOP_RR x)
    | SWC1 x: f "SWC1" (BINOP_RR x)
    | SWC2 x: f "SWC2" (BINOP_RR x)
    | SWE x: f "SWE" (BINOP_RR x)
    | SWL x: f "SWL" (BINOP_RR x)
    | SWLE x: f "SWLE" (BINOP_RR x)
    | SWR x: f "SWR" (BINOP_RR x)
    | SWRE x: f "SWRE" (BINOP_RR x)
    | SWXC1 x: f "SWXC1" (BINOP_RR x)
    | SYNC x: f "SYNC" (UNOP_R x)
    | SYNCI x: f "SYNCI" (UNOP_R x)
    | SYSCALL x: f "SYSCALL" (UNOP_R x)
    | TEQ x: f "TEQ" (TERNOP_RRR x)
    | TEQI x: f "TEQI" (BINOP_RR x)
    | TGE x: f "TGE" (TERNOP_RRR x)
    | TGEI x: f "TGEI" (BINOP_RR x)
    | TGEIU x: f "TGEIU" (BINOP_RR x)
    | TGEU x: f "TGEU" (TERNOP_RRR x)
    | TLBINV: f "TLBINV" (NULLOP)
    | TLBINVF: f "TLBINVF" (NULLOP)
    | TLBP: f "TLBP" (NULLOP)
    | TLBR: f "TLBR" (NULLOP)
    | TLBWI: f "TLBWI" (NULLOP)
    | TLBWR: f "TLBWR" (NULLOP)
    | TLT x: f "TLT" (TERNOP_RRR x)
    | TLTI x: f "TLTI" (BINOP_RR x)
    | TLTIU x: f "TLTIU" (BINOP_RR x)
    | TLTU x: f "TLTU" (TERNOP_RRR x)
    | TNE x: f "TNE" (TERNOP_RRR x)
    | TNEI x: f "TNEI" (BINOP_RR x)
    | TRUNC-L-fmt x: f "TRUNC.L" (BINOP_FLR x)
    | TRUNC-W-fmt x: f "TRUNC.W" (BINOP_FLR x)
    | WAIT x: f "WAIT" (UNOP_R x)
    | WRPGPR x: f "WRPGPR" (BINOP_RR x)
    | WSBH x: f "WSBH" (BINOP_LR x)
    | XOR x: f "XOR" (TERNOP_LRR x)
    | XORI x: f "XORI" (TERNOP_LRR x)
    | _: revision/traverse f insn
   end
