(* -------------------------------------------------------------------------- *
 *                     Vellvm - the Verified LLVM project                     *
 *                                                                            *
 *     Copyright (c) 2018 Steve Zdancewic <stevez@cis.upenn.edu>              *
 *                                                                            *
 *   This file is distributed under the terms of the GNU General Public       *
 *   License as published by the Free Software Foundation, either version     *
 *   3 of the License, or (at your option) any later version.                 *
 ---------------------------------------------------------------------------- *)


From Coq Require Import
     ZArith List String.

From ExtLib Require Import
     Structures.Monads
     Programming.Eqv
     Data.String.

From Vellvm Require Import 
     Util
     LLVMAst
     LLVMEvents
     Error
     UndefinedBehaviour
     IntrinsicsDefinitions.

From ITree Require Import
     ITree.

Import MonadNotation.
Import EqvNotation.
Import ListNotations.


Set Implicit Arguments.
Set Contextual Implicit.

(*
   LLVM _intrinsic_ functions are used like ordinary function calls, but
   they have a special interpretation.

     - any global identifier that starts with the prefix "llvm." is 
       considered to be an intrinsic function 

     - intrinsic functions must be delared in the global scope (to ascribe them types)

     - it is _illegal_ to take the address of an intrinsic function (they do not 
       always map directly to external functions, e.g. arithmetic intrinsics may 
       be lowered directly to in-lined assembly on platforms that support the 
       operations natively.

   As a consequence of the above, it is possible to _statically_ determine 
   that a call is an invocation of an intrinsic by looking for instructions
   of the form:
        call t @llvm._ (args...)
*)

(* This function extracts the string of the form [llvm._] from an LLVM expression.
   It returns None if the expression is not an intrinsic definition.
*) 
Definition intrinsic_ident (id:ident) : option string :=
  match id with
  | ID_Global (Name s) =>
    if String.prefix "llvm." s then Some s else None
  | _ => None
  end.

Definition intrinsic_exp {T} (e:exp T) : option string :=
  match e with
  | EXP_Ident id => intrinsic_ident id
  | _ => None
  end.


(* (Pure) Intrinsics -------------------------------------------------------- *)

(* The intrinsics interpreter looks for Calls to intrinsics defined by its
   argument and runs their semantic function, raising an error in case of
   exception.  Unknown Calls (either to other intrinsics or external calls) are
   passed through unchanged.
*)
Module Make(A:MemoryAddress.ADDRESS)(LLVMIO: LLVM_INTERACTIONS(A)).

  Module IS := IntrinsicsDefinitions.Make(A)(LLVMIO).
  Include IS.
  Import LLVMIO.
  Import DV.


  (* Interprets Call events found in the given association list by their
     semantic functions.  

     SAZ: This definition is trickier than one wants it to be because of the 
     dependent pattern matching.  The index of the IntrinsicE constructor need to 
     be used to coerce the result back to the general ITree type.

     We solve it by using the "Convoy Pattern" (see Chlipala's CPDT).  

     IntrinsicE ~> LLVM _MCFG1
   *)

  Definition defs_assoc := List.map (fun '(a,b) =>
                                  match dc_name typ a with
                                  | Name s => (s,b)
                                  | _ => ("",b)
                                  end
                               ) defined_intrinsics.

  
  Definition handle_intrinsics : IntrinsicE ~> LLVM _CFG :=
    (* This is a bit hacky: declarations without global names are ignored by mapping them to empty string *)
    fun X (e : IntrinsicE X) =>
      match e in IntrinsicE Y return X = Y -> LLVM _CFG Y with
      | (Intrinsic _ fname args) =>
          match assoc Strings.String.string_dec fname defs_assoc with
          | Some f => fun pf => 
                       match f args with
                       | inl msg => raise msg
                       | inr result => Ret result
                       end
          | None => fun pf => (eq_rect X (fun a => LLVM _CFG a) (trigger e)) dvalue pf
          end
      end eq_refl.
     

  (* CB / YZ / SAZ: TODO "principle this" *)
  Definition extcall_trigger : Handler CallE _CFG :=
  fun X e => trigger e.

  Definition rest_trigger : Handler (LLVMGEnvE +' (LLVMEnvE +' LLVMStackE) +' MemoryE +' DebugE +' FailureE +' UndefinedBehaviourE) _CFG :=
    fun X e => trigger e.

  Definition interpret_intrinsics: forall R, LLVM _CFG R -> LLVM _CFG R  :=
    interp (case_ extcall_trigger (case_ handle_intrinsics rest_trigger)).
  
End Make.
