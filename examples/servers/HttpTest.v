Require Import Ynot Basis.
Require Import List Ascii String.
Require Import RSep.
Require Import HttpParser.
Require Import Packrat Stream.

Open Local Scope stsepi_scope.
Open Local Scope hprop_scope.

Ltac s := unfold HTTP_correct,Packrat.ans_correct in *; rsep fail auto.

Definition parse_test : forall (str : string),
  STsep (__) 
        (fun _ : option (nat * ((method * string * (nat * nat)) * (list (string * string)) * string)) => __).
  intros; refine (
     is <- STRING_INSTREAM.instream_of_list_ascii (str2la str) ;
     parse <- http_parse is 0 ;
     INSTREAM.close is ;;
     {{Return parse}});
  solve [ s | destruct parse; sep fail auto ].
Qed.
