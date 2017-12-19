Require Import GHC.Base.
Import Notations.
Require Import GHC.Num.
Import Notations.

Require Import Data.Set.Base.
Require Import Coq.FSets.FSetInterface.

Require Import Omega.

From mathcomp Require Import ssrbool ssreflect.

Local Open Scope Z_scope.

(** This should be in a separate file, but let's keep it here for
    convenience for now. *)
Section Int_And_Z.
  Variables a b : Int.

  Lemma Int_plus_is_Z_plus :
    a GHC.Num.+ b = (a + b).
  Proof. rewrite /_GHC.Num.+_. reflexivity. Qed.

  Lemma Int_minus_is_Z_minus :
    a GHC.Num.- b = (a - b).
  Proof. rewrite /_GHC.Num.-_. reflexivity. Qed.

  Lemma Int_mult_is_Z_mult :
    a GHC.Num.* b = (a * b).
  Proof. rewrite /_GHC.Num.*_. reflexivity. Qed.

  Lemma Int_lt_is_Z_lt :
    a GHC.Base.< b = (a <? b).
  Proof. rewrite /_GHC.Base.<_. reflexivity. Qed.

  Lemma Int_le_is_Z_le :
    a GHC.Base.<= b = (a <=? b).
  Proof. rewrite /_GHC.Base.<=_. reflexivity. Qed.

  Lemma Int_gt_is_Z_gt :
    a GHC.Base.> b = (b <? a).
  Proof. rewrite /_GHC.Base.>_. reflexivity. Qed.

  Lemma Int_ge_is_Z_ge :
    a GHC.Base.>= b = (b <=? a).
  Proof. rewrite /_GHC.Base.>=_. reflexivity. Qed.

  Lemma Int_eq_is_Z_eq :
    a GHC.Base.== b = (Z.eqb a b).
  Proof. rewrite /_GHC.Base.==_. reflexivity. Qed.

  Lemma Int_is_Z : forall a : Z,
      # a = a.
  Proof. reflexivity. Qed.

End Int_And_Z.

Ltac rewrite_Int :=
  repeat (rewrite ?Int_plus_is_Z_plus ?Int_minus_is_Z_minus
                  ?Int_mult_is_Z_mult
                  ?Int_lt_is_Z_lt ?Int_le_is_Z_le
                  ?Int_ge_is_Z_ge ?Int_gt_is_Z_gt
                  ?Int_eq_is_Z_eq ?Int_is_Z).

Section Option_Int.
  Variables a b : option Int.
  
  Ltac rewrite_option_eq :=
    rewrite /op_zeze__ /Eq___option //= /op_zeze__ /Eq_Integer___ //=.

  Lemma Maybe_eq_is_Option_eq :
    a GHC.Base.== b <-> a = b.
  Proof.
    rewrite /_GHC.Base.==_ /Eq___option /= /Base.Eq___option_op_zeze__.
    destruct a; destruct b.
    - rewrite_Int. rewrite /is_true Z.eqb_eq.
      split; (elim + case); done.
    - split; discriminate.
    - split; discriminate.
    - split; auto.
  Qed.
End Option_Int.

