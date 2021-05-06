From Coq Require Import
     Arith
     FSets.FMapList
     Lia
     Lists.List
     Strings.String
     Structures.OrderedTypeEx
     ZArith.

Module Import StringMap := Coq.FSets.FMapList.Make(String_as_OT).

From ExtLib Require Import
     Structures.Monads
     Data.Monads.OptionMonad.
Import MonadNotation.

From Vellvm Require Import
     Syntax.
From tutorial Require Import Fin.

Import ListNotations.

Require Import Imp Vec.

Close Scope nat_scope.
Open Scope Z_scope.

Section compile_cvir.

(* Imp to CVir to Vir *)

Definition texp_i32 (reg : int) : texp typ :=
  (TYPE_I 32, EXP_Ident (ID_Local (Anon reg)))
.

Definition texp_ptr (reg : int) : texp typ :=
  (TYPE_I 32, EXP_Ident (ID_Local (Anon reg)))
.

Definition compile_binop (reg1 reg2 reg:int) (op: ibinop): code typ :=
  [((IId (Anon reg)),
    INSTR_Op (OP_IBinop (LLVMAst.Add false false) (TYPE_I 32)
      (EXP_Ident (ID_Local (Anon reg1)))
      (EXP_Ident (ID_Local (Anon reg2)))))].

(** Expressions are compiled straightforwardly.
    The argument [next_reg] is the number of registers already introduced to compile
    the expression, and is used for the name of the next one.
    The result of the computation [compile_expr l e env] always ends up stored in [l].
 *)
Fixpoint compile_expr (next_reg:int) (e: expr) (env: StringMap.t int): option (int * code typ) :=
  match e with
  | Var x =>
    addr <- find x env;;
    ret (next_reg, [(IId (Anon next_reg), INSTR_Load false (TYPE_I 32) (texp_ptr addr) None)])
  | Lit n => Some(next_reg, [(IId (Anon next_reg), INSTR_Op (EXP_Integer (Z.of_nat n)))])
  | Plus e1 e2 =>
    '(reg1, instrs1) <- compile_expr next_reg e1 env;;
    '(reg2, instrs2) <- compile_expr (reg1 + 1)%Z e2 env;;
    ret (reg2 + 1, instrs1 ++ instrs2 ++ compile_binop reg1 reg2 (reg2 + 1) (Add false false))
  | Minus e1 e2 =>
    '(reg1, instrs1) <- compile_expr next_reg e1 env;;
    '(reg2, instrs2) <- compile_expr (reg1 + 1) e2 env;;
    ret (reg2 + 1, instrs1 ++ instrs2 ++ compile_binop reg1 reg2 (reg2 + 1) (Sub false false))
  | Mult e1 e2 =>
    '(reg1, instrs1) <- compile_expr next_reg e1 env;;
    '(reg2, instrs2) <- compile_expr (reg1 + 1) e2 env;;
    ret (reg2 + 1, instrs1 ++ instrs2 ++ compile_binop reg1 reg2 (reg2 + 1) (Mul false false))
  end.

Definition compile_assign (next_reg : int) (x: Imp.var) (e: expr) (env : StringMap.t int)
: option (int * (StringMap.t int) * code typ) :=
  '(expr_reg, ir) <- compile_expr next_reg e env;;
  ret match find x env with
  | Some id => ((expr_reg + 2), env,
      ir ++ [(IId (Anon (expr_reg + 1)), INSTR_Store false (texp_i32 expr_reg) (texp_ptr id) None)]
      )
  | None => (expr_reg + 3, add x next_reg env,
      ir ++ [(IId (Anon (expr_reg + 1)), INSTR_Alloca (TYPE_I 32) None None)] ++
      [(IId (Anon (expr_reg + 2)), INSTR_Store false (texp_i32 expr_reg) (texp_ptr (expr_reg + 1)) None)]
      )
  end.

Record cvir (n_in n_out : nat) : Type := {
   n_int : nat;
   blocks : forall
     (v_in : Vec.t raw_id n_in)
     (v_out : Vec.t raw_id n_out)
     (v_int : Vec.t raw_id n_int),
     list (block typ);
}.

Definition mk_cvir
  {n_in n_out n_int : nat}
  (blocks : forall
    (v_in : Vec.t raw_id n_in)
    (v_out : Vec.t raw_id n_out)
    (v_int : Vec.t raw_id n_int),
    list (block typ)
  ) :
  cvir n_in n_out :=
  {|
    n_int := n_int;
    blocks := blocks
  |}.

Arguments n_int {_} {_}.
Arguments blocks {_} {_}.

