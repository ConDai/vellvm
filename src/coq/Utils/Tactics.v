Ltac flatten_goal :=
  match goal with
  | |- context[match ?x with | _ => _ end] => let Heq := fresh "Heq" in destruct x eqn:Heq
  end.

Ltac flatten_hyp h :=
  match type of h with
  | context[match ?x with | _ => _ end] => let Heq := fresh "Heq" in destruct x eqn:Heq
  end.

Ltac flatten_all :=
  match goal with
  | h: context[match ?x with | _ => _ end] |- _ => let Heq := fresh "Heq" in destruct x eqn:Heq
  | |- context[match ?x with | _ => _ end] => let Heq := fresh "Heq" in destruct x eqn:Heq
  end.

Ltac inv H := inversion H; try subst; clear H.

Global Tactic Notation "intros !" := repeat intro.
Ltac invn f :=
    match goal with
    | [ id: f |- _ ] => inv id
    | [ id: f _ |- _ ] => inv id
    | [ id: f _ _ |- _ ] => inv id
    | [ id: f _ _ _ |- _ ] => inv id
    | [ id: f _ _ _ _ |- _ ] => inv id
    | [ id: f _ _ _ _ _ |- _ ] => inv id
    | [ id: f _ _ _ _ _ _ |- _ ] => inv id
    | [ id: f _ _ _ _ _ _ _ |- _ ] => inv id
    | [ id: f _ _ _ _ _ _ _ _ |- _ ] => inv id
    end.
Ltac destructn f :=
    match goal with
    | [ id: f |- _ ] => destruct id
    | [ id: f _ |- _ ] => destruct id
    | [ id: f _ _ |- _ ] => destruct id
    | [ id: f _ _ _ |- _ ] => destruct id
    | [ id: f _ _ _ _ |- _ ] => destruct id
    | [ id: f _ _ _ _ _ |- _ ] => destruct id
    | [ id: f _ _ _ _ _ _ |- _ ] => destruct id
    | [ id: f _ _ _ _ _ _ _ |- _ ] => destruct id
    | [ id: f _ _ _ _ _ _ _ _ |- _ ] => destruct id
    end.
Ltac appn f :=
    match goal with
    | [ id: f |- _ ] => apply id
    | [ id: f _ |- _ ] => apply id
    | [ id: f _ _ |- _ ] => apply id
    | [ id: f _ _ _ |- _ ] => apply id
    | [ id: f _ _ _ _ |- _ ] => apply id
    | [ id: f _ _ _ _ _ |- _ ] => apply id
    | [ id: f _ _ _ _ _ _ |- _ ] => apply id
    | [ id: f _ _ _ _ _ _ _ |- _ ] => apply id
    | [ id: f _ _ _ _ _ _ _ _ |- _ ] => apply id
    end.
Ltac eappn f :=
    match goal with
    | [ id: f |- _ ] => eapply id
    | [ id: f _ |- _ ] => eapply id
    | [ id: f _ _ |- _ ] => eapply id
    | [ id: f _ _ _ |- _ ] => eapply id
    | [ id: f _ _ _ _ |- _ ] => eapply id
    | [ id: f _ _ _ _ _ |- _ ] => eapply id
    | [ id: f _ _ _ _ _ _ |- _ ] => eapply id
    | [ id: f _ _ _ _ _ _ _ |- _ ] => eapply id
    | [ id: f _ _ _ _ _ _ _ _ |- _ ] => eapply id
    end.
Ltac break_match_hyp :=
  match goal with
    | [ H : context [ match ?X with _ => _ end ] |- _] =>
      match type of X with
        | sumbool _ _ => destruct X
        | _ => destruct X eqn:?
      end
  end.
Ltac break_match_goal :=
  match goal with
    | [ |- context [ match ?X with _ => _ end ] ] =>
      match type of X with
        | sumbool _ _ => destruct X
        | _ => destruct X eqn:?
      end
  end.
Ltac break_match := break_match_goal || break_match_hyp.

Ltac inv_option :=
  match goal with
  | h: Some _ = Some _ |-  _ => inv h
  | h: None   = Some _ |-  _ => inv h
  | h: Some _ = None   |-  _ => inv h
  | h: None   = None   |-  _ => inv h
  end.

Ltac inv_sum :=
  match goal with
  | h: inl _ = inl _ |-  _ => inv h
  | h: inr _ = inr _ |-  _ => inv h
  | h: inl _ = inr _ |-  _ => inv h
  | h: inr _ = inl _ |-  _ => inv h
  end.

Ltac break_sum :=
  match goal with
  | v: _ + _ |- _ => destruct v
  end.

From ITree Require Import
     ITree
     Eq.Eq.

Ltac bind_ret_r1 :=
  match goal with
    |- eutt _ ?t ?s => let x := fresh in
                     remember s as x;
                     rewrite <- (bind_ret_r t); subst x
  end.

Ltac bind_ret_r2 :=
  match goal with
    |- eutt _ ?t ?s => let x := fresh in
                     remember t as x;
                     rewrite <- (bind_ret_r s); subst x
  end.

Ltac forward H :=
  let H' := fresh in
  match type of H with
  | ?P -> _ => assert P as H'; [| specialize (H H'); clear H']
  end.

(** [break_inner_match' t] tries to destruct the innermost [match] it
    find in [t]. *)
Ltac break_inner_match' t :=
 match t with
   | context[match ?X with _ => _ end] =>
     break_inner_match' X || destruct X eqn:?
   | _ => destruct t eqn:?
 end.

(** [break_inner_match_goal] tries to destruct the innermost [match] it
    find in your goal. *)
Ltac break_inner_match_goal :=
 match goal with
   | [ |- context[match ?X with _ => _ end] ] =>
     break_inner_match' X
 end.

(** [break_inner_match_hyp] tries to destruct the innermost [match] it
    find in a hypothesis. *)
Ltac break_inner_match_hyp :=
 match goal with
   | [ H : context[match ?X with _ => _ end] |- _ ] =>
     break_inner_match' X
 end.

(** [break_inner_match] tries to destruct the innermost [match] it
    find in your goal or a hypothesis. *)
Ltac break_inner_match := break_inner_match_goal || break_inner_match_hyp.

