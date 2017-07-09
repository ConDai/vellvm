Require Import List.
Import ListNotations.
Require Import String.

Require Import QuickChick.QuickChick.
Import QcDefaultNotation. Open Scope qc_scope.

Require Import Vminus.Atom.
Require Import Vminus.CompilImp.
Require Import Vminus.Vminus.

Require Import Vminus.AtomQuickChick.
Require Import Vminus.VminusQuickChick.

Generalizable All Variables.

Definition show_image_given_domain `{Show A}
           (f: Atom.t -> A) (l: list Atom.t) := (
  (List.fold_left (fun accum atom => accum ++ "(" ++ (Atom.string_of atom) ++ ", "
                                        ++ show (f atom) ++ ") ")
                  l "[") ++ "]")%string.

(** Opsem **)

(*
Instance gen_loc `{Gen nat} : GenSized (list Atom.t * V.Opsem.loc) :=
  {| arbitrarySized n :=
       let fresh_list := get_fresh_atoms n [] in
       bindGen (vectorOf n arbitrary) (fun nat_list => 
       returnGen (fresh_list,
                  fun (a : Atom.t) =>
                    match (index_of_atom_in_list a fresh_list) with
                    | None => None
                    | Some i =>
                      List.nth_error nat_list i
                    end))
  |}.

Instance show_loc `{Show Atom.t} `{Show nat}:
  Show (list Atom.t * V.Opsem.loc) :=
  {| show paired_loc := (
       let '(atom_list, atom_map) := paired_loc in
       let fix helper atom_list atom_map :=
           match atom_list with
           | [] => "]"
           | (a :: l) =>
             match atom_map a with
             | None => "loc domain is inconsistent"
             | Some n => "(" ++ (show a) ++ ", " ++ (show n) ++ "), "
                            ++ helper l atom_map
             end
           end in
       "[" ++ helper atom_list atom_map )%string
  |}.

Sample (@arbitrary (list Atom.t * V.Opsem.loc) _).
 *)

Record state_with_meta : Type :=
  mk_st_with_meta {
    stm_mem: V.Opsem.mem;
    stm_mem_dom: list Atom.t;
    stm_pc: Vminus.pc;
    stm_loc: V.Opsem.loc;
    stm_loc_dom: list Atom.t;
    stm_ppc: Vminus.pc;
    stm_ploc: V.Opsem.loc;
    stm_ploc_dom: list Atom.t
  }.

Definition gen_loc_from_atom_list
           `{Gen nat}
           (atom_list : list Atom.t) : G V.Opsem.loc :=
  bindGen (vectorOf (List.length atom_list) arbitrary) (fun nat_list => 
  returnGen (fun (a : Atom.t) =>
               match (index_of_atom_in_list a atom_list) with
               | None => None
               | Some i =>
                 List.nth_error nat_list i
               end)).

Definition gen_mem_from_atom_list
           `{Gen nat}
           (atom_list : list Atom.t) : G (V.Opsem.mem) :=
  bindGen (vectorOf (List.length atom_list) arbitrary) (fun nat_list => 
  returnGen (fun (a : Atom.t) =>
               match (index_of_atom_in_list a atom_list) with
               | None => 0
               | Some i =>
                 List.nth i nat_list 0
               end)).

Instance gen_opsem_state_with_meta `{Gen pc}: GenSized state_with_meta :=
  {| arbitrarySized n :=
       let mem_dom := get_fresh_atoms n [] in
       let loc_dom := get_fresh_atoms n [] in
       let gmem := gen_mem_from_atom_list mem_dom in
       let gloc := gen_loc_from_atom_list mem_dom in

       bindGen gmem (fun mem =>
       bindGen arbitrary (fun pc =>
       bindGen gloc (fun loc =>
       bindGen arbitrary (fun ppc =>
       bindGen gloc (fun prev_loc =>
         returnGen
           (mk_st_with_meta mem mem_dom
                            pc
                            loc loc_dom
                            ppc
                            prev_loc loc_dom))))))
  |}.

Instance show_state_with_meta `{Show pc} : Show state_with_meta :=
  {| show st :=
       let 'mk_st_with_meta mem mem_dom
                            pc
                            loc loc_dom
                            ppc
                            prev_loc prev_loc_dom := st in
       ("mem: " ++ show_image_given_domain mem mem_dom ++ ", " ++
        "pc: " ++ show pc ++ ", " ++
        "loc: " ++ show_image_given_domain loc loc_dom ++ ", " ++
        "ppc: " ++ show ppc ++ ", " ++
        "prev_loc: " ++ show_image_given_domain prev_loc prev_loc_dom)%string
  |}.

Definition state_of (stm: state_with_meta) :=
  V.Opsem.mkst (stm_mem stm) (stm_pc stm) (stm_loc stm)
               (stm_ppc stm) (stm_ploc stm).

(* Sample (@arbitrary state_with_meta _). *)






(* Generators for predicates *)

(*
Import 

Definition insn_at_pc := 

Fixpoint gen_cfg_with_instrs_at (
         (st GenSizedSuchThat (fun g => insns_at_pc g p instrs)
*)