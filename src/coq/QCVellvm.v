From QuickChick Require Import QuickChick.
From Vellvm Require Import GenAST TopLevel LLVMAst DynamicValues.
Require Import String.
Require Import ZArith.

From ITree Require Import
     ITree
     Interp.Recursion
     Events.Exception.

Require Import ExtrOcamlBasic.
Require Import ExtrOcamlString.

(* TODO: Use the existing vellvm version of this? *)
Inductive MlResult a e :=
| MlOk : a -> MlResult a e
| MlError : e -> MlResult a e.

Extract Inductive MlResult => "result" [ "Ok" "Error" ].

Unset Guard Checking.
Fixpoint step (t : ITreeDefinition.itree IO.L5 TopLevelEnv.res_L4) : MlResult TopLevelEnv.res_L0 string
  := match observe t with
     | RetF (_,(_,(_,x))) => MlOk TopLevelEnv.res_L0 string x
     | TauF t => step t
     | VisF _ e k => MlError TopLevelEnv.res_L0 string "Uninterpreted event"
     end.
Set Guard Checking.

Definition interpret (prog : list (toplevel_entity typ (list (block typ)))) : MlResult uvalue string
  := step (TopLevelEnv.interpreter prog).

Axiom to_caml_str : string -> string.
Extract Constant to_caml_str =>
"fun (s: char list) ->
  let r = Bytes.create (List.length s) in
  let rec fill pos = function
  | [] -> r
  | c :: s -> Bytes.set r pos c; fill (pos + 1) s
  in Bytes.to_string (fill 0 s)".


Axiom llc_command : string -> int.
Extract Constant llc_command => "fun prog -> let f = open_out ""temporary_vellvm.ll"" in Printf.fprintf f ""%s"" prog; close_out f; Sys.command ""clang temporary_vellvm.ll -o vellvmqc && ./vellvmqc""".

Definition run_llc (prog : list (toplevel_entity typ (list (block typ)))) : uvalue
  := UVALUE_I8 (repr (llc_command (to_caml_str (show prog)))).

Definition vellvm_agrees_with_clang (prog : list (toplevel_entity typ (list (block typ)))) : Checker
  := 
    collect (show prog)
            match interpret prog, run_llc prog with
            | MlOk (UVALUE_I8 x), UVALUE_I8 y => checker (eq x y)
            | _, _ => checker true
            end.

Extract Constant defNumTests    => "1000".
QuickChick (forAll (run_GenLLVM gen_llvm) vellvm_agrees_with_clang).