Module Foo (E : OrderedType) : WSfun(E).
  Local Instance Eq_t : GHC.Base.Eq_ E.t :=
    fun _ k => k {|
                op_zeze____ := fun x y => E.eq_dec x y;
                op_zsze____ := fun x y => negb (E.eq_dec x y);
              |}.

  Local Definition compare (x y: E.t) : comparison :=
    match E.compare x y with
    | EQ _ => Eq
    | LT _ => Lt
    | GT _ => Gt
    end.

  Local Instance Ord_t : GHC.Base.Ord E.t := GHC.Base.ord_default compare.

  Module OrdFacts := OrderedTypeFacts(E).

  Ltac rewrite_compare_e :=
    rewrite /Base.compare /Ord_t /ord_default /= /compare.

  Ltac destruct_match :=
    match goal with
    | [ H :context[match ?a with _ => _ end] |- _] =>
      let Heq := fresh "Heq" in
      destruct a eqn:Heq=>//
    | [ |- context[match ?a with _ => _ end]] =>
      let Heq := fresh "Heq" in
      destruct a eqn:Heq=>//
    end.

  Definition elt := E.t.

  (* Well-formedness *)
  Definition WF (s : Set_ elt) := valid s.
  (* Will it be easier for proof if [WF] is an inductive definition? *)
  Definition t := {s : Set_ elt | WF s}.
  Definition pack (s : Set_ elt) (H : WF s): t := exist _ s H.

  Lemma elt_lt : forall (e1 e2 : elt),
      e1 GHC.Base.< e2 <-> E.lt e1 e2.
  Proof.
    move=>e1 e2. rewrite /_GHC.Base.<_ /Ord_t /ord_default /=.
    rewrite /_GHC.Base.==_ /Eq_comparison___ /= /eq_comparison /compare.
    split.
    - destruct (E.compare e1 e2); auto; move=>Hcontra; inversion Hcontra.
    - move /OrdFacts.elim_compare_lt; elim. move=>x H; rewrite H=>//.
  Qed.

  Lemma elt_gt : forall (e1 e2 : elt),
      e1 GHC.Base.> e2 <-> E.lt e2 e1.
  Proof.
    move=>e1 e2. rewrite /_GHC.Base.>_ /Ord_t /ord_default /=.
    rewrite /_GHC.Base.==_ /Eq_comparison___ /= /eq_comparison /compare.
    split.
    - destruct (E.compare e2 e1); auto; move=>Hcontra; inversion Hcontra.
    - move /OrdFacts.elim_compare_lt; elim. move=>x H; rewrite H=>//.
  Qed.

  Lemma elt_compare_lt: forall (e1 e2 : elt),
      GHC.Base.compare e1 e2 = Lt <-> E.lt e1 e2.
  Proof.
    move=>e1 e2. rewrite_compare_e.
    destruct_match; split; move=>Hcontra; try solve [inversion Hcontra].
    - apply (OrdFacts.eq_not_lt e) in Hcontra. inversion Hcontra.
    - apply OrdFacts.lt_not_gt in Hcontra. contradiction.
  Qed.

  Lemma elt_compare_gt: forall (e1 e2 : elt),
      GHC.Base.compare e1 e2 = Gt <-> E.lt e2 e1.
  Proof.
    move=>e1 e2. rewrite_compare_e.
    destruct_match; split; move=>Hcontra; try solve [inversion Hcontra].
    - apply OrdFacts.lt_not_gt in Hcontra. contradiction.
    - clear Heq. apply E.eq_sym in e.
      apply (OrdFacts.eq_not_lt e) in Hcontra. inversion Hcontra.
  Qed.

  Lemma elt_compare_eq: forall (e1 e2 : elt),
      GHC.Base.compare e1 e2 = Eq <-> E.eq e1 e2.
  Proof.
    move=>e1 e2. rewrite /Base.compare /Ord_t /ord_default /= /compare.
    destruct_match; split; move=>Hcontra; try solve [inversion Hcontra].
    - apply OrdFacts.eq_not_lt in Hcontra. contradiction.
    - apply E.eq_sym in Hcontra. apply OrdFacts.eq_not_lt in Hcontra. contradiction.
  Qed.

  Hint Rewrite -> elt_gt : elt_compare.
  Hint Rewrite -> elt_lt : elt_compare.
  Hint Rewrite -> elt_compare_lt : elt_compare.
  Hint Rewrite -> elt_compare_gt : elt_compare.
  Hint Rewrite -> elt_compare_eq : elt_compare.

  Ltac rewrite_size :=
    repeat match goal with
           | [ |- _ ] => rewrite ![size (Bin _ _ _ _)]/size
           | [ |- _ ] => rewrite ![size Tip]/size
           | [H: context[size (Bin _ _ _ _)] |- _ ] =>
             rewrite ![size (Bin _ _ _ _)]/size in H
           | [H: context[size Tip] |- _ ] =>
             rewrite ![size Tip]/size in H
           end.

  Notation "x <-- f ;; P" :=
    (match f with
     | exist x _ => P
     end) (at level 99, f at next level, right associativity).

  Definition In_set x (s : Set_ elt) :=
    member x s = true.

  Definition In x (s' : t) :=
    s <-- s' ;;
    In_set x s.

  Definition Equal_set s s' := forall a : elt, In_set a s <-> In_set a s'.
  Definition Equal s s' := forall a : elt, In a s <-> In a s'.
  Definition Subset s s' := forall a : elt, In a s -> In a s'.
  Definition Empty s := forall a : elt, ~ In a s.
  Definition For_all (P : elt -> Prop) s := forall x, In x s -> P x.
  Definition Exists (P : elt -> Prop) s := exists x, In x s /\ P x.

  Definition empty : t := pack empty Logic.eq_refl.
  Definition is_empty : t -> bool := fun s' =>
    s <-- s' ;; null s.

  Lemma empty_1 : Empty empty.
  Proof. unfold Empty; intros a H. inversion H. Qed.

  Lemma is_empty_1 : forall s : t, Empty s -> is_empty s = true.
  Proof.
    move=>s. rewrite /Empty /In. case s=>[s'].
    case s'=>[ls x l r | ] => Hwf Hempty=>//.
    specialize (Hempty x). exfalso. apply Hempty.
    rewrite /In_set /member //=. rewrite_compare_e.
    have Heq: E.eq x x by done.
    apply OrdFacts.elim_compare_eq in Heq; destruct Heq.
    rewrite H=>//.
  Qed.

  Lemma is_empty_2 : forall s : t, is_empty s = true -> Empty s.
  Proof. move=>s. rewrite /Empty /In. elim s=>[s']. elim s'=>//. Qed.

  Lemma empty_not_bin : forall l e (s1 s2 : Set_ elt),
      ~ Equal_set Tip (Bin l e s1 s2).
  Proof.
    intros. rewrite /Equal_set=>Heq.
    specialize (Heq e). destruct Heq.
    move: H0. rewrite {1}/In_set /member /=.
    have Heq: E.eq e e by done.
    apply elt_compare_eq in Heq. rewrite Heq=>Hcontra.
    specialize (Hcontra Logic.eq_refl). inversion Hcontra.
  Qed.

  Lemma bin_not_empty : forall l e (s1 s2 : Set_ elt),
      ~ Equal_set (Bin l e s1 s2) Tip.
  Proof.
    intros. rewrite /Equal_set=>Heq.
    specialize (Heq e). destruct Heq.
    move: H. rewrite {1}/In_set /member /=.
    have Heq: E.eq e e by done.
    apply elt_compare_eq in Heq. rewrite Heq=>Hcontra.
    specialize (Hcontra Logic.eq_refl). inversion Hcontra.
  Qed.

  Definition eq_set : Set_ elt -> Set_ elt -> Prop := Equal_set.
  Definition eq : t -> t -> Prop := Equal.
  Definition eq_dec : forall s s' : t, {eq s s'} + {~ eq s s'}.
    destruct s as [s]; destruct s' as [s']; simpl.
    destruct (s == s') eqn:Heq; move: Heq;
      rewrite /_GHC.Base.==_ /Eq___Set_; simpl;
        rewrite /Base.Eq___Set__op_zeze__;
        rewrite /_GHC.Base.==_ /Eq_Integer___ /Eq_list; simpl;
          case: andP=>//.
    - elim; intros; left.
      rewrite /eq /Equal; intros. admit.
      (* TODO: need lemmas on [toAscList] *)
  Admitted.

  Lemma eq_set_refl : forall s, eq_set s s.
  Proof. intros; constructor; auto. Qed.

  Lemma eq_refl : forall s : t, eq s s.
  Proof. destruct s. simpl. apply eq_set_refl. Qed.

  Lemma eq_set_sym : forall s s', eq_set s s' -> eq_set s' s.
  Proof. rewrite /eq_set /Equal_set; symmetry; auto. Qed.

  Lemma eq_sym : forall s s' : t, eq s s' -> eq s' s.
  Proof. destruct s; destruct s'; simpl. apply eq_set_sym. Qed.

  Lemma eq_set_trans :
    forall s s' s'', eq_set s s' -> eq_set s' s'' -> eq_set s s''.
  Proof.
    rewrite /eq_set /Equal_set; intros s s' s'' H1 H2 a.
    apply (iff_trans (H1 a) (H2 a)).
  Qed.

  Lemma eq_trans :
    forall s s' s'' : t, eq s s' -> eq s' s'' -> eq s s''.
  Proof.
    destruct s; destruct s'; destruct s''; simpl. apply eq_set_trans.
  Qed.

  Lemma bin_compat : forall l e,
      forall x x', eq_set x x' ->
              forall y y', eq_set y y' ->
                      eq_set (Bin l e x y) (Bin l e x' y').
  Proof.
    induction x.
    - intros. destruct x'.
      + rewrite /eq_set /Equal_set /In_set /member //=.
        intros. repeat destruct_match; split=>//; admit.
      + apply bin_not_empty in H. inversion H.
    - intros. admit.
  Admitted.

  Add Parametric Relation : (Set_ elt) @eq_set
      reflexivity proved by (eq_set_refl)
      symmetry proved by (eq_set_sym)
      transitivity proved by (eq_set_trans)
        as eq_set_rel.

  Add Parametric Morphism l e : (Bin l e) with
        signature eq_set ==> eq_set ==> eq_set as union_mor.
  Proof. exact (bin_compat l e). Qed.

  Lemma balanced_children : forall {a} (s1 s2 : Set_ a) l e,
      balanced (Bin l e s1 s2) -> balanced s1 /\ balanced s2.
  Proof. split; simpl in H; move: H; case: and3P=>//; elim; done. Qed.

  Lemma balanced_size_constraints : forall (s1 s2 : Set_ elt) e l,
      balanced (Bin l e s1 s2) ->
      size s1 + size s2 <= 1 \/
      (size s1 <= delta * size s2 /\ size s2 <= delta * size s1).
  Proof.
    move=>s1 s2 e l. rewrite /balanced.
    case and3P=>//; elim; rewrite_Int.
    case orP=>//; elim;
      [rewrite /is_true !Z.leb_le; left; auto |
       case andP=>//; elim; rewrite /is_true !Z.leb_le;
       right; split; auto].
  Qed.

  Ltac derive_ordering :=
    match goal with
    | [H: context[ordered _] |- _ ] =>
      move: H; rewrite /ordered=>H
    end;
    repeat match goal with
           | [ H: context[andb _ (andb _ (andb _ _))] |- _ ] =>
             let Hlo := fresh "Hlo" in
             let Hhi := fresh "Hhi" in
             let Hboundl := fresh "Hboundl" in
             let Hboundh := fresh "Hboundh" in
             move: H; case /and4P=>// =>Hlo Hhi Hbouldl Hboundh
           end.

  Ltac step_in_ordered :=
    apply /and4P=>//; split=>//; try solve [derive_ordering].

  Definition partial_lt {a} `{Ord a} (x : a) : a -> bool :=
    (fun arg => arg GHC.Base.< x).
  Definition partial_gt {a} `{Ord a} (x : a) : a -> bool :=
    (fun arg => arg GHC.Base.> x).

  Lemma partial_lt_mono : forall x y z,
      E.lt y x \/ E.eq x y ->
      partial_lt z x -> partial_lt z y.
  Proof.
    move=>x y z [Hlt | Heq]; rewrite /partial_lt;
           autorewrite with elt_compare; intros; eauto.
    apply E.eq_sym in Heq; eauto.
  Qed.

  Lemma partial_lt_relax : forall x y z,
      E.lt x y \/ E.eq x y ->
      partial_lt x z -> partial_lt y z.
  Proof.
    move=>x y z [Hlt | Heq]; rewrite /partial_lt;
           autorewrite with elt_compare; intros; eauto.
  Qed.

  Lemma partial_gt_mono : forall x y z,
      E.lt x y \/ E.eq x y ->
      partial_gt z x -> partial_gt z y.
  Proof.
    move=>x y z [Hlt | Heq]; rewrite /partial_gt;
           autorewrite with elt_compare; intros; eauto.
  Qed.

  Lemma partial_gt_relax : forall x y z,
      E.lt y x \/ E.eq x y ->
      partial_gt x z -> partial_gt y z.
  Proof.
    move=>x y z [Hlt | Heq]; rewrite /partial_gt;
           autorewrite with elt_compare; intros; eauto.
    apply E.eq_sym in Heq; eauto.
  Qed.

  Definition local_bounded {a} `{Ord a} :=
    fix bounded lo hi t'
      := match t' with
         | Tip => true
         | Bin _ x l r => andb (lo x)
                              (andb (hi x)
                                    (andb
                                       (bounded lo (partial_lt x) l)
                                       (bounded (partial_gt x) hi r)))
         end.

  Ltac solve_local_bounded :=
    repeat match goal with
           | [H: is_true (local_bounded _ _ _) |- _ ] =>
             move: H; rewrite /local_bounded=>?
           | [ H: is_true (andb _ (andb _ (andb _ _))) |- _ ] =>
             let Hlo := fresh "Hlo" in
             let Hhi := fresh "Hhi" in
             let Hboundl := fresh "Hboundl" in
             let Hboundh := fresh "Hboundh" in
             move: H; case /and4P=>//; move=>Hlo Hhi Hboundl Hboundh
           | [ |- is_true (andb _ (andb _ (andb _ _))) ] =>
             apply /and4P=>//; split=>//
           | [H: context[partial_lt _ _] |- _ ] =>
             move: H; rewrite /partial_lt; move=>H
           | [H: context[partial_gt _ _] |- _ ] =>
             move: H; rewrite /partial_gt; move=>H
           end; autorewrite with elt_compare in *; eauto.

  Lemma local_bounded_left_relax : forall {a} `{Ord a} (f g f' : a -> bool) s,
      (forall x, f x -> f' x) ->
      local_bounded f g s ->
      local_bounded f' g s.
  Proof.
    move=>a Heq Hord f g f' s. move: f g f'.
    induction s=>//; intros; solve_local_bounded.
  Qed.

  Lemma local_bounded_right_relax : forall {a} `{Ord a} (f g g' : a -> bool) s,
      (forall x, g x -> g' x) ->
      local_bounded f g s ->
      local_bounded f g' s.
  Proof.
    move=>a Heq Hord f g g' s. move: f g g'.
    induction s=>//; intros; solve_local_bounded.
  Qed.

  Lemma bounded_impl_left_const_true : forall {a} `{GHC.Base.Ord a} f g s,
      local_bounded f g s -> local_bounded (const true) g s.
  Proof.
    intros. apply local_bounded_left_relax with (f0:=f); auto.
  Qed.

  Lemma bounded_impl_right_const_true : forall {a} `{Ord a} f g s,
      local_bounded f g s -> local_bounded f (const true) s.
  Proof.
    intros. apply local_bounded_right_relax with (g0:=g); auto.
  Qed.

  Lemma local_bounded_constr : forall {a} `{Ord a} (f g : a -> bool) x l r,
      f x ->
      g x ->
      local_bounded f (fun arg_0__ => arg_0__ GHC.Base.< x) l ->
      local_bounded (fun arg_1__ => arg_1__ GHC.Base.> x) g r ->
      local_bounded f g (Bin 0 x l r).
  Proof.
    intros. rewrite /local_bounded.
    apply /and4P=>//; split=>//.
  Qed.

  Lemma local_bounded_size_irrelevance :
    forall {a} `{Ord a} (f g : a -> bool) s1 s2 x l r,
      local_bounded f g (Bin s1 x l r) ->
      local_bounded f g (Bin s2 x l r).
  Proof. auto. Qed.

  Lemma ordered_children : forall {a} `{Ord a} (s1 s2 : Set_ a) l e,
      ordered (Bin l e s1 s2) -> ordered s1 /\ ordered s2.
  Proof.
    split; unfold ordered in *; move: H1; case: and4P=>//; elim; intros.
    - eapply (@bounded_impl_right_const_true a H H0). apply H3.
    - eapply (@bounded_impl_left_const_true a H H0). apply H4.
  Qed.

  Lemma ordered_rewrite : forall (s1 s2: Set_ elt) l e1 e2,
      E.eq e1 e2 -> ordered (Bin l e1 s1 s2) -> ordered (Bin l e2 s1 s2).
  Proof.
    move=>s1 s2 l e1 e2 Heq. rewrite /ordered -/local_bounded.
    case /and4P=>//; intros. apply /and4P=>//; split=>//.
    - apply local_bounded_right_relax
        with (g:=fun arg_0__ : E.t => _GHC.Base.<_ arg_0__ e1); auto.
      move=>x. autorewrite with elt_compare. move=>Hlt. eauto.
    - apply local_bounded_left_relax
        with (f:=fun arg_1__ : E.t => _GHC.Base.>_ arg_1__ e1); auto.
      move=>x. autorewrite with elt_compare. move=>Hlt.
      apply E.eq_sym in Heq. eauto.
  Qed.

  Definition local_realsize {a} :=
    fix realsize (t' : Set_ a) : option Size :=
      match t' with
      | Bin sz _ l r =>
        match realsize l with
        | Some n =>
          match realsize r with
          | Some m =>
            if _GHC.Base.==_ (n + m + 1)%Z sz
            then Some sz
            else None
          | None => None
          end
        | None => None
        end
      | Tip => Some 0%Z
      end.

  Lemma validsize_children : forall {a} (s1 s2 : Set_ a) l e,
      validsize (Bin l e s1 s2) -> validsize s1 /\ validsize s2.
  Proof.
    intros; move: H; rewrite /validsize=>H;
      move: H; rewrite -/local_realsize.
    split; generalize dependent e; generalize dependent l.
    - generalize dependent s2.
      destruct s1; intros.
      + move: H. rewrite /local_realsize /= -/local_realsize.
        repeat destruct_match. intros.
        apply Maybe_eq_is_Option_eq=>//.
      + rewrite /local_realsize /=. apply Maybe_eq_is_Option_eq=>//.
    - generalize dependent s1.
      destruct s2; intros.
      + move: H. rewrite /local_realsize /= -/local_realsize.
        repeat destruct_match.
        intros. apply Maybe_eq_is_Option_eq=>//.
      + rewrite /local_realsize /=. apply Maybe_eq_is_Option_eq=>//.
  Qed.

  Lemma WF_children : forall s1 s2 l e, WF (Bin l e s1 s2) -> WF s1 /\ WF s2.
  Proof.
    rewrite /WF /valid. move=>s1 s2 l e. case: and3P=>//.
    elim; move=>Hb Ho Hv H; clear H.
    split; apply /and3P; split;
      apply balanced_children in Hb;
      apply ordered_children in Ho;
      apply validsize_children in Hv; intuition.
  Qed.

  Lemma WF_size_children : forall s1 s2 l e,
      WF (Bin l e s1 s2) -> size s1 + size s2 + 1 = l.
  Proof.
    rewrite /WF /valid. move=>s1 s2 l e.
    case: and3P=>//. elim; move=>Hb Ho Hv H; clear H.
    apply validsize_children in Hv as Hv2. destruct Hv2.
    move: H0 H Hv. rewrite /validsize -/local_realsize.
    destruct s1; destruct s2=>//;
      try solve [repeat destruct_match; move: Heq1;
                 rewrite_size; rewrite_Int; move /Z.eqb_eq=>?;
                 repeat (move /Maybe_eq_is_Option_eq; (case=>? || elim));
                 subst; auto].
    simpl; do 2 elim. destruct_match.
    elim. move: Heq. move /Z.eqb_eq; auto.
  Qed.

  Lemma WF_size_nonneg : forall s, WF s -> size s >= 0.
  Proof.
    induction s; intros.
    - apply WF_size_children in H as H2.
      apply WF_children in H. destruct H.
      rewrite /size. subst. apply IHs1 in H. apply IHs2 in H0. omega.
    - simpl; omega.
  Qed.

  Lemma WF_size_pos : forall s1 s2 e l,
      WF (Bin l e s1 s2) -> size (Bin l e s1 s2) >= 1.
  Proof.
    intros. have: WF (Bin l e s1 s2) by done.
    apply WF_children in H; destruct H.
    move=>Hwf. apply WF_size_children in Hwf.
    rewrite /size -Hwf.
    apply WF_size_nonneg in H; apply WF_size_nonneg in H0.
    omega.
  Qed.

  Lemma WF_balanced : forall t,
      WF t -> balanced t.
  Proof. move=>t; rewrite /WF /valid; case /and3P=>//. Qed.

  Lemma WF_ordered : forall t,
      WF t -> ordered t.
  Proof. move=>t; rewrite /WF /valid; case /and3P=>//. Qed.

  Lemma WF_validsize : forall t,
      WF t -> validsize t.
  Proof. move=>t; rewrite /WF /valid; case /and3P=>//. Qed.

  Lemma WF_singleton : forall e, WF (singleton e).
  Proof. intros. rewrite /WF /valid. apply /and3P=>//. Qed.

  Ltac prepare_for_omega :=
    repeat match goal with
           | [H: context[_ <? _] |- _ ] => move: H
           | [H: context[_ <=? _] |- _ ] => move: H
           | [H: _ < _ |- _ ] => move: H
           | [H: _ <= _ |- _ ] => move: H
           | [H: _ > _ |- _ ] => move: H
           | [H: _ >= _ |- _ ] => move: H
           | [H: context[_ =? _] |- _ ] => move: H
           end; rewrite_size; rewrite_Int;
    rewrite /is_true ?Z.ltb_lt ?Z.ltb_ge ?Z.leb_le ?Z.leb_gt ?Z.eqb_eq.

  Ltac rewrite_for_omega :=
    repeat match goal with
           | [H: context[delta] |- _ ] => move: H
           | [H: context[ratio] |- _ ] => move: H
           end; rewrite /delta /ratio; prepare_for_omega.

  Ltac derive_constraints :=
    repeat match goal with
           | [Hwf: is_true (WF (Bin ?s ?x ?a ?b)) |- _ ] =>
             let Hsum := fresh "Hsum" in
             have: WF (Bin s x a b) by [done];
             move /WF_size_children; rewrite_size;
             move=>Hsum;
             let Hpos := fresh "Hpos" in
             have: WF (Bin s x a b) by [done];
             move /WF_size_pos; rewrite_size; move=>Hpos;
             let Hwfc := fresh "Hwfc" in
             let Hwfl := fresh "Hwfl" in
             let Hwfr := fresh "Hwfr" in
             have Hwfc : WF a /\ WF b by
                 [move: Hwf; move /WF_children];
             destruct Hwfc as [Hwfl Hwfr];
             let Hbalanced := fresh "Hbalanced" in
             have Hbalanced: (size a + size b <= 1) \/
                             (size a <= delta * size b /\
                              size b <= delta * size a) by
                 [ move: Hwf; move /WF_balanced /balanced_size_constraints];
             let Hvs := fresh "Hvs" in
             have Hvs: validsize (Bin s x a b) by
                 [apply WF_validsize in Hwf];
             let Hbl := fresh "Hbl" in
             have Hbl: balanced (Bin s x a b) by
                 [apply WF_balanced in Hwf];
             clear Hwf
           | [Hwf: is_true (WF ?t) |- _ ] =>
             let Hnonneg := fresh "Hnonneg" in
             have: WF t by [done];
             move /WF_size_nonneg; move=>Hnonneg;
             let Hvs := fresh "Hvs" in
             have Hvs: validsize t by
                 [apply WF_validsize in Hwf];
             clear Hwf
           | [H: is_true (validsize (Bin ?s ?x ?l ?r)) |- _ ] =>
             let Hrs := fresh "Hrealsize" in
             have: validsize (Bin s x l r) by [done];
             apply validsize_children in H; destruct H;
             rewrite /validsize -/local_realsize;
             move=>Hrs; apply Maybe_eq_is_Option_eq in Hrs;
                  rewrite ?Hrs
           | [H: is_true (validsize ?t) |- _ ] =>
             let Hrs := fresh "Hrealsize" in
             move: H; rewrite /validsize -/local_realsize;
             move=>Hrs; apply Maybe_eq_is_Option_eq in Hrs;
                  rewrite ?Hrs
           end.

  Ltac lucky_balanced_solve :=
    derive_constraints; subst; rewrite_for_omega; intros; omega.

  Ltac solve_balanced_trivial :=
    solve [auto; repeat (match goal with
                         | [H: is_true (WF (Bin _ _ _ _)) |- _] =>
                           apply WF_balanced in H;
                           apply balanced_children in H;
                           destruct H
                         end; auto)].

  Ltac step_in_balanced :=
    rewrite /balanced; apply /and3P=>//; split=>//;
      try solve_balanced_trivial.

  Ltac solve_balanced :=
    repeat match goal with
           | [ |- is_true (balanced _)] =>
             step_in_balanced
           | [ |- is_true (andb _ (andb _ _))] =>
             step_in_balanced
           | [ |- is_true (orb _ (andb _ _)) ] =>
             apply /orP=>//;
                   ((right; apply /andP=>//) + left);
                    solve [derive_constraints; subst;
                           rewrite_for_omega; intros; omega]
           end;
    try solve [derive_constraints; subst;
           repeat match goal with
                  | [ H: is_true (balanced _) |- _ ] =>
                    move: H; rewrite /balanced;
                    case /and3P=>//; move=>? ? ?
                  end].

  Lemma balanceL_add_size : forall (x : elt) (l r : Set_ elt),
      WF l -> WF r ->
      size (balanceL x l r) = size l + size r + 1.
  Proof.
    destruct r as [sr xr rl rr | ];
      destruct l as [sl xl ll lr | ].
    - rewrite /balanceL; destruct_match.
      + destruct ll as [sll xll lll llr | ];
          destruct lr as [slr xlr lrl lrr | ];
          try solve [intros; derive_constraints; subst;
                     rewrite_for_omega; intros; omega].
        destruct_match; intros;
          rewrite_size; rewrite_Int; (* why can't [omega] solve it? *)
            rewrite -Z.add_assoc [1 + _]Z.add_comm //.
      + intros. rewrite_size; rewrite_Int.
        rewrite -Z.add_assoc [1 + _]Z.add_comm //.
    - intros. rewrite_size; rewrite_Int.
      rewrite Z.add_0_l Z.add_comm //.
    - rewrite /balanceL;
        destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ].
      + destruct_match; intros; rewrite_size; rewrite_Int;
          rewrite -Z.add_assoc Z.add_0_l Z.add_comm //.
      + intros. derive_constraints; subst.
        destruct Hbalanced; rewrite_for_omega.
        * intros. have Hs: (size lll + size llr = 0) by omega. rewrite Hs //.
        * intros. omega.
      + intros. derive_constraints; subst.
        destruct Hbalanced; rewrite_for_omega.
        * intros. have Hs: (size lrl + size lrr = 0) by omega. rewrite Hs //.
        * intros. omega.
      + intros; derive_constraints. move: Hsum.
        rewrite_for_omega. intros. rewrite -Hsum. reflexivity.
    - rewrite_size. do 2 elim. rewrite_Int. reflexivity.
  Qed.

  Lemma balanceR_add_size : forall (x : elt) (l r : Set_ elt),
      WF l -> WF r ->
      size (balanceR x l r) = size l + size r + 1.
  Proof.
    destruct l as [sl xl ll lr | ];
      destruct r as [sr xr rl rr | ].
    - rewrite /balanceR; destruct_match.
      + destruct rl as [srl xrl rll rlr | ];
          destruct rr as [srr xrr rrl rrr | ];
          try solve [intros; derive_constraints; subst;
                     rewrite_for_omega; intros; omega].
        destruct_match; intros;
          rewrite_size; rewrite_Int; (* why can't [omega] solve it? *)
            rewrite -Z.add_assoc [1 + _]Z.add_comm //.
      + intros. rewrite_size; rewrite_Int.
        rewrite -Z.add_assoc [1 + _]Z.add_comm //.
    - intros. rewrite_size; rewrite_Int.
      rewrite Z.add_0_r Z.add_comm //.
    - rewrite /balanceR;
        destruct rl as [srl xrl rll rlr | ];
        destruct rr as [srr xrr rrl rrr | ].
      + destruct_match; intros; rewrite_size; rewrite_Int;
          rewrite -Z.add_assoc Z.add_0_l Z.add_comm //.
      + intros. derive_constraints; subst.
        destruct Hbalanced; rewrite_for_omega.
        * intros. have Hs: (size rll + size rlr = 0) by omega. rewrite Hs //.
        * intros. omega.
      + intros. derive_constraints; subst.
        destruct Hbalanced; rewrite_for_omega.
        * intros. have Hs: (size rrl + size rrr = 0) by omega. rewrite Hs //.
        * intros. omega.
      + intros; derive_constraints. move: Hsum.
        rewrite_for_omega. intros. rewrite -Hsum. reflexivity.
    - rewrite_size. do 2 elim. rewrite_Int. reflexivity.
  Qed.

  (** The balancing condition is that [ls <= delta*rs] and [rs <=
      delta*ls].  The moment that balancing is broken because of
      insertion/deletion of one single element, we know exactly one
      constraint will be broken. [belanceL] is called when the left
      child is bigger, so we know what happened is that now [ls =
      delta * rs + 1].

      To prove ordering, here should be another constraint, that [x]
      is greater than any value in [l], and smaller than any value in
      [r]. *)
  Definition before_balancedL (x: elt) (l r : Set_ elt) : Prop :=
    (size l + size r <= 2 /\ size r <= 1) \/
    (size l <= delta * size r + 1 /\ size r <= delta * size l).

  Lemma balanceL_balanced: forall (x: elt) (l r : Set_ elt),
      WF l -> WF r ->
      before_balancedL x l r -> balanced (balanceL x l r).
  Proof.
    intros x l r Hwfl Hwfr.
    destruct r as [sr xr rl rr | ]; destruct l as [sl xl ll lr | ];
      rewrite /before_balancedL /balanceL; rewrite_Int; move=>Hbefore.
    - (** [l] and [r] are both [Bin]s. *)
      destruct_match.
      + (** The [ls > delta*rs] branch in Haskell code. *)
        destruct ll as [sll xll lll llr | ];
          destruct lr as [slr xlr lrl lrr | ]; rewrite_Int;
            try solve [lucky_balanced_solve].
        * (** [ll] and [lr] are both Bins *)
          destruct_match; solve_balanced.
          -- (** [Bin (1+lls+size lrl) lx ll lrl] is balanced. *)
            destruct lrl; solve_balanced.
          -- (** [Bin (1+rs+size lrr) x lrr r] is balanced. *)
            destruct lrr; solve_balanced.
      + (** The [otherwise] branch, i.e. [ls <= delta*rs]. *)
        solve_balanced.
    - (** [l] is [Tip] *)
      destruct rl; destruct rr; solve_balanced.
    - (** [r] is [Tip] *)
      destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ];
        solve_balanced.
      (** [ll] is [Bin sll xll lll llr] *)
      destruct_match; solve_balanced.
    - (** Both [l] and [r] and [Tip]s. *)
      step_in_balanced.
      Time Qed. (* Finished transaction in 24.677 secs (24.357u,0.303s) (successful) *)

    Definition before_balancedR (x: elt) (l r : Set_ elt) : Prop :=
    (size l + size r <= 2 /\ size l <= 1) \/
    (size r <= delta * size l + 1 /\ size l <= delta * size r).

  Lemma balanceR_balanced: forall (x: elt) (l r : Set_ elt),
      WF l -> WF r ->
      before_balancedR x l r -> balanced (balanceR x l r).
  Proof.
    intros x l r Hwfl Hwfr.
    destruct l as [sl xl ll lr | ]; destruct r as [sr xr rl rr | ];
      rewrite /before_balancedR /balanceR; rewrite_Int; move=>Hbefore.
    - (** [l] and [r] are both [Bin]s. *)
      destruct_match.
      + (** The [rs > delta*ls] branch in Haskell code. *)
        destruct rl as [srl xrl rll rlr | ];
          destruct rr as [srr xrr rrl rrr | ]; rewrite_Int;
            try solve [lucky_balanced_solve].
        * (** [rl] and [rr] are both Bins *)
          destruct_match; solve_balanced.
          -- (** [Bin (1+ls+size rll) x l rll] is balanced. *)
            destruct rll; solve_balanced.
          -- (** [Bin (1+rrs+size rlr) rx rlr rr] is balanced. *)
            destruct rlr; solve_balanced.
      + (** The [otherwise] branch, i.e. [ls <= delta*rs]. *)
        solve_balanced.
    - (** [r] is [Tip] *)
      destruct ll; destruct lr; solve_balanced.
    - (** [l] is [Tip] *)
        destruct rl as [srl xrl rll rlr | ];
          destruct rr as [srr xrr rrl rrr | ];
          solve_balanced.
      (** [rr] is [Bin srr xrr rrl rrr] *)
      destruct_match; solve_balanced.
    - (** Both [l] and [r] and [Tip]s. *)
      step_in_balanced.
      Time Qed. (* Finished transaction in 28.41 secs (28.006u,0.287s) (successful) *)

  Definition before_ordered (x : elt) (l r : Set_ elt) (f g : elt -> bool) :=
    f x /\ (forall x y, E.lt x y \/ E.eq x y -> f x -> f y) /\
    g x /\ (forall x y, E.lt y x \/ E.eq x y -> g x -> g y) /\
    local_bounded f (fun arg_1__ => arg_1__ GHC.Base.< x) l /\
    local_bounded (fun arg_0__ => arg_0__ GHC.Base.> x) g r.

  Lemma size_irrelevance_in_ordered : forall s1 s2 x (l r : Set_ elt),
      ordered (Bin s1 x l r) -> ordered (Bin s2 x l r).
  Proof. move=>s1 s2 x l r. rewrite /ordered; auto. Qed.

  Lemma balanceL_ordered : forall (x: elt) (l r : Set_ elt) f g,
      (** We need [before_balancedL] as preconditions to eliminate the
          impossible cases. *)
      WF l ->
      WF r ->
      before_balancedL x l r ->
      before_ordered x l r f g ->
      local_bounded f g (balanceL x l r).
  Proof.
    move=>x l r f g Hwfl Hwfr.
    destruct r as [sr xr rl rr | ]; destruct l as [sl xl ll lr | ];
      rewrite /before_ordered /balanceL; rewrite_Int;
        move=>Hbefore_balance Hbefore_ordered;
               destruct Hbefore_ordered as [? [? [? [? [? ?]]]]];
               try solve [solve_local_bounded].
    - (** Both [r] and [l] are [Bin]s *)
      destruct_match; try solve [solve_local_bounded].
      destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ];
        try solve [lucky_balanced_solve].
      destruct_match; rewrite_Int; solve_local_bounded.
    - (** [r] is a [Tip] *)
      destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ];
        try solve [solve_local_bounded].
      destruct_match; solve_local_bounded.
  Qed.

  Lemma balanceR_ordered : forall (x: elt) (l r : Set_ elt) f g,
      WF l ->
      WF r ->
      before_balancedR x l r ->
      before_ordered x l r f g ->
      local_bounded f g (balanceR x l r).
  Proof.
    move=>x l r f g Hwfl Hwfr.
    destruct l as [sl xl ll lr | ]; destruct r as [sr xr rl rr | ];
      rewrite /before_ordered /balanceR; rewrite_Int;
        move=>Hbefore_balance Hbefore_ordered;
               destruct Hbefore_ordered as [? [? [? [? [? ?]]]]];
               try solve [solve_local_bounded].
    - (** Both [r] and [l] are [Bin]s *)
      destruct_match; try solve [solve_local_bounded].
        destruct rl as [srl xrl rll rlr | ];
          destruct rr as [srr xrr rrl rrr | ];
          try solve [lucky_balanced_solve].
      destruct_match; rewrite_Int; solve_local_bounded.
    - (** [l] is a [Tip] *)
      destruct rl as [srl xrl rll rlr | ];
        destruct rr as [srr xrr rrl rrr | ];
        try solve [solve_local_bounded].
      destruct_match; solve_local_bounded.
  Qed.

  Ltac solve_realsize :=
    apply Maybe_eq_is_Option_eq;
    rewrite /local_realsize;
    derive_constraints; rewrite_size; rewrite_Int;
    repeat match goal with
           | [ |- context[if ?c then _ else _] ] =>
             let Heq := fresh "Heq" in
             have Heq: c by [ rewrite_for_omega; omega];
             rewrite Heq=>//
           end.

  Lemma balanceL_validsize: forall (x: elt) (l r : Set_ elt),
      WF l -> WF r ->
      before_balancedL x l r -> validsize (balanceL x l r).
  Proof.
    move=>x l r Hwfl Hwfr.
    rewrite /validsize -/local_realsize.
    destruct r as [sr xr rl rr | ]; destruct l as [sl xl ll lr | ];
      rewrite /before_balancedL /balanceL; intros; try solve [solve_realsize].
    - rewrite_Int. destruct_match; try solve [solve_realsize].
      destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ];
        try solve [lucky_balanced_solve].
      destruct_match; solve_realsize.
    - destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ];
        try solve [lucky_balanced_solve || solve_realsize].
  Qed.

  Lemma balanceR_validsize: forall (x: elt) (l r : Set_ elt),
      WF l -> WF r ->
      before_balancedR x l r -> validsize (balanceR x l r).
  Proof.
    move=>x l r Hwfl Hwfr.
    rewrite /validsize -/local_realsize.
    destruct l as [sl xl ll lr | ]; destruct r as [sr xr rl rr | ];
      rewrite /before_ordered /balanceR; intros; try solve [solve_realsize].
    - rewrite_Int. destruct_match; try solve [solve_realsize].
      destruct rl as [srl xrl rll rlr | ];
        destruct rr as [srr xrr rrl rrr | ];
        try solve [lucky_balanced_solve].
      destruct_match; solve_realsize.
    - destruct rl as [srl xrl rll rlr | ];
        destruct rr as [srr xrr rrl rrr | ];
        try solve [lucky_balanced_solve || solve_realsize].
      destruct_match; solve_realsize.
  Qed.

  Lemma balanceL_WF: forall (x: elt) (l r : Set_ elt),
      WF l -> WF r ->
      before_balancedL x l r ->
      before_ordered x l r (const true) (const true) ->
      WF (balanceL x l r).
  Proof with auto.
    intros. rewrite /WF /valid.
    apply /and3P=>//; split.
    - apply balanceL_balanced...
    - apply balanceL_ordered...
    - apply balanceL_validsize...
  Qed.

  Lemma balanceR_WF: forall (x: elt) (l r : Set_ elt),
      WF l -> WF r ->
      before_balancedR x l r ->
      before_ordered x l r (const true) (const true) ->
      WF (balanceR x l r).
  Proof with auto.
    intros. rewrite /WF /valid.
    apply /and3P=>//; split.
    - apply balanceR_balanced...
    - apply balanceR_ordered...
    - apply balanceR_validsize...
  Qed.

  Ltac derive_compare :=
    repeat match goal with
           | [H: is_true
                   (andb _ (andb _ (andb (local_bounded _ _ _)
                                         (local_bounded _ _ _)))) |- _] =>
             let Hc1 := fresh "Hcomp" in
             let Hc2 := fresh "Hcomp" in
             let Hl1 := fresh "Hlb" in
             let Hl2 := fresh "Hlb" in
             move: H; case /and4P=>//;
             rewrite -/local_bounded /partial_gt /partial_lt;
             move=> Hc1 Hc2 Hl1 Hl2
           | [H: is_true (local_bounded _ _ _) |- _ ] =>
             let Hc1 := fresh "Hcomp" in
             let Hc2 := fresh "Hcomp" in
             let Hl1 := fresh "Hlb" in
             let Hl2 := fresh "Hlb" in
             move: H; rewrite /local_bounded;
             case /and4P=>//;
             rewrite -/local_bounded /partial_gt /partial_lt;
             move=> Hc1 Hc2 Hl1 Hl2
            end; autorewrite with elt_compare in *.

  Lemma inset_balanceL : forall (x y : elt) (l r : Set_ elt),
      WF l ->
      WF r ->
      before_balancedL x l r ->
      before_ordered x l r (const true) (const true) ->
      E.eq x y \/ (E.lt y x /\ In_set y l) \/ (E.lt x y /\ In_set y r) ->
      In_set y (balanceL x l r).
  Proof.
    (** The proof is very very tedious. There must be a better way! *)
    destruct r as [sr xr rl rr | ];
      destruct l as [sl xl ll lr | ].
    - rewrite /before_balancedL.
      rewrite /balanceL; destruct_match.
      + destruct ll as [sll xll lll llr | ];
          destruct lr as [slr xlr lrl lrr | ];
          try solve [intros; lucky_balanced_solve].
        move=>Hwfl Hwfr Hbeforeb Hbefore [Hxy | [Hinl | Hinr]];
               move: Hbefore; rewrite /before_ordered;
                 move=>H; destruct H as [_ [_ [_ [_ [? ?]]]]];
                        derive_compare.
        * destruct_match.
          -- rewrite /In_set /member /=.
             have Hgt: E.lt xl y by [eauto].
             apply elt_compare_gt in Hgt. rewrite Hgt.
             apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy.
             rewrite Hxy //.
          -- rewrite /In_set /member /=.
             have Hgt: E.lt xlr y by [eauto].
             apply elt_compare_gt in Hgt. rewrite Hgt.
             apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy.
             rewrite Hxy //.
        * destruct_match.
          -- move: Hinl. rewrite /In_set /member /= -!/member //=.
             elim. move=>Hlt.
             do 2 destruct_match; intros;
               apply elt_compare_lt in Hlt; rewrite Hlt //.               
          -- move: Hinl. rewrite /In_set /member /= -!/member //=.
             elim. move=>Hlt.
             apply elt_compare_lt in Hlt. rewrite Hlt //.
             destruct_match.
             ++ autorewrite with elt_compare in *.
                have Hlt': E.lt y xlr by [eauto].
                apply elt_compare_lt in Hlt'. rewrite Hlt' //.
             ++ autorewrite with elt_compare in *.
                have Hlt': E.lt y xlr by [eauto].
                apply elt_compare_lt in Hlt'. rewrite Hlt' //.
        * destruct_match.
          -- move: Hinr. rewrite /In_set /member /= -!/member //=.
             elim. move=>Hlt.
             have Hgt: E.lt xl y by [eauto].
             apply elt_compare_gt in Hgt; rewrite Hgt //.
             apply elt_compare_gt in Hlt; rewrite Hlt //.
          -- move: Hinr. rewrite /In_set /member /= -!/member //=.
             elim. move=>Hlt.
             have Hgt: E.lt xl y by [eauto].
             have Hgt': E.lt xlr y by [eauto].
             apply elt_compare_gt in Hgt; rewrite Hgt //.
             apply elt_compare_gt in Hlt; rewrite Hlt //.
             apply elt_compare_gt in Hgt'; rewrite Hgt' //.
      + move=>Hwfl Hwfr Hbeforeb Hbefore [Hxy | [Hinl | Hinr]].
        * rewrite /In_set /member // -/member /=.
          apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy.
          rewrite Hxy //.
        * move: Hinl. rewrite /In_set /member /= -!/member //=.
          elim. move=>Hlt.
          apply elt_compare_lt in Hlt. rewrite Hlt //.
        * move: Hinr. rewrite /In_set /member /= -!/member //=.
          elim. move=>Hlt.
          apply elt_compare_gt in Hlt. rewrite Hlt //.
    - move=>Hwfl Hwfr Hbeforeb Hbefore [Hxy | [Hinl | Hinr]].
      + move: Hbefore. rewrite /before_ordered.
        move => [_ [_ [_ [_ [? ?]]]]]. derive_compare.
        rewrite /balanceL /In_set /member /= -!/member //=.
        apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy. rewrite Hxy //.
      + move: Hinl. elim. rewrite /In_set /member //.
      + move: Hinr. elim. rewrite /In_set /member /= -!/member.
        move=>Hgt. apply elt_compare_gt in Hgt. rewrite Hgt //.
    - destruct ll as [sll xll lll llr | ];
        destruct lr as [slr xlr lrl lrr | ];
        move=>Hwfl Hwfr Hbeforeb; rewrite /before_ordered;
        move=>[_ [_ [_ [_ [? ?]]]]]; derive_compare.
      + move=>[Hxy | [Hinl | Hinr]]; rewrite /balanceL.
        * destruct_match.
          -- rewrite /In_set /member /= -!/member /=.
             have Hgt: E.lt xl y by [eauto].
             apply elt_compare_gt in Hgt. rewrite Hgt //.
             apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy. rewrite Hxy //.
          -- rewrite /In_set /member /= -!/member /=.
             have Hgt: E.lt xlr y by [eauto].
             apply elt_compare_gt in Hgt. rewrite Hgt //.
             apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy. rewrite Hxy //.
        * destruct_match.
          -- move: Hinl. elim. move=>Hlt. 
             rewrite /In_set /member /= -!/member /=.
             apply elt_compare_lt in Hlt. rewrite Hlt //.
          -- move: Hinl. elim. move=>Hlt.
             rewrite /In_set /member /= -!/member /=.
             apply elt_compare_lt in Hlt. rewrite Hlt //.
             destruct_match; autorewrite with elt_compare in *;
               have Hlt': E.lt y xlr by [eauto];
               apply elt_compare_lt in Hlt'; rewrite Hlt' //.
        * move: Hinr. rewrite /In_set /member /=. elim. done.
      + move=>[Hxy | [Hinl | Hinr]]; rewrite /balanceL.
        * rewrite /In_set /member /= -!/member /=.
          have Hlt: E.lt xl y by [eauto]. apply E.eq_sym in Hxy.
          apply elt_compare_gt in Hlt. rewrite Hlt //. 
          apply elt_compare_eq in Hxy. rewrite Hxy //.
        * move: Hinl. elim. move=>Hlt.
          rewrite /In_set /member /= -!/member /=.
          apply elt_compare_lt in Hlt. rewrite Hlt //.
        * move: Hinr. rewrite /In_set /member /=. elim. done.
      + move=>[Hxy | [Hinl | Hinr]]; rewrite /balanceL.
        * rewrite /In_set /member /= -!/member /=.
          have Hlt: E.lt xlr y by [eauto]. apply E.eq_sym in Hxy.
          apply elt_compare_gt in Hlt. rewrite Hlt //. 
          apply elt_compare_eq in Hxy. rewrite Hxy //.
        * destruct lrl; destruct lrr; try solve [lucky_balanced_solve].
          move: Hinl. elim. move=>Hlt.
          rewrite /In_set /member /= -!/member /=.
          apply elt_compare_lt in Hlt. rewrite Hlt //.
          destruct_match.
          autorewrite with elt_compare in *.
          have Hlt': E.lt y xlr by [eauto].
          apply elt_compare_lt in Hlt'. rewrite Hlt' //.
        * destruct Hinr. inversion H0.
      + move=>[Hxy | [Hinl | Hinr]]; rewrite /balanceL.
        * rewrite /In_set /member /= -!/member /=.
          apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy. rewrite Hxy //.
        * move: Hinl. elim. move=>Hlt.
          rewrite /In_set /member /= -!/member /=.
          apply elt_compare_lt in Hlt. rewrite Hlt //.
        * destruct Hinr. inversion H0.
    - move=>Hwfl Hwfr Hbeforeb Hbefore [Hxy | [Hinl | Hinr]].
      + rewrite /balanceL /In_set /member /=.
        apply E.eq_sym in Hxy. apply elt_compare_eq in Hxy. rewrite Hxy //.
      + destruct Hinl. inversion H0.
      + destruct Hinr. inversion H0.
  Qed.
  
  Lemma inset_balanceR : forall (x y : elt) (l r : Set_ elt),
      WF l ->
      WF r ->
      before_balancedR x l r ->
      before_ordered x l r (const true) (const true) ->
      E.eq x y \/ (E.lt y x /\ In_set y l) \/ (E.lt x y /\ In_set y r) ->
      In_set y (balanceR x l r).
  Admitted.
  
  Definition mem : elt -> t -> bool := fun e s' =>
    s <-- s' ;; member e s.

  Ltac split3 := split; [| split].

  Ltac solve_local_bounded_with_relax :=
    solve_local_bounded; rewrite -/local_bounded;
    ((eapply local_bounded_right_relax; [| eassumption];
      intros; eapply partial_lt_relax;
      (idtac + (multimatch goal with
                | [H: E.eq _ _ |- _] => apply E.eq_sym in H
                end))) +
     (eapply local_bounded_left_relax; [| eassumption];
      intros; eapply partial_gt_relax;
      (idtac + (multimatch goal with
                | [H: E.eq _ _ |- _] => apply E.eq_sym in H
                end)))); solve [eauto].

  Lemma insert_prop : forall e s,
      WF s ->
      WF (insert e s) /\
      (size (insert e s) = size s + 1 \/ size (insert e s) = size s) /\
      (forall a,
          (forall (f : elt -> bool),
              E.lt e a -> f e ->
              (forall x y, E.lt x y \/ E.eq x y -> f x -> f y) ->
              local_bounded f (fun arg => arg GHC.Base.< a) s ->
              local_bounded f (fun arg => arg GHC.Base.< a) (insert e s)) /\
          (forall (g : elt -> bool),
              E.lt a e -> g e ->
              (forall x y, E.lt y x \/ E.eq x y -> g x -> g y) ->
              local_bounded (fun arg => arg GHC.Base.> a) g s ->
              local_bounded (fun arg => arg GHC.Base.> a) g (insert e s))).
  Proof.
    induction s.
    - intros. rewrite /insert/=. destruct_match; split3.
      + (** s is Bin, e = a, prove: WF (insert e s) *)
        apply elt_compare_eq in Heq. move: H.
        rewrite /WF /valid. case /and3P=>//; intros.
        apply /and3P=>//; split=>//. apply E.eq_sym in Heq.
        eapply ordered_rewrite; eauto.
      + (** prove [size (insert e s) = size s] *)
        right. rewrite /size=>//.
      + intros. split; intros; solve_local_bounded_with_relax.
      + (** s is Bin, e < a, prove: WF (insert e s) *)
        intros. apply balanceL_WF.
        * (** WF (insert e s2) *)
          apply WF_children in H. apply IHs1. tauto.
        * (** WF s3 *)
          apply WF_children in H. tauto.
        * (** (insert e s2) and s3 satisfy [before_balancedL]'s
              pre-condbitions. *)
          rewrite -/insert /before_balancedL.
          have Hs1: WF s2 by [apply WF_children in H; tauto].
          apply IHs1 in Hs1; destruct Hs1.
          (** cases analysis: did we insert an element to s2?  *)
          destruct H1 as [[H1 | H1] _].
          -- (** we did *)
            destruct s2; destruct s3; derive_constraints; subst;
              repeat match goal with
                     | [H: _ \/ _ |- _ ] => destruct H
                     | [H: _ /\ _ |- _ ] => destruct H
                     end; rewrite_for_omega; rewrite ?H1;
                try solve [(right + left); omega].
          -- (** we didn't *) derive_constraints; subst.
             rewrite H1. destruct Hbalanced; (left + right); omega.
        * (** prove [before_ordered] pre-conditions *)
          rewrite -/insert /before_ordered.
          have Hord: ordered (Bin 0 a s2 s3).
          { apply WF_ordered in H.
            eapply size_irrelevance_in_ordered. eauto. }
          move: Hord. rewrite /ordered. rewrite -/local_bounded.
          case /and4P=>// => _ _ Hlo Hhi.
          split; [| split; [| split; [| split; [| split]]]]=>//.
          apply WF_children in H; destruct H.
          apply IHs1 in H. destruct H as [ _ [_ Hord']].
          specialize (Hord' a); destruct Hord'.
          apply H=>//. autorewrite with elt_compare in *. auto.
      + (** prove [size (insert e s) = size s + 1] *)
        rewrite -/insert.
        have Hs1: WF s2 by [apply WF_children in H; tauto].
        rewrite balanceL_add_size=>//.
        * apply IHs1 in Hs1.
          destruct Hs1 as [_ [[Hs | Hs] _]];
            derive_constraints; subst; rewrite Hs.
          -- left.
             rewrite [size s2 + 1]Z.add_comm [(_ + 1) + 1]Z.add_comm !Z.add_assoc //.
          -- right. reflexivity.
        * apply IHs1 in Hs1. tauto.
        * apply WF_children in H. tauto.
      + intros; split; intros;
          apply balanceL_ordered=>//;
          try solve [rewrite -/insert; apply WF_children in H; destruct H;
                     apply IHs1 in H; tauto];
          try solve [apply WF_children in H; tauto];
          try solve [rewrite -/insert /before_balancedL;
                     have Hwf: WF (Bin s1 a s2 s3) by [done];
                     apply WF_children in H; destruct H;
                     apply IHs1 in H; destruct H as [? [Hs _]];
                     destruct Hs; derive_constraints;
                     subst; rewrite_for_omega;
                     rewrite H5; intros; omega].
        * move: H3. case /and4P=>// => Hf Hlt Hlo Hhi.
          rewrite -/insert /before_ordered.
          split; [| split; [| split; [| split; [| split]]]]=>//.
          -- intros. autorewrite with elt_compare in *.
             intuition; eauto. apply E.eq_sym in H5; eauto.
          -- apply WF_children in H; destruct H.
             apply IHs1 in H. destruct H as [ _ [_ Hord']].
             specialize (Hord' a); destruct Hord'.
             apply H=>//. autorewrite with elt_compare in *. auto.
        * move: H3. case /and4P=>// => Hf Hlt Hlo Hhi.
          rewrite -/insert /before_ordered.
          split; [| split; [| split; [| split; [| split]]]]=>//.
          -- intros. autorewrite with elt_compare in *.
             intuition; eauto. 
          -- apply WF_children in H; destruct H.
             apply IHs1 in H. destruct H as [ _ [_ Hord']].
             specialize (Hord' a0); destruct Hord'.
             apply H4=>//; try intros;
               autorewrite with elt_compare in *; auto.
             destruct H5; eauto. apply E.eq_sym in H5. eauto.
      + (** s is Bin, e > a, prove: WF (insert e s) *)
        intros. apply balanceR_WF.
        * (** WF s2 *)
          apply WF_children in H. tauto.
        * (** WF (insert e s3) *)
          apply WF_children in H. apply IHs2. tauto.
        * (** s2 and (insert e s3) satisfy [before_balancedR]'s
              pre-condbitions. *)
          rewrite -/insert /before_balancedR.
          have Hs2: WF s3 by [apply WF_children in H; tauto].
          apply IHs2 in Hs2; destruct Hs2.
          (** cases analysis: did we insert an element to s3?  *)
          destruct H1 as [[H1 | H1] _].
          -- (** we did *)
            destruct s2; destruct s3; derive_constraints; subst;
              rewrite_for_omega; rewrite ?H1; intros; omega.
          -- (** we didn't *) derive_constraints; subst.
             rewrite H1. destruct Hbalanced; (left + right); omega.
        * (** prove [before_ordered] pre-conditions *)
          rewrite -/insert /before_ordered.
          have Hord: ordered (Bin 0 a s2 s3).
          { apply WF_ordered in H.
            eapply size_irrelevance_in_ordered. eauto. }
          move: Hord. rewrite /ordered. rewrite -/local_bounded.
          case /and4P=>// => _ _ Hlo Hhi.
          split; [| split; [| split; [| split; [| split]]]]=>//.
          apply WF_children in H; destruct H.
          apply IHs2 in H0. destruct H0 as [ _ [_ Hord']].
          specialize (Hord' a); destruct Hord'.
          apply H1=>//. autorewrite with elt_compare in *. auto.
      + rewrite -/insert.
        have Hs2: WF s3 by [apply WF_children in H; tauto].
        rewrite balanceR_add_size=>//.
        * apply IHs2 in Hs2.
          destruct Hs2 as [_ [[Hs | Hs] _]];
            derive_constraints; subst; rewrite Hs.
          -- left. rewrite Z.add_assoc //.
          -- right. reflexivity.
        * apply WF_children in H. tauto.
        * apply IHs2 in Hs2. tauto.
      + intros; split; intros;
          apply balanceR_ordered=>//;
          try solve [rewrite -/insert; apply WF_children in H; destruct H;
                     apply IHs1 in H; tauto];
          try solve [apply WF_children in H; tauto];
          try solve [rewrite -/insert /before_balancedR;
                     have Hwf: WF (Bin s1 a s2 s3) by [done];
                     apply WF_children in H; destruct H as [_ H];
                     apply IHs2 in H; destruct H as [? [Hs _]];
                     destruct Hs as [Hs | Hs]; derive_constraints;
                       subst; rewrite_for_omega;
                         rewrite Hs; intros; omega].
        * move: H3. case /and4P=>// => Hf Hlt Hlo Hhi.
          rewrite -/insert /before_ordered.
          split; [| split; [| split; [| split; [| split]]]]=>//.
          -- intros. autorewrite with elt_compare in *.
             intuition; eauto. apply E.eq_sym in H5; eauto.
          -- apply WF_children in H; destruct H.
             apply IHs2 in H3. destruct H3 as [ _ [_ Hord']].
             specialize (Hord' a0); destruct Hord'.
             apply H3=>//; try intros; autorewrite with elt_compare in *; auto.
             destruct H5; eauto.
        * move: H3. case /and4P=>// => Hf Hlt Hlo Hhi.
          rewrite -/insert /before_ordered.
          split; [| split; [| split; [| split; [| split]]]]=>//.
          -- intros. autorewrite with elt_compare in *.
             intuition; eauto. 
          -- apply WF_children in H; destruct H.
             apply IHs2 in H3. destruct H3 as [ _ [_ Hord']].
             specialize (Hord' a); destruct Hord'.
             apply H4=>//; autorewrite with elt_compare in *; auto.
    - simpl. elim. rewrite /singleton. split3.
      + apply WF_singleton.
      + left; reflexivity.
      + intros; split; intros; apply /and3P=>//; split=>//.
        * autorewrite with elt_compare. auto.
        * autorewrite with elt_compare. auto.
  Qed.

  Definition add (e: elt) (s': t) : t.
    refine (s <-- s' ;;
              pack (insert e s) _).
    move: i=>H. eapply insert_prop in H. destruct H. eauto.
  Defined.

  Definition singleton : elt -> t.
    refine (fun e => pack (singleton e) _).
    apply WF_singleton.
  Defined.

  Definition remove : elt -> t -> t. Admitted.
  Definition union : t -> t -> t. Admitted.
  Definition inter : t -> t -> t. Admitted.
  Definition diff : t -> t -> t. Admitted.

  Definition equal : t -> t -> bool :=
    fun ws ws' => s <-- ws ;;
               s' <-- ws' ;;
               s == s'.

  Definition subset : t -> t -> bool :=
    fun ws ws' => s <-- ws ;;
               s' <-- ws' ;;
               isSubsetOf s s'.

  Definition fold : forall A : Type, (elt -> A -> A) -> t -> A -> A. Admitted.
  Definition for_all : (elt -> bool) -> t -> bool. Admitted.
  Definition exists_ : (elt -> bool) -> t -> bool. Admitted.
  Definition filter : (elt -> bool) -> t -> t. Admitted.
  Definition partition : (elt -> bool) -> t -> t * t. Admitted.
  Definition cardinal : t -> nat. Admitted.
  Definition elements : t -> list elt. Admitted.
  Definition choose : t -> option elt. Admitted.

  Lemma In_1 :
    forall (s : t) (x y : elt), E.eq x y -> In x s -> In y s.
  Proof.
    move=>s x y. rewrite /In /In_set. elim s=>[s'].
    elim s'=>[sl sx l IHl r IHr | ]=>Hwf Heq.
    - simpl. destruct_match.
      + apply elt_compare_eq in Heq0.
        apply E.eq_sym in Heq. apply (E.eq_trans Heq) in Heq0.
        elim. apply elt_compare_eq in Heq0; rewrite Heq0 //=.
      + apply elt_compare_lt in Heq0. intro.
        apply WF_children in Hwf; destruct Hwf.
        apply (IHl H0) in Heq as Heq1=>//.
        apply E.eq_sym in Heq. apply (OrdFacts.eq_lt Heq) in Heq0.
        apply elt_compare_lt in Heq0. rewrite Heq0. apply Heq1.
      + apply elt_compare_gt in Heq0. intro.
        apply WF_children in Hwf; destruct Hwf.
        apply (IHr H1) in Heq as Heq1=>//.
        apply (OrdFacts.lt_eq Heq0) in Heq.
        apply elt_compare_gt in Heq. rewrite Heq. apply Heq1.
    (** We are using [elt_compare_lt] and [elt_comapre_gt] back
            and forth during proofs -- maybe it's a good place to use
            proof by reflection? *)
    - elim. rewrite /member //.
  Qed.

  Lemma mem_1 : forall (s : t) (x : elt), In x s -> mem x s = true.
  Proof. unfold In; intros; destruct s as [s]; auto. Qed.

  Lemma mem_2 : forall (s : t) (x : elt), mem x s = true -> In x s.
  Proof. unfold In; intros; destruct s as [s]; auto. Qed.

  Lemma equal_1 : forall s s' : t, Equal s s' -> equal s s' = true. Admitted.
  Lemma equal_2 : forall s s' : t, equal s s' = true -> Equal s s'. Admitted.
  Lemma subset_1 : forall s s' : t, Subset s s' -> subset s s' = true. Admitted.
  Lemma subset_2 : forall s s' : t, subset s s' = true -> Subset s s'. Admitted.

  Lemma singleton_1 :
    forall x y : elt, In y (singleton x) -> E.eq x y.
  Proof.
    rewrite /singleton /In /In_set //.
    intros. simpl in H.
    destruct (Base.compare y x) eqn:Hcomp;
      apply E.eq_sym; apply elt_compare_eq=>//.
  Qed.

  Lemma singleton_2 :
    forall x y : elt, E.eq x y -> In y (singleton x).
  Proof.
    rewrite /singleton /In /In_set //.
    rewrite_compare_e. intros.
    destruct (Base.compare y x) eqn:Hcomp=>//; exfalso.
    - apply elt_compare_lt in Hcomp. apply E.eq_sym in H.
      apply OrdFacts.eq_not_lt in H. contradiction.
    - apply elt_compare_gt in Hcomp. apply E.eq_sym in H.
      apply OrdFacts.eq_not_gt in H. contradiction.
  Qed.
  
  Lemma add_1 :
    forall (s : t) (x y : elt), E.eq x y -> In y (add x s).
  Proof.
    intros. destruct s as [s]. simpl. 
    induction s.
    - rewrite /insert /= -/insert. destruct_match.
      + rewrite /In_set /member /= -/member.
        apply E.eq_sym in H. apply elt_compare_eq in H. rewrite H //.
      + apply inset_balanceL.
        * apply WF_children in i; destruct i.
          apply insert_prop with (e:=x) in H0. destruct H0 as [? _]. auto.
        * apply WF_children in i. tauto.
        * have Hwf: WF (Bin s1 a s2 s3) by [done].
          apply WF_children in i; destruct i.
          apply insert_prop with (e:=x) in H0. destruct H0 as [_ [? _]].
          rewrite /before_balancedL. derive_constraints; subst.
          destruct H0 as [Hs | Hs]; rewrite_for_omega;
            rewrite Hs; intros; omega.
        * autorewrite with elt_compare in *.
          have Hord: ordered (Bin 0 a s2 s3).
          { apply WF_ordered in i.
            eapply size_irrelevance_in_ordered. eauto. }
          move: Hord. rewrite /ordered. rewrite -/local_bounded.
          case /and4P=>//. move=>_ _ Hlo Hhi.
          rewrite /before_ordered. repeat (split=>//).
          apply WF_children in i; destruct i.
          apply insert_prop with (e:=x) in H0. destruct H0 as [_ [_ ?]].
          specialize (H0 a). destruct H0 as [Hf Hg].
          apply Hf=>//.
        * autorewrite with elt_compare in *. right; left. split.
          -- apply E.eq_sym in H. eauto.
          -- apply WF_children in i. destruct i. apply IHs1 in H0. auto.
      + admit.
    - rewrite /insert /= /Base.singleton /In_set /member /=.
      apply E.eq_sym in H. apply elt_compare_eq in H. rewrite H //.
  Admitted.
        
  Lemma add_2 : forall (s : t) (x y : elt), In y s -> In y (add x s). Admitted.
  Lemma add_3 :
    forall (s : t) (x y : elt), ~ E.eq x y -> In y (add x s) -> In y s. Admitted.
  Lemma remove_1 :
    forall (s : t) (x y : elt), E.eq x y -> ~ In y (remove x s). Admitted.
  Lemma remove_2 :
    forall (s : t) (x y : elt), ~ E.eq x y -> In y s -> In y (remove x s). Admitted.
  Lemma remove_3 :
    forall (s : t) (x y : elt), In y (remove x s) -> In y s. Admitted.

  Lemma union_1 :
    forall (s s' : t) (x : elt), In x (union s s') -> In x s \/ In x s'. Admitted.
  Lemma union_2 :
    forall (s s' : t) (x : elt), In x s -> In x (union s s'). Admitted.
  Lemma union_3 :
    forall (s s' : t) (x : elt), In x s' -> In x (union s s'). Admitted.
  Lemma inter_1 :
    forall (s s' : t) (x : elt), In x (inter s s') -> In x s. Admitted.
  Lemma inter_2 :
    forall (s s' : t) (x : elt), In x (inter s s') -> In x s'. Admitted.
  Lemma inter_3 :
    forall (s s' : t) (x : elt), In x s -> In x s' -> In x (inter s s'). Admitted.
  Lemma diff_1 :
    forall (s s' : t) (x : elt), In x (diff s s') -> In x s. Admitted.
  Lemma diff_2 :
    forall (s s' : t) (x : elt), In x (diff s s') -> ~ In x s'. Admitted.
  Lemma diff_3 :
    forall (s s' : t) (x : elt), In x s -> ~ In x s' -> In x (diff s s'). Admitted.
  Lemma fold_1 :
    forall (s : t) (A : Type) (i : A) (f : elt -> A -> A),
      fold A f s i =
      fold_left (fun (a : A) (e : elt) => f e a) (elements s) i. Admitted.
  Lemma cardinal_1 : forall s : t, cardinal s = length (elements s). Admitted.
  Lemma filter_1 :
    forall (s : t) (x : elt) (f : elt -> bool),
      compat_bool E.eq f -> In x (filter f s) -> In x s. Admitted.
  Lemma filter_2 :
    forall (s : t) (x : elt) (f : elt -> bool),
      compat_bool E.eq f -> In x (filter f s) -> f x = true. Admitted.
  Lemma filter_3 :
    forall (s : t) (x : elt) (f : elt -> bool),
      compat_bool E.eq f -> In x s -> f x = true -> In x (filter f s). Admitted.
  Lemma for_all_1 :
    forall (s : t) (f : elt -> bool),
      compat_bool E.eq f ->
      For_all (fun x : elt => f x = true) s -> for_all f s = true. Admitted.
  Lemma for_all_2 :
    forall (s : t) (f : elt -> bool),
      compat_bool E.eq f ->
      for_all f s = true -> For_all (fun x : elt => f x = true) s. Admitted.
  Lemma exists_1 :
    forall (s : t) (f : elt -> bool),
      compat_bool E.eq f ->
      Exists (fun x : elt => f x = true) s -> exists_ f s = true. Admitted.
  Lemma exists_2 :
    forall (s : t) (f : elt -> bool),
      compat_bool E.eq f ->
      exists_ f s = true -> Exists (fun x : elt => f x = true) s. Admitted.
  Lemma partition_1 :
    forall (s : t) (f : elt -> bool),
      compat_bool E.eq f -> Equal (fst (partition f s)) (filter f s). Admitted.
  Lemma partition_2 :
    forall (s : t) (f : elt -> bool),
      compat_bool E.eq f ->
      Equal (snd (partition f s)) (filter (fun x : elt => negb (f x)) s). Admitted.
  Lemma elements_1 :
    forall (s : t) (x : elt), In x s -> InA E.eq x (elements s). Admitted.
  Lemma elements_2 :
    forall (s : t) (x : elt), InA E.eq x (elements s) -> In x s. Admitted.
  Lemma elements_3w : forall s : t, NoDupA E.eq (elements s). Admitted.
  Lemma choose_1 :
    forall (s : t) (x : elt), choose s = Some x -> In x s. Admitted.
  Lemma choose_2 : forall s : t, choose s = None -> Empty s. Admitted.

End Foo.
