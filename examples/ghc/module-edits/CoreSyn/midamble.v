(* ------------- CoreSyn midamble.v ------------ *)

Parameter tickishCounts : forall {id}, Tickish id -> bool.
Parameter tickishIsCode : forall {id}, Tickish id -> bool.

Require Import Omega.

Ltac intro_split := 
  try intros [? [? [? ?]]];
  try intros [? [? ?]];
  try intros [? ?].
  
Ltac distinguish3 := 
  split; intros; unfold not;  intro_split; discriminate.

Ltac solve_collectAnnArgsTicks :=   
  Tactics.program_simpl;
  try solve [distinguish3];
  try solve [repeat match goal with [ f : AnnExpr _ _ |- _ ] => destruct f end;
             Tactics.program_simpl;
             omega].


(* ANTALSZ NOTE: to make this function structurally recursive, we need to 
   define size_AnnAlt as a *local* helper function, not a mutual 
   helper function. Changing size_AnnAlt to "with" results in an error. *)

Fixpoint size_AnnExpr' {a}{b} (e: AnnExpr' a b) :=
  match e with 
  | AnnVar _ => 0
  | AnnLit _ => 0
  | AnnLam _ (_ , bdy) => S (size_AnnExpr' bdy)
  | AnnApp (_,e1) (_, e2) => S (size_AnnExpr' e1 + size_AnnExpr' e2)
  | AnnCase (_,scrut) bndr _ alts => 
    S (size_AnnExpr' scrut + 
       List.fold_right plus 0 
                          (List.map (fun p =>
                                       match p with 
                                         | (_,_,(_,e)) => size_AnnExpr' e
                                    end) 
                                    alts))
  | AnnLet (AnnNonRec v (_,rhs)) (_,body) => 
        S (size_AnnExpr' rhs + size_AnnExpr' body)
  | AnnLet (AnnRec pairs) (_,body) => 
        S (Lists.List.fold_right plus 0 
                                 (Lists.List.map (fun p => size_AnnExpr' (snd (snd p))) pairs) +
           size_AnnExpr' body)

  | AnnCast (_,e) _ => S (size_AnnExpr' e)
  | AnnTick _ (_,e) => S (size_AnnExpr' e)
  | AnnType _ => 0
  | AnnCoercion _ => 0
  end.


Fixpoint core_size {v} (e : Expr v) : nat :=
    match e with
    | Mk_Var v => 0
    | Lit l => 0
    | App e1 e2 => S (core_size e1 + core_size e2)
    | Lam v e => S (core_size e)
    | Let (NonRec v rhs) body => 
        S (core_size rhs + core_size body)
    | Let (Rec pairs) body => 
        S (Lists.List.fold_right plus 0 (Lists.List.map (fun p => core_size (snd p)) pairs) +
           core_size body)
    | Case scrut bndr ty alts  => 
        S (core_size scrut +
           Lists.List.fold_right plus 0 (Lists.List.map (fun p => core_size (snd p)) alts))
    | Cast e _ =>   S (core_size e)
    | Tick _ e =>   S (core_size e)
    | Type_ _  =>   0
    | Coercion _ => 0
    end.

(*
Fixpoint size_Expr {b} (e: Expr b) :=
  let size_Alt  : Alt b -> nat :=
      fun x => 
        match x with 
        | ((con, args), rhs) => size_Expr rhs
        end in
  let size_Bind  : Bind b -> nat :=
      fun x => 
        match x with 
        | NonRec _ e => size_Expr e
        | Rec grp => List.fold_left 
                         (fun n y => 
                            n + size_Expr (snd y)) grp 1
        end in

  match e with 
  | Mk_Var _ => 1
  | Lit _ => 1
  | Lam _ bdy => 1 + size_Expr bdy
  | App e1 e2 => 1 + size_Expr e1 + size_Expr e2
  | Case e _ _ brs => 1 + size_Expr e + 
                            List.fold_left (fun x y => x + size_Alt y) brs 1 
  | Let _ e => 1 + size_Expr e
  | Cast e _ => 1 + size_Expr e
  | Tick _ e => 1 + size_Expr e
  | Type_ _ => 1
  | Coercion _ => 1
  end.
*)






Instance Default__Expr {b} : GHC.Err.Default (Expr b) :=
  GHC.Err.Build_Default _ (Mk_Var GHC.Err.default).

Instance Default__Tickish {a} : GHC.Err.Default (Tickish a) :=
  GHC.Err.Build_Default _ (Breakpoint GHC.Err.default GHC.Err.default).


Instance Default_TaggedBndr {t}`{GHC.Err.Default t} : GHC.Err.Default (TaggedBndr t) :=
  GHC.Err.Build_Default _ (TB GHC.Err.default GHC.Err.default).

Instance Default__AnnExpr' {a}{b} : GHC.Err.Default (AnnExpr' a b) :=
  GHC.Err.Build_Default _ (AnnVar GHC.Err.default). 

Instance Default__AnnBind {a}{b} : GHC.Err.Default (AnnBind a b) :=
  GHC.Err.Build_Default _ (AnnRec GHC.Err.default). 

Instance Default__Bind {b} : GHC.Err.Default (Bind b) :=
  GHC.Err.Build_Default _ (Rec GHC.Err.default). 

Instance Default__CoreVect : GHC.Err.Default CoreVect :=
  GHC.Err.Build_Default _ (Vect GHC.Err.default GHC.Err.default). 

Instance Default__CoreRule : GHC.Err.Default CoreRule :=
  GHC.Err.Build_Default _ (BuiltinRule GHC.Err.default GHC.Err.default GHC.Err.default GHC.Err.default).

Instance Default__RuleEnv : GHC.Err.Default RuleEnv :=
  GHC.Err.Build_Default _ (Mk_RuleEnv GHC.Err.default GHC.Err.default).

(* ANTALSZ: Here are some examples of mutual recursion that I've unwound 
   by hand. We would like to generate these instead. *)

Fixpoint deAnnotate' {bndr} {annot} (arg_0__ : AnnExpr' bndr annot) : Expr bndr :=
  let deAnnotate {bndr} {annot} : AnnExpr bndr annot -> Expr bndr :=
       fun arg_0__ =>  match arg_0__ with | pair _ e => deAnnotate' e end in
  let deAnnAlt {bndr} {annot} : AnnAlt bndr annot -> Alt bndr :=
      fun arg_0__ =>
        match arg_0__ with
        | pair (pair con args) rhs => pair (pair con args) (deAnnotate rhs)
        end in
    match arg_0__ with
      | AnnType t => Type_ t
      | AnnCoercion co => Coercion co
      | AnnVar v => Mk_Var v
      | AnnLit lit => Lit lit
      | AnnLam binder body => Lam binder (deAnnotate body)
      | AnnApp fun_ arg => App (deAnnotate fun_) (deAnnotate arg)
      | AnnCast e (pair _ co) => Cast (deAnnotate e) co
      | AnnTick tick body => Tick tick (deAnnotate body)
      | AnnLet bind body =>
        let deAnnBind :=
            fun arg_9__ =>
              match arg_9__ with
              | AnnNonRec var rhs => NonRec var (deAnnotate rhs)
              | AnnRec pairs => Rec (let cont_11__ arg_12__ :=
                                        match arg_12__ with
                                        | pair v rhs => cons (pair v (deAnnotate rhs)) nil
                                        end in
                                    Coq.Lists.List.flat_map cont_11__ pairs)
              end in
        Let (deAnnBind bind) (deAnnotate body)
      | AnnCase scrut v t alts => Case (deAnnotate scrut) v t (GHC.Base.map deAnnAlt
                                                                           alts)
    end.

(* ANTALSZ: Here is another example *)

Fixpoint collectAnnArgs_go {b}{a}(expr : AnnExpr' b a) g as_ :=
  match expr with
    | AnnApp f a => collectAnnArgs_go (snd f) (fst f) (cons a as_)
    | e          => ((g,e), as_)
  end.

Definition collectAnnArgs {b}{a} :
  AnnExpr b a -> (AnnExpr b a * list (AnnExpr b a))%type :=
  fun expr => collectAnnArgs_go (snd expr) (fst expr) nil.


Fixpoint deTagExpr {t} (arg_0__ : TaggedExpr t) : CoreExpr :=
  let deTagAlt {t} : TaggedAlt t -> CoreAlt :=
  fun arg_0__ =>
    match arg_0__ with
      | pair (pair con bndrs) rhs =>
        pair (pair con (let cont_1__ arg_2__ :=
                            match arg_2__ with
                            | TB b _ => cons b nil
                            end in
                        Coq.Lists.List.flat_map cont_1__ bndrs)) (deTagExpr rhs)
    end in
  let deTagBind {t} : TaggedBind t -> CoreBind :=
      fun arg_0__ =>
        match arg_0__ with
        | NonRec (TB b _) rhs => NonRec b (deTagExpr rhs)
        | Rec prs => Rec (let cont_2__ arg_3__ :=
                             match arg_3__ with
                             | pair (TB b _) rhs => cons (pair b (deTagExpr rhs)) nil
                             end in
                         Coq.Lists.List.flat_map cont_2__ prs)
        end
  in match arg_0__ with
     | Mk_Var v => Mk_Var v
     | Lit l => Lit l
     | Type_ ty => Type_ ty
     | Coercion co => Coercion co
     | App e1 e2 => App (deTagExpr e1) (deTagExpr e2)
     | Lam (TB b _) e => Lam b (deTagExpr e)
     | Let bind body => Let (deTagBind bind) (deTagExpr body)
     | Case e (TB b _) ty alts => Case (deTagExpr e) b ty (GHC.Base.map deTagAlt
                                                                       alts)
     | Tick t e => Tick t (deTagExpr e)
     | Cast e co => Cast (deTagExpr e) co
     end.

Definition collectNAnnBndrs {bndr} {annot}`{GHC.Err.Default annot}
           : nat -> AnnExpr bndr annot -> (list bndr * AnnExpr bndr annot)%type :=
          fun orig_n e =>
            let fix collect (arg_0__:nat) (arg_1__ : list bndr) (arg_2__:AnnExpr bndr annot) :=
                               match arg_0__, arg_1__, arg_2__ with
                               | O, bs, body =>
                                 pair (GHC.List.reverse bs) body 
                               | S m, bs, body =>
                                   match arg_0__, arg_1__, arg_2__ with
                                   | n, bs, pair _ (AnnLam b body) => collect m (cons b bs) body
                                   | _, _, _ =>
                                       Panic.panicStr (GHC.Base.hs_string__ "collectNBinders") Panic.someSDoc
                                   end
                               end in
            collect orig_n nil e.



(*
Definition exprToType : CoreExpr -> Core.Type_ :=
  fun arg_0__ =>
    match arg_0__ with
      | Type_ ty => ty
      | _bad => GHC.Err.error (GHC.Base.hs_string__ "exprToType")
    end.

Definition applyTypeToArg : Core.Type_ -> (CoreExpr -> Core.Type_) :=
  fun fun_ty arg => TyCoRep.piResultTy fun_ty (exprToType arg). *)

