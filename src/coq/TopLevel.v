(* -------------------------------------------------------------------------- *
 *                     Vellvm - the Verified LLVM project                     *
 *                                                                            *
 *     Copyright (c) 2017 Steve Zdancewic <stevez@cis.upenn.edu>              *
 *                                                                            *
 *   This file is distributed under the terms of the GNU General Public       *
 *   License as published by the Free Software Foundation, either version     *
 *   3 of the License, or (at your option) any later version.                 *
 ---------------------------------------------------------------------------- *)
From Coq Require Import
     List String.

From ITree Require Import
     ITree.

From ExtLib Require Import 
     Structures.Monads.

From Vellvm Require Import 
     LLVMIO
     StepSemantics
     Memory
     Intrinsics.


Import MonadNotation.
Import ListNotations.

Module IO := LLVMIO.Make(Memory.A).
Module M := MemoryCerberus. (* Memory.Make(IO). *)
Module SS := StepSemantics(Memory.A)(IO).
Module INT := Intrinsics.Make(Memory.A)(IO).

Import IO.
Export IO.DV.

Module CMM <: Memory.
   Axiom memM : Type -> Type.
   Extract Constant memM "'a" => "'a Concrete.memM".
   Axiom ret : forall a, a -> memM a.
   Extract Constant ret => "Concrete.return".
   Axiom bind : forall a b, memM a -> (a -> memM b) -> memM b.
   Extract Constant bind => "Concrete.bind".

   Definition name := "Vellvm memory model...".

   Axiom pointer_value : Type.
   Extract Constant pointer_value => "Concrete.pointer_value".
   Axiom integer_value : Type.
   Extract Constant integer_value => "Concrete.integer_value".
   Axiom floating_value : Type.
   Extract Constant floating_value => "Concrete.floating_value".

   Axiom mem_value : Type.
   Extract Constant mem_value => "Concrete.mem_value".

   (* Definition mem_iv_constraint = Mem_Common.mem_constraint integer_value.*)

   Axiom footprint : Type.
   Extract Constant footprint => "Concrete.footprint".

   Axiom mem_state : Type.
   Extract Constant mem_state => "Concrete.mem_state".

   Axiom initial_mem_state : mem_state.
   Extract Constant initial_mem_state => "Concrete.initial_mem_state".

   (* TODO Original just uses Cthread.thread_id, not sure what we would use. *)
   Axiom thread_id : Type.
   Extract Constant thread_id => "Cthread.thread_id".

   (* TODO Original used Core_ctype.ctype0... Not sure what this is, though. *)
   Axiom ctype0 : Type.
   Extract Constant ctype0 => "Core_ctype.ctype0".

   (* TODO Symbol.prefix *)
   Axiom symbol_prefix : Type.
   Extract Constant symbol_prefix => "Symbol.prefix".

   (* TODO Symbol.sym? *)
   Axiom symbol_sym : Type.
   Extract Constant symbol_sym => "Symbol.sym".
   
   (* Pointer value constructors *)
   Axiom null_ptrval : ctype0 -> pointer_value.
   Extract Constant null_ptrval => "Concrete.null_ptrval".
   Axiom fun_ptrval: symbol_sym -> pointer_value.
   Extract Constant fun_ptrval => "Concrete.fun_ptrval".

   (* TODO Location_ocaml.t, not sure what this is... *)
   Axiom loc_ocaml_t : Type.
   Extract Constant loc_ocaml_t => "Location_ocaml.t".

   (* TODO AilTypes.integerType ? *)
   Axiom AilIntegerType : Type.
   Extract Constant AilIntegerType => "AilTypes.integerType".

   (* TODO Nat_big_num.num ? *)
   Axiom big_num : Type.
   Extract Constant big_num => "Nat_big_num.num".

   (* TODO AilTypes.floatingType *)
   Axiom AilFloatingType : Type.
   Extract Constant AilFloatingType => "AilTypes.floatingType".

   (* TODO float *)
   Axiom float : Type.
   Extract Inlined Constant float => "float".

   (* TODO Cabs.cabs_identifier ? *)
   Axiom cabs_identifier : Type.
   Extract Constant cabs_identifier => "Cabs.cabs_identifier".

   (* TODO Mem_common.integer_operator *)
   Axiom Mem_common_integer_operator : Type.
   Extract Constant Mem_common_integer_operator => "Mem_common.integer_operator".

   (* TODO Mem_common.floating_operator *)
   Axiom Mem_common_floating_operator : Type.
   Extract Constant Mem_common_floating_operator => "Mem_common.floating_operator".

   Axiom do_overlap : footprint -> footprint -> bool.
   Extract Constant do_overlap => "Concrete.do_overlap".
   Axiom allocate_static :
     thread_id -> symbol_prefix -> integer_value -> ctype0 -> option mem_value -> memM pointer_value.
   Extract Constant allocate_static => "Concrete.allocate_static".
   Axiom allocate_dynamic : thread_id -> symbol_prefix -> integer_value -> integer_value -> memM pointer_value.
   Extract Constant allocate_dynamic => "Concrete.allocate_dynamic".
   Axiom kill : loc_ocaml_t -> bool -> pointer_value -> memM ().
   Extract Constant kill => "Concrete.kill".
   Axiom load : loc_ocaml_t -> ctype0 -> pointer_value -> memM (footprint * mem_value).
   Extract Constant load => "Concrete.load".
   Axiom store : loc_ocaml_t -> ctype0 -> bool -> pointer_value -> mem_value -> memM footprint.
   Extract Constant store => "Concrete.store".
   Axiom eq_ptrval : pointer_value -> pointer_value -> memM bool.
   Extract Constant eq_ptrval => "Concrete.eq_ptrval".
   Axiom ne_ptrval : pointer_value -> pointer_value -> memM bool.
   Extract Constant ne_ptrval => "Concrete.ne_ptrval".
   Axiom lt_ptrval : pointer_value -> pointer_value -> memM bool.
   Extract Constant lt_ptrval => "Concrete.lt_ptrval".
   Axiom gt_ptrval : pointer_value -> pointer_value -> memM bool.
   Extract Constant gt_ptrval => "Concrete.gt_ptrval".
   Axiom le_ptrval : pointer_value -> pointer_value -> memM bool.
   Extract Constant le_ptrval => "Concrete.le_ptrval".
   Axiom ge_ptrval : pointer_value -> pointer_value -> memM bool.
   Extract Constant ge_ptrval => "Concrete.ge_ptrval".
   Axiom diff_ptrval : ctype0 -> pointer_value -> pointer_value -> memM integer_value.
   Extract Constant diff_ptrval => "Concrete.diff_ptrval".
   Axiom validForDeref_ptrval : ctype0 -> pointer_value -> memM bool.
   Extract Constant validForDeref_ptrval => "Concrete.validForDeref_ptrval".
   Axiom isWellAligned_ptrval : ctype0 -> pointer_value -> memM bool.
   Extract Constant isWellAligned_ptrval => "Concrete.isWellAligned_ptrval".
   Axiom ptrcast_ival : ctype0 -> ctype0 -> integer_value -> memM pointer_value.
   Extract Constant ptrcast_ival => "Concrete.ptrcast_ival".
   Axiom intcast_ptrval : ctype0 -> AilIntegerType -> pointer_value -> memM integer_value.
   Extract Constant intcast_ptrval => "Concrete.intcast_ptrval".
   Axiom array_shift_ptrval : pointer_value -> ctype0 -> integer_value -> pointer_value.
   Extract Constant array_shift_ptrval => "Concrete.array_shift_ptrval".
   Axiom member_shift_ptrval : pointer_value -> symbol_sym -> cabs_identifier -> pointer_value.
   Extract Constant member_shift_ptrval => "Concrete.member_shift_ptrval".
   Axiom memcmp : pointer_value -> pointer_value -> integer_value -> memM integer_value.
   Extract Constant memcmp => "Concrete.memcmp".
   Axiom concurRead_ival : AilIntegerType -> symbol_sym -> integer_value.
   Extract Constant concurRead_ival => "Concrete.concurRead_ival".
   Axiom integer_ival : big_num -> integer_value.
   Extract Constant integer_ival => "Concrete.integer_ival".
   Axiom max_ival : AilIntegerType -> integer_value.
   Extract Constant max_ival => "Concrete.max_ival".
   Axiom min_ival : AilIntegerType -> integer_value.
   Extract Constant min_ival => "Concrete.min_ival".
   Axiom op_ival : Mem_common_integer_operator -> integer_value -> integer_value -> integer_value.
   Extract Constant op_ival => "Concrete.op_ival".
   Axiom offsetof_ival : symbol_sym -> cabs_identifier -> integer_value.
   Extract Constant offsetof_ival => "Concrete.offsetof_ival".
   Axiom sizeof_ival : ctype0 -> integer_value.
   Extract Constant sizeof_ival => "Concrete.sizeof_ival".
   Axiom alignof_ival : ctype0 -> integer_value.
   Extract Constant alignof_ival => "Concrete.alignof_ival".
   Axiom bitwise_complement_ival : AilIntegerType -> integer_value -> integer_value.
   Extract Constant bitwise_complement_ival => "Concrete.bitwise_complement_ival".
   Axiom bitwise_and_ival : AilIntegerType -> integer_value -> integer_value -> integer_value.
   Extract Constant bitwise_and_ival => "Concrete.bitwise_and_ival".
   Axiom bitwise_or_ival : AilIntegerType -> integer_value -> integer_value -> integer_value.
   Extract Constant bitwise_or_ival => "Concrete.bitwise_or_ival".
   Axiom bitwise_xor_ival : AilIntegerType -> integer_value -> integer_value -> integer_value.
   Extract Constant bitwise_xor_ival => "Concrete.bitwise_xor_ival".
   Axiom case_integer_value : forall a : Type, integer_value -> (big_num -> a) -> (() -> a) -> a.
   Extract Constant case_integer_value => "Concrete.case_integer_value".
   Axiom is_specified_ival : integer_value -> bool.
   Extract Constant is_specified_ival => "Concrete.is_specified_ival".
   Axiom eq_ival : option mem_state -> integer_value -> integer_value -> option bool.
   Extract Constant eq_ival => "Concrete.eq_ival".
   Axiom lt_ival : option mem_state -> integer_value -> integer_value -> option bool.
   Extract Constant lt_ival => "Concrete.lt_ival".
   Axiom le_ival : option mem_state -> integer_value -> integer_value -> option bool.
   Extract Constant le_ival => "Concrete.le_ival".
   Axiom eval_integer_value : integer_value -> option big_num.
   Extract Constant eval_integer_value => "Concrete.eval_integer_value".
   Axiom zero_fval : floating_value.
   Extract Constant zero_fval => "Concrete.zero_fval".
   Axiom str_fval : ocaml_string -> floating_value.
   Extract Constant str_fval => "Concrete.str_fval".

   (*
   Axiom case_fval : forall a : Type, floating_value -> (() -> a) -> (float -> a) -> a.
   Extract Constant case_fval => "Concrete.case_fval".
   *)
   Axiom op_fval : Mem_common_floating_operator -> floating_value -> floating_value -> floating_value.
   Extract Constant op_fval => "Concrete.op_fval".
   Axiom eq_fval : floating_value -> floating_value -> bool.
   Extract Constant eq_fval => "Concrete.eq_fval".
   Axiom lt_fval : floating_value -> floating_value -> bool.
   Extract Constant lt_fval => "Concrete.lt_fval".
   Axiom le_fval : floating_value -> floating_value -> bool.
   Extract Constant le_fval => "Concrete.le_fval".
   Axiom fvfromint : integer_value -> floating_value.
   Extract Constant fvfromint => "Concrete.fvfromint".
   Axiom ivfromfloat : AilIntegerType -> floating_value -> integer_value.
   Extract Constant ivfromfloat => "Concrete.ivfromfloat".
   Axiom unspecified_mval : ctype0 -> mem_value.
   Extract Constant unspecified_mval => "Concrete.unspecified_mval".
   Axiom integer_value_mval : AilIntegerType -> integer_value -> mem_value.
   Extract Constant integer_value_mval => "Concrete.integer_value_mval".
   Axiom floating_value_mval : AilFloatingType -> floating_value -> mem_value.
