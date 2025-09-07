///| Union type `A | B` for JavaScript values.
#external
type Union2[_, _]

///|
pub fn[A : Cast, B] Union2::to0(self : Union2[A, B]) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast] Union2::to1(self : Union2[A, B]) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B] Union2::from0(value : A) -> Union2[A, B] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast] Union2::from1(value : B) -> Union2[A, B] {
  Cast::from(value).cast()
}

///| Union type `A | B | C` for JavaScript values.
#external
type Union3[_, _, _]

///|
pub fn[A : Cast, B, C] Union3::to0(self : Union3[A, B, C]) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast, C] Union3::to1(self : Union3[A, B, C]) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C : Cast] Union3::to2(self : Union3[A, B, C]) -> C? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B, C] Union3::from0(value : A) -> Union3[A, B, C] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast, C] Union3::from1(value : B) -> Union3[A, B, C] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C : Cast] Union3::from2(value : C) -> Union3[A, B, C] {
  Cast::from(value).cast()
}

///| Union type `A | B | C | D` for JavaScript values.
#external
type Union4[_, _, _, _]

///|
pub fn[A : Cast, B, C, D] Union4::to0(self : Union4[A, B, C, D]) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast, C, D] Union4::to1(self : Union4[A, B, C, D]) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C : Cast, D] Union4::to2(self : Union4[A, B, C, D]) -> C? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D : Cast] Union4::to3(self : Union4[A, B, C, D]) -> D? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B, C, D] Union4::from0(value : A) -> Union4[A, B, C, D] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast, C, D] Union4::from1(value : B) -> Union4[A, B, C, D] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C : Cast, D] Union4::from2(value : C) -> Union4[A, B, C, D] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D : Cast] Union4::from3(value : D) -> Union4[A, B, C, D] {
  Cast::from(value).cast()
}

///| Union type `A | B | C | D | E` for JavaScript values.
#external
type Union5[_, _, _, _, _]

///|
pub fn[A : Cast, B, C, D, E] Union5::to0(self : Union5[A, B, C, D, E]) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast, C, D, E] Union5::to1(self : Union5[A, B, C, D, E]) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C : Cast, D, E] Union5::to2(self : Union5[A, B, C, D, E]) -> C? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D : Cast, E] Union5::to3(self : Union5[A, B, C, D, E]) -> D? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E : Cast] Union5::to4(self : Union5[A, B, C, D, E]) -> E? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B, C, D, E] Union5::from0(value : A) -> Union5[A, B, C, D, E] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast, C, D, E] Union5::from1(value : B) -> Union5[A, B, C, D, E] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C : Cast, D, E] Union5::from2(value : C) -> Union5[A, B, C, D, E] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D : Cast, E] Union5::from3(value : D) -> Union5[A, B, C, D, E] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E : Cast] Union5::from4(value : E) -> Union5[A, B, C, D, E] {
  Cast::from(value).cast()
}

///| Union type `A | B | C | D | E | F` for JavaScript values.
#external
type Union6[_, _, _, _, _, _]

///|
pub fn[A : Cast, B, C, D, E, F] Union6::to0(
  self : Union6[A, B, C, D, E, F],
) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast, C, D, E, F] Union6::to1(
  self : Union6[A, B, C, D, E, F],
) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C : Cast, D, E, F] Union6::to2(
  self : Union6[A, B, C, D, E, F],
) -> C? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D : Cast, E, F] Union6::to3(
  self : Union6[A, B, C, D, E, F],
) -> D? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E : Cast, F] Union6::to4(
  self : Union6[A, B, C, D, E, F],
) -> E? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E, F : Cast] Union6::to5(
  self : Union6[A, B, C, D, E, F],
) -> F? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B, C, D, E, F] Union6::from0(
  value : A,
) -> Union6[A, B, C, D, E, F] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast, C, D, E, F] Union6::from1(
  value : B,
) -> Union6[A, B, C, D, E, F] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C : Cast, D, E, F] Union6::from2(
  value : C,
) -> Union6[A, B, C, D, E, F] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D : Cast, E, F] Union6::from3(
  value : D,
) -> Union6[A, B, C, D, E, F] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E : Cast, F] Union6::from4(
  value : E,
) -> Union6[A, B, C, D, E, F] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E, F : Cast] Union6::from5(
  value : F,
) -> Union6[A, B, C, D, E, F] {
  Cast::from(value).cast()
}

