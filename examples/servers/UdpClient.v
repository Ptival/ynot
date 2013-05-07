Require Import List Ascii.
Require Import Ynot.
Require Import IO Net FS.

Open Local Scope hprop_scope.
Open Local Scope stsepi_scope.
Open Local Scope char_scope.

Set Implicit Arguments.

Inductive trace (local remote : Net.SockAddr) : IO.Trace -> Prop :=
| NilCorrect : trace local remote nil
| ConsCorrect : forall data reply past wait, trace local remote past -> 
  (forall msg, ~In (UDP.Recd local remote msg) wait) ->
  trace local remote 
      (WroteString stdout reply ++
       UDP.Recd local remote reply :: wait ++ UDP.Sent local remote data :: 
       ReadLine stdin data ++ past).

Lemma proj_inv : forall (T1 T2 : Type) (a b : T1) (c d : T2),
  (a,c) = (b,d) -> a = b /\ c = d.
  intros; inversion H; auto.
Qed.

Definition waitReceive : forall (local remote : Net.SockAddr) (tr : [Trace]),
  STsep (tr ~~ IO.traced tr)
        (fun res:(list ascii * [Trace]) => tr ~~ 
          im :~~ (snd res) in IO.traced (UDP.Recd local remote (fst res) :: (im ++ tr))).
  refine (fun local remote tr =>
    {{Fix (fun im => im ~~ tr ~~ IO.traced (im ++ tr))
        (fun _ (res:list ascii * [Trace]) => tr ~~
           im :~~ (snd res) in IO.traced (UDP.Recd local remote (fst res) :: (im ++ tr)))
        (fun self im => 
           reply <- UDP.recv local (inhabit_unpack2 im tr (fun im tr => im ++ tr)); 
           if sock_eq remote (fst reply) then 
             {{Return (snd reply, im)}}
           else
             {{self (im ~~~ (UDP.Recd local (fst reply) (snd reply)) :: im)}}
         ) [@nil Action]%inhabited}});
  solve [ sep fail auto
        | sep fail auto; apply proj_inv in H; destruct H; sep fail auto ].
Qed.

Definition iter : forall (local remote : Net.SockAddr) (tr : [Trace]),
  STsep (tr ~~ IO.traced tr * handle FS.stdin * handle FS.stdout)
        (fun _:unit => tr ~~ Exists request :@ list ascii, Exists reply :@ list ascii, Exists q :@ Trace,
          handle FS.stdin * handle FS.stdout *
          IO.traced (WroteString FS.stdout reply  ++
            (UDP.Recd local remote reply :: (q ++ UDP.Sent local remote request ::
              (ReadLine FS.stdin request ++ tr))))).
  refine (fun local remote tr =>
    ln <- readline FS.stdin FS.ro_readable tr <@> _ ;
    UDP.send local remote ln (tr ~~~ ReadLine FS.stdin ln ++ tr) <@> _ ;;
    reply <- waitReceive local remote (tr ~~~ UDP.Sent local remote ln :: (ReadLine FS.stdin ln ++ tr)) <@> _;
    writeline FS.stdout (fst reply) FS.wo_writeable (inhabit_unpack2 tr (snd reply) 
      (fun tr q => (UDP.Recd local remote (fst reply)) :: q ++ (UDP.Sent local remote ln ::
        (ReadLine FS.stdin ln ++ tr)))) <@> _ ;;
    {{Return tt}});
  solve [ inhabiter; unpack_conc; rsep fail auto; sep fail auto; rsep fail auto ].
Qed.

Theorem list_no_cycle' : forall (T : Type) (l1 l2 : list T),
  l2 <> nil -> l2 ++ l1 <> l1.
  intros; pose (@list_no_cycle T l1 l2); unfold not in *; auto.
Qed.

Definition client : forall (local remote : Net.SockAddr) (tr : [Trace]),
  STsep (tr ~~ [trace local remote tr] * IO.traced tr * handle FS.stdin * handle FS.stdout)
        (fun _:unit => tr ~~ Exists v :@ Trace, [v <> tr] * [trace local remote tr] *
             IO.traced v * handle FS.stdin * handle FS.stdout).
  intros. refine ({{iter local remote tr <@> (tr ~~ [trace local remote tr])}}).
  sep fail auto.
  intros; inhabiter. sep fail auto. assert (WroteString stdout v1 ++
      (UDP.Recd local remote v1
       :: v2 ++ UDP.Sent local remote v0 :: ReadLine stdin v0 ++ x) <> x).
  unfold WroteString, ReadLine. assert ((WroteString stdout v1 ++
   UDP.Recd local remote v1
   :: v2 ++
      UDP.Sent local remote v0
      :: ReadLine stdin v0) ++ x <> x).
  eapply list_no_cycle'. firstorder. rewrite app_ass in H3. simpl in *. rewrite app_ass in H3. simpl in *. firstorder.
  sep fail auto.
Qed.