open Sign
open Syntax
open Syntax.Apx
open Print.Apx
open Meta
open MetaSub
open Match
open Recon

module I = Syntax.Int
module IP = Print.Int

let tc_constructor (sign , cG : signature * I.ctx) (u : I.universe) (tel : I.tel)
                   (n , tel', (n', es) : def_name * tel * dsig) : signature_entry * I.decl =
  Debug.print_string ("Typechecking constructor: " ^ n) ;
  let tel'', uc = check_tel (sign, cG) u tel' in
  if uc <= u then
    begin
      let check' = check (sign, (ctx_of_tel tel'') @ cG) in
      let rec check_indices es tel =
        match es, tel with
        | [], [] -> []
        | e::es', (_, x, t)::tel' ->
           let e' = check' e t in
           e'::check_indices es' (simul_subst_on_tel [x, e'] tel')
        | _ -> raise (Error.Error ("Constructor " ^ n
             ^ " does not return a term of the fully applied type for " ^ n'))
      in
      Debug.print (fun () -> "Checking indices applied to " ^ n' ^ " at the tail of signature of " ^ n
        ^ "\nes = (" ^ String.concat ", " (List.map print_exp es) ^ ")\ntel = " ^ IP.print_tel tel);
      let es' = check_indices es tel in
      Constructor (n, tel'', (n', es')), (n, tel'', (n', es'))
    end
  else
    raise (Error.Error ("Constructor " ^ n ^ " has universe " ^ print_universe uc
                        ^ " which does not fit in " ^ print_universe u
                        ^ ", the universe of the data type " ^ n'))

let rec tc_constructors (sign , cG : signature * I.ctx) (u : I.universe) (tel : I.tel)
                    (ds : decls) : signature * I.decls =
  match ds with
  | [] -> sign, []
  | d::ds ->
     let se, d' = tc_constructor (sign, cG) u tel d in
     let sign', ds' = tc_constructors (sign, cG) u tel ds in
     se::sign', d'::ds'

let tc_observation (sign , cG : signature * I.ctx) (u : I.universe) (tel : I.tel)
                   (n , tel', (m, n', es), e : def_name * tel * codsig * exp) : signature_entry * I.codecl =
  Debug.print_string ("Typechecking constructor: " ^ n) ;
  let tel'', uc = check_tel (sign, cG) u tel' in
  if uc <= u then                       (* Note: Is that check needed for codatatypes? *)
    begin
      let rec check_indices es tel =
        match es, tel with
        | [], [] -> []
        | e::es', (_, x, t)::tel' ->
           let e' = check (sign, (ctx_of_tel tel'') @ cG) e t in
           e'::check_indices es' (simul_subst_on_tel [x, e'] tel')
        | _ -> raise (Error.Error ("Constructor " ^ n
             ^ " does not return a term of the fully applied type for " ^ n'))
      in
      Debug.print (fun () -> "Checking indices applied to " ^ n' ^ " at the tail of signature of " ^ n
        ^ "\nes = (" ^ String.concat ", " (List.map print_exp es) ^ ")\ntel = " ^ IP.print_tel tel);
      let es' = check_indices es tel in
      let e' = check (sign, (m, I.App (I.Const n', es')) :: ((ctx_of_tel tel'') @ cG)) e (I.Set u) in
      Observation (n, tel'', (m, n', es'), e'), (n, tel'', (m, n', es'), e')
    end
  else
    raise (Error.Error ("Constructor " ^ n ^ " has universe " ^ print_universe uc
                        ^ " which does not fit in " ^ print_universe u
                        ^ ", the universe of the data type " ^ n'))

let rec tc_observations (sign , cG : signature * I.ctx) (u : I.universe) (tel : I.tel)
           (ds : codecls) : signature * I.codecls =
  match ds with
  | [] -> sign, []
  | d::ds ->
     let se, d' = tc_observation (sign, cG) u tel d in
     let sign', ds' = tc_observations (sign, cG) u tel ds in
     se::sign', d'::ds'

let tc_syn_constructor (sign , cG : signature * I.ctx) (tel : I.stel)
                       (n , tel', (n', es) : def_name * stel * dsig) : signature_entry * I.sdecl =
  Debug.print_string ("Typechecking syntax constructor: " ^ n) ;
  let tel'' = check_stel (sign, cG) I.Nil tel' in
  let cP = bctx_of_stel I.Nil tel'' in
  let check' = check_syn (sign, cG) cP in
  let rec check_indices es tel cP' s =
    match es, tel with
    | [], [] -> []
    | e::es', (_, x, t)::tel' ->
       let e' = check' e (I.Clos (t, s, cP')) in
       e' :: check_indices es' tel' (I.Snoc(cP', x, t)) (I.Dot(s, e'))
    | _ -> raise (Error.Error ("Constructor " ^ n
             ^ " does not return a term of the fully applied type for " ^ n'))
  in
  Debug.print (fun () -> "Checking indices applied to " ^ n' ^ " at the tail of signature of " ^ n);
  let es' = check_indices es tel cP I.id_sub in
  SConstructor (n, tel'', (n', es')), (n, tel'', (n', es'))

let rec tc_syn_constructors (sign , cG : signature * I.ctx) (tel : I.stel)
                        (ds : sdecls) : signature * I.sdecls =
  match ds with
  | [] -> sign, []
  | d::ds ->
     let se, d' = tc_syn_constructor (sign, cG) tel d in
     let sign', ds' = tc_syn_constructors (sign, cG) tel ds in
     se::sign', d'::ds'

let tc_program (sign : signature) : program -> signature * I.program =
  function
  | Data (n, ps, is, u, ds) ->
    Debug.print_string ("Typechecking data declaration: " ^ n ^ "\nps = "
                        ^ print_tel ps ^ "\nis = " ^ print_tel is);
     let ps', u' = check_tel (sign, []) u ps in
     let cG = ctx_of_tel ps' in
     let is', u'' = check_tel (sign, cG) u' is in
     let sign' = DataDef (n, ps', is', u'') :: sign in
     let sign'', ds' = tc_constructors (sign', cG) u (ps' @ is') ds in
     sign'', I.Data(n, ps', is', u'', List.rev ds')
     (* TODO Add positivity checking *)

  | Codata (n, ps, is, u, ds) ->
    Debug.print_string ("Typechecking data declaration: " ^ n ^ "\nps = "
                        ^ print_tel ps ^ "\nis = " ^ print_tel is);
    let ps', u' = check_tel (sign, []) u ps in
    let cG = ctx_of_tel ps' in
    let is', u'' = check_tel (sign, cG) u' is in
    let sign' = CodataDef (n, ps', is', u'') :: sign in
    let sign'', ds' = tc_observations (sign', cG) u (ps' @ is') ds in
    sign'', I.Codata(n, ps', is', u'', List.rev ds')

  | Spec (n, tel, ds) ->
    Debug.print_string ("Typechecking syn declaration: " ^ n);
    Debug.indent ();
    let tel' = check_stel (sign, []) I.Nil tel in
    let sign' = SpecDef (n, tel') :: sign in
    let sign'', ds' = tc_syn_constructors (sign', []) tel' ds in
    Debug.deindent ();
    sign'', I.Spec(n, tel', List.rev ds')

  | DefPM (n, tel, t, ds) ->
     Debug.print_string ("\nTypechecking pattern matching definition: " ^ n);
     Debug.indent ();
     let t' = if tel = [] then t else Pi(tel, t) in
     let t'', _u = infer_type (sign, []) t' in
     let sign', tree = Split.check_clauses sign n t'' ds in
     Debug.deindent ();
     sign', I.DefPMTree(n, t'', tree)

  | Def (n, t, e) ->
     Debug.print_string ("Typechecking definition: " ^ n);
     Debug.indent ();
     let t', _ = infer_type (sign, []) t in
     let tel, t'' = match t' with
       | I.Pi(tel, t') -> tel, t'
       | _ -> [], t'
     in
     let e' = check (sign, []) e t' in
     Debug.deindent ();
     (Definition (n, tel, t'', e', Reduces))::sign, I.Def(n, t', e')
