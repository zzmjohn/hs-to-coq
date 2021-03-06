Require Import GHC.Base.
Require Import CoreFVs.
Require Import Id.
Require Import Core.
Require UniqFM.

Import GHC.Base.ManualNotations.

Require Import Proofs.GHC.Base.
Require Import Proofs.GHC.List.

Require Import Psatz.
Require Import Coq.Lists.List.
Require Import Coq.NArith.BinNat.

Import ListNotations.

Require Import Proofs.GhcTactics.
Require Import Proofs.Unique.
Require Import Proofs.Var.
Require Import Proofs.Base.
(* Require Import Proofs.ContainerAxioms.
   Require Import IntSetProofs.  *)

Require Import Proofs.VarSetFSet.

Open Scope Z_scope.

Set Bullet Behavior "Strict Subproofs".

(** ** Valid VarSets *)

Definition ValidVarSet (vs : VarSet) : Prop :=
  forall v1 v2, lookupVarSet vs v1 = Some v2 -> (v1 GHC.Base.== v2) = true.


(** ** [VarSet] as FiniteSets  *)

(* These lemmas relate the GHC VarSet operations to more general 
   operations on finite sets. *)

Lemma delVarSet_remove : forall x s, delVarSet s x = remove x s.
tauto. Qed.

Lemma extendVarSet_add : forall x s, extendVarSet s x = add x s.
tauto. Qed.

Lemma unitVarSet_singleton : forall x, unitVarSet x = singleton x.
auto. Qed.

Lemma extendVarSetList_foldl' : forall x xs, 
    extendVarSetList x xs = 
    Foldable.foldl' (fun x y => add y x) x xs.
Proof.
  intros.
  unfold extendVarSetList,
         UniqSet.addListToUniqSet;
  replace UniqSet.addOneToUniqSet with 
      (fun x y => add y x).
  auto.
  auto.
Qed.

Lemma delVarSetList_foldl : forall vl vs,
    delVarSetList vs vl = Foldable.foldl delVarSet vs vl.
Proof. 
  induction vl.
  - intro vs. 
    unfold delVarSetList.
    unfold UniqSet.delListFromUniqSet.
    destruct vs.
    unfold UniqFM.delListFromUFM.
    unfold_Foldable_foldl.
    simpl.
    auto.
  - intro vs. 
    unfold delVarSetList in *.
    unfold UniqSet.delListFromUniqSet in *.
    destruct vs.
    unfold UniqFM.delListFromUFM in *.
    revert IHvl.
    unfold_Foldable_foldl.
    simpl.
    intro IHvl.
    rewrite IHvl with (vs:= (UniqSet.Mk_UniqSet (UniqFM.delFromUFM u a))).
    auto.
Qed.


Lemma mkVarSet_extendVarSetList : forall xs,
    mkVarSet xs = extendVarSetList emptyVarSet xs.
Proof.
  reflexivity.
Qed.


Ltac rewrite_extendVarSetList := 
  unfold extendVarSetList, UniqSet.addListToUniqSet;
  replace UniqSet.addOneToUniqSet with (fun x y => add y x) by auto.

(* This tactic rewrites the boolean functions into the 
   set properties to make them more suitable for fsetdec. *)

Ltac set_b_iff :=
  repeat
   progress
    rewrite <- not_mem_iff in *
  || rewrite <- mem_iff in *
  || rewrite <- subset_iff in *
  || rewrite <- is_empty_iff in *
  || rewrite delVarSet_remove in *
  || rewrite extendVarSet_add in *
  || rewrite empty_b in *
  || rewrite unitVarSet_singleton in *
  || rewrite_extendVarSetList
  || rewrite delVarSetList_foldl in *.

(**************************************)

(* Q: is there a way to do the automatic destructs safely? Sometimes 
   loses too much information. *)

Ltac unfold_VarSet :=
  unfold subVarSet,elemVarSet, isEmptyVarSet, 
         minusVarSet, extendVarSet, extendVarSetList in *;
  unfold UniqSet.elementOfUniqSet, 
         UniqSet.isEmptyUniqSet, 
         UniqSet.addOneToUniqSet,
         UniqSet.minusUniqSet,
         UniqSet.addListToUniqSet in *;
  try repeat match goal with
  | vs: VarSet, H : context[match ?vs with _ => _ end]  |- _ => destruct vs
  end;
  try repeat match goal with
  | vs: VarSet |- context[match ?vs with _ => _ end ] => destruct vs
  end;

  unfold UniqFM.addToUFM, 
         UniqFM.minusUFM, UniqFM.isNullUFM, 
         UniqFM.elemUFM in *;
  try repeat match goal with
  | u: UniqFM.UniqFM ?a, H : context[match ?u with _ => _ end]  |- _ => destruct u
  end;
  try repeat match goal with
  | u: UniqFM.UniqFM ?a |- context[match ?u with _ => _ end] => destruct u
  end. 

