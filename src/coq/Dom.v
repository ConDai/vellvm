

(** Reasoning about dominators in a graph. *)

Require Import List Equalities Orders RelationClasses.
Require Import FSets FMaps.
Import ListNotations.
Require Import Vellvm.Util.


Module Type LATTICE.
  Include EqLe'.

  Declare Instance eq_equiv : Equivalence eq.
  Declare Instance le_preorder : PreOrder le.
  Declare Instance le_poset : PartialOrder eq le.
  
  Parameter eq_dec : forall x y, {x == y} + {x ~= y}.

  Parameter bot : t.
  Axiom le_bot : forall x, bot <= x.

  Parameter top : t.
  Axiom le_top : forall x, x <= top.

  Parameter join : t -> t -> t.
  Axiom le_join_l : forall x y, x <= join x y.
  Axiom le_join_r : forall x y, y <= join x y.
End LATTICE.

Module BoundedSet(Import S:FSetInterface.WS) <: LATTICE.

  Module Import SFacts := FSetFacts.WFacts S.

  Definition t : Type := option S.t.

  Definition eq (t1 t2: t) : Prop :=
    match t1, t2 with
      | Some s1, Some s2 => s1 [=] s2
      | None, None => True
      | _, _ => False
    end.

  Definition le (t1 t2: t) : Prop :=
    match t1, t2 with
      | Some s1, Some s2 => s2 [<=] s1
      | None, Some _ | None, None => True
      | Some _, None => False
    end.

  Include EqLeNotation.

  Instance eq_equiv : Equivalence eq.
  Proof.
    constructor.
    red. destruct x; simpl; intuition.
    red. destruct x, y; simpl; intros; intuition.
    red. destruct x, y, z; simpl; intros; intuition.
    transitivity t1; auto.
  Qed.

  Instance le_preorder : PreOrder le.
  Proof.
    constructor.
    red. destruct x; simpl; intuition. 
    red. destruct x, y, z; simpl; intros; intuition.
    transitivity t1; auto.
  Qed.

  Instance le_poset : PartialOrder eq le.
  Proof.
    constructor.
    intro. repeat red. split.
    destruct x, x0; simpl in *; intuition. 
    unfold Subset. intros. rewrite H; auto.
    red. destruct x, x0; simpl in *; intuition.
    unfold Subset. intros. rewrite <- H. auto.

    destruct x, x0; simpl; 
      intros H; repeat red in H; simpl in H; 
      intuition.
    repeat red in H1. repeat red in H0.
    red; intuition.
  Qed.

  Definition eq_dec : forall x y, {x == y} + {x ~= y}.
    refine (fun t1 t2 => match t1, t2 with
                           | Some s1, Some s2 => _
                           | None, None => left _
                           | _, _ => right _
                         end); auto using S.eq_dec.
  Defined.

  Definition bot : t := None.

  Lemma le_bot : forall x, bot <= x.
  Proof.
    simpl; destruct x; trivial.
  Qed.

  Definition top : t := Some S.empty.
  Lemma le_top : forall x, x <= top.
  Proof. 
    simpl. destruct x; trivial. red. intros.
    exfalso. eapply empty_iff; eauto. 
  Qed.

  Definition join (t1 t2: t) : t :=
    match t1, t2 with
      | Some s1, Some s2 => Some (S.inter s1 s2) 
      | None, Some s | Some s, None => Some s
      | None, None => None
    end.

  Lemma le_join_l : forall x y, x <= join x y.
  Proof.
    intros. destruct x, y; repeat red; auto.
    intros. eapply inter_1; eauto.
  Qed.

  Lemma le_join_r : forall x y, y <= join x y.
  Proof.
    intros. destruct x, y; repeat red; auto.
    intros. eapply inter_2; eauto.
  Qed.

  Definition union (t1 t2: t) : t :=
    match t1, t2 with
      | Some s1, Some s2 => Some (S.union s1 s2) 
      | None, Some s | Some s, None => None
      | None, None => None
    end.
    
  Definition singleton (e:S.elt) : t := Some (S.singleton e).

  Definition In (e:S.elt) (t:t) : Prop :=
    match t with
      | Some s => S.In e s
      | None => True
    end.