Definition block_cvir (c : code typ) : cvir 1 1 :=
  mk_cvir (fun
    (vi : Vec.t raw_id 1)
    (vo : Vec.t raw_id 1)
    (vt : Vec.t raw_id 0)
    => [mk_block (Vec.hd vi) List.nil c (TERM_Br_1 (hd vo)) None]
  ).

Definition branch_cvir (c : code typ) (e : texp typ) : cvir 1 2 :=
  mk_cvir (fun
    (vi : Vec.t raw_id 1)
    (vo : Vec.t raw_id 2)
    (vt : Vec.t raw_id 0)
    => [mk_block (Vec.hd vi) (List.nil) c (TERM_Br e (Vec.hd vo) (Vec.hd (Vec.tl vo))) None]
  ).

Definition merge_cvir
  {ni1 no1 ni2 no2 : nat}
  (b1: cvir ni1 no1)
  (b2: cvir ni2 no2) :
  cvir (ni1+ni2) (no1+no2) :=
    mk_cvir (fun vi vo vt =>
      let '(li,ri) := Vec.splitat ni1 vi in
      let '(lo,ro) := Vec.splitat no1 vo in
      let '(lt,rt) := Vec.splitat (n_int b1) vt in
      (blocks b1 li lo lt) ++ (blocks b2 ri ro rt)
    ).

Definition seq_cvir {ni1 no1 ni2 no2 : nat}
  (b1 : cvir ni1 (S no1))
  (b2: cvir (S ni2) no2) :
  cvir (ni1+ni2) (no1+no2) :=
    mk_cvir (fun vi vo (vt : Vec.t raw_id (S (n_int b1 + n_int b2))) =>
      let '(newint,vt) := Vec.uncons vt in
      let b1 := mk_cvir (fun vi vo vt => (blocks b1) vi (newint :: vo)%vec vt) in
      let b2 := mk_cvir (fun vi vo vt => (blocks b2) (newint :: vi)%vec vo vt) in
      blocks (merge_cvir b1 b2) vi vo vt
    ).

Definition loop_cvir {ni no : nat} (b : cvir (S ni) (S no)) : cvir ni no :=
  mk_cvir (fun vi vo vt =>
    let '(newint,vt) := Vec.uncons vt in
    (blocks b) (newint :: vi)%vec (newint :: vo)%vec vt
  ).

Program Definition loop_cvir' {ni no ni' no' : nat} (b : cvir ni no) (Heqi : ni = S ni') (Heqo : no = S no') : cvir ni' no' :=
  mk_cvir (fun vi vo vt =>
    let '(newint,vt) := Vec.uncons vt in
    (blocks b) (Vec.cast (newint :: vi)%vec _) (Vec.cast (newint :: vo)%vec _) vt
  ).

Program Definition focus_input_cvir {ni no : nat} (b : cvir ni no) (i : Fin.fin ni) : cvir ni no :=
  match proj1_sig i with
  | O => b
  | S i' =>
    match ni with
    | S ni =>
      mk_cvir (fun vi vo vt =>
        let '(vi1, vi2) := Vec.splitat (S i') (cast vi _) : (Vec.t _ (S i')) * (Vec.t _ (ni - i')) in
        let '(i1, vi1) := Vec.uncons vi1 in
        (blocks b) (Vec.cast (vi1 ++ i1 :: vi2)%vec _) vo vt
      )
    | _ => b
    end
  end.
Next Obligation.
  destruct i. simpl in *.
  rewrite le_plus_minus_r. reflexivity.
  apply le_S_n.
  subst.
  apply Nat.lt_le_incl.
  assumption.
Defined.
Next Obligation.
  destruct i.
  simpl in *. clear Heq_anonymous.
  rewrite minus_Sn_m. rewrite le_plus_minus_r ; auto.
  apply Nat.le_le_succ_r.
  all: subst ; apply le_S_n ; apply Nat.lt_le_incl ; assumption.
Defined.

(*Program Definition focus_output_cvir {ni no : nat} (b : cvir ni (S no)) (i : Fin.fin no) : cvir ni (S no) :=
  mk_cvir (fun vi vo vt =>
    let '(vo1, vo2) := Vec.splitat (S (proj1_sig i)) (Vec.cast vo _) : (Vec.t _ (S (proj1_sig i))) * (Vec.t _ (no - proj1_sig i)) in
    let '(o1, vo1) := Vec.uncons vo1 in
    (blocks b) vi (Vec.cast (vo1 ++ o1 :: vo2)%vec _) vt
  ).
Next Obligation.
  destruct i. simpl.
  f_equal.
  rewrite le_plus_minus_r ; auto.
  apply Nat.lt_le_incl.
  assumption.
Defined.
Next Obligation.
  destruct i.
  simpl. rewrite minus_Sn_m. rewrite le_plus_minus_r ; auto.
  apply Nat.le_le_succ_r.
  all: apply Nat.lt_le_incl ; assumption.
Defined.*)

