(* -------------------------------------------------------------------------- *
 *                     Vir - the Verified LLVM project                     *
 *                                                                            *
 *     Copyright (c) 2017 Steve Zdancewic <stevez@cis.upenn.edu>              *
 *                                                                            *
 *   This file is distributed under the terms of the GNU General Public       *
 *   License as published by the Free Software Foundation, either version     *
 *   3 of the License, or (at your option) any later version.                 *
 ---------------------------------------------------------------------------- *)

Require Import Equalities.
From Coq Require Import ZArith List String Omega.
Require Import Vir.AstLib Vir.LLVMAst.
Require Import Vir.Util.
From ExtLib Require Import
     Core.RelDec
     Programming.Eqv
     Structures.Monads
     Data.Monads.OptionMonad.
Require Import Ceres.Ceres.
Import ListNotations.
Import EqvNotation.
Import MonadNotation.
Open Scope monad_scope.
Record pc :=
  mk_pc {
      fn : function_id;
      bk : block_id;
      pt : instr_id;
    }.

Section hiding_notations.
  Local Open Scope sexp_scope.
  Global Instance serialize_pc : Serialize pc :=
    fun p => [Atom "@" ; to_sexp (fn p) ; Atom ":" ; to_sexp (bk p) ; Atom ":" ; to_sexp (pt p)].
End hiding_notations.


Ltac unfold_eqv :=
  repeat (unfold eqv in *; unfold eqv_raw_id in *; unfold eqv_instr_id in *).

Module PC <: UsualDecidableTypeFull.
  Definition t := pc.
  Include HasUsualEq.
  Include UsualIsEq.
  Include UsualIsEqOrig.


  Lemma eq_dec : forall (x y : pc), {x = y} + {x <> y}.
  Proof.
    intros x y.
    destruct x as [xf xi xp]; destruct y as [yf yi yp].
    destruct (xf ~=? yf); unfold_eqv.
    - destruct (xi ~=? yi); unfold_eqv.
     + destruct (xp ~=? yp); unfold_eqv.
        * subst. left. reflexivity.
        * right. unfold not. intros. apply n. inversion H. auto.
     + right. unfold not. intros. apply n. inversion H. auto.
    - right. unfold not. intros. apply n. inversion H. auto.
  Defined.

  Include HasEqDec2Bool.

End PC.
Instance eq_dec_pc : RelDec (@eq pc) := RelDec_from_dec (@eq pc) PC.eq_dec.
Section CFG.
  Variable (T:Set).

Inductive cmd : Set :=
| Inst (i:instr T)
| Term (t:terminator T)
.
  Record cfg := mkCFG
                  {
                    init : block_id;
                    blks : list (block T);
                    args : list ident;
                  }.
Definition mcfg : Set := modul T cfg.

Definition find_defn {X:Set} (fid:function_id) (d:definition T X) : option (definition T X) :=
  if (ident_of d) ~=? (ID_Global fid) then Some d else None.

Definition find_function (CFG : mcfg) (fid:function_id) : option (definition T cfg) :=
  find_map (find_defn fid) (m_definitions CFG).


Definition fallthrough (cd: (code T)) term_id : instr_id :=
  match cd with
  | [] => term_id
  | (next, _)::_ => next
  end.

Definition blk_term_id (b: block T) := fst (blk_term b).
Definition blk_terminator (b: block T) := snd (blk_term b).

Definition blk_entry_id (b:block T) : instr_id := fallthrough (blk_code b) (blk_term_id b).

Definition blk_entry_pc (fid:function_id) (b:block T) :=
  mk_pc fid (blk_id b) (blk_entry_id b).

Definition blk_term_pc (fid:function_id) (b:block T) :=
  mk_pc fid (blk_id b) (blk_term_id b).

Definition find_block bs block_id : option (block T) :=
  find (fun b => if (blk_id b) ~=? block_id then true else false) bs.

Fixpoint find_instr (cd : (code T)) (p:instr_id) (t:instr_id) : option (cmd * option instr_id) :=
  match cd with
  | [] =>  None
  | (x,i)::cd =>
    if p ~=? x then
      Some (Inst i, Some (fallthrough cd t))
    else
      find_instr cd p t
  end.

Definition block_to_cmd (b:block T) (iid:instr_id) : option (cmd * option instr_id) :=
  let term_id := blk_term_id b in
  if term_id ~=? iid then
    Some (Term (snd (blk_term b)), None)
  else
    find_instr (blk_code b) iid term_id
.

Inductive block_entry : Set :=
| BlockEntry (phis:list (local_id * (phi T))) (p:pc).

Definition block_to_entry (fid:function_id) (b:block T) : block_entry :=
  BlockEntry (blk_phis b) (blk_entry_pc fid b).

Definition find_block_entry (CFG:mcfg) (fid:function_id) (bid:block_id) : option block_entry :=
  cfg <- find_function CFG fid ;;
  blk <- find_block (blks (df_instrs cfg)) bid ;;
  ret (block_to_entry fid blk).

Inductive function_entry : Set :=
| FunctionEntry (args:list local_id) (p:pc).


Definition find_function_entry (CFG:mcfg) (fid:function_id) : option function_entry :=
  dfn <- find_function CFG fid ;;
  let cfg := df_instrs dfn in
  blk <- find_block (blks cfg) (init cfg) ;;
  ret (FunctionEntry (df_args dfn) (mk_pc fid (init cfg) (blk_entry_id blk))).
Definition init_of_definition (d: definition T (block T * list (block T))) : block_id :=
  blk_id (fst (df_instrs d)).

Definition cfg_of_definition (d:definition T (block T * list (block T))) : cfg :=
  let args := List.map (fun x => ID_Local x) (df_args d) in
  {| init := init_of_definition d;
     blks := fst (df_instrs d) :: snd (df_instrs d);
     args := args;
  |}.

Definition mcfg_of_modul (m:modul T (block T * list (block T))) : mcfg :=
  let defns := map (fun d => {|
                     df_prototype := df_prototype d;
                     df_args := df_args d;
                     df_instrs := cfg_of_definition d
                      |}) (m_definitions m)
  in
  {|
    m_name := m_name m;
    m_target := m_target m;
    m_datalayout := m_datalayout m;
    m_type_defs := m_type_defs m;
    m_globals := m_globals m;
    m_declarations := m_declarations m;
    m_definitions := defns
  |}.
End CFG.