///| Union type `A | B | C | D | E | F | G` for JavaScript values.
#external
type Union7[_, _, _, _, _, _, _]

///|
pub fn[A : Cast, B, C, D, E, F, G] Union7::to0(
  self : Union7[A, B, C, D, E, F, G],
) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast, C, D, E, F, G] Union7::to1(
  self : Union7[A, B, C, D, E, F, G],
) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C : Cast, D, E, F, G] Union7::to2(
  self : Union7[A, B, C, D, E, F, G],
) -> C? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D : Cast, E, F, G] Union7::to3(
  self : Union7[A, B, C, D, E, F, G],
) -> D? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E : Cast, F, G] Union7::to4(
  self : Union7[A, B, C, D, E, F, G],
) -> E? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E, F : Cast, G] Union7::to5(
  self : Union7[A, B, C, D, E, F, G],
) -> F? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E, F, G : Cast] Union7::to6(
  self : Union7[A, B, C, D, E, F, G],
) -> G? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B, C, D, E, F, G] Union7::from0(
  value : A,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast, C, D, E, F, G] Union7::from1(
  value : B,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C : Cast, D, E, F, G] Union7::from2(
  value : C,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D : Cast, E, F, G] Union7::from3(
  value : D,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E : Cast, F, G] Union7::from4(
  value : E,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E, F : Cast, G] Union7::from5(
  value : F,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E, F, G : Cast] Union7::from6(
  value : G,
) -> Union7[A, B, C, D, E, F, G] {
  Cast::from(value).cast()
}

///| Union type `A | B | C | D | E | F | G | H` for JavaScript values.
#external
type Union8[_, _, _, _, _, _, _, _]

///|
pub fn[A : Cast, B, C, D, E, F, G, H] Union8::to0(
  self : Union8[A, B, C, D, E, F, G, H],
) -> A? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B : Cast, C, D, E, F, G, H] Union8::to1(
  self : Union8[A, B, C, D, E, F, G, H],
) -> B? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C : Cast, D, E, F, G, H] Union8::to2(
  self : Union8[A, B, C, D, E, F, G, H],
) -> C? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D : Cast, E, F, G, H] Union8::to3(
  self : Union8[A, B, C, D, E, F, G, H],
) -> D? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E : Cast, F, G, H] Union8::to4(
  self : Union8[A, B, C, D, E, F, G, H],
) -> E? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E, F : Cast, G, H] Union8::to5(
  self : Union8[A, B, C, D, E, F, G, H],
) -> F? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E, F, G : Cast, H] Union8::to6(
  self : Union8[A, B, C, D, E, F, G, H],
) -> G? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A, B, C, D, E, F, G, H : Cast] Union8::to7(
  self : Union8[A, B, C, D, E, F, G, H],
) -> H? {
  Cast::into(Value::cast_from(self))
}

///|
pub fn[A : Cast, B, C, D, E, F, G, H] Union8::from0(
  value : A,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B : Cast, C, D, E, F, G, H] Union8::from1(
  value : B,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C : Cast, D, E, F, G, H] Union8::from2(
  value : C,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D : Cast, E, F, G, H] Union8::from3(
  value : D,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E : Cast, F, G, H] Union8::from4(
  value : E,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E, F : Cast, G, H] Union8::from5(
  value : F,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E, F, G : Cast, H] Union8::from6(
  value : G,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}

///|
pub fn[A, B, C, D, E, F, G, H : Cast] Union8::from7(
  value : H,
) -> Union8[A, B, C, D, E, F, G, H] {
  Cast::from(value).cast()
}
