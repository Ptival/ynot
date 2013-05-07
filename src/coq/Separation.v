(* Copyright (c) 2008-2009, Harvard University
 * All rights reserved.
 *
 * Authors: Adam Chlipala, Gregory Malecha
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

Require Import Qcanon.
Require Import Ynot.Axioms.
Require Import Ynot.Util.
Require Import Ynot.PermModel.
Require Import Ynot.Heap.
Require Import Ynot.Hprop.
Require Import RelationClasses.

Set Implicit Arguments.

Theorem himp_any_conc : forall p, p ==> ??.
  unfold hprop_imp, hprop_any; trivial.
Qed.

Theorem empty_right p : p * __ <==> p.
Proof. split; simp_heap; subst; autorewrite with Ynot. auto.
  eauto with Ynot.
Qed.

Hint Resolve split_refl : Ynot.

Theorem hstar_comm p q : p * q <==> q * p.
Proof. split; simp_heap; eauto 7 with Ynot. Qed.

Lemma empty_left p : emp * p <==> p.
Proof. intros. now rewrite hstar_comm, empty_right. Qed.

Theorem himp_empty_prem : forall p q,
  p ==> q
  -> __ * p ==> q. intros p q Hpq. now rewrite hstar_comm, empty_right.
Qed.

Theorem himp_empty_prem' : forall p q,
  p * __ ==> q
  -> p ==> q. intros p q; now rewrite empty_right. 
Qed.

Theorem himp_empty_conc : forall p q,
  p ==> q
  -> p ==> __ * q. intros p q; now rewrite (hstar_comm __), empty_right.
Qed.

Theorem himp_empty_conc' : forall p q,
  p ==> q * __
  -> p ==> q. intros p q; now rewrite empty_right.
Qed.

Theorem himp_comm_prem : forall p q r,
  q * p ==> r
  -> p * q ==> r. intros p q r; now rewrite hstar_comm.
Qed.

Theorem hstar_assoc p q r :
  p * (q * r) <==> p * q * r.
Proof. split; intros. 
  unfold hprop_imp, hprop_sep; intuition. repeat (dest_exists || dest_conj).
  exists (h1 * h0)%heap; exists h3%heap. intuition. 
  eauto using split_splice''. 
  exists h1 ; exists h0. intuition. apply split_refl. 
  destruct Hl. destruct Hrrl. subst. eauto with Ynot.

  unfold hprop_imp, hprop_sep; intuition. repeat (dest_exists || dest_conj).
  exists h0; exists  (h2 * h3)%heap. intuition.
  eapply split_splice; eauto with Ynot.
  exists h3; exists h2. intuition. 
  destruct Hl. destruct Hrll. subst. apply split_comm.
  apply split_refl. eauto with Ynot.
Qed.

Theorem himp_assoc_prem1 : forall p q r s,
  p * (q * r) ==> s
  -> (p * q) * r ==> s. 
Proof. intros; now rewrite <- hstar_assoc.
Qed.

Theorem himp_assoc_prem2 : forall p q r s,
  q * (p * r) ==> s
  -> (p * q) * r ==> s.
Proof. intros. now rewrite (hstar_comm p q), <- hstar_assoc. 
Qed.

Theorem himp_comm_conc : forall p q r,
  r ==> q * p
  -> r ==> p * q.
Proof. intros; now rewrite hstar_comm.
Qed.

Theorem himp_assoc_conc1 : forall p q r s,
  s ==> p * (q * r)
  -> s ==> (p * q) * r.
Proof. intros. now rewrite <- hstar_assoc. Qed.

Theorem himp_assoc_conc2 : forall p q r s,
  s ==> q * (p * r)
  -> s ==> (p * q) * r.
Proof. intros; now rewrite (hstar_comm p q), <- hstar_assoc. Qed.

Definition isExistential T (x : T) := True.

Lemma isExistential_any : forall T (x : T), isExistential x.
  constructor.
Qed.

Ltac mark_existential e := generalize (isExistential_any e); intro.

Theorem himp_ex_prem : forall T (p1 : T -> _) p2 p,
  (forall v, isExistential v -> p1 v * p2 ==> p)
  -> hprop_ex p1 * p2 ==> p.
  Hint Immediate isExistential_any.

  unfold hprop_imp, hprop_ex, hprop_sep; simpl; intuition.
  do 2 destruct H0; intuition.
  destruct H0.
  eauto 6.
Qed.

Theorem himp_ex_conc : forall p T (p1 : T -> _) p2,
  (exists v, p ==> p1 v * p2)
  -> p ==> hprop_ex p1 * p2. 
Proof. red.
  intros. destruct H. 
  generalize (H _ H0); clear H H0. simp_heap. eauto 7 with Ynot.
Qed.

Theorem himp_ex_conc_trivial : forall T p p1 p2,
  p ==> p1 * p2
  -> T
  -> p ==> hprop_ex (fun _ : T => p1) * p2.
  simp_heap.
  generalize (H _ H0); clear H H0. simp_heap. eauto 7 with Ynot.
Qed.

Hint Extern 4 => progress (unfold hprop_unpack in *) : Ynot.

Theorem hiff_unpack : forall (T : Set) (x : T) p1,
  p1 x <==> hprop_unpack [x] p1.
Proof. simp_heap. split; intros; simp_heap. red. eauto 7 with Ynot. 
  generalize (pack_injective Hl); intros; subst; eauto with Ynot.
Qed. 
  
Theorem himp_unpack_prem : forall (T : Set) (x : T) p1 p2 p,
  p1 x * p2 ==> p
  -> hprop_unpack [x] p1 * p2 ==> p.
Proof. intros. now rewrite <- hiff_unpack. Qed.

(** Really needs T in Type ? *)

Theorem himp_unpack_conc : forall T x (y:[T]) p1 p2 p,
  y = [x]%inhabited
  -> p ==> p1 x * p2
  -> p ==> hprop_unpack y p1 * p2.
  unfold hprop_imp, hprop_unpack, hprop_sep; subst. intros.
  generalize (H0 _ H1). subst y.
  intros; simp_heap. subst. eauto 10 with Ynot.
Qed.

Theorem himp_unpack_conc_meta : forall T x (y:[T]) p1 p2 p,
  p ==> p1 x * p2
  -> y = [x]%inhabited
  -> p ==> hprop_unpack y p1 * p2.
  unfold hprop_imp, hprop_unpack, hprop_sep; subst. intros.
  generalize (H _ H1).
  intros; simp_heap. subst. eauto 10 with Ynot.
Qed.

Theorem himp_split : forall p1 p2 q1 q2,
  p1 ==> q1
  -> p2 ==> q2
  -> p1 * p2 ==> q1 * q2.
Proof. intros p1 p2 q1 q2 H H'; now rewrite H, H'. 
Qed.

Theorem himp_pure P : [P] ==> emp.
Proof. reduce. red in H. intuition. Qed.

Theorem himp_pure' (P : Prop) : P -> emp ==> [P].
Proof. reduce. red in H0. intuition. Qed.

Theorem himp_inj_prem : forall (P : Prop) p q,
  (P -> p ==> q)
  -> [P] * p ==> q. intros.
  unfold hprop_imp, hprop_inj, hprop_sep. simp_heap. subst.
  autorewrite with Ynot in *.
  apply H; eauto.
Qed.

Lemma pure_imp P p : [P] * p ==> p.
Proof. intros. now rewrite himp_pure, empty_left. Qed.

Lemma pure_imp_rev (P : Prop) p : P -> p ==> [P] * p.
Proof. intros. now rewrite <- (himp_pure' H), empty_left. Qed.

Theorem himp_inj_prem_keep : forall (P : Prop) p q,
  (P -> [P] * p ==> q)
  -> [P] * p ==> q. intros. apply himp_inj_prem.
  intro H0; specialize (H H0). now rewrite <- (pure_imp_rev p H0) in H.
Qed.

Theorem himp_inj_prem_add : forall (P : Prop) p q,
  P
  -> [P] * p ==> q
  -> p ==> q. 
Proof. intros. now rewrite <- (pure_imp_rev p H) in H0.
Qed.

Theorem himp_inj_conc : forall (P : Prop) p q,
  P
  -> p ==> q
  -> p ==> [P] * q. 
Proof. intros. now rewrite <- (pure_imp_rev q H). Qed.

Theorem himp_frame : forall p q1 q2,
  q1 ==> q2
  -> p * q1 ==> p * q2.
Proof. intros. now rewrite H. Qed.

Theorem himp_frame_cell : forall n (T : Set) (v1 v2 : T) q1 q2 (p:perm),
  v1 = v2
  -> q1 ==> q2
  -> n -[p]-> v1 * q1 ==> n -[p]-> v2 * q2.
Proof. intros; subst. now rewrite H0. Qed.

Lemma himp_cell_split : forall (q1 q2 : perm) (p : ptr) A (v:A),
  q1 |#| q2 -> p -[ q1 + q2 ]-> v ==> p -[ q1 ]-> v * p -[ q2 ]-> v.
Proof.
  red. intuition. 
  exists (p |--> (Dyn v, q1))%heap.
  exists (p |--> (Dyn v, q2))%heap.
  intuition; try solve [red; intuition].
  red in H0.
  unfold split, singleton, join, disjoint, read in *. intuition.
  destruct (ptr_eq_dec p0 p); intuition.
  ext_eq.
  unfold hvalo_plus, hval_plus in *.
  destruct (ptr_eq_dec x p); simpl; intuition.
  subst.
  rewrite perm_plus_when_compat by auto.
  auto.
Qed.

Lemma himp_cell_join : forall (q1 q2 : perm) (p : ptr) A (v:A),
  q1 |#| q2 -> p -[ q1 ]-> v * p -[ q2 ]-> v ==> p -[ q1 + q2 ]-> v.
Proof.
  red. intuition. 
  red in H0. destruct H0. destruct H0. unfold split in H0. 
  intuition. subst.
  unfold hprop_cell, join, read in *.
  intuition.
  rewrite H2, H1. simpl.
  unfold hval_plus. simpl.
  rewrite perm_plus_when_compat by auto.
  auto.

  rewrite H3, H5 by auto.
  simpl. auto.
Qed.

Lemma himp_trans Q P R : P ==> Q -> Q ==> R -> P ==> R.
Proof. intros; now transitivity Q. Qed.

Lemma himp_apply P T : P ==> T -> forall Q, Q ==> P -> Q ==> T.
Proof. intros. now rewrite H0. Qed.

Theorem add_fact F P Q R : 
  (P ==> [F] * ??) ->
  (F -> (P * Q ==> R)) ->
  (P * Q ==> R).
Proof.
  repeat intro. apply H0; auto. 
  destruct H1 as [? [? [? [Px ?]]]].
  destruct (H _ Px) as [? [? [? [[? ?] ?]]]]; trivial.
Qed.

Lemma himp_any_ret (P:Prop) : P -> forall h, ([P] * ??)%hprop h.
Proof.
 red. repeat econstructor; firstorder eauto with Ynot.
Qed.

Lemma himp_cell_same : forall (T:Set) p (q q' : perm) (v v' : T) P Q,
    (q |#| q' -> v = v' -> p -[q]-> v * p -[q']-> v' * P ==> Q) ->
    p -[q]-> v * p -[q']-> v' * P ==> Q.
Proof.
 intros.
 eapply (@add_fact (q |#| q' /\ v = v')); intuition.
 red. intros. destruct H0 as [? [? ?]]. intuition.
 apply himp_any_ret.
 destruct H1. destruct H0. destruct H3. subst.
 specialize (H1 p).
 rewrite H0, H3 in H1.
 simpl in H1; intuition.
 apply Dyn_inj. auto.
Qed.

Theorem himp_frame_prem : forall p1 p2 q p1',
  p1 ==> p1'
  -> p1' * p2 ==> q
  -> p1 * p2 ==> q. 
Proof. intros. now rewrite H. 
Qed.

Theorem himp_frame_conc : forall p q1 q2 q1',
  q1' ==> q1
  -> p ==> q1' * q2
  -> p ==> q1 * q2.
Proof. intros. now rewrite <- H.
Qed.

Theorem unpack : forall T (h : [T]) (P : Prop),
  (forall x, h = [x]%inhabited -> P)
  -> P.
  dependent inversion h; eauto.
Qed.

Theorem himp_unpack_prem_eq : forall (T : Set) h (x : T) p1 p2 p,
  h = [x]%inhabited
  -> p1 x * p2 ==> p
  -> hprop_unpack h p1 * p2 ==> p.
  intros; subst. now rewrite <- hiff_unpack.
Qed.

Theorem himp_unpack_prem_alone : forall (T : Set) h (x : T) p1 p,
  h = [x]%inhabited
  -> p1 x ==> p
  -> hprop_unpack h p1 ==> p.
  intros. subst. now rewrite <- hiff_unpack.
Qed.