Program Definition seq_cvir' {ni1 no1 ni2 no2 : nat}
  (b1 : cvir ni1 (S no1))
  (b2: cvir (S ni2) no2) :
  cvir (ni1+ni2) (no1+no2) :=
    let b := merge_cvir b1 b2 in
    let b := focus_input_cvir b (fi' ni1) in
    loop_cvir' b _ _.
Next Obligation.
  apply Nat.lt_add_pos_r.
  apply Nat.lt_0_succ.
Defined.

Definition loop_cvir_open {ni no : nat} (b : cvir (S ni) (S no)) : cvir (S ni) no :=
  mk_cvir (fun vi vo vt =>
    (blocks b) vi (hd vi :: vo)%vec vt
  ).

Definition join_cvir {ni no : nat} (b : cvir ni (S (S no))) : cvir ni (S no) :=
  mk_cvir (fun vi vo vt =>
    let '(o, vo) := Vec.uncons vo in
    (blocks b) vi (o :: o :: vo)%vec vt
  ).

Definition close_cvir {ni} (b : cvir ni 0) : cvir 0 0 :=
  mk_cvir (fun vi vo vt =>
    let '(vi,vt) := Vec.splitat ni vt in
    (blocks b) vi vo vt
  ).

(*Definition cond_cvir {ni1 no1 ni2 no2 : nat}
  (b1 : cvir (S ni1) (S no1)) (b2: cvir (S ni2) (S no2)) (e : texp typ) :
  cvir (ni1+ni2) (no1+no2) :=
    let cond_ir := branch_cvir [] e in
    join_cvir (seq_cvir (seq_cvir cond_ir b1) b2).*)

Fixpoint compile (next_reg : int) (s : stmt) (env: StringMap.t int)
: option (int * (StringMap.t int) * cvir 1 1) :=
  match s with
  | Skip => Some(next_reg, env, block_cvir [])
  | Assign x e =>
      '(next_reg, env, ir) <- compile_assign next_reg x e env;;
      ret (next_reg, env, block_cvir ir)
  | Seq l r =>
      '(next_reg, env, ir_l) <- compile next_reg l env;;
      '(next_reg, env, ir_r) <- compile next_reg r env;;
       ret (next_reg, env, seq_cvir ir_l ir_r)
  | While e b =>
      '(expr_reg, expr_ir) <- compile_expr next_reg e env;;
      '(next_reg, _, ir) <- compile (expr_reg + 1) b env;;
      let br := branch_cvir expr_ir (texp_i32 expr_reg) in
      let body := seq_cvir br ir in
      let ir := loop_cvir_open body in
      let ir := mk_cvir (fun vi vo vt => (blocks ir) vi (rev vo) vt) in
      ret (next_reg, env, ir) : option (int * (StringMap.t int) * cvir 1 1)
  (*| If e l r =>
      '(expr_reg, expr_ir) <- compile_expr next_reg e env;;
      '(next_reg, _, ir_l) <- compile (expr_reg + 1) l env;;
      '(next_reg, _, ir_r) <- compile next_reg r env;;
      ret (next_reg, env, cond_cvir ir_l ir_r (texp_i32 expr_reg)
      )*)
  | _ => None
  end.

Definition fnbody := (block typ * list (block typ))%type.
Definition program := toplevel_entity typ fnbody.

Definition entry_block : block typ :=
  mk_block (Anon 0) List.nil List.nil (TERM_Br_1 (Anon 1)) None.

Definition exit_block_cvir : cvir 1 0 :=
  mk_cvir (fun vi vo (vt : Vec.t raw_id 0) =>
    [mk_block (Vec.hd vi) List.nil List.nil (TERM_Ret_void) None]
  ).

Definition compile_cvir (ir : cvir 1 1) : program :=
  let ir := seq_cvir ir exit_block_cvir in
  let vt_seq := map Anon (map Z.of_nat (seq 2 (n_int ir))) in
  let blocks := (blocks ir) (cons (Anon 1) (empty raw_id)) (empty raw_id) vt_seq in
  let body := (entry_block, blocks) in
  let decl := mk_declaration
    (Name "imp_main")
    (TYPE_Function TYPE_Void nil)
    (nil, nil) None None None None nil None None None
  in
  let def := mk_definition fnbody decl nil body in
  TLE_Definition def.

Definition compile_program (s : stmt) (env : StringMap.t int) :
  option program :=
  '(_, _, ir) <- compile 0 s env;;
  ret (compile_cvir ir).

Definition fact_ir := (compile_program (fact "a" "b" 5) (StringMap.empty int)).

Eval compute in fact_ir.

End compile_cvir.
