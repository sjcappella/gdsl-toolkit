
structure FromCore : sig
   val run:
      Core.Spec.t ->
         CPS.Spec.t CompilationMonad.t
end = struct

   structure CM = CompilationMonad
   structure Exp = CPS.Exp
   structure CCTab = CPS.CCTab

   val variable = Atom.atom "x"
   val function = Atom.atom "f"
   val constructor = Atom.atom "cons"
   val continuation = CCTab.kont

   val constructors: (Spec.sym * Spec.ty option) SymMap.map ref = ref SymMap.empty

   fun isEnumLike c =
      case SymMap.lookup (!constructors, c) of
         (_, NONE) => true | _ => false

   fun fresh variable = let
      val (tab, sym) =
         VarInfo.fresh (!SymbolTables.varTable, variable)
   in
      sym before SymbolTables.varTable := tab
   end

   fun bind map v t = SymMap.insert (map, v, t) 

   local open Core.Exp in

   fun translate spec =
      Spec.upd
         (fn cs =>
            let
               val main = fresh function
               val kont = fresh continuation
               val () = constructors := Spec.get#constructors spec
            in
               trans0 
                  (* TODO: "export" exported symbols as record *)
                  (LETREC (cs, RECORD []))
                  (fn z => Exp.APP (main, kont, z))
            end) spec

   and trans0 e kappa = 
      case e of
         LETVAL (v, e, body) =>
            let
               val j = fresh continuation
               val body = trans0 body kappa
            in
               Exp.LETCC ([(j, v, body)], trans1 e j)
            end
       | LETREC (ds, body) => Exp.LETREC (map trans0rec ds, trans0 body kappa)
       | IF (iff, thenn, elsee) =>
            trans0
               (CASE
                  (iff,
                   [(Core.Pat.BIT "1", thenn),
                    (Core.Pat.BIT "0", elsee)]))
               kappa
       | CASE (e, ps) =>
            let
               val j = fresh continuation
               fun trans z ps cps ks =
                  case ps of
                     [] =>
                        let
                           val x = fresh variable
                        in
                           Exp.LETCC
                              ((j, x, kappa x)::cps,
                               Exp.CASE (z, ks))
                        end
                   | (p, e)::ps =>
                        let
                           val k = fresh continuation
                           val (x, ks) = transPat p k ks
                        in
                           trans z ps ((k, x, trans1 e j)::cps) ks
                        end
            in
               trans0 e (fn z => trans z ps [] StringMap.empty)
            end
       | APP (e1, e2) =>
            let
               val k = fresh continuation
               val x = fresh variable
            in
               trans0 e1 (fn x1 =>
                  trans0 e2 (fn x2 =>
                     Exp.LETCC ([(k, x, kappa x)], Exp.APP (x1, k, x2))))
            end
       | FN (x, e) =>
            let
               val f = fresh function
               val k = fresh continuation
            in
               Exp.LETREC ([(f, k, [x], trans1 e k)], kappa f) 
            end
       | RECORD fs =>
            let
               fun trans fs fvs =
                  case fs of
                     [] =>
                        let
                           val x = fresh variable
                        in
                           Exp.LETVAL (x, Exp.REC fvs, kappa x)
                        end
                   | (f, e)::fs =>
                        trans0 e (fn z =>
                           trans fs ((f, z)::fvs))
            in
               trans fs []
            end
       | UPDATE fs => 
            let
               val f = fresh function
               val k = fresh continuation
               val x = fresh variable
               val z = fresh variable
               fun trans y fs fvs =
                  case fs of
                     [] =>
                        let
                           val x = fresh variable
                        in
                           Exp.LETUPD (x, y, fvs, kappa x)
                        end
                   | (f, e)::fs =>
                        trans0 e (fn z =>
                           trans y fs ((f, z)::fvs))
            in
               (* Exp.LETREC ([(f, k, [x], trans x fs [])], kappa f) *)
               Exp.LETVAL
                  (f,
                   Exp.FN (k, x, trans x fs []),
                   kappa f)
            end
       | SELECT fld =>
            let
               val f = fresh function
               val k = fresh continuation
               val x = fresh variable
               val z = fresh variable
            in
               
               (* Exp.LETREC
                  ([(f, k, [x],
                     Exp.LETPRJ (z, fld, x, Exp.CC (k, z)))],
                   kappa f) *)
               Exp.LETVAL
                  (f,
                   Exp.FN
                     (k,
                      x,
                      Exp.LETPRJ (z, fld, x, Exp.CC (k, z))),
                   kappa f)
            end
       | CON c =>
            if isEnumLike c
               then
                  let
                     val x = fresh variable
                     val y = fresh variable
                  in
                     Exp.LETVAL (y, Exp.UNT,
                     Exp.LETVAL (x, Exp.INJ (c, y), kappa x))
                  end
            else
               let
                  val f = fresh constructor
                  val k = fresh continuation
                  val x = fresh variable
                  val y = fresh variable
               in
                  (* Exp.LETREC
                     ([(f, k, [x],
                       Exp.LETVAL (y, Exp.INJ (c, x), Exp.CC (k, y)))],
                      kappa f) *)
                  Exp.LETVAL
                     (f,
                      Exp.FN
                        (k,
                         x,
                         Exp.LETVAL (y, Exp.INJ (c, x), Exp.CC (k, y))),
                      kappa f)
               end
       | LIT l =>
            let
               val x = fresh variable
            in
               Exp.LETVAL (x, transLit l, kappa x)
            end
       | ID v => kappa v
       | _ => raise CM.CompilationError
  
   and transPat p k ks =
      let (* TODO *)
         open Core.Pat
         fun toIdx p =
            case p of
               BIT str => str
             | INT i => IntInf.toString i
             | CON (s, NONE) => Int.toString (SymbolTable.toInt s)
             | _ => "" 
         val x = fresh variable
      in
         (x, StringMap.insert (ks, toIdx p, k))
      end

   and trans0rec (n, args, e) =
      let
         val k = fresh continuation
      in
         (n, k, args, trans1 e k)
      end

   and trans1 e kont =
      case e of
         LETVAL (v, e, body) =>
            let
               val j = fresh continuation
               val body = trans1 body kont
            in
               Exp.LETCC ([(j, v, body)], trans1 e j)
            end
       | LETREC (ds, body) => Exp.LETREC (map trans0rec ds, trans1 body kont)
       | IF (iff, thenn, elsee) =>
            trans1
               (CASE
                  (iff,
                   [(Core.Pat.BIT "1", thenn),
                    (Core.Pat.BIT "0", elsee)]))
               kont
       | CASE (e, ps) =>
            let
               fun trans z ps cps ks =
                  case ps of
                     (p, e)::ps =>
                        let
                           val k = fresh continuation
                           val (x, ks) = transPat p k ks
                        in
                           trans z ps ((k, x, trans1 e kont)::cps) ks
                        end
                   | [] => Exp.LETCC (cps, Exp.CASE (z, ks))
            in
               trans0 e (fn z => trans z ps [] StringMap.empty)
            end
       | APP (e1, e2) =>
            trans0 e1 (fn x1 =>
               trans0 e2 (fn x2 =>
                  Exp.APP (x1, kont, x2)))
       | FN (x, e) =>
            let
               val f = fresh function
               val j = fresh continuation
            in
               Exp.LETVAL (f, Exp.FN (j, x, trans1 e kont), Exp.CC (kont, f))
            end
       | RECORD fs =>
            let
               fun trans fs fvs =
                  case fs of
                     [] =>
                        let
                           val x = fresh variable
                        in
                           Exp.LETVAL (x, Exp.REC fvs, Exp.CC (kont, x))
                        end
                   | (f, e)::fs =>
                        trans0 e (fn z =>
                           trans fs ((f, z)::fvs))
            in
               trans fs []
            end
       | UPDATE fs => 
            let
               val f = fresh function
               val k = fresh continuation
               val x = fresh variable
               val z = fresh variable
               fun trans y fs fvs =
                  case fs of
                     [] =>
                        let
                           val x = fresh variable
                        in
                           Exp.LETUPD (x, y, fvs, Exp.CC (kont, x))
                        end
                   | (f, e)::fs =>
                        trans0 e (fn z =>
                           trans y fs ((f, z)::fvs))
            in
               (* TODO: letval f = \k x. ... *)
               Exp.LETVAL
                  (f,
                   Exp.FN (k, x, trans x fs []),
                   Exp.CC (kont, f))
            end
       | SELECT fld =>
            let
               val f = fresh function
               val k = fresh continuation
               val x = fresh variable
               val z = fresh variable
            in
               (* TODO: letval f = \k x. ... *)
               Exp.LETVAL
                  (f,
                   Exp.FN (k, x, Exp.LETPRJ (z, fld, x, Exp.CC (k, z))),
                   Exp.CC (kont, f))
            end
       | CON c =>
            if isEnumLike c
               then
                  let
                     val x = fresh variable
                     val y = fresh variable
                  in
                     Exp.LETVAL (y, Exp.UNT,
                     Exp.LETVAL (x, Exp.INJ (c, y), Exp.CC (kont, x)))
                  end
            else
               let
                  val f = fresh constructor
                  val k = fresh continuation
                  val x = fresh variable
                  val y = fresh variable
               in
                  (* TODO: letval f = \k x. ... *)
                  Exp.LETVAL
                     (f,
                      Exp.FN
                        (k,
                         x,
                         Exp.LETVAL
                           (y, Exp.INJ (c, x), Exp.CC (k, y))),
                      Exp.CC (kont, f))
               end
       | LIT l =>
            let
               val x = fresh variable
            in
               Exp.LETVAL (x, transLit l, Exp.CC (kont, x))
            end
       | ID x => Exp.CC (kont, x)
       | _ => raise CM.CompilationError

   and transLit l =
      case l of
         Core.Lit.INTlit i => Exp.INT i
       | Core.Lit.FLTlit f => Exp.FLT f
       | Core.Lit.VEClit v => Exp.VEC v 
       | Core.Lit.STRlit s => Exp.STR s

   end (* end local *)

   fun dumpPre (os, spec) = Pretty.prettyTo (os, Core.PP.spec spec)
   fun dumpPost (os, spec) = Pretty.prettyTo (os, CPS.PP.spec spec)

   val translate =
      BasicControl.mkKeepPass
         {passName="translateCoreToCPS",
          registry=CPSControl.registry,
          pass=translate,
          preExt="ast",
          preOutput=dumpPre,
          postExt="ast",
          postOutput=dumpPost}

   fun run spec = CM.return (translate spec)
end