(* Copyright (c) 2008, Harvard University
 * All rights reserved.
 *
 * Author: Avi Shinnar
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * - The names of contributors may not be used to endorse or promote products
 *   derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *)

Require Import Ynot.
Require Import FiniteMap.
Set Implicit Arguments.

(***************************************************************************)
(* The following is an argument to the hash-table functor and provides the *)
(* key comparison, key hash, and initial table size needed to build the    *)
(* hash-table.                                                             *)
(***************************************************************************)
Module Type HASH_ASSOCIATION.
  Variable key_t : Set.
  Variable value_t : key_t -> Set.
  Variable key_eq_dec : forall (k1 k2:key_t), {k1 = k2} + {k1 <> k2}.
  Notation "k1 =! k2" := (key_eq_dec k1 k2) (at level 70, right associativity).
  Variable hash : key_t -> nat.
  Variable table_size : nat.
  Variable table_size_gt_zero : table_size > 0.
End HASH_ASSOCIATION.

Module HashTableModel(A : HASH_ASSOCIATION).
  Import A.
  Module AL := AssocList(A).
  Export AL.
  Require Import Euclid Peano_dec Minus.
  Require Import Array.
  (* We compose the modulo function from the Peano_dec library with the key hash
     * to get something that's guaranteed to be in range. *)
  Program Definition hash(k:A.key_t) : nat := modulo A.table_size A.table_size_gt_zero (A.hash k).

    Ltac simpl_sig := repeat
      match goal with 
        | [|- context [(proj1_sig ?x)]] => destruct x; simpl
        | [H:context [(proj1_sig ?x)] |- _] => destruct x; simpl in H
        | [H:exists x, _ |- _] => destruct H
      end; intuition. 
  
    Lemma hash_below(k:A.key_t) : hash k < A.table_size.
    Proof. unfold hash; intros; simpl_sig. Qed.

    (* given a list of key value pairs, return only those where the hash of the key equals i *)
    Fixpoint filter_hash (i:nat) (l:alist_t) {struct l} : alist_t := 
      match l with
      | nil => nil
      | (k,, v)::l' => 
        if eq_nat_dec (hash k) i then 
          (k,,v):: (filter_hash i l')
        else
          filter_hash i l'
      end.

    Lemma sub_succ(x y:nat) : S x <= y -> S (y - S x) = y - x.
    Proof. intros ; omega. Qed.

    Hint Rewrite sub_succ using solve[auto] : AssocListModel.
    Hint Rewrite <- minus_n_n : AssocListModel.

    (* TODO: split up simpler into model and hash table parts
     * the model should not need to import Array *)
    Ltac simpler := subst;
      repeat (progress ((repeat 
        match goal with
          | [|- context [?n - ?n]] => rewrite <- minus_n_n
          | [|- context [_ + 0]] => rewrite <- plus_n_O
          | [H:context [_ + 0] |- _] => rewrite <- plus_n_O in H
          | [|- context [_ - 0]] => rewrite <- minus_n_O
          | [H:context [_ - 0] |- _] => rewrite <- minus_n_O in H
(*          | [|- context [?x - ?x]] => rewrite <- minus_n_n
          | [|- context [S (A.table_size - S ?x)]] => rewrite sub_succ; [idtac | solve[auto]] *)
          | [H:array_length ?x = _ |- context [array_length ?x]] => rewrite H
          | [ |- context[if eq_nat_dec ?e1 ?e2 then _ else _] ] => 
            destruct (eq_nat_dec e1 e2) ; try congruence ; try solve [assert False; intuition]; try subst
        end); AL.simpler)).
    Ltac t := repeat (progress (simpler; simpl in *; autorewrite with AssocListModel; auto; intuition)).

    (* some facts about filter_hash *)
    Lemma filter_hash_lookup k l : lookup k (filter_hash (hash k) l) = lookup k l.
    Proof. induction l; t. Qed.

    Lemma filter_hash_lookup_none x i l :  lookup x l = None -> lookup x (filter_hash i l) = None.
    Proof. induction l; t. Qed.

    Lemma filter_hash_perm i l l' : Permutation l l' -> Permutation (filter_hash i l) (filter_hash i l').
    Proof. induction 1; t; eauto. Qed.
    Hint Resolve filter_hash_lookup filter_hash_lookup_none.

    Lemma filter_hash_distinct i l : distinct l -> distinct (filter_hash i l).
    Proof. induction l; t. Qed.
    Hint Resolve filter_hash_perm filter_hash_distinct.

    Lemma remove_filter_eq (k:A.key_t)(l:alist_t) : 
      remove k (filter_hash (hash k) l) = filter_hash (hash k) (remove k l).
    Proof. induction l; t. Qed.
      
    Lemma remove_filter_neq (k:A.key_t)(i:nat)(l:alist_t) : 
      (hash k <> i) -> filter_hash i (remove k l) = filter_hash i l.
    Proof. induction l ; t. Qed.
    Hint Rewrite filter_hash_lookup remove_filter_eq : AssocListModel.

    Lemma insert_filter_eq k v (l:alist_t) : 
      insert v (filter_hash (hash k) l) = (k,,v)::filter_hash (hash k) (remove k l).
    Proof. unfold insert; t. Qed.
    Hint Rewrite insert_filter_eq : AssocListModel.
    Hint Rewrite remove_filter_neq using solve[omega|congruence|t]: AssocListModel.

  End HashTableModel.

(*************************************************************************************)
(* The hash-table implementation is a functor, parameterized by a HASH_ASSOCIATION,  *)
(* and a finite map implementation F over the keys and values from HASH_ASSOCIATION. *)
(* We use F to implement the buckets.                                                *)
(*************************************************************************************)
Module HashTable(HA : HASH_ASSOCIATION)
                (F : FINITE_MAP with Module A := HA) : FINITE_MAP with Module A := HA.

  Open Local Scope hprop_scope.
  Require Export Array.
  Require Import Peano_dec.

  Module HL := HashTableModel(HA).

  Module AT <: FINITE_MAP_AT with Module A:=HA.
    Module A := HA.
    Module AL := F.AL.
    Import A AL HL.
    Definition fmap_t : Set := array. (* of F.fmap_t's *)
                                  
    (* The ith bucket of a hash-table is well-formed with respect to the association list
     * l, if it points to an F.fmap_t that represents l filtered by i. *)

    Definition wf_bucket (f:fmap_t) (l:alist_t) (i:nat) : hprop := 
      (Exists r :@ F.AT.fmap_t, 
        (p :~~ array_plus f i in p --> r) * F.AT.rep r (filter_hash i l)).

    (* A hash-table represents list l if each of the buckets is well-formed with respect
     * to l.  Note that we also have to keep around the fact that the array_length of the
     * array is equal to HA.table_size so that we can free the array. *)
    Definition rep (f:fmap_t) (l:alist_t) : hprop := 
      [array_length f = HA.table_size] * {@ (wf_bucket f l i) | i <- 0 + HA.table_size}.

  End AT.

  Module T:=FINITE_MAP_T(HA)(AT).

  Module A := HA.
  Module AL := F.AL.
  Import AL AT HL.
  
  Open Local Scope stsepi_scope.
  Open Local Scope hprop_scope.

  Ltac s := T.unfm_t; intros.

  (* The following is used to initialize an array with empty F.fmap_t's *)
  Definition init_pre(f:array)(n:nat) := 
    {@ p :~~ array_plus f i in (Exists A :@ Set, Exists v :@ A, p --> v) | i <- (HA.table_size - n) + n }.

  Definition init_post (f:array)(n:nat)(_:unit) := {@ wf_bucket f nil_al i | i <- (HA.table_size - n) + n}.
  Definition init_table_spec (f:array)(n:nat) := (n <= HA.table_size) -> STsep (init_pre f n) (init_post f n).


  Definition free_pre (f:array)(l:[alist_t])(n:nat) := l ~~ {@ wf_bucket f l i | i <- (HA.table_size - n) + n}.
  Definition free_post (f:array)(n:nat) (_:unit) := {@ p :~~ array_plus f i in p -->? | i <- (HA.table_size - n) + n}.
  Definition free_spec (f:array)(l:[alist_t])(n:nat) := (n <= HA.table_size) -> STsep (free_pre f l n) (free_post f n).

  (* This should be generalized for all finite maps. *)
  Lemma add_dis (v:F.AT.fmap_t) (l:F.AL.alist_t) P Q : 
    (distinct l -> (F.AT.rep v l * P ==> Q)) ->
    (F.AT.rep v l * P ==> Q).
  Proof. intros. apply (add_fact (@F.distinct _ _ ) H). Qed.

  Ltac add_dis :=
    repeat(search_prem ltac:(idtac; (match goal with
                                       [|- F.AT.rep ?v ?l * ?P ==> ?Q] => 
                                       match goal with
                                         | [H:distinct l |- _] => fail 1
                                         | _ => apply add_dis; intros
                                       end
                                     end))).
  
  Ltac unf := unfold init_pre, init_post, free_pre, free_post, rep, wf_bucket, ptsto_any.
  Ltac t := unf; simpl; simpler; sep fail ltac:(subst; unfold_local; simpler); 
    simpler; autorewrite with AssocListModel; sep fail auto.

  Definition init_table: forall (f:array)(n:nat), init_table_spec f n.
  intro.
  refine(
    fix init(n:nat) : init_table_spec f n :=
          IfZero n
          Then fun _ => {{Return tt}}
          Else fun _ => m <- F.new <@> _
                      ; upd_array f (HA.table_size - S n) m
                        <@> (init_pre f n * F.AT.rep m nil_al)
                 ;; {{init n _ <@> wf_bucket f nil_al (HA.table_size - S n)}})
  ; t. Qed.
(*  ; [| | | | t' | | | t' |]; t'. Qed. *)

  (* We allocate an array and then initialize it with empty F.fmap_t's *)
  Definition new : T.new. s.
  refine (  t <- new_array HA.table_size 
         ; @init_table t HA.table_size _ <@>  _ 
         ;; {{Return t}})
  ; t. Qed.


  (* the following runs through the array and calls F.free on each of the buckets. *)
  Definition free_table(f:array)(l:[alist_t]) : forall (n:nat), free_spec f l n.
  refine (fix free_tab(n:nat) : free_spec f l n := 
          match n as n' return free_spec f l n' 
          with
          | 0 => fun H => {{Return tt}}
          | S i => fun H => let j := HA.table_size - S i in
                              let p := array_plus f j in 
              fm <- sub_array f j 
                       (fun fm => l ~~ F.AT.rep fm (filter_hash j l) * 
                        iter_sep (wf_bucket f l) (HA.table_size - i) i) 
            ; F.free fm (l ~~~ filter_hash j l)
                <@> ((p ~~ p --> fm) * free_pre f l i)
           ;; {{free_tab i _ <@> _}}
          end)
  ; clear free_tab; t. 
Defined.

  (* Run through the array, call F.free on all of the maps, and then call array_free *)
  Definition free : T.free. s.
  refine (@free_table x l HA.table_size _ 
              <@> [array_length x = HA.table_size]
      ;; free_array x)
; t. Defined.


Lemma iter_imp_f(P1 P2:nat->hprop)(len start:nat) Q R : 
  (forall i, i >= start -> i < len + start -> P1 i ==> P2 i) -> 
  Q ==> R -> 
  iter_sep P1 start len * Q ==> iter_sep P2 start len * R.
Proof.
 Hint Resolve iter_imp. intros. apply himp_split; auto. 
Qed.

Ltac iter_imp := 
  search_conc 
  ltac:(idtac; match goal with
          [|- ?Q1 ==> iter_sep ?P ?s ?len * ?R1] => 
          search_prem
          ltac:(idtac; match goal with
                  [|- iter_sep ?P1 s len * ?Q2 ==> ?R2] => apply iter_imp_f
                end)
        end).

  Lemma perm : T.perm.
  Proof. Hint Resolve F.perm. s; t; iter_imp; t; add_dis; t. Qed.
  Hint Resolve hash_below.

  Lemma himp_trans_frame P Q F1 R : P ==> Q -> Q * F1 ==> R -> P * F1 ==> R.
  Proof. intros. eapply himp_trans. 2: eauto. sep fail auto. Qed.

  Ltac trans_imp := 
  search_prem ltac:(idtac; 
    match goal with
      [H:?P ==> ?Q |- ?P * ?F1 ==> ?R] => apply (@himp_trans_frame P Q F1 R H)
    end).

  Lemma iter_sep_inj (len s:nat) P Q  : len > 0 -> {@ Q i * [P] | i <- s + len} ==> {@ Q i | i <- s + len} * [P].
  Proof. induction len; t. assert False; intuition. iter_imp; t. Qed.

  Lemma iter_sep_star_conc : forall (len s:nat) P Q, {@ P i * Q i  | i <- s + len} 
    ==> {@ P i | i <- s + len} * {@ Q i | i <- s + len} .
  Proof. induction len; t. apply himp_comm_conc. auto. Qed.

  Lemma iter_sep_star_prem : forall (len s:nat) P Q, {@ P i | i <- s + len} * {@ Q i | i <- s + len} 
    ==> {@ P i * Q i  | i <- s + len}.
  Proof. induction len; t. apply himp_comm_prem. auto. Qed.

  Lemma iter_sep_any : forall (len s:nat) P, {@ P i * ??  | i <- s + len} ==> {@ P i | i <- s + len} * ??.
  Proof. intros. apply himp_empty_prem'.
    Hint Resolve himp_any_conc.
  apply (@himp_trans_frame _ _ __ ({@P i | i <- (s) + len} * ??)
    ((iter_sep_star_conc len s P (fun _ => ??)))). sep fail auto.
  Qed.

  Lemma iter_sep_empty : forall (len s:nat), {@ __  | i <- s + len} ==> __.
  Proof. induction len; t. Qed.

  Lemma iter_sep_inj_empty : forall (len s:nat) P, {@ [P i]  | i <- s + len} ==> __.
  Proof. induction len; t. Qed.

  Lemma inj_and_conc P Q R : P ==> [Q] -> P ==> [R] -> P ==> [Q /\ R].
  Proof. firstorder. Qed.

  Lemma distinct_from_parts l :{@ [distinct (filter_hash i l)] | i <- (0) + HA.table_size} ==> [distinct l].
  Proof. intros. induction l. t.
    assert (A0:iter_sep (fun _ : nat => [True]) 0 HA.table_size ==> iter_sep (fun _ : nat => __) 0 HA.table_size).
    iter_imp; t. trans_imp. t. apply iter_sep_empty.
    destruct a. simpl.
    split_index. apply (hash_below x).
    simpler.
    assert (A1:{@[distinct
      (if eq_nat_dec (hash x) i
        then (x,, v) :: filter_hash i l
        else filter_hash i l)] | i <- (0) + hash x} ==> 
    {@[distinct
      (filter_hash i l)] | i <- (0) + hash x}). iter_imp; t.
    assert(A2:{@[distinct
      (if eq_nat_dec (hash x) i
        then (x,, v) :: filter_hash i l
        else filter_hash i l)] | i <- (S (hash x)) +
    HA.table_size - hash x - 1} ==> 
    {@[distinct
      (filter_hash i l)]  | i <- (S (hash x)) +
    HA.table_size - hash x - 1}). iter_imp; t.
    repeat trans_imp; clear A1 A2.
    apply inj_and_conc. rewrite filter_hash_lookup. sep fail auto.
    apply himp_empty_conc'. apply himp_split; apply iter_sep_inj_empty.
    eapply himp_trans; [idtac|apply IHl].
    apply himp_empty_conc'. eapply sp_index_conc; t.
  Qed.

  Lemma distinct_from_parts_any l :{@ [distinct (filter_hash i l)] * ?? | i <- (0) + HA.table_size} ==> [distinct l] * ??.
  Proof. intros.
    eapply himp_trans.
    apply iter_sep_any. sep fail auto.
    apply distinct_from_parts.
  Qed.

  Lemma distinct : T.distinct.
  Proof. s.
    eapply himp_trans; [| apply distinct_from_parts_any].
    t. iter_imp; t. add_dis. t.
  Qed.
 
  Definition its := iter_sep.
  Lemma its_re : its = iter_sep. reflexivity. Qed.

   Ltac init_split :=  rewrite <- its_re.

   Ltac split_index'_ := idtac; 
     match goal with
       | [ |- its ?P ?s ?len * ?Q ==> ?R ] => 
         eapply (sp_index_hyp P); [solve[auto] |]
       | [ |- ?R ==> its ?P ?s ?len * ?Q] => 
         eapply (sp_index_conc P); [solve[auto] |]
     end.

   Ltac split_index_ := search_prem split_index'_ || search_conc split_index'_.

   Definition lookup : T.lookup. s;
   refine (fm <- sub_array x (hash k)   (* extract the right bucket *)
     (fun fm => 
                l ~~ [array_length x = HA.table_size] * 
                F.AT.rep fm (filter_hash (hash k) l) * 
                   iter_sep (wf_bucket x l) 0 (hash k) * 
                   iter_sep (wf_bucket x l) (S (hash k)) (HA.table_size - (hash k) - 1))
         ; {{F.lookup fm k (l ~~~ (filter_hash (hash k) l))
               <@> (l ~~ [array_length x = HA.table_size] * 
                 (let p := array_plus x (hash k) in p ~~ p --> fm) *
                 iter_sep (wf_bucket x l) 0 (hash k) * 
                 iter_sep (wf_bucket x l) (S (hash k)) (HA.table_size - (hash k) - 1))}}); 
   unf; repeat (simpl; init_split; sep fail ltac:(subst; try split_index_; simpler; unfold_local); t).
 Qed.

  Definition insert : T.insert. s;
  refine (fm <- sub_array x (hash k) (* find the right bucket *)
           (fun fm =>
             [array_length x = HA.table_size] * 
             (l ~~ F.AT.rep fm (filter_hash (hash k) l) * 
                 iter_sep (wf_bucket x l) 0 (hash k) * 
                 iter_sep (wf_bucket x l) (S (hash k)) (HA.table_size - (hash k) - 1)))
         (* and use F.insert to insert the key value pair *)
         ; {{F.insert fm v (l ~~~ (filter_hash (hash k) l))    
           <@> 
             [array_length x = HA.table_size] * 
             (let p := array_plus x (hash k) in p ~~ p --> fm) * 
             (l ~~ (iter_sep (wf_bucket x l) 0 (hash k) * 
                iter_sep (wf_bucket x l) (S (hash k)) (HA.table_size - (hash k) - 1)))
        }}); 
  unf; repeat (simpl; init_split; sep fail ltac:(subst; try split_index_; simpler; unfold_local); t); unfold its.
  repeat (iter_imp; t).
  Qed.

  Definition remove : T.remove. s;
  refine (fm <- sub_array x (hash k) (* find the right bucket *)
           (fun fm =>
             [array_length x = HA.table_size] * 
             (l ~~ F.AT.rep fm (filter_hash (hash k) l) * 
                 iter_sep (wf_bucket x l) 0 (hash k) * 
                 iter_sep (wf_bucket x l) (S (hash k)) (HA.table_size - (hash k) - 1)))
         (* and use F.insert to insert the key value pair *)
       ; {{F.remove fm k (l ~~~ (filter_hash (hash k) l))    
           <@> 
             [array_length x = HA.table_size] * 
             (let p := array_plus x (hash k) in p ~~ p --> fm) * 
             (l ~~ (iter_sep (wf_bucket x l) 0 (hash k) * 
                iter_sep (wf_bucket x l) (S (hash k)) (HA.table_size - (hash k) - 1)))}}) ; 
  unf; repeat (simpl; init_split; sep fail ltac:(subst; try split_index_; simpler; unfold_local); t); unfold its.
  repeat (iter_imp; t).
  Qed.

End HashTable.
