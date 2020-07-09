(* -------------------------------------------------------------------------- *
 *                     Vir - the Verified LLVM project                     *
 *                                                                            *
 *     Copyright (c) 2017 Steve Zdancewic <stevez@cis.upenn.edu>              *
 *                                                                            *
 *   This file is distributed under the terms of the GNU General Public       *
 *   License as published by the Free Software Foundation, either version     *
 *   3 of the License, or (at your option) any later version.                 *
 ---------------------------------------------------------------------------- *)

From Coq Require Import String.
Require Import ExtLib.Structures.Monads.
Require Export ExtLib.Data.Monads.EitherMonad.

From ITree Require Import
     ITree
     Events.Exception.

Notation err := (sum string).

Instance Monad_err : Monad err := Monad_either string.
Instance Exception_err : MonadExc string err := Exception_either string.

Instance EqM_err: Monad.EqM err := fun a x y => @eq (err a) x y.

Instance EqMProps_err: Monad.EqMProps err.
  constructor.
  - repeat intro. repeat red. destruct x; reflexivity.
  - repeat intro. repeat red. repeat red in H.
    destruct x; destruct y; try auto; try contradiction.
  - repeat intro. repeat red in H, H0. repeat red.
    destruct x, y, z; auto; try contradiction; try etransitivity; eauto.
Qed.

Instance MonadLaws_err: Monad.MonadLaws err.
  constructor.
  - intros. repeat red. cbn. auto.
  - intros. repeat red. cbn. destruct x eqn: Hx; auto.
  - intros. repeat red. cbn.
    destruct x; auto.
  - repeat intro. repeat red. cbn. repeat red in H. rewrite H.
    repeat red in H0. destruct y; auto.
Qed.

Definition trywith {E A:Type} {F} `{Monad F} `{MonadExc E F} (e:E) (o:option A) : F A :=
    match o with
    | Some x => ret x
    | None => raise e
    end.
Hint Unfold trywith: core.
Arguments trywith _ _ _ _ _: simpl nomatch.

Definition failwith {A:Type} {F} `{Monad F} `{MonadExc string F} (s:string) : F A := raise s.
Hint Unfold failwith: core.
Arguments failwith _ _ _ _: simpl nomatch.
Definition undef := err.
Definition undef_or_err := eitherT string err.

Instance Monad_undef_or_err : Monad undef_or_err.
unfold undef_or_err. typeclasses eauto.
Defined.

Instance EqM_undef_or_err : Monad.EqM undef_or_err :=
  fun (a : Type) (x y : undef_or_err a) => x = y.

Instance EqMProps_undef_or_err : Monad.EqMProps undef_or_err.
constructor; intuition.
repeat intro. etransitivity; eauto.
Defined.

Instance MonadLaws_undef_or_err: Monad.MonadLaws undef_or_err.
constructor.
- repeat intro. cbn. destruct (f x). cbn. reflexivity.
- repeat intro. cbn. destruct x. cbn. destruct unEitherT; try reflexivity.
  destruct s; reflexivity.
- repeat intro. cbn. destruct x. destruct unEitherT; destruct s; reflexivity.
- repeat intro. destruct x, y. rewrite H. destruct unEitherT, unEitherT0; cbn; try reflexivity.
  destruct s0; [reflexivity | rewrite H0; reflexivity].
  destruct s0; [reflexivity | rewrite H0; reflexivity].
Qed.
