export = 

type asm_opnds_callbacks = {next:int, init:int}
type asm_opnd_callbacks = {register:int, memory:int, imm:int, post_op:int, pre_op:int, rel:int, annotation:int, sum:int, scale:int, bounded:int}
type asm_boundary_callbacks = {sz:int, sz_o:int}
type asm_annotations_callbacks = {next:int, init:int}
type asm_annotation_callbacks = {ann_string:int, function:int, opnd:int}
type asm_immediate_callbacks = {immediate:int, unknown_signedness:int}

type asm_callbacks = {
  insn:int,
  opnds:asm_opnds_callbacks,
  opnd:asm_opnd_callbacks,
  boundary:asm_boundary_callbacks,
  annotations:asm_annotations_callbacks,
  annotation:asm_annotation_callbacks,
  immediate:asm_immediate_callbacks
}

val asm-convert-insn cbs insn = cbs.insn insn.length insn.mnemonic (asm-convert-annotations cbs insn.annotations) (asm-convert-opnds cbs insn.opnds)

val asm-convert-opnds cbs opnds = let
  val convert-inner list opnds = case opnds of
     ASM_OPNDS_NIL: list
   | ASM_OPNDS_CONS next: convert-inner (cbs.opnds.next (asm-convert-opnd cbs next.hd) list) next.tl
  end
in
  convert-inner (cbs.opnds.init void) opnds
end

val asm-convert-opnd cbs opnd = case opnd of
   ASM_REGISTER r: cbs.opnd.register r
 | ASM_MEMORY m: cbs.opnd.memory (asm-convert-opnd cbs m)
 | ASM_IMM i: cbs.opnd.imm (asm-convert-immediate cbs i)
 | ASM_POST_OP po: cbs.opnd.post_op (asm-convert-opnd cbs po.expr) (asm-convert-opnd cbs po.opnd)
 | ASM_PRE_OP pr: cbs.opnd.pre_op (asm-convert-opnd cbs pr.expr) (asm-convert-opnd cbs pr.opnd)
 | ASM_REL r: cbs.opnd.rel (asm-convert-opnd cbs r)
 | ASM_ANNOTATION a: cbs.opnd.annotation (asm-convert-annotation cbs a.ann) (asm-convert-opnd cbs a.opnd)
 | ASM_SUM s: cbs.opnd.sum (asm-convert-opnd cbs s.lhs) (asm-convert-opnd cbs s.rhs)
 | ASM_SCALE s: cbs.opnd.scale s.factor (asm-convert-opnd cbs s.rhs)
 | ASM_BOUNDED b: cbs.opnd.bounded (asm-convert-boundary cbs b.boundary) (asm-convert-opnd cbs b.opnd)
end

val asm-convert-boundary cbs b = case b of
   ASM_BOUNDARY_SZ sz: cbs.boundary.sz sz
 | ASM_BOUNDARY_SZ_O szo: cbs.boundary.sz_o szo.size szo.offset
end

val asm-convert-annotations cbs anns = let
  val convert-inner list anns = case anns of
     ASM_ANNS_NIL: list
   | ASM_ANNS_CONS next: convert-inner (cbs.annotations.next (asm-convert-annotation cbs next.hd) list) next.tl
  end
in
  convert-inner (cbs.annotations.init void) anns
end

val asm-convert-annotation cbs ann = case ann of
   ASM_ANN_STRING s: cbs.annotation.ann_string s
 | ASM_ANN_FUNCTION f: cbs.annotation.function f.name (asm-convert-opnds cbs f.args)
 | ASM_ANN_OPND o: cbs.annotation.opnd o.name (asm-convert-opnd cbs o.opnd)
end

val asm-convert-immediate cbs imm = case imm of
   ASM_IMMEDIATE i: cbs.immediate.immediate i
 | ASM_UNKNOWN_SIGNEDNESS us: cbs.immediate.unknown_signedness us.value us.size
end