p   Extract Constant floating_value_mval => "Concrete.floating_value_mval".
   Axiom pointer_mval : ctype0 -> pointer_value -> mem_value.
   Extract Constant pointer_mval => "Concrete.pointer_mval".
   Axiom array_mval : list mem_value -> mem_value.
   Extract Constant array_mval => "Concrete.array_mval".
   (*
   Axiom struct_mval : symbol_sym -> list (cabs_identifier * ctype0 * mem_value) -> mem_value.
   Extract Constant struct_mval => "Concrete.struct_mval".
   *)
   Axiom union_mval : symbol_sym -> cabs_identifier -> mem_value -> mem_value.
   Extract Constant union_mval => "Concrete.union_mval".
   (*
   Axiom case_mem_value :
     forall a : Type,
     mem_value ->
     (ctype0 -> a) ->
     (AilIntegerType -> symbol_sym -> a) ->
     (AilIntegerType -> integer_value -> a) ->
     (AilFloatingType -> floating_value -> a) ->
     (ctype0 -> pointer_value -> a) ->
     (list mem_value -> a) ->
     (symbol_sym -> list (cabs_identifier * mem_value) -> a) ->
     (symbol_sym -> cabs_identifier -> mem_value -> a) -> a.
   Extract Constant case_mem_value => "Concrete.case_mem_value".
   *)
   Axiom sequencePoint : memM ().
   Extract Constant sequencePoint => "Concrete.sequencePoint".