Ltac safe_unfold_VarSet :=
  unfold subVarSet,elemVarSet, isEmptyVarSet, 
         minusVarSet, extendVarSet, extendVarSetList in *;
  unfold UniqSet.elementOfUniqSet, 
         UniqSet.isEmptyUniqSet, 
         UniqSet.addOneToUniqSet,
         UniqSet.minusUniqSet,
         UniqSet.addListToUniqSet in *;
  unfold UniqFM.addToUFM, 
         UniqFM.minusUFM, UniqFM.isNullUFM, 
         UniqFM.elemUFM in *.

(**************************************)

(** ** [extendVarSetList]  *)

Lemma extendVarSetList_nil:
  forall s,
  extendVarSetList s [] = s.
Proof.
  intro s.
  set_b_iff.
  reflexivity.
Qed.

Lemma extendVarSetList_cons:
  forall s v vs,
  extendVarSetList s (v :: vs) = extendVarSetList (extendVarSet s v) vs.
Proof.
  intros.
  set_b_iff.
  unfold_Foldable_foldl'.
  reflexivity.
Qed.


Lemma extendVarSetList_append:
  forall s vs1 vs2,
  extendVarSetList s (vs1 ++ vs2) = extendVarSetList (extendVarSetList s vs1) vs2.
Proof.
  intros.
  set_b_iff.
  rewrite Foldable_foldl'_app.
  auto.
Qed.

(** ** [elemVarSet]  *)

Lemma elemVarSet_emptyVarSet : forall v, elemVarSet v emptyVarSet = false.
  intro v.
  set_b_iff.
  fsetdec.
Qed.

(** ** [extendVarSet]  *)

Lemma lookupVarSet_extendVarSet_self:
  forall v vs,
  lookupVarSet (extendVarSet vs v) v = Some v.
Admitted.


Lemma extendVarSet_elemVarSet_true : forall set v, 
    elemVarSet v set = true -> extendVarSet set v [=] set.
Proof. 
  intros.
  apply add_equal.
  auto.
Qed.


Lemma elemVarSet_extendVarSet:
  forall v vs v',
  elemVarSet v (extendVarSet vs v') = (v' GHC.Base.== v) || elemVarSet v vs.
