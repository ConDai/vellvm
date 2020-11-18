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

Ltac unfold_eqv :=
  repeat (unfold eqv in *; unfold eqv_raw_id in *; unfold eqv_instr_id in *).

(* Control flow graphs (CFGs) ----------------------------------------------- *)
Section CFG.
  Variable (T:Set).

  Inductive cmd : Set :=
  | Inst (i:instr T)
  | Term (t:terminator T)
  .

  (* Each function definition corresponds to a control-flow graph
   - init is the entry block
   - blks is a list of labeled blocks
   - args is the list of identifiers brought into scope by this function
   *)
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