End CMM.

Module MC <: Memory.MemoryConversion IO CMM.
  Import IO. Import DV.
  Import CMM.

    (* Conversion functions *)
  Axiom pointer_value_to_dvalue : pointer_value -> dvalue.
  Coercion pointer_value_to_dvalue : pointer_value >-> dvalue.
  Extract Constant pointer_value_to_dvalue => "CoqCerberus.pointer_value_to_dvalue".

  Axiom dvalue_to_pointer_value : dvalue -> pointer_value.
  Coercion dvalue_to_pointer_value : dvalue >-> pointer_value.
  Extract Constant dvalue_to_pointer_value => "CoqCerberus.dvalue_to_pointer_value".

  Axiom integer_value_to_dvalue : integer_value -> dvalue.
  Coercion integer_value_to_dvalue : integer_value >-> dvalue.
  Extract Constant integer_value_to_dvalue => "CoqCerberus.integer_value_to_dvalue".

  Axiom dvalue_to_integer_value : dvalue -> integer_value.
  Coercion dvalue_to_integer_value : dvalue >-> integer_value.
  Extract Constant dvalue_to_integer_value => "CoqCerberus.dvalue_to_integer_value".

  Axiom floating_value_to_dvalue : floating_value -> dvalue.
  Coercion floating_value_to_dvalue : floating_value >-> dvalue.
  Extract Constant floating_value_to_dvalue => "CoqCerberus.floating_value_to_dvalue".

  Axiom dvalue_to_floating_value : dvalue -> floating_value.
  Coercion dvalue_to_floating_value : dvalue >-> floating_value.
  Extract Constant dvalue_to_floating_value => "CoqCerberus.dvalue_to_floating_value".

  Axiom mem_value_to_dvalue : mem_value -> dvalue.
  Coercion mem_value_to_dvalue : mem_value >-> dvalue.
  Extract Constant mem_value_to_dvalue => "CoqCerberus.mem_value_to_dvalue".

  Axiom dvalue_to_mem_value : dvalue -> mem_value.
  Coercion dvalue_to_mem_value : dvalue >-> mem_value.
  Extract Constant dvalue_to_mem_value => "CoqCerberus.dvalue_to_mem_value".

  Axiom dtyp_to_ctype : dtyp -> ctype0.
  Coercion dtyp_to_ctype : dtyp >-> ctype0.
  Extract Constant dtyp_to_ctype => "CoqCerberus.dtyp_to_ctype".

  Axiom Z_to_iv : Z -> integer_value.
  Coercion Z_to_iv : Z >-> integer_value.
  Extract Constant Z_to_iv => "CoqCerberus.z_to_iv".

  Axiom dtyp_to_ail_integer_type : dtyp -> AilIntegerType.
  Coercion dtyp_to_ail_integer_type : dtyp >-> AilIntegerType.
  Extract Constant dtyp_to_ail_integer_type => "CoqCerberus.dtyp_to_ail_integer_type".

  Axiom thread_zero : thread_id.
  Extract Constant thread_zero => "0".
  Axiom empty_prefix : symbol_prefix.
  Extract Constant empty_prefix => "Symbol.PrefOther """"".
  Axiom empty_loc : loc_ocaml_t.
  Extract Constant empty_loc => "Location_ocaml.unknown".
End MC.
  
Module M := Memory.Make IO CMM MC.
(* Module MemLLVM := M.MemoryLLVM(CMM). *)

(* TODO: Probably relies on runND in smt2.ml *)
Axiom runMemM : forall a, a -> CMM.memM a -> a.
Extract Constant runMemM => "fun def m -> match (List.hd Smt2.(runND Random Concrete.cs_module m Concrete.initial_mem_state)) with | (Active a, _, _) -> a | (Killed kr, _, _) -> CoqCerberus.print_kill_reason kr; def".

Definition run_with_memory prog : option (Trace DV.dvalue) :=
  let scfg := Vellvm.AstLib.modul_of_toplevel_entities prog in
  match CFG.mcfg_of_modul scfg with
  | None => None
  | Some mcfg =>
    mret (runMemM _ (mret (DVALUE_I64 (repr (-1))))
            (M.memD M.empty
                          ('s <- SS.init_state mcfg "main";
                           SS.step_sem mcfg (SS.Step s))))
  end.

(* From master *)
(*
Open Scope string_scope.

Definition run_with_memory prog : option (LLVM (failureE +' debugE) (M.memory * DV.dvalue)) :=
  let scfg := Vellvm.AstLib.modul_of_toplevel_entities prog in
  mcfg <- CFG.mcfg_of_modul scfg ;;
  let core_trace : LLVM (failureE +' debugE) dvalue :=
      s <- SS.init_state mcfg "main" ;;
        SS.step_sem mcfg (SS.Step s)
  in
  let after_intrinsics_trace := INT.evaluate_with_defined_intrinsics core_trace in
  ret (M.memD M.empty after_intrinsics_trace).
*)
