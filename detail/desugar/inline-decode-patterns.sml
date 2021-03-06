
(**
 * ## Inlining of decode patterns.
 *)
structure VarAux = struct
   val variables = SymbolTables.varTable
   fun atomOf x = VarInfo.getAtom (!variables, x)
   fun get s = VarInfo.lookup (!variables, Atom.atom s)
   fun find s = VarInfo.find (!variables, Atom.atom s)
   fun fresh variable = let
      val (tab, sym) =
         VarInfo.fresh (!variables, variable)
   in
      sym before SymbolTables.varTable := tab
   end
end

structure ASTSubst = struct
   val empty = SymMap.empty
   fun apply sigma x =
      case SymMap.find (sigma, x) of
         NONE => x
       | SOME y => y
   fun applyAll sigma xs = map (apply sigma) xs
   fun extend sigma x y = SymMap.insert (sigma, y, x)
   fun extendAll sigma xs ys =
      foldl
         (fn ((y, x), sigma) =>
            extend sigma y x)
         sigma (ListPair.zip (xs, ys))

   fun copy x =
      let
         val name = VarAux.atomOf x
         val x' = VarAux.fresh name
      in
         x'
      end
   fun copyAll xs = map copy xs

   fun singleton y x = extend empty y x

   local open SpecAbstractTree in

   fun run sigma t = visitExp sigma t

   and visitExp sigma t =
      case t of
         MARKexp t => visitExp sigma (#tree t)
       | LETRECexp (ds, e) =>
            LETRECexp (map (visitRec sigma) ds, visitExp sigma e)
       | IFexp (iff, thenn, elsee) =>
            IFexp
               (visitExp sigma iff,
                visitExp sigma thenn,
                visitExp sigma elsee)
       | CASEexp (e, cs) =>
            CASEexp
               (visitExp sigma e,
                map (visitCase sigma) cs)
       | BINARYexp (e1, binop, e2) =>
            BINARYexp
               (visitExp sigma e1,
                binop,
                visitExp sigma e2)
       | APPLYexp (e, es) =>
            APPLYexp 
               (visitExp sigma e,
                map (visitExp sigma) es)
       | RECORDexp fs => RECORDexp (map (visitField sigma) fs)
       | UPDATEexp fs => UPDATEexp (map (visitFieldOpt sigma) fs)
       | SEQexp es => SEQexp (map (visitSeqexp sigma) es)
       | FNexp (x, e) => FNexp (x, visitExp sigma e)
       | IDexp sym => IDexp (apply sigma sym)
       | otherwise => otherwise

   and visitRec sigma (f, xs, e) = (f, xs, visitExp sigma e)
   and visitCase sigma (pat, e) = (pat, visitExp sigma e)
   and visitField sigma (f, e) = (f, visitExp sigma e)
   and visitFieldOpt sigma (f, eOpt) = (f, Option.map (visitExp sigma) eOpt)
   and visitSeqexp sigma t =
      case t of
         MARKseqexp t => visitSeqexp sigma (#tree t)
       | ACTIONseqexp e => ACTIONseqexp (visitExp sigma e)
       | BINDseqexp (x, e) => BINDseqexp (x, visitExp sigma e)

   fun rename t = renameExp empty t

   and renameExp sigma t =
      case t of
         MARKexp t => renameExp sigma (#tree t)
       | LETRECexp (ds, e) =>
            let
               val (sigma,ds) = renameRecs sigma ds
            in
               LETRECexp (ds, renameExp sigma e)
            end
       | IFexp (iff, thenn, elsee) =>
            IFexp
               (renameExp sigma iff,
                renameExp sigma thenn,
                renameExp sigma elsee)
       | CASEexp (e, cs) =>
            CASEexp
               (renameExp sigma e,
                map (renameCase sigma) cs)
       | BINARYexp (e1, binop, e2) =>
            BINARYexp
               (renameExp sigma e1,
                binop,
                renameExp sigma e2)
       | APPLYexp (e, es) =>
            APPLYexp
               (renameExp sigma e,
                map (renameExp sigma) es)
       | RECORDexp fs => RECORDexp (map (renameField sigma) fs)
       | UPDATEexp fs => UPDATEexp (map (renameFieldOpt sigma) fs)
       | SEQexp es =>
            let
               fun visitSeqexp sigma e =
                  case e of
                     MARKseqexp e => visitSeqexp sigma (#tree e)
                   | ACTIONseqexp e => ACTIONseqexp (renameExp sigma e)
                   | BINDseqexp (x, e) =>
                        (* {x} was renamed so we just have to
                         * substitute it here *)
                        BINDseqexp (apply sigma x, renameExp sigma e)

               fun previsit (t, sigma) =
                  case t of
                     MARKseqexp t => previsit (#tree t,sigma)
                   | BINDseqexp (x, e) => 
                        let
                           val x' = copy x
                           val sigma = extend sigma x' x
                        in
                           sigma
                        end
                   | _ => sigma
                  
               val sigma = foldl previsit sigma es
            in
               SEQexp (map (visitSeqexp sigma) es)
            end
       | FNexp (xs, e) =>
            let
               val xs' = copyAll xs
               val sigma = extendAll sigma xs' xs
            in
               FNexp (xs', renameExp sigma e)
            end
       | IDexp sym => IDexp (apply sigma sym)
       | otherwise => otherwise

   and renameRecs sigma ds =
      let
         fun renameFn ((f,xs,_),sigma) =
            let
               val f' = copy f
               val xs' = copyAll xs
               val sigma = extend sigma f' f
               val sigma = extendAll sigma xs' xs
            in
               sigma
            end
         val sigma = List.foldl renameFn sigma ds
      in
         (sigma, map (renameRec sigma) ds)
      end
   and renameRec sigma (f, xs, e) =
      let
         val f' = apply sigma f
         val xs' = applyAll sigma xs
         val e' = renameExp sigma e
      in
         (f', xs', e')
      end
   and renameCase sigma (pat, e) = (pat, renameExp sigma e)
   and renameField sigma (f, e) = (f, renameExp sigma e)
   and renameFieldOpt sigma (f, eOpt) = (f, Option.map (renameExp sigma) eOpt)
   end
end
 
structure InlineDecodePatterns : sig
   val run: DesugarGuards.o -> DesugarGuards.o CompilationMonad.t
end = struct

   structure T = SpecAbstractTree
   structure Map = SymMap

   fun bind (map, n, d) =
      Map.unionWith op@ (map, Map.singleton (n, d))

   fun rmSpans pats =
       let
          fun decodepat (T.MARKdecodepat t) = decodepat (#tree t)
            | decodepat (T.TOKENdecodepat p) = T.TOKENdecodepat (tokpat p)
            | decodepat (T.BITdecodepat bs) = T.BITdecodepat (List.map bitpat bs)
          and bitpat (T.MARKbitpat t) = bitpat (#tree t)
            | bitpat bp = bp
          and tokpat (T.MARKtokpat t) = tokpat (#tree t)
            | tokpat tp = tp
       in 
         List.map decodepat pats
      end

   fun flattenDecodePatterns (err, ds) = let
      open T
      val map = ref ds
      val varmap = !SymbolTables.varTable
      fun inline spOpt (x, exp) =
         case Map.find (!map, x) of
            NONE =>
               (Error.errorAt
                  (err,
                   VarInfo.getSpan (varmap, x),
                   ["Unbound or recursive pattern detected"])
               ;raise CompilationMonad.CompilationError)
          | SOME ds =>
               let
                  (* remove `x` from available patterns, if it coccurs twice,
                   * we have found recursion (remember that all `x` are unique)
                   *)
                  val (map', _) = Map.remove (!map, x)
                  val () = map := map'
                  val ps =
                     List.concat (List.map
                        (fn (pats, exp') =>
                           flattenDecodePats spOpt
                              (rmSpans pats,
                               SEQexp
                                 [ACTIONseqexp (ASTSubst.rename exp'),
                                  ACTIONseqexp
                                     (if List.length ds > 1
                                         then ASTSubst.rename exp
                                      else exp)]))
                         ds)
               in
                  map := Map.insert (!map, x, ds)
                 ;ps
               end

      and flattenTokPat spOpt (tokpat, exp) =
         case tokpat of
            MARKtokpat t' => flattenTokPat (SOME (#span t')) (#tree t', exp)
          | NAMEDtokpat x => inline spOpt (x, exp)
          | _ => 
            (case spOpt of
               NONE => [([TOKENdecodepat tokpat], exp)]
             | SOME sp  => [([MARKdecodepat {span=sp, tree=TOKENdecodepat tokpat}], exp)]
            )

      and renamePatternBinding spOpt (pat, exp) =
         case pat of
            BITVECbitpat (x, lit) =>
               let
                  val y = ASTSubst.copy x
                  val exp = ASTSubst.run (ASTSubst.singleton y x) exp
               in
                  case spOpt of
                     NONE => (BITVECbitpat (y, lit), exp)
                   | SOME sp  => (MARKbitpat {span=sp, tree=BITVECbitpat (y, lit)}, exp)
               end
          | otherwise => (otherwise, exp)

      and flattenBitPat spOpt (bitpat, exp) =
         case bitpat of
            MARKbitpat t' => flattenBitPat (SOME (#span t')) (#tree t', exp)
          | NAMEDbitpat x => inline spOpt (x, exp)
          | _ =>
            let
               val (bitpat, exp) = renamePatternBinding spOpt (bitpat, exp)
            in
               case spOpt of
                  NONE => [([BITdecodepat [bitpat]], exp)]
                | SOME sp  => [([MARKdecodepat {span=sp, tree=BITdecodepat [bitpat]}], exp)]
            end

      and flattenDecodePat spOpt (decodepat, exp) =
         case decodepat of
            MARKdecodepat t' => flattenDecodePat (SOME (#span t')) (#tree t', exp)
          | TOKENdecodepat tokpat => flattenTokPat spOpt (tokpat, exp)
          | BITdecodepat bitpats =>
               let
                  fun lp (bitpats, exp, acc) =
                     case bitpats of
                        [] => [(List.concat acc, exp)]
                      | b::bs =>
                           let
                              val ds = flattenBitPat spOpt (b, exp)
                           in
                              List.concat (List.map
                                 (fn (ps, exp) =>
                                    lp (bs, exp, ps::acc))
                                 ds)
                           end
               in
                  lp (rev bitpats, exp, [])
               end

      and flattenDecodePats spOpt (pats, exp) = let
         fun lp (pats, exp, acc) =
            case pats of
               [] => [(List.concat acc, exp)]
             | p::ps =>
                  let
                     val ds = flattenDecodePat spOpt (p, exp)
                  in
                     List.concat
                        (List.map
                           (fn (inlinedPats, exp) =>
                              lp (ps, exp, inlinedPats::acc))
                           ds)
                  end
      in
         lp (rev pats, exp, [])
      end

      and flattenDecodeDecl (n, ds, map) = let
         fun flatten (pats, map) = bind (map, n, flattenDecodePats NONE pats)
      in
         foldl flatten map ds
      end
   in
      Map.foldli flattenDecodeDecl Map.empty ds
   end

   fun dumpPre (os, (_, spec)) = Pretty.prettyTo (os, DesugarGuards.layout spec)
   fun dumpPost (os, spec) = Pretty.prettyTo (os, DesugarGuards.layout spec)

   val inline =
      BasicControl.mkKeepPass
         {passName="inlineDecodePatterns",
          registry=DesugarControl.registry,
          pass=flattenDecodePatterns,
          preExt="ast",
          preOutput=dumpPre,
          postExt="ast",
          postOutput=dumpPost}

   fun run spec = let
      open CompilationMonad
      infix >>=
   in
      getErrorStream >>= (fn errs =>
      return (Spec.upd (fn (vs, ds) => (vs, inline (errs, ds))) spec))
   end
end