End BoundedSet.



(** ** GRAPH *)
(** Interface for a nonempty graph [t] with: 
     - a set of _vertices_ of type [V]
     - a distinguished _entry vertex_
     - an _edge relation_ [Succ]
*)

Module Type GRAPH.
  Parameter Inline t V : Type.
  
  Parameter Inline entry : t -> V.
  Parameter Inline Succ : t -> V -> V -> Prop.
  Parameter Inline Mem : t -> V -> Prop.
End GRAPH.

(** ** Specification of Dominators *)

Module Spec (Import G:GRAPH).

(** Defines a path in the graph. *)

  Inductive Path (g:G.t) : V -> V -> list V -> Prop :=
  | path_nil : forall v, 
      Mem g v -> Path g v v [v]
  | path_cons : forall v1 v2 v3 vs,
      Path g v1 v2 vs -> Mem g v3 -> Succ g v2 v3 
      -> Path g v1 v3 (v3::vs).

(** *** Definition of domination *)

  Definition Dom (g:G.t) (v1 v2: V) : Prop :=
    forall vs, Path g (entry g) v2 vs -> In v1 vs.

  Definition SDom (g:G.t) (v1 v2 : V) : Prop :=
    v1 <> v2 /\ Dom g v1 v2.

  Lemma dom_step : forall g v1 v2,
    Mem g v2 -> Succ g v1 v2 -> forall v', SDom g v' v2 -> Dom g v' v1.
(* FOLD *)
  Proof.
    unfold SDom, Dom. intros g v1 v2 Hmem Hsucc v' [Hneq Hdom] p Hp.
    cut (In v' (v2::p)). inversion 1; subst; intuition. 
    apply Hdom. eapply path_cons; eauto. 
  Qed.
(* /FOLD *)

End Spec.

(** *** Relate an algorithm to the specification *)
Module Type Algdom (Import G:GRAPH).
  Module Import GS := Spec G.

  Declare Module E : UsualDecidableType with Definition t := V.
  Declare Module NS : FSetInterface.WS with Module E:=E.
  Module L := BoundedSet NS.
  Include EqLeNotation L.

  Parameter calc_sdom : G.t -> option (V -> L.t).

  Axiom entry_sound : forall g sdom,
    calc_sdom g = Some sdom ->
    sdom (entry g) == L.top.

  Axiom successors_sound : forall g sdom n1 n2,
    calc_sdom g = Some sdom ->
    Mem g n1 -> Mem g n2 -> Succ g n1 n2 -> 
    L.union (L.singleton n1) (sdom n1) <= sdom n2.

  Axiom complete : forall g sdom n1 n2,
    calc_sdom g = Some sdom ->
    SDom g n1 n2 -> L.In n1 (sdom n2).

End Algdom.

Module AlgdomProperties (Import G:GRAPH) (Import A : Algdom G).
  Module Import GS := Spec G.

  Lemma sound : forall g sdom n1 n2,
    calc_sdom g = Some sdom ->              
    L.In n1 (sdom n2) -> Dom g n1 n2.
(* FOLD *)
  Proof.
    red; intros. remember (entry g). induction H1. subst.
    pose proof entry_sound g sdom H. 

    destruct (sdom (entry g)); try contradiction; simpl in *.
      exfalso. rewrite H2 in H0. eapply L.SFacts.empty_iff. eauto.
      
    right. destruct (E.eq_dec v2 n1). subst. inversion H1; intuition.
    apply IHPath; auto.

    destruct (sdom v2) eqn:Heqv2; simpl in *; auto.
    cut (NS.In n1 (NS.union (NS.singleton v2) t0)).
    intro Hin. apply NS.union_1 in Hin as [Hin | Hin]; auto.
    contradict n. apply NS.singleton_1. assumption.

    pose proof successors_sound g sdom v2 v3 as Hss.
    simpl in Hss. rewrite Heqv2 in Hss. simpl in Hss.
    destruct (sdom v3). apply Hss; inversion H1; eauto.
    exfalso. apply Hss; inversion H1; eauto.
  Qed.
(* /FOLD *)

End AlgdomProperties.