Proof.
  intros.
  unfold_zeze.
  replace (realUnique v' =? realUnique v)%nat with 
    (F.eqb v' v).
  eapply MP.Dec.F.add_b.
  unfold F.eqb. destruct F.eq_dec.
  unfold Var_as_DT.eq in e.
  unfold Var_as_DT.eqb in e.
  revert e.
  unfold_zeze.
  auto.
  unfold Var_as_DT.eq in n.
  unfold Var_as_DT.eqb in n.
  revert n.
  unfold_zeze.
  set (blah := (realUnique v' =? realUnique v)%nat).
  now destruct blah.
Qed.


(** ** [delVarSet]  *)

Lemma delVarSet_elemVarSet_false : forall v set, 
    elemVarSet v set = false -> delVarSet set v [=] set.
intros.
set_b_iff.
apply remove_equal.
auto.
Qed.


Lemma delVarSet_extendVarSet : 
  forall set v, 
    elemVarSet v set = false -> 
    (delVarSet (extendVarSet set v) v) [=] set.
Proof.
  intros.
  set_b_iff.
  apply remove_add.
  auto.
Qed.

(** ** [delVarSetList]  *)

Lemma delVarSetList_single:
  forall e a, delVarSetList e [a] = delVarSet e a.
Proof.
  intros. unfold delVarSetList, delVarSet.
  unfold UniqSet.delListFromUniqSet, UniqSet.delOneFromUniqSet.
  destruct e; reflexivity.
Qed.

Lemma delVarSetList_cons:
  forall e a vs, delVarSetList e (a :: vs) = delVarSetList (delVarSet e a) vs.
Proof.
  induction vs; try revert IHvs;
    unfold delVarSetList, UniqSet.delListFromUniqSet; destruct e;
      try reflexivity.
Qed.

Lemma delVarSetList_app:
  forall e vs vs', delVarSetList e (vs ++ vs') = delVarSetList (delVarSetList e vs) vs'.
Proof.
  induction vs'.
  - rewrite app_nil_r.
    unfold delVarSetList, UniqSet.delListFromUniqSet.
    destruct e; reflexivity.
  - intros.
    unfold delVarSetList, UniqSet.delListFromUniqSet; destruct e.
    unfold UniqFM.delListFromUFM.
Admitted.
(*
    repeat rewrite hs_coq_foldl_list. rewrite fold_left_app. reflexivity.
Qed. *)


Lemma elemVarSet_delVarSet: forall v1 fvs v2,
  elemVarSet v1 (delVarSet fvs v2) = true <-> 
  (varUnique v1 <> varUnique v2 /\ elemVarSet v1 fvs = true).
Proof.
  intros.
  set_b_iff.
  set_iff.
  unfold Var_as_DT.eqb.
  unfold_zeze.
Admitted.


(**************************************)


(** ** [subVarSet]  *)
  
Lemma subVarSet_refl:
  forall vs1,
  subVarSet vs1 vs1 = true.
Proof.
  intros.
  set_b_iff.
  fsetdec.
Qed.

Lemma elemVarSet_unitVarSet: forall v1 v2,
  (elemVarSet v1 (unitVarSet v2) = true) <-> (varUnique v1 = varUnique v2).
Proof.
  intros v1 v2.
  set_b_iff.
  rewrite singleton_iff.
  unfold Var_as_DT.eqb.
  unfold_zeze.
Admitted.
  

Lemma elemVarSet_false_true:
  forall v1 fvs v2,
  elemVarSet v1 fvs = false ->
  elemVarSet v2 fvs = true ->
  varUnique v1 <> varUnique v2.
Proof.
  intros v1 fvs v2.
  set_b_iff.
  intros.
Admitted.
  

Lemma subVarSet_elemVarSet_true:
  forall v vs vs',
  subVarSet vs vs' = true ->
  elemVarSet v vs = true ->
  elemVarSet v vs' = true.
Proof.
  intros v vs vs'.
  set_b_iff.
  fsetdec.
Qed.

Lemma subVarSet_elemVarSet_false:
  forall v vs vs',
  subVarSet vs vs' = true ->
  elemVarSet v vs' = false ->
  elemVarSet v vs = false.
Proof.
  intros v vs vs'.
  set_b_iff.
  fsetdec.
Qed.

Lemma subVarSet_extendVarSetList_l:
  forall vs1 vs2 vs,
  subVarSet vs1 vs2 = true ->
  subVarSet vs1 (extendVarSetList vs2 vs) = true.
Proof.
  intros vs1 vs2 vs.
  generalize vs2. clear vs2.
  induction vs.
  - intro vs2. rewrite extendVarSetList_nil. auto.
  - intro vs2. intro h. 
    rewrite extendVarSetList_cons. 
    rewrite IHvs. auto. 
    set_b_iff. fsetdec.
Qed.

Lemma subVarSet_extendVarSetList_r:
  forall vs vs1 vs2,
  subVarSet vs1 (mkVarSet vs) = true ->
  subVarSet vs1 (extendVarSetList vs2 vs) = true.
Proof.
  intros vs. 
  induction vs; intros vs1 vs2.
  - set_b_iff.
    unfold_Foldable_foldl'.
    simpl.
    fsetdec.
  - intro h. 
    rewrite mkVarSet_extendVarSetList in h.
    rewrite extendVarSetList_cons in *.
Admitted.
    
    
Lemma subVarSet_extendVarSet:
  forall vs1 vs2 v,
  subVarSet vs1 vs2 = true ->
  subVarSet vs1 (extendVarSet vs2 v) = true.
Proof.
  intros.
  set_b_iff.
  fsetdec.
Qed.


Lemma subVarSet_delVarSetList:
  forall vs1 vl,
  subVarSet (delVarSetList vs1 vl) vs1 = true.
Proof.
  intros.
  set_b_iff.
  generalize vs1. clear vs1. induction vl.
  - intros vs1. unfold_Foldable_foldl.
    simpl.
    fsetdec.
  - intros vs1. revert IHvl.
    unfold_Foldable_foldl.
    simpl.
    intro IH. 
    rewrite IH with (vs1 := delVarSet vs1 a).
    set_b_iff.
    fsetdec.
Qed.

(** ** [mkVarSet]  *)


Lemma elemVarSet_mkVarset_iff_In:
  forall v vs,
  elemVarSet v (mkVarSet vs) = true <->  List.In (varUnique v) (map varUnique vs).
Proof.
  intros.
  set_b_iff.
  remember (mkVarSet vs) as vss.
  unfold_VarSet.
  rewrite <- getUnique_varUnique.
  rewrite unique_In.
  set (key := (Unique.getWordKey (Unique.getUnique v))).
  (* Need theory about IntMap. *)
Admitted. 

Axiom disjointVarSet_mkVarSet:
  forall vs1 vs2,
  disjointVarSet vs1 (mkVarSet vs2) = true <->
  Forall (fun v => elemVarSet v vs1 = false) vs2.

Axiom disjointVarSet_subVarSet_l:
  forall vs1 vs2 vs3,
  disjointVarSet vs2 vs3 = true ->
  subVarSet vs1 vs2 = true ->
  disjointVarSet vs1 vs3 = true.

(** ** [InScopeVars] *)

Lemma getInScopeVars_extendInScopeSet:
  forall iss v,
  getInScopeVars (extendInScopeSet iss v) = extendVarSet (getInScopeVars iss) v.
Proof.
  intros.
  unfold getInScopeVars.
  unfold extendInScopeSet.
  destruct iss.
  reflexivity.
Qed.

Lemma getInScopeVars_extendInScopeSetList:
  forall iss vs,
  getInScopeVars (extendInScopeSetList iss vs) = extendVarSetList (getInScopeVars iss) vs.
Proof.
  intros.
  unfold getInScopeVars.
  unfold extendInScopeSetList.
  set_b_iff.
  destruct iss.
  unfold_Foldable_foldl'.
  unfold_Foldable_foldl.
  f_equal.
Qed.

(** ** [uniqAway] *)

Axiom isJoinId_maybe_uniqAway:
  forall s v, 
  isJoinId_maybe (uniqAway s v) = isJoinId_maybe v.



Lemma elemVarSet_uniqAway:
  forall v iss vs,
  subVarSet vs (getInScopeVars iss) = true ->
  elemVarSet (uniqAway iss v) vs = false.
Proof.
  intros.
  safe_unfold_VarSet.
  destruct vs.
  destruct iss.
  destruct v0.
  destruct u.
  destruct u0.
  simpl in *.
  unfold uniqAway.
  unfold elemInScopeSet.
  unfold elemVarSet.
  unfold uniqAway'.
  unfold realUnique.
Admitted.

(** ** [lookupVarSet] *)

Lemma lookupVarSet_elemVarSet : 
  forall v1 v2 vs, lookupVarSet vs v1 = Some v2 -> elemVarSet v1 vs = true.
Admitted.

Lemma elemVarSet_lookupVarSet :
  forall v1 vs, elemVarSet v1 vs = true -> exists v2, lookupVarSet vs v1 = Some v2.
Admitted.

Lemma lookupVarSet_extendVarSet_eq :
      forall v1 v2 vs,
      v1 GHC.Base.== v2 = true ->
      lookupVarSet (extendVarSet vs v1) v2 = Some v1.
Proof.
  intros.
  unfold lookupVarSet, extendVarSet.
  unfold UniqSet.lookupUniqSet, UniqSet.addOneToUniqSet.
  destruct vs.
  unfold UniqFM.lookupUFM, UniqFM.addToUFM.
  destruct u.
  unfold GHC.Base.op_zeze__, Eq___Var, Base.op_zeze____, 
  Core.Eq___Var_op_zeze__ in H.
Admitted.


(** ** Compatibility with [almostEqual] *)

Lemma lookupVarSet_ae : 
  forall vs v1 v2, 
    almostEqual v1 v2 -> 
    lookupVarSet vs v1 = lookupVarSet vs v2.
Proof. 
  induction 1; simpl; unfold UniqFM.lookupUFM; simpl; auto.
Qed.

Lemma delVarSet_ae:
  forall vs v1 v2,
  almostEqual v1 v2 ->
  delVarSet vs v1 = delVarSet vs v2.
Proof.
  induction 1; simpl;
  unfold UniqFM.delFromUFM; simpl; auto.
Qed.

Lemma elemVarSet_ae:
  forall vs v1 v2,
  almostEqual v1 v2 ->
  elemVarSet v1 vs = elemVarSet v2 vs.
Proof.
  induction 1; simpl;
  unfold UniqFM.delFromUFM; simpl; auto.
Qed.

(** ** [StrongSubset] *)


(* A strong subset doesn't just have a subset of the uniques, but 
     also requires that the variables in common be almostEqual. *)
Definition StrongSubset (vs1 : VarSet) (vs2: VarSet) := 
  forall var, match lookupVarSet vs1 var with 
           | Some v =>  match lookupVarSet vs2 v with
                          | Some v' => almostEqual v v'
                          | None => False
                       end
           | None => True 
         end.

