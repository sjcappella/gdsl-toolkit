
(*structure BetaContFunPass = MkCPSPass (BetaContFun)
structure BetaContFunShrinkPass = MkCPSPass (BetaContFunShrink)
structure BetaContractPass = MkCPSPass (BetaContract)
structure BetaPairPass = MkCPSPass (BetaPair)
structure HoistFunPass = MkCPSPass (HoistFun)
structure DeadValPass = MkCPSPass (DeadVal)*)

structure BetaReductionPass = MkIMPPass (BetaReduction)

structure ImpPasses : sig
   val run:
      Core.Spec.t ->
         Imp.Spec.t CompilationMonad.t
end = struct

   structure CM = CompilationMonad

   open CM
   infix >>=

   fun all s = 
      ImpFromCore.run s >>=
      BetaReductionPass.run

   fun dumpPre (os, (_, spec)) = Pretty.prettyTo (os, Core.PP.spec spec)
   fun dumpPost (os, spec) = Pretty.prettyTo (os, Imp.PP.spec spec)
   fun pass (s, spec) = CM.run s (all spec)

   val passes =
      BasicControl.mkKeepPass
         {passName="imp",
          registry=ImpControl.registry,
          pass=pass,
          preExt="ast",
          preOutput=dumpPre,
          postExt="imp",
          postOutput=dumpPost}

   fun run spec =
      getState >>= (fn s =>
      return (passes (s, spec)))
end