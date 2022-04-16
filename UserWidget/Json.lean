import Lean.Data.Json

/-!
# Json-like syntax for Lean.

Now you can write

```lean
#eval json% {
  hello : "world",
  cheese : ["edam", "cheddar", {kind : "spicy", rank : 100.2}],
  lemonCount : 100e30,
  isCool : true,
  isBug : null,
  lookACalc: $(23 + 54 * 2)
}
```
 -/

open Lean Parser
declare_syntax_cat jso
declare_syntax_cat jso_field
declare_syntax_cat jso_ident

instance : OfScientific JsonNumber where
  ofScientific mantissa exponentSign decimalExponent :=
    if exponentSign then
      {mantissa := mantissa, exponent := decimalExponent}
    else
      {mantissa := mantissa * (10: Nat)^decimalExponent, exponent := 0}

instance : Neg JsonNumber where
  neg jn := ⟨- jn.mantissa, jn.exponent⟩

syntax "[" jso,* "]" : jso
syntax "-"? scientific : jso
syntax "-"? num : jso
syntax str : jso
syntax "true" : jso
syntax "false" : jso
syntax "null" : jso
syntax ident : jso_ident
syntax "$(" term ")" : jso_ident
syntax str : jso_ident
syntax jso_ident ": " jso : jso_field
syntax "{" jso_field,* "}" : jso
syntax "$(" term ")" : jso
syntax "json% " jso  : term

macro_rules
  | `(json% $($t))          => `(Lean.toJson $t)
  | `(json% null)           => `(Lean.Json.null)
  | `(json% true)           => `(Lean.Json.bool Bool.true)
  | `(json% false)          => `(Lean.Json.bool Bool.false)
  | `(json% $n:str)         => `(Lean.Json.str $n)
  | `(json% $n:num)         => `(Lean.Json.num $n)
  | `(json% $n:scientific)  => `(Lean.Json.num $n)
  | `(json% -$n:num)        => `(Lean.Json.num (-$n))
  | `(json% -$n:scientific) => `(Lean.Json.num (-$n))
  | `(json% [$[$xs],*])     => `(Lean.Json.arr #[$[json% $xs],*])
  | `(json% {$[$ks:jso_ident : $vs:jso],*}) =>
    let ks := ks.map fun
      | `(jso_ident| $k:ident)   => (k.getId |> toString |> quote)
      | `(jso_ident| $k:str)     => k
      | `(jso_ident| $($k:term)) => k
      | stx                      => panic! s!"unrecognized ident syntax {stx}"
    `(Lean.Json.mkObj [$[($ks, json% $vs)],*])
