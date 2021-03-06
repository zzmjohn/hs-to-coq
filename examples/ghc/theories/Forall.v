Require Import Coq.Lists.List.

Lemma Forall_map:
  forall {a b} P (f : a -> b) xs,
  Forall P (map f xs) <-> Forall (fun x => P (f x)) xs.
Proof.
  intros.
  induction xs; simpl.
  * split; intro; constructor.
  * split; intro H; inversion_clear H; constructor; try apply IHxs; assumption.
Qed.


(* The termination checker does not like recursion through [Forall], but
   through [map] is fine... oh well. *)
Definition Forall' {a} (P : a -> Prop) xs := Forall id (map P xs).

Lemma Forall'_Forall:
  forall  {a} (P : a -> Prop) xs,
  Forall' P xs <-> Forall P xs.
Proof.
  intros.
  unfold Forall'.
  unfold id.
  rewrite Forall_map.
  reflexivity.
Qed.
